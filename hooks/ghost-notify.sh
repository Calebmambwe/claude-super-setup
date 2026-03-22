#!/bin/bash

# Ghost Mode — Dual-channel notification dispatcher
# Usage: bash ghost-notify.sh <level> <message> [pr-url]
# Levels: start, phase, warning, success, failure

set -euo pipefail

LEVEL="${1:-info}"
MESSAGE="${2:-Ghost Mode notification}"
PR_URL="${3:-}"

CONFIG_FILE="$HOME/.claude/ghost-config.json"
NOTIFY_URL=""

# Read ntfy URL from config if available
if [[ -f "$CONFIG_FILE" ]]; then
  NOTIFY_URL=$(jq -r '.notify_url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
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

exit 0
