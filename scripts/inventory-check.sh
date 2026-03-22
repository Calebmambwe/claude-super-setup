#!/usr/bin/env bash
set -euo pipefail

# Assert minimum file counts to catch accidental deletions
ERRORS=0

check_count() {
  local dir="$1"
  local pattern="$2"
  local min="$3"
  local label="$4"

  local count
  count=$(find "$dir" -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$count" -lt "$min" ]; then
    echo "FAIL: $label — found $count, expected >= $min"
    ERRORS=$((ERRORS + 1))
  else
    echo "OK: $label — $count (min: $min)"
  fi
}

check_count "commands" "*.md" 70 "Commands"
check_count "agents" "*.md" 40 "Agents"
check_count "hooks" "*.sh" 12 "Hooks"
check_count "rules" "*.md" 13 "Rules"
check_count "config/stacks" "*.yaml" 3 "Stack templates"

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS inventory check(s) failed"
  exit 1
fi

echo "All inventory checks passed."
