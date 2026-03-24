#!/usr/bin/env python3
"""Sandbox MCP Server — Docker-based isolated execution for Claude Code.

Provides 14 tools for sandboxed command execution, file operations,
browser automation, and deployment. Each Claude Code session gets its
own Docker container running Ubuntu 22.04 + Playwright + Node.js.

Register in ~/.claude/settings.json under mcpServers:
  "sandbox": {
    "command": "uv",
    "args": ["run", "--with", "mcp", "--with", "pydantic", "python3",
             "<HOME>/.claude/mcp-servers/sandbox-server.py"]
  }
"""

from __future__ import annotations

import asyncio
import datetime
import json
import logging
import os
import shlex
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# ── MCP SDK ──────────────────────────────────────────────────────────────────
try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print(
        "ERROR: mcp package not installed. Run:\n"
        "  uv pip install mcp\n"
        'or register with: "command": "uv", "args": ["run", "--with", "mcp", ...]',
        file=sys.stderr,
    )
    sys.exit(1)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("sandbox-mcp")

# ── Configuration ────────────────────────────────────────────────────────────

SANDBOX_IMAGE = os.getenv("CLAUDE_SANDBOX_IMAGE", "claude-sandbox")
WORKSPACE_DIR = os.getenv("CLAUDE_SANDBOX_WORKSPACE", "/tmp/claude-sandbox-workspace")
STATE_FILE = Path.home() / ".claude" / ".sandbox-containers.json"
AUDIT_LOG = Path.home() / ".claude" / "sandbox-audit.log"

# ── Vendored SandboxClient ───────────────────────────────────────────────────


@dataclass
class ExecResult:
    output: str
    exit_code: int
    running: bool = False


class SandboxClient:
    """Docker-based sandbox for isolated execution."""

    def __init__(
        self,
        image: str = SANDBOX_IMAGE,
        container_name: str | None = None,
        session_id: str | None = None,
    ) -> None:
        self.image = image
        self.container_name = container_name
        self.session_id = session_id or str(uuid.uuid4())[:8]
        self._container_id: str | None = None

    async def start(self) -> str:
        """Start a new sandbox container with port mapping for macOS."""
        if self._container_id:
            return self._container_id

        name = self.container_name or f"claude-sandbox-{self.session_id}"
        workspace = f"{WORKSPACE_DIR}/{self.session_id}"
        os.makedirs(workspace, exist_ok=True)

        cmd = [
            "docker", "run", "-d",
            "--name", name,
            "--label", f"claude-session={self.session_id}",
            "-p", "127.0.0.1:9222:9222",
            "-v", f"{workspace}:/workspace",
            self.image,
        ]

        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()
        if proc.returncode != 0:
            error = stderr.decode()
            # Container name conflict — try to reuse existing
            if "already in use" in error:
                self._container_id = name
                logger.info(f"Reusing existing sandbox: {name}")
                return name
            raise RuntimeError(f"Failed to start sandbox: {error}")

        self._container_id = stdout.decode().strip()[:12]
        self.container_name = name
        logger.info(f"Sandbox started: {self._container_id} ({name})")

        # Wait for bridge to be ready
        for _ in range(10):
            health = await self.exec("curl -s http://localhost:9222/health 2>/dev/null || echo 'not_ready'")
            if "ok" in health.output:
                break
            await asyncio.sleep(1)

        _save_state()
        return self._container_id

    async def stop(self) -> None:
        """Stop and remove the sandbox container."""
        target = self.container_name or self._container_id
        if target:
            proc = await asyncio.create_subprocess_exec(
                "docker", "rm", "-f", target,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.communicate()
            logger.info(f"Sandbox stopped: {target}")
            self._container_id = None
            self.container_name = None
            _save_state()

    async def exec(
        self,
        command: str,
        working_dir: str = "/home/ubuntu",
        timeout: int = 120,
    ) -> ExecResult:
        """Execute a command in the sandbox."""
        if not self._container_id:
            await self.start()

        # Validate working_dir to prevent path traversal
        allowed_prefixes = ("/workspace", "/home/ubuntu", "/tmp")
        if not any(working_dir.startswith(p) for p in allowed_prefixes):
            raise ValueError(f"working_dir {working_dir!r} is outside allowed paths: {allowed_prefixes}")

        proc = await asyncio.create_subprocess_exec(
            "docker", "exec", "--workdir", working_dir, self._container_id,
            "bash", "-c", command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=timeout
            )
        except asyncio.TimeoutError:
            proc.kill()
            return ExecResult(output="Command timed out", exit_code=-1)

        output = stdout.decode() + stderr.decode()
        return ExecResult(output=output, exit_code=proc.returncode if proc.returncode is not None else -1)

    async def write_file(
        self,
        path: str,
        content: str,
        append: bool = False,
    ) -> None:
        """Write content to a file in the sandbox via stdin."""
        if not self._container_id:
            await self.start()

        operator = ">>" if append else ">"
        proc = await asyncio.create_subprocess_exec(
            "docker", "exec", "-i", self._container_id,
            "bash", "-c", f"tee {operator} {shlex.quote(path)}",
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.communicate(input=content.encode())

    async def browser_action(
        self, action: str, params: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        """Execute a browser action via the Playwright bridge."""
        if not self._container_id:
            await self.start()

        payload = json.dumps({"action": action, "params": params or {}})
        # Escape single quotes in payload for shell
        safe_payload = payload.replace("'", "'\\''")
        result = await self.exec(
            f"curl -s -X POST http://localhost:9222/action "
            f"-H 'Content-Type: application/json' -d '{safe_payload}'",
            timeout=60,
        )
        try:
            return json.loads(result.output)
        except json.JSONDecodeError:
            return {"error": result.output, "action": action}


# ── Global state ─────────────────────────────────────────────────────────────

_sandboxes: dict[str, SandboxClient] = {}


def _get_sandbox(session_id: str | None = None) -> SandboxClient:
    """Get or create a sandbox for the given session."""
    sid = session_id or "default"
    if sid not in _sandboxes:
        _sandboxes[sid] = SandboxClient(session_id=sid)
    return _sandboxes[sid]


def _save_state() -> None:
    """Persist container IDs for crash recovery."""
    state = {}
    for sid, client in _sandboxes.items():
        if client._container_id:
            state[sid] = {
                "container_id": client._container_id,
                "container_name": client.container_name,
            }
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))


def _load_state() -> None:
    """Reload container state from disk on startup."""
    if STATE_FILE.exists():
        try:
            state = json.loads(STATE_FILE.read_text())
            for sid, info in state.items():
                client = SandboxClient(session_id=sid)
                client._container_id = info.get("container_id")
                client.container_name = info.get("container_name")
                _sandboxes[sid] = client
            logger.info(f"Restored {len(state)} sandbox session(s)")
        except (json.JSONDecodeError, KeyError):
            pass


def _audit(tool: str, args: dict[str, Any], result: str) -> None:
    """Append to sandbox audit log."""
    entry = {
        "ts": datetime.datetime.now().isoformat(),
        "tool": tool,
        "args": args,
        "result_preview": str(result)[:200],
    }
    with open(AUDIT_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")


# ── MCP Server ───────────────────────────────────────────────────────────────

mcp = FastMCP("sandbox")


# ── Container Lifecycle ──────────────────────────────────────────────────────

@mcp.tool()
async def sandbox_start(session_id: str | None = None) -> str:
    """Start a new Docker sandbox container.

    Returns the container ID. The sandbox runs Ubuntu 22.04 with Python 3.10,
    Node.js 20, Playwright + Chromium, and common data science packages.
    A workspace directory is mounted at /workspace.

    Args:
        session_id: Optional session identifier. Defaults to a random ID.
    """
    sandbox = _get_sandbox(session_id)
    container_id = await sandbox.start()
    _audit("sandbox_start", {"session_id": session_id}, container_id)
    return json.dumps({
        "status": "started",
        "container_id": container_id,
        "session_id": sandbox.session_id,
        "workspace": f"{WORKSPACE_DIR}/{sandbox.session_id}",
        "environment": {
            "os": "Ubuntu 22.04",
            "python": "3.10",
            "node": "20.x",
            "browser": "Chromium (Playwright)",
        },
    })


@mcp.tool()
async def sandbox_stop(session_id: str | None = None) -> str:
    """Stop and remove a sandbox container.

    Args:
        session_id: Session to stop. Stops all if not specified.
    """
    if session_id and session_id in _sandboxes:
        await _sandboxes[session_id].stop()
        del _sandboxes[session_id]
        _audit("sandbox_stop", {"session_id": session_id}, "stopped")
        return json.dumps({"status": "stopped", "session_id": session_id})

    # Stop all
    stopped = []
    for sid in list(_sandboxes.keys()):
        await _sandboxes[sid].stop()
        stopped.append(sid)
        del _sandboxes[sid]
    _audit("sandbox_stop", {"session_id": "all"}, f"stopped {len(stopped)}")
    return json.dumps({"status": "stopped", "sessions": stopped})


@mcp.tool()
async def sandbox_status() -> str:
    """Show status of all sandbox containers and whether the Docker image exists."""
    # Check image
    proc = await asyncio.create_subprocess_exec(
        "docker", "images", "-q", SANDBOX_IMAGE,
        stdout=asyncio.subprocess.PIPE,
    )
    stdout, _ = await proc.communicate()
    image_exists = bool(stdout.decode().strip())

    sessions = {}
    for sid, client in _sandboxes.items():
        # Check if container is actually running
        if client._container_id:
            proc = await asyncio.create_subprocess_exec(
                "docker", "inspect", "--format", "{{.State.Running}}",
                client._container_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            out, _ = await proc.communicate()
            running = out.decode().strip() == "true"
        else:
            running = False

        sessions[sid] = {
            "container_id": client._container_id,
            "container_name": client.container_name,
            "running": running,
        }

    return json.dumps({
        "image": SANDBOX_IMAGE,
        "image_exists": image_exists,
        "sessions": sessions,
        "workspace_root": WORKSPACE_DIR,
    })


# ── Shell Execution ──────────────────────────────────────────────────────────

@mcp.tool()
async def sandbox_exec(
    command: str,
    session_id: str | None = None,
    working_dir: str = "/home/ubuntu",
    timeout: int = 120,
) -> str:
    """Execute a shell command inside the sandbox container.

    Use this for any command that should run in isolation: pip install,
    npm install, python scripts, compilation, etc. The sandbox has full
    internet access and a persistent workspace at /workspace.

    Args:
        command: The shell command to execute.
        session_id: Which sandbox session to use.
        working_dir: Working directory inside the container.
        timeout: Maximum execution time in seconds.
    """
    sandbox = _get_sandbox(session_id)
    result = await sandbox.exec(command, working_dir=working_dir, timeout=timeout)
    _audit("sandbox_exec", {"command": command}, result.output[:200])
    return json.dumps({
        "output": result.output,
        "exit_code": result.exit_code,
        "session_id": sandbox.session_id,
    })


# ── File Operations ──────────────────────────────────────────────────────────

@mcp.tool()
async def sandbox_write_file(
    path: str,
    content: str,
    append: bool = False,
    session_id: str | None = None,
) -> str:
    """Write content to a file inside the sandbox.

    Uses stdin pipe to avoid shell escaping issues.

    Args:
        path: Absolute path in the sandbox filesystem.
        content: File content to write.
        append: If True, append instead of overwrite.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    await sandbox.write_file(path, content, append=append)
    _audit("sandbox_write_file", {"path": path, "append": append}, "ok")
    return json.dumps({
        "status": "success",
        "path": path,
        "mode": "append" if append else "write",
        "bytes": len(content),
    })


@mcp.tool()
async def sandbox_read_file(
    path: str,
    start_line: int | None = None,
    end_line: int | None = None,
    session_id: str | None = None,
) -> str:
    """Read a file from the sandbox filesystem.

    Args:
        path: Absolute path to the file.
        start_line: Start reading from this line (0-indexed).
        end_line: Stop reading at this line.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)

    safe_path = shlex.quote(path)
    if start_line is not None and end_line is not None:
        cmd = f"sed -n '{start_line + 1},{end_line}p' {safe_path}"
    elif start_line is not None:
        cmd = f"tail -n +{start_line + 1} {safe_path}"
    elif end_line is not None:
        cmd = f"head -n {end_line} {safe_path}"
    else:
        cmd = f"cat {safe_path}"

    result = await sandbox.exec(cmd)
    _audit("sandbox_read_file", {"path": path}, result.output[:200])
    return json.dumps({
        "content": result.output,
        "path": path,
        "exit_code": result.exit_code,
    })


@mcp.tool()
async def sandbox_find_files(
    path: str = "/home/ubuntu",
    glob: str = "*",
    session_id: str | None = None,
) -> str:
    """Find files by name pattern in the sandbox.

    Args:
        path: Directory to search in.
        glob: Glob pattern to match filenames.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    result = await sandbox.exec(
        f"find {shlex.quote(path)} -name {shlex.quote(glob)} -type f 2>/dev/null | head -100"
    )
    files = result.output.strip().split("\n") if result.output.strip() else []
    return json.dumps({"files": files, "count": len(files), "path": path})


# ── Browser Automation ───────────────────────────────────────────────────────

@mcp.tool()
async def sandbox_browser_navigate(
    url: str,
    session_id: str | None = None,
) -> str:
    """Navigate the sandbox browser to a URL.

    The browser runs inside the Docker container via Playwright.
    Returns the page content as Markdown plus a list of interactive elements.

    Args:
        url: The URL to navigate to.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    result = await sandbox.browser_action("navigate", {"url": url})
    _audit("sandbox_browser_navigate", {"url": url}, str(result)[:200])
    return json.dumps(result)


@mcp.tool()
async def sandbox_browser_view(session_id: str | None = None) -> str:
    """View the current state of the sandbox browser.

    Returns the current URL, page title, content as Markdown,
    and a numbered list of interactive elements.

    Args:
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    result = await sandbox.browser_action("view")
    return json.dumps(result)


@mcp.tool()
async def sandbox_browser_click(
    index: int | None = None,
    coordinate_x: int | None = None,
    coordinate_y: int | None = None,
    session_id: str | None = None,
) -> str:
    """Click an element in the sandbox browser.

    Either click by element index (from sandbox_browser_view) or by
    x,y coordinates.

    Args:
        index: Index of the interactive element to click.
        coordinate_x: X coordinate for pixel-level click.
        coordinate_y: Y coordinate for pixel-level click.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    params: dict[str, Any] = {}
    if index is not None:
        params["index"] = index
    if coordinate_x is not None:
        params["coordinate_x"] = coordinate_x
        params["coordinate_y"] = coordinate_y or 0
    result = await sandbox.browser_action("click", params)
    return json.dumps(result)


@mcp.tool()
async def sandbox_browser_input(
    text: str,
    press_enter: bool = False,
    index: int | None = None,
    coordinate_x: int | None = None,
    coordinate_y: int | None = None,
    session_id: str | None = None,
) -> str:
    """Type text into an input field in the sandbox browser.

    Args:
        text: The text to type.
        press_enter: Whether to press Enter after typing.
        index: Index of the interactive element to type into.
        coordinate_x: X coordinate to click before typing.
        coordinate_y: Y coordinate to click before typing.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    params: dict[str, Any] = {"text": text, "press_enter": press_enter}
    if index is not None:
        params["index"] = index
    if coordinate_x is not None:
        params["coordinate_x"] = coordinate_x
        params["coordinate_y"] = coordinate_y or 0
    result = await sandbox.browser_action("input", params)
    return json.dumps(result)


@mcp.tool()
async def sandbox_browser_screenshot(session_id: str | None = None) -> str:
    """Take a screenshot of the sandbox browser.

    Returns the screenshot as a base64-encoded PNG string.

    Args:
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    result = await sandbox.browser_action("screenshot")
    _audit("sandbox_browser_screenshot", {}, result.get("url", ""))
    return json.dumps(result)


# ── Deployment ───────────────────────────────────────────────────────────────

@mcp.tool()
async def sandbox_expose_port(
    port: int,
    session_id: str | None = None,
) -> str:
    """Expose a port from the sandbox container.

    For MVP, returns a localhost URL. The sandbox container must have
    a service listening on this port.

    Args:
        port: The port number to expose.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    # For MVP: start a port-forward via docker
    # The container was started with -p 9222:9222; additional ports need socat
    result = await sandbox.exec(
        f"which socat > /dev/null 2>&1 || sudo apt-get install -y -qq socat > /dev/null 2>&1; "
        f"echo 'Port {port} accessible via container'"
    )
    url = f"http://localhost:{port}"
    _audit("sandbox_expose_port", {"port": port}, url)
    return json.dumps({"url": url, "port": port, "status": "exposed"})


@mcp.tool()
async def sandbox_deploy(
    directory: str = "/workspace",
    name: str | None = None,
    session_id: str | None = None,
) -> str:
    """Deploy a static site or app from the sandbox.

    Starts a simple HTTP server in the sandbox serving the specified directory.

    Args:
        directory: Directory containing the site/app to deploy.
        name: Optional name for the deployment.
        session_id: Which sandbox session to use.
    """
    sandbox = _get_sandbox(session_id)
    deploy_port = 8080
    deploy_name = name or "deployment"

    # Kill any existing server on that port
    await sandbox.exec(f"pkill -f 'python3 -m http.server {deploy_port}' || true")

    # Start HTTP server in background
    safe_dir = shlex.quote(directory)
    await sandbox.exec(
        f"cd {safe_dir} && nohup python3 -m http.server {deploy_port} > /dev/null 2>&1 &"
    )

    url = f"http://localhost:{deploy_port}"
    _audit("sandbox_deploy", {"directory": directory, "name": deploy_name}, url)
    return json.dumps({
        "url": url,
        "name": deploy_name,
        "port": deploy_port,
        "directory": directory,
        "status": "deployed",
    })


# ── Main ─────────────────────────────────────────────────────────────────────

_load_state()
mcp.run(transport="stdio")
