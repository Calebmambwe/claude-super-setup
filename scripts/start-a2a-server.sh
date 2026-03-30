#!/usr/bin/env bash
# Start the A2A server for the VPS Claude agent
# Usage: start-a2a-server.sh [--background]
set -euo pipefail

A2A_DIR="$HOME/.claude-super-setup/claude_a2a"
VENV="$A2A_DIR/.venv"
LOG="$HOME/.claude/logs/a2a-server.log"
PID_FILE="$HOME/.claude/a2a-server.pid"

mkdir -p "$(dirname "$LOG")"

# Load environment
if [ -f "$HOME/.claude/.env.local" ]; then
    set -a
    source "$HOME/.claude/.env.local"
    set +a
fi

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "A2A server already running (PID $OLD_PID)"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# Activate venv
if [ ! -d "$VENV" ]; then
    echo "ERROR: Virtual environment not found at $VENV"
    echo "Run: cd $A2A_DIR && uv venv .venv && source .venv/bin/activate && uv pip install -e ."
    exit 1
fi

PYTHON="$VENV/bin/python3"
export PYTHONPATH="$HOME/.claude-super-setup:${PYTHONPATH:-}"

# Default port
export A2A_PORT="${A2A_PORT:-9999}"
export A2A_HOST="${A2A_HOST:-0.0.0.0}"

if [ "${1:-}" = "--background" ]; then
    echo "Starting A2A server in background on port $A2A_PORT..."
    nohup "$PYTHON" -m claude_a2a >> "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    echo "PID: $(cat "$PID_FILE")"
    echo "Log: $LOG"
else
    echo "Starting A2A server on port $A2A_PORT..."
    "$PYTHON" -m claude_a2a
fi
