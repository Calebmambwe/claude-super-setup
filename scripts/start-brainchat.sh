#!/usr/bin/env bash
# Start BrainChat — voice brainstorm web app
# Usage: start-brainchat.sh [--background]
set -euo pipefail

APP_DIR="$HOME/.claude-super-setup/apps/brainchat"
LOG="$HOME/.claude/logs/brainchat.log"
PID_FILE="$HOME/.claude/brainchat.pid"

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
        echo "BrainChat already running (PID $OLD_PID)"
        echo "URL: http://$(hostname -I | awk '{print $1}'):3010"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

cd "$APP_DIR"

# Install deps if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    pnpm install 2>&1 | tail -3
fi

export PORT=3010

if [ "${1:-}" = "--background" ]; then
    echo "Starting BrainChat in background..."
    nohup pnpm dev >> "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 3
    IP=$(hostname -I | awk '{print $1}')
    echo "BrainChat running!"
    echo "  Local:  http://localhost:3010"
    echo "  Network: http://${IP}:3010"
    echo "  PID: $(cat "$PID_FILE")"
    echo "  Log: $LOG"
else
    echo "Starting BrainChat..."
    pnpm dev
fi
