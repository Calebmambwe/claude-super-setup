#!/usr/bin/env bash
# Warns when editing existing files — reminder only, does not block.
# The actual enforcement comes from Claude's Read-before-Edit convention.
set -euo pipefail
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Allow new file creation
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# For existing files, print a reminder (non-blocking)
echo "Reminder: '$FILE_PATH' exists. Ensure you've read it before modifying."
exit 0
