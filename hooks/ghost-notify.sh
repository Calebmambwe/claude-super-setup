#!/bin/bash

# Ghost Mode — Triple-channel notification dispatcher (macOS + ntfy.sh + Telegram)
# Usage: bash ghost-notify.sh <level> <message> [pr-url]
# Levels: start, phase, warning, success, failure

set -euo pipefail

LEVEL="${1:-info}"
MESSAGE="${2:-Ghost Mode notification}"
PR_URL="${3:-}"

CONFIG_FILE="$HOME/.claude/ghost-config.json"
NOTIFY_URL=""
TELEGRAM_CHAT_ID=""

# Read config if available
if [[ -f "$CONFIG_FILE" ]]; then
  NOTIFY_URL=$(jq -r '.notify_url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
  TELEGRAM_CHAT_ID=$(jq -r '.telegram_chat_id // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
fi

# Read Telegram bot token from channel config
TELEGRAM_BOT_TOKEN=""
TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"
if [[ -f "$TELEGRAM_ENV" ]]; then
  TELEGRAM_BOT_TOKEN=$(grep 'TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//' || echo "")
fi

# Auto-detect Telegram chat ID from access.json if not in ghost config
if [[ -z "$TELEGRAM_CHAT_ID" ]] && [[ -f "$HOME/.claude/channels/telegram/access.json" ]]; then
  TELEGRAM_CHAT_ID=$(jq -r '.allowFrom[0] // ""' "$HOME/.claude/channels/telegram/access.json" 2>/dev/null || echo "")
fi

# Map level to ntfy priority and macOS sound
case "$LEVEL" in
  start)
    PRIORITY="default"
    TITLE="Ghost Mode Started"
    SOUND="Glass"
    TAGS="rocket"
    ;;
  phase)
    PRIORITY="low"
    TITLE="Ghost Mode Progress"
    SOUND="Pop"
    TAGS="hourglass"
    ;;
  warning)
    PRIORITY="high"
    TITLE="Ghost Mode Warning"
    SOUND="Basso"
    TAGS="warning"
    ;;
  success)
    PRIORITY="high"
    TITLE="Ghost Mode Complete"
    SOUND="Purr"
    TAGS="white_check_mark"
    ;;
  failure)
    PRIORITY="urgent"
    TITLE="Ghost Mode Failed"
    SOUND="Sosumi"
    TAGS="x"
    ;;
  *)
    PRIORITY="default"
    TITLE="Ghost Mode"
    SOUND="Pop"
    TAGS="ghost"
    ;;
esac

# Channel 1: macOS notification (local, fails silently if not on macOS)
osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"$SOUND\"" 2>/dev/null || true

# Channel 2: ntfy.sh push notification (remote, fails silently if no URL)
if [[ -n "$NOTIFY_URL" ]]; then
  NTFY_BODY="$MESSAGE"
  if [[ -n "$PR_URL" ]]; then
    NTFY_BODY="$MESSAGE\n\nPR: $PR_URL"
  fi

  # Build curl args
  CURL_ARGS=(
    -s -o /dev/null
    -H "Title: $TITLE"
    -H "Priority: $PRIORITY"
    -H "Tags: $TAGS"
  )

  # Add click URL for PR links
  if [[ -n "$PR_URL" ]]; then
    CURL_ARGS+=(-H "Click: $PR_URL")
  fi

  curl "${CURL_ARGS[@]}" -d "$NTFY_BODY" "$NOTIFY_URL" 2>/dev/null || true
fi

# Channel 3: Telegram push notification (remote, fails silently if no token/chat_id)
if [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
  # Map tags to emoji for Telegram
  case "$TAGS" in
    rocket)           TG_EMOJI="🚀" ;;
    hourglass)        TG_EMOJI="⏳" ;;
    warning)          TG_EMOJI="⚠️" ;;
    white_check_mark) TG_EMOJI="✅" ;;
    x)                TG_EMOJI="❌" ;;
    *)                TG_EMOJI="👻" ;;
  esac

  TG_TEXT="${TG_EMOJI} *${TITLE}*\n\n${MESSAGE}"
  if [[ -n "$PR_URL" ]]; then
    TG_TEXT="${TG_TEXT}\n\n🔗 [View PR](${PR_URL})"
  fi

  curl -s -o /dev/null -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$(printf '%b' "$TG_TEXT")" \
    --data-urlencode "parse_mode=Markdown" \
    --data-urlencode "disable_web_page_preview=true" \
    2>/dev/null || true
fi

exit 0
