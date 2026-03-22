#!/usr/bin/env bash
set -euo pipefail

# Validate that all agent .md files have either:
# - YAML front-matter with name and description fields, OR
# - A title heading (# heading)
AGENTS_DIR="agents"
ERRORS=0
COUNT=0

while IFS= read -r -d '' agent; do
  COUNT=$((COUNT + 1))
  # Check for YAML front-matter (---) or markdown heading (#)
  if head -1 "$agent" | grep -q "^---$"; then
    # Has front-matter — check for name field
    if ! head -10 "$agent" | grep -q "^name:"; then
      echo "FAIL: $agent — front-matter missing 'name' field"
      ERRORS=$((ERRORS + 1))
    fi
  elif ! head -5 "$agent" | grep -q "^#"; then
    echo "FAIL: $agent — missing front-matter or title heading"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$AGENTS_DIR" -name "*.md" -not -name "README.md" -print0)

echo "Checked $COUNT agent files."

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS agent(s) failed validation"
  exit 1
fi

echo "All agents have valid structure."
