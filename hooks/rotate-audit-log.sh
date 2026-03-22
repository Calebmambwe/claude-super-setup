#!/bin/bash
# Rotate Claude Code command audit log
# Keeps weekly archives for 4 weeks, then deletes old ones
#
# Install via crontab:
#   crontab -e
#   0 0 * * 0 ~/.claude/hooks/rotate-audit-log.sh

AUDIT_LOG="$HOME/.claude/command-audit.log"
METRICS_LOG="$HOME/.claude/metrics.jsonl"

# Rotate audit log if it exists and has content
if [ -s "$AUDIT_LOG" ]; then
  mv "$AUDIT_LOG" "$HOME/.claude/command-audit.$(date +%Y%m%d).log"
  touch "$AUDIT_LOG"
fi

# Delete audit archives older than 28 days
find "$HOME/.claude/" -name "command-audit.*.log" -mtime +28 -delete 2>/dev/null

# Rotate metrics log if over 10MB (keep as archive, don't delete)
if [ -f "$METRICS_LOG" ]; then
  SIZE=$(stat -f%z "$METRICS_LOG" 2>/dev/null || stat -c%s "$METRICS_LOG" 2>/dev/null || echo 0)
  if [ "$SIZE" -gt 10485760 ]; then
    mv "$METRICS_LOG" "$HOME/.claude/metrics.$(date +%Y%m%d).jsonl"
    touch "$METRICS_LOG"
  fi
fi
