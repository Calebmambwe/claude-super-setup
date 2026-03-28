#!/usr/bin/env bash
set -eo pipefail

# TeammateIdle hook — fires when a team member agent goes idle
# Use this to coordinate handoffs: when implementer finishes, trigger tester
# Returns feedback via stderr (exit 2) to give the teammate a new task,
# or JSON with continue:false to stop the teammate

INPUT=$(cat)

TEAMMATE_NAME=$(printf '%s' "$INPUT" | jq -r '.teammate_name // ""' 2>/dev/null || echo "")
TEAM_NAME=$(printf '%s' "$INPUT" | jq -r '.team_name // ""' 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

# Log the idle event
jq -n -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg teammate "$TEAMMATE_NAME" \
  --arg team "$TEAM_NAME" \
  --arg session "$SESSION_ID" \
  '{timestamp: $ts, event: "TeammateIdle", teammate: $teammate, team: $team, session: $session}' \
  >> "$LOG_DIR/team-events.jsonl" 2>/dev/null || true

# Notify via Telegram (async)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/ghost-notify.sh" ]; then
  bash "$SCRIPT_DIR/ghost-notify.sh" phase "Team agent '${TEAMMATE_NAME}' finished its task in team '${TEAM_NAME}'." &>/dev/null &
fi

# Default: let the teammate stop naturally (don't force more work)
exit 0
