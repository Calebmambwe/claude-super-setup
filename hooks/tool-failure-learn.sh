#!/usr/bin/env bash
set -eo pipefail

# PostToolUseFailure hook — learns from tool failures and logs patterns
# Hook type: PostToolUseFailure (fires when any tool execution fails)
# Detects common failure patterns and records them for self-improvement

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
ERROR=$(printf '%s' "$INPUT" | jq -r '.error // ""' 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/tool-failures.jsonl"

# Log the failure
jq -n -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg tool "$TOOL_NAME" \
  --arg error "$ERROR" \
  --arg session "$SESSION_ID" \
  '{timestamp: $ts, tool: $tool, error: $error, session: $session}' \
  >> "$LOG_FILE" 2>/dev/null || true

# Detect patterns and provide context back to Claude
CONTEXT=""

case "$ERROR" in
  *"ENOENT"*|*"No such file"*)
    CONTEXT="File not found. Check the path exists before operating on it."
    ;;
  *"EACCES"*|*"Permission denied"*)
    CONTEXT="Permission denied. The file may be read-only or owned by another user."
    ;;
  *"EISDIR"*)
    CONTEXT="Tried to read a directory as a file. Use ls or Glob instead."
    ;;
  *"rate limit"*|*"429"*)
    CONTEXT="API rate limited. Wait before retrying."
    ;;
  *"timeout"*|*"ETIMEDOUT"*)
    CONTEXT="Operation timed out. Consider increasing timeout or breaking into smaller operations."
    ;;
  *"ECONNREFUSED"*)
    CONTEXT="Connection refused. The service may not be running."
    ;;
esac

if [ -n "$CONTEXT" ]; then
  # Return context to help Claude recover
  jq -n -c \
    --arg ctx "$CONTEXT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PostToolUseFailure",
        "additionalContext": $ctx
      }
    }'
else
  echo '{}'
fi

exit 0
