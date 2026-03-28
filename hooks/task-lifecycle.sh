#!/usr/bin/env bash
set -eo pipefail

# TaskCreated / TaskCompleted hook — logs task lifecycle and sends Telegram updates
# Hook type: TaskCreated + TaskCompleted
# Provides real-time progress updates via Telegram during pipeline runs

INPUT=$(cat)

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || echo "")
TASK_ID=$(printf '%s' "$INPUT" | jq -r '.task_id // ""' 2>/dev/null || echo "")
TASK_SUBJECT=$(printf '%s' "$INPUT" | jq -r '.task_subject // ""' 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/task-lifecycle.jsonl"

# Log the event
jq -n -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg event "$EVENT" \
  --arg task_id "$TASK_ID" \
  --arg subject "$TASK_SUBJECT" \
  --arg session "$SESSION_ID" \
  '{timestamp: $ts, event: $event, task_id: $task_id, subject: $subject, session: $session}' \
  >> "$LOG_FILE" 2>/dev/null || true

# Send Telegram notification for task completion (not creation — too noisy)
if [ "$EVENT" = "TaskCompleted" ] && [ -n "$TASK_SUBJECT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Count completed vs total tasks in this session
  COMPLETED=$(grep -c "\"TaskCompleted\"" "$LOG_FILE" 2>/dev/null || echo "0")
  TOTAL=$(grep -c "$SESSION_ID" "$LOG_FILE" 2>/dev/null || echo "0")
  TOTAL=$(( TOTAL / 2 ))  # Each task has created + completed events

  MSG="Task done: ${TASK_SUBJECT} (${COMPLETED}/${TOTAL})"

  # Only notify via Telegram if ghost-notify exists (non-blocking)
  if [ -x "$SCRIPT_DIR/ghost-notify.sh" ]; then
    bash "$SCRIPT_DIR/ghost-notify.sh" phase "$MSG" &>/dev/null &
  fi
fi

# Always allow — never block task creation/completion
exit 0
