#!/bin/bash
# Anthropic Claude Code Docs Monitor
# Checks for new features, updates, and best practices from Anthropic
# Runs daily — fetches latest docs, compares with cached version, reports changes

set -euo pipefail

LOG_DIR="$HOME/.claude/logs"
CACHE_DIR="$HOME/.claude/cache/anthropic-docs"
REPORT_FILE="$CACHE_DIR/latest-report.md"
DIFF_FILE="$CACHE_DIR/changes.diff"
mkdir -p "$LOG_DIR" "$CACHE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/anthropic-monitor.log"; }

log "Starting Anthropic docs monitor"

# URLs to monitor
URLS=(
  "https://docs.anthropic.com/en/docs/claude-code/overview"
  "https://docs.anthropic.com/en/docs/claude-code/cli-usage"
  "https://docs.anthropic.com/en/docs/claude-code/settings"
  "https://docs.anthropic.com/en/docs/claude-code/hooks"
  "https://docs.anthropic.com/en/docs/claude-code/mcp-servers"
  "https://docs.anthropic.com/en/docs/claude-code/ide-integrations"
  "https://docs.anthropic.com/en/docs/claude-code/agent-tool"
  "https://docs.anthropic.com/en/docs/claude-code/best-practices"
  "https://docs.anthropic.com/en/docs/claude-code/troubleshooting"
  "https://docs.anthropic.com/en/docs/claude-code/security"
  "https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering"
  "https://docs.anthropic.com/en/docs/about-claude/models"
)

CHANGES_FOUND=0
REPORT="# Anthropic Docs Monitor Report - $(date '+%Y-%m-%d')\n\n"

for url in "${URLS[@]}"; do
  slug=$(echo "$url" | sed 's|https://docs.anthropic.com/en/docs/||; s|/|_|g')
  cached="$CACHE_DIR/$slug.txt"
  new_file="$CACHE_DIR/${slug}.new.txt"

  # Fetch current content (text only, strip HTML)
  curl -s "$url" 2>/dev/null | \
    sed 's/<[^>]*>//g; s/&nbsp;/ /g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g' | \
    tr -s '[:space:]' '\n' | head -500 > "$new_file" 2>/dev/null || continue

  if [ -f "$cached" ]; then
    # Compare with cached version
    if ! diff -q "$cached" "$new_file" > /dev/null 2>&1; then
      CHANGES_FOUND=$((CHANGES_FOUND + 1))
      REPORT+="## CHANGED: $slug\n"
      REPORT+="URL: $url\n"
      REPORT+="$(diff "$cached" "$new_file" | head -30)\n\n"
      log "CHANGE DETECTED: $slug"
    fi
  else
    REPORT+="## NEW: $slug (first scan)\n"
    log "First scan: $slug"
  fi

  # Update cache
  mv "$new_file" "$cached"
done

REPORT+="---\nTotal changes: $CHANGES_FOUND\n"
echo -e "$REPORT" > "$REPORT_FILE"

# If changes found, notify via Telegram
if [ "$CHANGES_FOUND" -gt 0 ]; then
  VPS_BOT_TOKEN=$(grep 'VPS_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^VPS_BOT_TOKEN=//' | tr -d '[:space:]')
  CHAT_ID=$(grep 'TELEGRAM_CHAT_ID=' ~/.claude/.env.local 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')

  if [ -n "$VPS_BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    MSG="[Anthropic Docs Monitor] $CHANGES_FOUND changes detected in Claude Code documentation. Run 'cat ~/.claude/cache/anthropic-docs/latest-report.md' for details."
    curl -s -X POST "https://api.telegram.org/bot${VPS_BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${CHAT_ID}" \
      --data-urlencode "text=${MSG}" > /dev/null 2>&1
  fi
  log "Report sent: $CHANGES_FOUND changes"
else
  log "No changes detected"
fi

log "Monitor complete"
