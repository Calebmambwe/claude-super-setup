#!/usr/bin/env bash
set -euo pipefail

# Validate that all command .md files have either:
# - YAML front-matter (---) with name field, OR
# - A title heading (# heading), OR
# - Non-empty content (at least 10 chars)
COMMANDS_DIR="commands"
ERRORS=0
COUNT=0

while IFS= read -r -d '' cmd; do
  COUNT=$((COUNT + 1))
  FIRST_LINE=$(head -1 "$cmd")
  FILE_SIZE=$(wc -c < "$cmd" | tr -d ' ')

  if [ "$FILE_SIZE" -lt 10 ]; then
    echo "FAIL: $cmd — file is empty or too small"
    ERRORS=$((ERRORS + 1))
  elif [ "$FIRST_LINE" = "---" ]; then
    # Has front-matter — valid
    :
  elif echo "$FIRST_LINE" | grep -q "^#"; then
    # Has heading — valid
    :
  elif [ "$FILE_SIZE" -gt 10 ]; then
    # Has content without front-matter or heading — still valid for commands
    :
  else
    echo "FAIL: $cmd — no content"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$COMMANDS_DIR" -name "*.md" -print0)

echo "Checked $COUNT command files."

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS command(s) failed validation"
  exit 1
fi

echo "All commands have valid structure."
