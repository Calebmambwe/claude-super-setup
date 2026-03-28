#!/usr/bin/env bash
set -eo pipefail

# StopFailure hook — alerts when Claude session ends due to API errors
# Hook type: StopFailure (fires on rate_limit, auth failure, billing, server_error)
# Sends triple-channel notification so Ghost Mode failures don't go unnoticed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)

ERROR_TYPE=$(printf '%s' "$INPUT" | jq -r '.error // "unknown"' 2>/dev/null || echo "unknown")
ERROR_DETAILS=$(printf '%s' "$INPUT" | jq -r '.error_details // ""' 2>/dev/null || echo "")
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# Map error types to severity
case "$ERROR_TYPE" in
  rate_limit)
    LEVEL="warning"
    MSG="Rate limited — session paused. ${ERROR_DETAILS:+Details: $ERROR_DETAILS}"
    ;;
  authentication_failed)
    LEVEL="failure"
    MSG="Auth failed — API key may be expired or invalid. Check ANTHROPIC_API_KEY."
    ;;
  billing_error)
    LEVEL="failure"
    MSG="Billing error — account may need attention. ${ERROR_DETAILS:+Details: $ERROR_DETAILS}"
    ;;
  server_error)
    LEVEL="warning"
    MSG="Anthropic server error — temporary outage. Will retry. ${ERROR_DETAILS:+Details: $ERROR_DETAILS}"
    ;;
  max_output_tokens)
    LEVEL="phase"
    MSG="Hit max output tokens — response was truncated."
    ;;
  *)
    LEVEL="warning"
    MSG="Session ended with error: $ERROR_TYPE. ${ERROR_DETAILS:+Details: $ERROR_DETAILS}"
    ;;
esac

# Log to alerts
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
printf '[%s] StopFailure type=%s session=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ERROR_TYPE" "$SESSION_ID" >> "$LOG_DIR/alerts.jsonl" 2>/dev/null || true

# Send notification (skip max_output_tokens — too noisy)
if [ "$ERROR_TYPE" != "max_output_tokens" ]; then
  bash "$SCRIPT_DIR/ghost-notify.sh" "$LEVEL" "$MSG" &>/dev/null &
fi

# No decision control — audit/logging only
exit 0
