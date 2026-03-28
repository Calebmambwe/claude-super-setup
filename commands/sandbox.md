---
description: "Manage Docker sandbox — isolated execution environment for Claude Code"
allowed-tools: "Bash, mcp__sandbox__*"
---

# /sandbox — Docker Sandbox Management

You are managing an isolated Docker sandbox environment. Parse `$ARGUMENTS` to determine the sub-command.

## Sub-commands

### `/sandbox start` (or no arguments)
1. Call `mcp__sandbox__sandbox_start()` to start a Docker container
2. Start the bridge server: `cd ~/.claude && python3 sandbox-bridge.py &`
3. Start the dashboard: `cd ~/.claude/sandbox-dashboard && npm run dev &`
4. Tell the user to open http://localhost:7334 in VS Code Simple Browser to see the visual workspace
5. Report the sandbox status

### `/sandbox stop`
1. Call `mcp__sandbox__sandbox_stop()` to stop all containers
2. Kill the bridge server: `pkill -f sandbox-bridge.py`
3. Kill the dashboard: `pkill -f "next dev.*7334"`
4. Report cleanup complete

### `/sandbox status`
1. Call `mcp__sandbox__sandbox_status()` to check containers and image
2. Check if bridge server is running: `pgrep -f sandbox-bridge.py`
3. Check if dashboard is running: `pgrep -f "next dev.*7334"`
4. Report all statuses

### `/sandbox build`
1. Run `bash ~/.claude/sandbox/build.sh` to build the Docker image
2. Report the result

### `/sandbox browse <url>`
1. Ensure sandbox is started
2. Call `mcp__sandbox__sandbox_browser_navigate(url="<url>")`
3. Report the page title and content summary

### `/sandbox exec <command>`
1. Ensure sandbox is started
2. Call `mcp__sandbox__sandbox_exec(command="<command>")`
3. Report the output

### `/sandbox deploy [directory]`
1. Call `mcp__sandbox__sandbox_deploy(directory="<directory>")`
2. Report the deployment URL

## Important
- If the Docker image doesn't exist yet, prompt the user to run `/sandbox build` first
- Always check sandbox status before exec/browse operations
- The sandbox runs Ubuntu 22.04 with Python 3.10, Node.js 20, and Playwright
- Workspace files persist at /tmp/claude-sandbox-workspace/
