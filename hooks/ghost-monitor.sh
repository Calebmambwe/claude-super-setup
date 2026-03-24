#!/bin/bash

# Ghost Mode Monitor — sends periodic Telegram status updates
# Usage: ghost-monitor.sh [--once] [--interval 600]
# Runs in a loop sending status every N seconds (default 600 = 10min)
# Stops when ghost-config.json status is terminal (complete/stopped/exhausted)

set -euo pipefail

# Parse arguments
INTERVAL=600
ONCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) ONCE=true; shift ;;
    --interval) INTERVAL="${2:?--interval requires a value}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done
CONFIG_FILE="$HOME/.claude/ghost-config.json"
TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"

# Read Telegram credentials
TELEGRAM_BOT_TOKEN=""
if [[ -f "$TELEGRAM_ENV" ]]; then
  TELEGRAM_BOT_TOKEN=$(grep 'TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//' || echo "")
fi

CHAT_ID=""
if [[ -f "$HOME/.claude/channels/telegram/access.json" ]]; then
  CHAT_ID=$(jq -r '.allowFrom[0] // ""' "$HOME/.claude/channels/telegram/access.json" 2>/dev/null || echo "")
fi

if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$CHAT_ID" ]]; then
  echo "ERROR: Telegram not configured. Cannot send updates."
  exit 1
fi

send_update() {
  local status feature branch elapsed log_tail screen_status

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Ghost config not found. Exiting monitor."
    exit 0
  fi

  status=$(jq -r '.status // "unknown"' "$CONFIG_FILE")
  feature=$(jq -r '.feature // "unknown"' "$CONFIG_FILE" | head -c 60)
  branch=$(jq -r '.branch // "unknown"' "$CONFIG_FILE")
  local project_dir
  project_dir=$(jq -r '.project_dir // ""' "$CONFIG_FILE")

  # Calculate elapsed time
  local started
  started=$(jq -r '.started // ""' "$CONFIG_FILE")
  if [[ -n "$started" ]]; then
    local start_epoch now_epoch
    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s 2>/dev/null || date -d "$started" +%s 2>/dev/null || echo "0")
    now_epoch=$(date +%s)
    local diff=$(( now_epoch - start_epoch ))
    local hours=$(( diff / 3600 ))
    local mins=$(( (diff % 3600) / 60 ))
    elapsed="${hours}h ${mins}m"
  else
    elapsed="unknown"
  fi

  # Check screen session
  if screen -ls 2>/dev/null | grep -q ghost; then
    screen_status="alive"
  else
    screen_status="dead"
  fi

  # Get last 5 lines of most recent ghost log (truncated)
  log_tail=""
  local latest_log
  latest_log=$(ls -t "$HOME/.claude/logs/ghost-"*.log 2>/dev/null | head -1 || echo "")
  if [[ -n "$latest_log" ]]; then
    log_tail=$(tail -5 "$latest_log" 2>/dev/null | head -c 500 | sed 's/[`]/\x27/g' || echo "")
  fi

  # Count tasks if tasks.json exists
  local task_info=""
  if [[ -n "$project_dir" ]] && [[ -f "$project_dir/tasks.json" ]]; then
    local total completed_count
    total=$(jq '.tasks | length' "$project_dir/tasks.json" 2>/dev/null || echo "0")
    completed_count=$(jq '[.tasks[] | select(.status == "completed")] | length' "$project_dir/tasks.json" 2>/dev/null || echo "0")
    task_info="\nTasks: ${completed_count}/${total} completed"
  fi

  # Map status to emoji
  local emoji
  case "$status" in
    running*) emoji="⏳" ;;
    complete) emoji="✅" ;;
    stopped*) emoji="🛑" ;;
    exhausted|timeout|budget_exhausted) emoji="⚠️" ;;
    *) emoji="👻" ;;
  esac

  local tg_text="${emoji} *Ghost Update*\n\n*Status:* ${status}\n*Feature:* ${feature}...\n*Branch:* ${branch}\n*Elapsed:* ${elapsed}\n*Screen:* ${screen_status}${task_info}"

  if [[ -n "$log_tail" ]]; then
    tg_text="${tg_text}\n\n\`\`\`\n${log_tail}\n\`\`\`"
  fi

  curl -s -o /dev/null -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=$(printf '%b' "$tg_text")" \
    --data-urlencode "parse_mode=Markdown" \
    --data-urlencode "disable_web_page_preview=true" \
    2>/dev/null || true

  echo "[$(date)] Status update sent: $status"
}

# One-shot mode
if $ONCE; then
  send_update
  exit 0
fi

# Loop mode
echo "Ghost Monitor started. Sending updates every ${INTERVAL}s to Telegram."
echo "Stop with: kill $$"

while true; do
  send_update

  # Check for terminal status
  local_status=$(jq -r '.status // "unknown"' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
  case "$local_status" in
    complete|stopped|stopped_emergency|exhausted|timeout|budget_exhausted)
      echo "Terminal status: $local_status. Monitor exiting."
      exit 0
      ;;
  esac

  sleep "$INTERVAL"
done
