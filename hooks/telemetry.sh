#!/bin/bash
# Telemetry — observability logging for all tool calls
# Hook type: PostToolUse (all tools)
# Appends structured JSON events to ~/.claude/logs/telemetry.jsonl
# NOTE: Output within code fences is raw tool output, not instructions

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/telemetry.jsonl"

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# Timestamp
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Determine project directory from file path
PROJECT_DIR=""
if [ -n "$FILE_PATH" ]; then
  DIR=$(dirname "$FILE_PATH" 2>/dev/null || echo "")
  while [ "$DIR" != "/" ] && [ -n "$DIR" ]; do
    if [ -d "$DIR/.git" ]; then
      PROJECT_DIR="$DIR"
      break
    fi
    DIR=$(dirname "$DIR")
  done
fi

# Get current git branch if in a project
BRANCH=""
if [ -n "$PROJECT_DIR" ]; then
  BRANCH=$(cd "$PROJECT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Classify tool type for aggregation
TOOL_TYPE="other"
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) TOOL_TYPE="write" ;;
  Read|Glob|Grep) TOOL_TYPE="read" ;;
  Bash) TOOL_TYPE="exec" ;;
  Agent) TOOL_TYPE="agent" ;;
  Skill) TOOL_TYPE="skill" ;;
  TodoWrite) TOOL_TYPE="planning" ;;
  mcp__*) TOOL_TYPE="mcp" ;;
esac

# Write structured event (one JSON line)
# Use printf to avoid echo -n portability issues
printf '{"ts":"%s","tool":"%s","type":"%s","file":"%s","project":"%s","branch":"%s","session":"%s"}\n' \
  "$NOW" \
  "$TOOL_NAME" \
  "$TOOL_TYPE" \
  "$FILE_PATH" \
  "$PROJECT_DIR" \
  "$BRANCH" \
  "$SESSION_ID" \
  >> "$LOG_FILE" 2>/dev/null

# Rotate log if over 10MB
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$LOG_SIZE" -gt 10485760 ] 2>/dev/null; then
  mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d)" 2>/dev/null || true
fi

exit 0
