#!/usr/bin/env bash
# Telegram listener watchdog — runs via cron every 5 minutes
# Belt-and-suspenders: catches cases where systemd gives up or the service is stopped
set -euo pipefail

SERVICE="claude-telegram@${USER}.service"
LOG_FILE="${HOME}/.claude/logs/telegram-watchdog.log"
BOT_TOKEN_FILE="${HOME}/.claude/channels/telegram/.env"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Check if systemd service is active
if systemctl --user is-active --quiet "$SERVICE" 2>/dev/null; then
  exit 0
fi

# Service is not running — restart it
log "WATCHDOG: $SERVICE is not active. Restarting..."

# Reset failure count so systemd doesn't refuse to start
systemctl --user reset-failed "$SERVICE" 2>/dev/null || true

# Start the service
if systemctl --user start "$SERVICE" 2>/dev/null; then
  log "WATCHDOG: $SERVICE restarted successfully"

  # Notify via Telegram
  if [ -f "$BOT_TOKEN_FILE" ]; then
    source "$BOT_TOKEN_FILE"
    CHAT_ID="${TELEGRAM_CHAT_ID:-8328233140}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${CHAT_ID}" \
      --data-urlencode "text=Watchdog: Telegram listener was down. Restarted successfully." \
      > /dev/null 2>&1 || true
  fi
else
  log "WATCHDOG: Failed to restart $SERVICE"
  # Try system-level if user-level fails
  if sudo systemctl start "$SERVICE" 2>/dev/null; then
    log "WATCHDOG: Restarted via system-level systemctl"
  else
    log "WATCHDOG: CRITICAL — could not restart $SERVICE at any level"
  fi
fi
