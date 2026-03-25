#!/usr/bin/env bash
set -euo pipefail

# VPS Telegram Health Monitor — runs via cron every 5 minutes
# Checks if the Telegram listener is actually processing messages.
# If unhealthy, restarts via supervisor and sends alert via direct Bot API.

LOG_FILE="$HOME/.claude/logs/telegram-healthcheck.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# --- Load bot credentials for direct alerts ---
BOT_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$HOME/.claude/channels/telegram/.env" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//' | tr -d '[:space:]' || echo "")
CHAT_ID=""
if [ -f "$HOME/.claude/channels/telegram/access.json" ]; then
  CHAT_ID=$(python3 -c "import json; print(json.load(open('$HOME/.claude/channels/telegram/access.json')).get('allowFrom',[''])[0])" 2>/dev/null || echo "")
fi
if [ -z "$CHAT_ID" ]; then
  CHAT_ID=$(grep '^TELEGRAM_CHAT_ID=' "$HOME/.claude/.env.local" 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]' || echo "")
fi

notify() {
  local MSG="$1"
  if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${CHAT_ID}" \
      --data-urlencode "text=${MSG}" > /dev/null 2>&1 || true
  fi
}

# --- Check 1: Is tmux session alive? ---
TMUX_OK=false
if tmux has-session -t claude-telegram 2>/dev/null; then
  TMUX_OK=true
fi

# --- Check 2: Is the bun Telegram server running? ---
BUN_OK=false
if pgrep -f "bun.*server.ts" > /dev/null 2>&1; then
  BUN_OK=true
fi

# --- Check 3: Is the Claude process alive? ---
CLAUDE_OK=false
if pgrep -f "claude.*channels.*telegram" > /dev/null 2>&1 || pgrep -f "claude.*dangerously" > /dev/null 2>&1; then
  CLAUDE_OK=true
fi

# --- Check 4: Is the bot actually responding? (check pending updates) ---
BOT_RESPONSIVE=true
if [ -n "$BOT_TOKEN" ]; then
  PENDING=$(curl -s --max-time 10 "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result',{}).get('pending_update_count',0))" 2>/dev/null || echo "0")
  if [ "$PENDING" -gt 10 ] 2>/dev/null; then
    BOT_RESPONSIVE=false
    log "WARNING: $PENDING pending updates — bot may be unresponsive"
  fi
fi

# --- Check 5: Has the Claude process been idle too long? ---
IDLE_TOO_LONG=false
SUPERVISOR_LOG="$HOME/.claude/logs/telegram-supervisor.log"
if [ -f "$SUPERVISOR_LOG" ]; then
  LAST_MOD=$(stat -c %Y "$SUPERVISOR_LOG" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$(( NOW - LAST_MOD ))
  # If no log activity in 30 minutes AND pending updates > 5, it's frozen
  if [ "$AGE" -gt 1800 ] && [ "${PENDING:-0}" -gt 5 ] 2>/dev/null; then
    IDLE_TOO_LONG=true
    log "WARNING: No log activity in ${AGE}s AND $PENDING pending updates"
  fi
fi

log "Health: tmux=$TMUX_OK bun=$BUN_OK claude=$CLAUDE_OK responsive=$BOT_RESPONSIVE idle_too_long=$IDLE_TOO_LONG"

# --- Decision: healthy or restart? ---
NEEDS_RESTART=false
REASON=""

if [ "$TMUX_OK" = "false" ]; then
  NEEDS_RESTART=true
  REASON="tmux session dead"
elif [ "$BUN_OK" = "false" ]; then
  NEEDS_RESTART=true
  REASON="bun telegram server not running"
elif [ "$CLAUDE_OK" = "false" ]; then
  NEEDS_RESTART=true
  REASON="claude process not found"
elif [ "$IDLE_TOO_LONG" = "true" ]; then
  NEEDS_RESTART=true
  REASON="process frozen (no activity + pending messages)"
fi

if [ "$NEEDS_RESTART" = "false" ]; then
  log "HEALTHY"
  exit 0
fi

# --- Restart ---
log "UNHEALTHY: $REASON — restarting..."

# Kill existing session
tmux kill-session -t claude-telegram 2>/dev/null || true
sleep 2

# Kill any orphaned processes
pkill -f "claude.*channels.*telegram" 2>/dev/null || true
pkill -f "bun.*server.ts" 2>/dev/null || true
sleep 2

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
export PATH="$HOME/.nvm/versions/node/v22.22.2/bin:$HOME/.bun/bin:$PATH"

CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.nvm/versions/node/v22.22.2/bin/claude")

# Start new tmux session with the startup script
STARTUP_SCRIPT="$HOME/.claude-super-setup/scripts/vps-telegram-start.sh"
if [ -f "$STARTUP_SCRIPT" ]; then
  tmux new-session -d -s claude-telegram "bash $STARTUP_SCRIPT"
else
  # Fallback: start directly
  tmux new-session -d -s claude-telegram "$CLAUDE_BIN --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official"
fi

sleep 5

# Auto-approve trust prompt
tmux send-keys -t claude-telegram Enter 2>/dev/null || true
sleep 3

# Auto-approve effort prompt
tmux send-keys -t claude-telegram Enter 2>/dev/null || true
sleep 8

# Verify restart worked
RESTART_OK=false
if pgrep -f "bun.*server.ts" > /dev/null 2>&1; then
  RESTART_OK=true
fi

if [ "$RESTART_OK" = "true" ]; then
  log "HEALED: Restarted successfully (reason: $REASON)"
  notify "VPS health monitor: Telegram listener was down ($REASON). Auto-restarted successfully."
else
  log "FAILED: Restart did not bring up bun server (reason: $REASON)"
  notify "ALERT: VPS Telegram listener restart FAILED ($REASON). May need manual SSH intervention."
fi
