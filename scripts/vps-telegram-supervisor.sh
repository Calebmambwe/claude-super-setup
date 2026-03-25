#!/usr/bin/env bash
set -euo pipefail

# VPS Telegram Supervisor — Manages Claude listener via tmux
# Claude Code REQUIRES a TTY — cannot run under supervisord directly.
# This script launches Claude inside tmux and monitors it, restarting on crash.
# Designed to be run by supervisord (which restarts THIS script if it dies).

LOG_FILE="$HOME/.claude/logs/telegram-supervisor.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# --- Load bot credentials for crash alerts ---
BOT_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$HOME/.claude/channels/telegram/.env" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//' | tr -d '[:space:]' || echo "")
CHAT_ID=""
if [ -f "$HOME/.claude/channels/telegram/access.json" ]; then
  CHAT_ID=$(python3 -c "import json; print(json.load(open('$HOME/.claude/channels/telegram/access.json')).get('allowFrom',[''])[0])" 2>/dev/null || echo "")
fi

notify() {
  local MSG="$1"
  if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${CHAT_ID}" \
      --data-urlencode "text=${MSG}" > /dev/null 2>&1 || true
  fi
}

# --- NVM setup ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
export PATH="$HOME/.nvm/versions/node/v22.22.2/bin:$HOME/.bun/bin:$PATH"

CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.nvm/versions/node/v22.22.2/bin/claude")
SESSION_NAME="claude-telegram"

RESTART_COUNT=0
MAX_RAPID_RESTARTS=20
LAST_START=0

log "=== Supervisor starting (tmux mode) ==="

start_tmux_session() {
  # Kill any existing session
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
  pkill -f "bun.*server.ts" 2>/dev/null || true
  sleep 2

  # Launch Claude in tmux (provides the TTY it needs)
  tmux new-session -d -s "$SESSION_NAME" "$CLAUDE_BIN --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official"
  sleep 5

  # Auto-approve trust prompt
  tmux send-keys -t "$SESSION_NAME" Enter 2>/dev/null || true
  sleep 3

  # Auto-approve effort prompt
  tmux send-keys -t "$SESSION_NAME" Enter 2>/dev/null || true
  sleep 5
}

is_healthy() {
  # Check tmux session exists
  tmux has-session -t "$SESSION_NAME" 2>/dev/null || return 1
  # Check bun telegram server is running
  pgrep -f "bun.*server.ts" > /dev/null 2>&1 || return 1
  return 0
}

while true; do
  NOW=$(date +%s)

  # Check if listener is already running and healthy
  if is_healthy; then
    # All good — sleep and check again
    sleep 30
    continue
  fi

  # Not healthy — need to start/restart
  UPTIME=$(( NOW - LAST_START ))
  LAST_START=$NOW

  # Rate limit rapid restarts
  if [ "$UPTIME" -lt 60 ] && [ "$LAST_START" -gt 0 ]; then
    RESTART_COUNT=$((RESTART_COUNT + 1))
    BACKOFF=$(( RESTART_COUNT * 15 ))
    [ "$BACKOFF" -gt 300 ] && BACKOFF=300

    log "Rapid restart #$RESTART_COUNT (ran for ${UPTIME}s). Backing off ${BACKOFF}s..."

    if [ "$RESTART_COUNT" -ge "$MAX_RAPID_RESTARTS" ]; then
      log "FATAL: $MAX_RAPID_RESTARTS rapid restarts — giving up"
      notify "ALERT: VPS Telegram supervisor gave up after $MAX_RAPID_RESTARTS rapid restarts. Manual intervention needed."
      exit 1
    fi

    sleep "$BACKOFF"
  else
    RESTART_COUNT=0
  fi

  log "Starting Claude Telegram listener in tmux (attempt $((RESTART_COUNT + 1)))..."
  start_tmux_session

  # Wait and verify
  sleep 10
  if is_healthy; then
    log "Listener started successfully"
    notify "VPS supervisor: Telegram listener restarted successfully."
  else
    log "WARNING: Listener may not have started properly"
  fi
done
