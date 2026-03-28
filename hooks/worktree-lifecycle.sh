#!/usr/bin/env bash
set -eo pipefail

# WorktreeCreate / WorktreeRemove hook — logs worktree lifecycle and notifies
# Hook type: WorktreeCreate + WorktreeRemove
# Tracks all worktree operations for debugging and metrics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree.jsonl"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Log the event
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg event "$EVENT" \
  --arg session "$SESSION_ID" \
  --arg cwd "$CWD" \
  '{timestamp: $ts, event: $event, session: $session, cwd: $cwd}' \
  >> "$LOG_FILE" 2>/dev/null || true

# Count active worktrees
WORKTREE_COUNT=$(git worktree list 2>/dev/null | wc -l | tr -d ' ' || echo "1")

if [ "$EVENT" = "WorktreeCreate" ]; then
  # Notify on creation (async, non-blocking)
  if [ -x "$SCRIPT_DIR/ghost-notify.sh" ]; then
    bash "$SCRIPT_DIR/ghost-notify.sh" phase "Worktree created (${WORKTREE_COUNT} active). Agent spawned in isolated context." &>/dev/null &
  fi
fi

if [ "$EVENT" = "WorktreeRemove" ]; then
  # Log cleanup
  if [ -x "$SCRIPT_DIR/ghost-notify.sh" ]; then
    bash "$SCRIPT_DIR/ghost-notify.sh" phase "Worktree removed (${WORKTREE_COUNT} remaining). Changes merged." &>/dev/null &
  fi
fi

exit 0
