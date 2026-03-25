#!/usr/bin/env bash
set -euo pipefail

# VPS Telegram Supervisor — Simple bash supervisor loop
# Runs the startup script forever, restarting on crash.
# This is the fallback if supervisord is not available.
# Run this inside a tmux/screen session or via systemd.

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

STARTUP_SCRIPT="$(dirname "$0")/vps-telegram-start.sh"
if [ ! -f "$STARTUP_SCRIPT" ]; then
  STARTUP_SCRIPT="$HOME/.claude-super-setup/scripts/vps-telegram-start.sh"
fi

if [ ! -f "$STARTUP_SCRIPT" ]; then
  log "FATAL: Cannot find vps-telegram-start.sh"
  exit 1
fi

RESTART_COUNT=0
MAX_RAPID_RESTARTS=20
LAST_START=0

log "=== Supervisor starting ==="
log "Startup script: $STARTUP_SCRIPT"

while true; do
  NOW=$(date +%s)
  UPTIME=$(( NOW - LAST_START ))
  LAST_START=$NOW

  # Rate limit: if last run was < 30s, it's a rapid restart
  if [ "$UPTIME" -lt 30 ] && [ "$LAST_START" -gt 0 ]; then
    RESTART_COUNT=$((RESTART_COUNT + 1))
    BACKOFF=$(( RESTART_COUNT * 10 ))
    # Cap backoff at 5 minutes
    [ "$BACKOFF" -gt 300 ] && BACKOFF=300

    log "Rapid restart #$RESTART_COUNT (ran for ${UPTIME}s). Backing off ${BACKOFF}s..."

    if [ "$RESTART_COUNT" -ge "$MAX_RAPID_RESTARTS" ]; then
      log "FATAL: $MAX_RAPID_RESTARTS rapid restarts — giving up"
      notify "ALERT: VPS Telegram supervisor gave up after $MAX_RAPID_RESTARTS rapid restarts. Manual intervention required."
      exit 1
    fi

    sleep "$BACKOFF"
  else
    # Healthy run — reset counter
    RESTART_COUNT=0
  fi

  log "Starting Claude Telegram listener (attempt $((RESTART_COUNT + 1)))..."

  # Run the startup script
  bash "$STARTUP_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
  EXIT_CODE=${PIPESTATUS[0]}

  log "Claude exited with code $EXIT_CODE after ${UPTIME}s"

  # Alert on crash (but not on first start)
  if [ "$EXIT_CODE" -ne 0 ]; then
    notify "VPS supervisor: Claude listener crashed (exit $EXIT_CODE). Auto-restarting..."
  fi

  # Brief pause before restart
  sleep 5
done
