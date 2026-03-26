#!/usr/bin/env python3
"""Structured JSONL logger for agent observability.

Logs every tool call, task lifecycle event, and error with full context.
Output goes to ~/.claude/logs/agent-events.jsonl (append-only).

Usage:
    from agent_logger import log_event, log_tool_call, log_task_start, log_task_complete, log_error

    log_task_start(task_id="abc", prompt="Build a todo app", mode="agent")
    log_tool_call(task_id="abc", tool="Bash", input={"command": "ls"}, output="file.txt", duration_ms=45)
    log_task_complete(task_id="abc", success=True, duration_ms=12000, credits=5)
    log_error(task_id="abc", error="TimeoutError", context={"timeout_ms": 30000})
"""

import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


LOG_DIR = Path.home() / ".claude" / "logs"
LOG_FILE = LOG_DIR / "agent-events.jsonl"
MAX_LOG_SIZE_MB = 50


def _ensure_log_dir() -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)


def _rotate_if_needed() -> None:
    """Rotate log file if it exceeds MAX_LOG_SIZE_MB."""
    if LOG_FILE.exists() and LOG_FILE.stat().st_size > MAX_LOG_SIZE_MB * 1024 * 1024:
        archive = LOG_FILE.with_suffix(f".{int(time.time())}.jsonl")
        LOG_FILE.rename(archive)


def log_event(
    event_type: str,
    *,
    task_id: str | None = None,
    data: dict[str, Any] | None = None,
    level: str = "info",
) -> None:
    """Write a single structured event to the JSONL log."""
    _ensure_log_dir()
    _rotate_if_needed()

    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "event": event_type,
        "level": level,
        "pid": os.getpid(),
        "session_id": os.environ.get("CLAUDE_SESSION_ID", "unknown"),
    }
    if task_id:
        entry["task_id"] = task_id
    if data:
        entry["data"] = data

    line = json.dumps(entry, separators=(",", ":"), default=str)

    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def log_task_start(
    task_id: str,
    prompt: str,
    mode: str = "auto",
    agent_profile: str = "quality",
) -> None:
    log_event(
        "task.start",
        task_id=task_id,
        data={
            "prompt": prompt[:500],
            "mode": mode,
            "agent_profile": agent_profile,
        },
    )


def log_task_complete(
    task_id: str,
    success: bool,
    duration_ms: int,
    credits: int = 0,
    result_length: int = 0,
) -> None:
    log_event(
        "task.complete",
        task_id=task_id,
        data={
            "success": success,
            "duration_ms": duration_ms,
            "credits": credits,
            "result_length": result_length,
        },
        level="info" if success else "error",
    )


def log_tool_call(
    task_id: str,
    tool: str,
    input_summary: str = "",
    output_summary: str = "",
    duration_ms: int = 0,
    success: bool = True,
) -> None:
    log_event(
        "tool.call",
        task_id=task_id,
        data={
            "tool": tool,
            "input": input_summary[:200],
            "output": output_summary[:200],
            "duration_ms": duration_ms,
            "success": success,
        },
    )


def log_error(
    task_id: str | None = None,
    error: str = "",
    context: dict[str, Any] | None = None,
) -> None:
    log_event(
        "error",
        task_id=task_id,
        data={
            "error": error[:500],
            "context": context or {},
        },
        level="error",
    )


def log_agent_step(
    task_id: str,
    step_number: int,
    tool: str,
    status: str,
    message: str = "",
) -> None:
    log_event(
        "agent.step",
        task_id=task_id,
        data={
            "step": step_number,
            "tool": tool,
            "status": status,
            "message": message[:300],
        },
    )


# CLI interface for testing
if __name__ == "__main__":
    if len(sys.argv) > 1:
        event_type = sys.argv[1]
        log_event(event_type, data={"args": sys.argv[2:]})
        print(f"Logged: {event_type}")
    else:
        # Demo
        log_task_start("demo-001", "Build a hello world app", "agent")
        log_tool_call("demo-001", "Bash", "ls -la", "total 42...", 15)
        log_tool_call("demo-001", "Write", "src/app.ts", "created", 8)
        log_task_complete("demo-001", True, 5000, 3, 150)
        print(f"Demo events logged to {LOG_FILE}")
