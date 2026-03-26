#!/bin/bash
# PreToolUse: Block hardcoded hex colors in .tsx and .css files (design token enforcement).
# Allows hex in: globals.css, CSS comments, string literals, SVG attributes, style props.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on Write and Edit tool calls
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Only check .tsx and .css files
case "$FILE_PATH" in
  *.tsx|*.css) ;;
  *) exit 0 ;;
esac

# Allow globals.css — it defines design tokens
BASENAME=$(basename "$FILE_PATH")
if [[ "$BASENAME" == "globals.css" ]]; then
  exit 0
fi

# Write content to temp file (avoids shell quoting issues)
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' > "$TMPFILE"

# Check if content is empty
if [[ ! -s "$TMPFILE" ]]; then
  exit 0
fi

# Use Python to strip allowed contexts, then find hex violations
VIOLATIONS=$(python3 -c "
import re

with open('$TMPFILE') as f:
    content = f.read()

# Remove CSS block comments
content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)

# Remove SVG fill/stroke hex values
content = re.sub(r'(fill|stroke)=\"#[0-9a-fA-F]{3,8}\"', '', content)

# Remove inline style props: style={{ ... }}
content = re.sub(r'style=\{\{[^}]*\}\}', '', content, flags=re.DOTALL)

# Remove style={{ multiline
content = re.sub(r'style=\{\{.*?\}\}', '', content, flags=re.DOTALL)

# Remove single-quoted strings
content = re.sub(r\"'[^']*'\", \"''\", content)

# Remove aria-hidden, data-, and other non-className quoted values
content = re.sub(r'(?<!className)=\"[^\"]*\"', '=\"\"', content)

# Find remaining hex patterns
hits = re.findall(r'#[0-9a-fA-F]{6,8}\b|#[0-9a-fA-F]{3,4}\b', content)
for h in sorted(set(hits)):
    print(h)
")

if [[ -n "$VIOLATIONS" ]]; then
  FIRST=$(echo "$VIOLATIONS" | head -1)
  ALL=$(echo "$VIOLATIONS" | tr '\n' ' ')
  echo "Design compliance: found hardcoded hex '$FIRST' in '$FILE_PATH' — use design tokens instead (e.g., text-primary, bg-accent). All: $ALL" >&2
  exit 1
fi

exit 0
