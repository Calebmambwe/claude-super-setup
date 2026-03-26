#!/usr/bin/env bash
# cost-tracker.sh — PostToolUse hook for model cost tracking
# Monitors Bash tool calls that invoke model-router.sh or openrouter-client.sh
# and ensures cost data is written to ~/.claude/logs/model-costs.jsonl
#
# Hook type: PostToolUse (Bash)
# This hook runs after Bash commands that match model dispatch patterns.

set -euo pipefail

COST_LOG="${HOME}/.claude/logs/model-costs.jsonl"
COST_LIMIT_FILE="${HOME}/config/model-routing.json"

mkdir -p "$(dirname "$COST_LOG")"

# Rotate log at 10MB (matches telemetry.sh pattern)
if [[ -f "$COST_LOG" ]]; then
  log_size=$(stat -c%s "$COST_LOG" 2>/dev/null || stat -f%z "$COST_LOG" 2>/dev/null || echo 0)
  if [[ "$log_size" -gt 10485760 ]]; then
    mv "$COST_LOG" "${COST_LOG}.$(date +%Y%m%d-%H%M%S).bak"
  fi
fi

# Check budget warnings
if [[ -f "$COST_LOG" && -f "$COST_LIMIT_FILE" ]]; then
  warn_at=$(jq -r '.cost_tracking.warn_at_usd // 40' "$COST_LIMIT_FILE" 2>/dev/null)
  hard_limit=$(jq -r '.cost_tracking.hard_limit_usd // 50' "$COST_LIMIT_FILE" 2>/dev/null)

  # Sum total cost from log
  total_cost=$(jq -r '.cost_usd // "0"' "$COST_LOG" 2>/dev/null | awk '{s+=$1} END {printf "%.2f", s}')

  if (( $(echo "$total_cost >= $hard_limit" | bc -l 2>/dev/null || echo 0) )); then
    echo "COST ALERT: Total model spend \$${total_cost} exceeds hard limit \$${hard_limit}" >&2
  elif (( $(echo "$total_cost >= $warn_at" | bc -l 2>/dev/null || echo 0) )); then
    echo "COST WARNING: Total model spend \$${total_cost} approaching limit \$${hard_limit}" >&2
  fi
fi
