#!/usr/bin/env bash
# PostToolUse hook — auto-records when TeachMe creates new skills/agents.
# Triggers on Write to ~/.claude/skills/ or agents/community/ paths.
# Logs the creation to the activity log and optionally notifies via Telegram.

set -euo pipefail

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/teach-me-activity.log"

mkdir -p "$LOG_DIR"

# Only process Write/Edit tool results for skill/agent paths
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Detect new skill creation
if echo "$FILE_PATH" | grep -q "skills/.*/SKILL.md"; then
  SKILL_NAME=$(echo "$FILE_PATH" | sed 's|.*/skills/\([^/]*\)/.*|\1|')
  echo "[$TIMESTAMP] SKILL_CREATED: $SKILL_NAME ($FILE_PATH)" >> "$LOG_FILE"

  # Notify via Telegram if bot is available
  if [ -f "$HOME/.claude/channels/telegram/.env" ]; then
    BOT_TOKEN=$(grep 'BOT_TOKEN=' "$HOME/.claude/channels/telegram/.env" 2>/dev/null | sed 's/^BOT_TOKEN=//' | tr -d '[:space:]')
    CHAT_ID=$(grep 'TELEGRAM_CHAT_ID' "$HOME/.claude/.env.local" 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
      curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${CHAT_ID}" \
        --data-urlencode "text=🧠 TeachMe: New skill created — $SKILL_NAME" \
        > /dev/null 2>&1 || true
    fi
  fi
fi

# Detect new agent creation
if echo "$FILE_PATH" | grep -qE "agents/community/.*\.md$|agents/core/.*\.md$"; then
  AGENT_NAME=$(basename "$FILE_PATH" .md)
  echo "[$TIMESTAMP] AGENT_CREATED: $AGENT_NAME ($FILE_PATH)" >> "$LOG_FILE"
fi

# Detect new command creation
if echo "$FILE_PATH" | grep -qE "commands/.*\.md$"; then
  CMD_NAME=$(basename "$FILE_PATH" .md)
  # Only log if this is a NEW file (not an edit of existing)
  if [ ! -f "$FILE_PATH" ] 2>/dev/null; then
    echo "[$TIMESTAMP] COMMAND_CREATED: $CMD_NAME ($FILE_PATH)" >> "$LOG_FILE"
  fi
fi

# Always allow — this is a logging hook, never blocks
echo '{"decision": "allow"}'
