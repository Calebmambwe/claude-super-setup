#!/usr/bin/env bash
# One-time script: Add autoMode.environment and prune Bash allow rules from settings.json
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
BACKUP="$HOME/.claude/settings.json.bak-$(date +%Y%m%d-%H%M%S)"

# Backup first
cp "$SETTINGS" "$BACKUP"
echo "Backup saved to: $BACKUP"

# Transform: add autoMode, prune Bash(*) from permissions.allow
jq '
  .autoMode = {
    "environment": {
      "sourceControlOrgs": ["calebmambwe"],
      "trustedInternalDomains": ["api.telegram.org"],
      "keyInternalServices": ["Telegram Bot API", "GitHub API"]
    }
  }
  | .permissions.allow = [.permissions.allow[] | select(startswith("Bash(") | not)]
' "$SETTINGS" > "${SETTINGS}.tmp"

mv "${SETTINGS}.tmp" "$SETTINGS"

# Report
BEFORE=$(jq '.permissions.allow | length' "$BACKUP")
AFTER=$(jq '.permissions.allow | length' "$SETTINGS")
echo "permissions.allow: $BEFORE entries -> $AFTER entries ($(($BEFORE - $AFTER)) Bash rules removed)"
echo "autoMode.environment added with sourceControlOrgs, trustedInternalDomains, keyInternalServices"
echo "permissions.deny: unchanged"
