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

# ─── Centralized Telegram credential resolution ──────────────────────────────
# Single resolution order used by ALL notification scripts:
#   1. ghost-config.json telegram_chat_id / telegram_bot_token
#   2. channels/telegram/.env TELEGRAM_BOT_TOKEN
#   3. .env.local TELEGRAM_CHAT_ID
#   4. channels/telegram/access.json allowFrom[0]

TELEGRAM_BOT_TOKEN=""
TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"
if [[ -f "$TELEGRAM_ENV" ]]; then
  TELEGRAM_BOT_TOKEN=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//; s/[[:space:]]*#.*//; s/[[:space:]]*$//' || echo "")
fi

# Chat ID fallback chain
if [[ -z "$TELEGRAM_CHAT_ID" ]] && [[ -f "$HOME/.claude/.env.local" ]]; then
  TELEGRAM_CHAT_ID=$(grep -m1 '^TELEGRAM_CHAT_ID=' "$HOME/.claude/.env.local" 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//; s/[[:space:]]*$//' || echo "")
fi
if [[ -z "$TELEGRAM_CHAT_ID" ]] && [[ -f "$HOME/.claude/channels/telegram/access.json" ]]; then
  TELEGRAM_CHAT_ID=$(jq -r '.allowFrom[0] // ""' "$HOME/.claude/channels/telegram/access.json" 2>/dev/null || echo "")
fi

# ─── Notification preferences ────────────────────────────────────────────────
# Optional: ghost-config.json .notifications.levels.{level} = ["macos","telegram","ntfy"]
# If not set, all channels fire for all levels (backward compatible)
CHANNEL_MACOS=true
CHANNEL_TELEGRAM=true
CHANNEL_NTFY=true

if [[ -f "$CONFIG_FILE" ]]; then
  PREF=$(jq -r ".notifications.levels.${LEVEL} // null" "$CONFIG_FILE" 2>/dev/null || echo "null")
  if [[ "$PREF" != "null" ]]; then
    echo "$PREF" | jq -e 'index("macos")'    &>/dev/null || CHANNEL_MACOS=false
    echo "$PREF" | jq -e 'index("telegram")' &>/dev/null || CHANNEL_TELEGRAM=false
    echo "$PREF" | jq -e 'index("ntfy")'     &>/dev/null || CHANNEL_NTFY=false
  fi

  # Quiet hours: suppress non-failure notifications between start-end
  QUIET_START=$(jq -r '.notifications.quiet_hours.start // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
  QUIET_END=$(jq -r '.notifications.quiet_hours.end // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
  if [[ -n "$QUIET_START" ]] && [[ -n "$QUIET_END" ]]; then
    CURRENT_HOUR=$(date +%H)
    QS_HOUR="${QUIET_START%%:*}"
    QE_HOUR="${QUIET_END%%:*}"
    IN_QUIET=false
    if [[ "$QS_HOUR" -gt "$QE_HOUR" ]]; then
      # Overnight quiet hours (e.g., 23:00-07:00)
      [[ "$CURRENT_HOUR" -ge "$QS_HOUR" || "$CURRENT_HOUR" -lt "$QE_HOUR" ]] && IN_QUIET=true
    else
      [[ "$CURRENT_HOUR" -ge "$QS_HOUR" && "$CURRENT_HOUR" -lt "$QE_HOUR" ]] && IN_QUIET=true
    fi
    if $IN_QUIET; then
      # Check override list (failures always get through)
      OVERRIDE=$(jq -r ".notifications.quiet_hours.override // [] | index(\"$LEVEL\") // null" "$CONFIG_FILE" 2>/dev/null || echo "null")
      if [[ "$OVERRIDE" == "null" ]]; then
        exit 0  # Suppress notification during quiet hours
      fi
    fi
  fi
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
if $CHANNEL_MACOS; then
  # Escape double quotes to prevent AppleScript injection
  SAFE_MSG="${MESSAGE//\"/\\\"}"
  SAFE_TITLE="${TITLE//\"/\\\"}"
  osascript -e "display notification \"$SAFE_MSG\" with title \"$SAFE_TITLE\" sound name \"$SOUND\"" 2>/dev/null || true
fi

# Channel 2: ntfy.sh push notification (remote, fails silently if no URL)
if $CHANNEL_NTFY && [[ -n "$NOTIFY_URL" ]]; then
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
if $CHANNEL_TELEGRAM && [[ -n "$TELEGRAM_BOT_TOKEN" ]] && [[ -n "$TELEGRAM_CHAT_ID" ]]; then
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
