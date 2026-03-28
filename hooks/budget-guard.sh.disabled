#!/usr/bin/env bash
# Budget Guard — PostToolUse hook that tracks cumulative tool calls per session
# Hook type: PostToolUse (all tools)
# Blocks further tool calls if session exceeds configured limits.
# Outputs: {"decision": "allow"} or {"decision": "block", "reason": "..."}
set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────────
TASK_MAX_TOOL_CALLS="${TASK_MAX_TOOL_CALLS:-200}"
TASK_MAX_SUBAGENTS="${TASK_MAX_SUBAGENTS:-20}"
WARM_UP_CALLS=10   # Grace period: never block during the first N tool calls

TRACKER_FILE="$HOME/.claude/budget-tracker.json"
TRACKER_TMP="${TRACKER_FILE}.tmp"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/budget.log"

# ─── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" 2>/dev/null || true

# ─── Read hook input ───────────────────────────────────────────────────────────
INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")

# ─── Session ID ────────────────────────────────────────────────────────────────
# Use CLAUDE_SESSION_ID env var if set; fall back to a date-based session ID
SESSION_ID="${CLAUDE_SESSION_ID:-$(date -u +%Y%m%d)}"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ─── Detect subagent calls ─────────────────────────────────────────────────────
IS_SUBAGENT=0
case "$TOOL_NAME" in
  Agent) IS_SUBAGENT=1 ;;
esac

# ─── Read or initialise tracker ────────────────────────────────────────────────
if [ -f "$TRACKER_FILE" ]; then
  STORED_SESSION=$(jq -r '.session_id // ""' "$TRACKER_FILE" 2>/dev/null || echo "")
  if [ "$STORED_SESSION" != "$SESSION_ID" ]; then
    # New session — reset
    TOOL_CALLS=0
    SUBAGENT_CALLS=0
    STARTED_AT="$NOW"
  else
    TOOL_CALLS=$(jq -r '.tool_calls // 0'     "$TRACKER_FILE" 2>/dev/null || echo 0)
    SUBAGENT_CALLS=$(jq -r '.subagent_calls // 0' "$TRACKER_FILE" 2>/dev/null || echo 0)
    STARTED_AT=$(jq -r '.started_at // ""'    "$TRACKER_FILE" 2>/dev/null || echo "$NOW")
  fi
else
  TOOL_CALLS=0
  SUBAGENT_CALLS=0
  STARTED_AT="$NOW"
fi

# ─── Increment counters ────────────────────────────────────────────────────────
TOOL_CALLS=$(( TOOL_CALLS + 1 ))
if [ "$IS_SUBAGENT" -eq 1 ]; then
  SUBAGENT_CALLS=$(( SUBAGENT_CALLS + 1 ))
fi

# ─── Atomic write tracker ──────────────────────────────────────────────────────
jq -n -c \
  --arg session    "$SESSION_ID" \
  --arg started    "$STARTED_AT" \
  --argjson calls  "$TOOL_CALLS" \
  --argjson agents "$SUBAGENT_CALLS" \
  --arg last_tool  "$TOOL_NAME" \
  --arg updated    "$NOW" \
  '{
    session_id:     $session,
    started_at:     $started,
    tool_calls:     $calls,
    subagent_calls: $agents,
    last_tool:      $last_tool,
    last_updated:   $updated
  }' > "$TRACKER_TMP" 2>/dev/null && mv "$TRACKER_TMP" "$TRACKER_FILE" 2>/dev/null || true

# ─── Warm-up grace period ──────────────────────────────────────────────────────
if [ "$TOOL_CALLS" -le "$WARM_UP_CALLS" ]; then
  printf '{"decision":"allow"}\n'
  exit 0
fi

# ─── Check limits ──────────────────────────────────────────────────────────────
if [ "$TOOL_CALLS" -gt "$TASK_MAX_TOOL_CALLS" ]; then
  MSG="Budget exceeded: ${TOOL_CALLS} tool calls (max ${TASK_MAX_TOOL_CALLS}). Run /budget-status for details. Override with TASK_MAX_TOOL_CALLS=500."

  # Log the budget event
  printf '[%s] BLOCKED session=%s calls=%d max=%d tool=%s\n' \
    "$NOW" "$SESSION_ID" "$TOOL_CALLS" "$TASK_MAX_TOOL_CALLS" "$TOOL_NAME" \
    >> "$LOG_FILE" 2>/dev/null || true

  # Send notification on first block only (prevent spam)
  BLOCK_SENTINEL="$HOME/.claude/.budget-block-notified-${SESSION_ID}"
  if [ ! -f "$BLOCK_SENTINEL" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/ghost-notify.sh" warning "Budget exhausted: ${TOOL_CALLS}/${TASK_MAX_TOOL_CALLS} tool calls. Session blocked. Override: TASK_MAX_TOOL_CALLS=500" &>/dev/null &
    touch "$BLOCK_SENTINEL" 2>/dev/null || true
  fi

  jq -n -c \
    --arg reason "$MSG" \
    '{"decision":"block","reason":$reason}'
  exit 0
fi

if [ "$SUBAGENT_CALLS" -gt "$TASK_MAX_SUBAGENTS" ]; then
  MSG="Budget exceeded: ${SUBAGENT_CALLS} subagent calls (max ${TASK_MAX_SUBAGENTS}). Run /budget-status for details. Override with TASK_MAX_SUBAGENTS=50."

  printf '[%s] BLOCKED session=%s subagents=%d max=%d\n' \
    "$NOW" "$SESSION_ID" "$SUBAGENT_CALLS" "$TASK_MAX_SUBAGENTS" \
    >> "$LOG_FILE" 2>/dev/null || true

  jq -n -c \
    --arg reason "$MSG" \
    '{"decision":"block","reason":$reason}'
  exit 0
fi

# ─── Log milestone events (every 50 calls, or at 80% / 100% of limit) ──────────
PCT=$(( TOOL_CALLS * 100 / TASK_MAX_TOOL_CALLS ))
REMAINDER=$(( TOOL_CALLS % 50 ))
if [ "$REMAINDER" -eq 0 ] || [ "$PCT" -ge 80 ]; then
  printf '[%s] MILESTONE session=%s calls=%d/%d (%d%%) subagents=%d/%d tool=%s\n' \
    "$NOW" "$SESSION_ID" "$TOOL_CALLS" "$TASK_MAX_TOOL_CALLS" "$PCT" \
    "$SUBAGENT_CALLS" "$TASK_MAX_SUBAGENTS" "$TOOL_NAME" \
    >> "$LOG_FILE" 2>/dev/null || true
fi

printf '{"decision":"allow"}\n'
exit 0
