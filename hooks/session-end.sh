#!/usr/bin/env bash
# Session end hook — runs when a Claude Code session ends
# Logs session end and basic metrics

set -euo pipefail

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

SESSION_LOG="$LOG_DIR/sessions.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Log session end
echo "[$TIMESTAMP] SESSION_END dir=$(pwd)" >> "$SESSION_LOG"

# Rotate audit log if it exists and is large
AUDIT_LOG="$HOME/.claude/command-audit.log"
if [ -f "$AUDIT_LOG" ] && [ "$(wc -l < "$AUDIT_LOG")" -gt 500 ]; then
  tail -500 "$AUDIT_LOG" > "$AUDIT_LOG.tmp" && mv "$AUDIT_LOG.tmp" "$AUDIT_LOG"
fi
