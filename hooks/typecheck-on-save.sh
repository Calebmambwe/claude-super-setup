#!/bin/bash
# PostToolUse: Run TypeScript type-check (tsc --noEmit) after .ts/.tsx writes.
# Warns (exit 2) if type errors are found. Times out after 10 seconds.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on Write and Edit tool calls
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Only check .ts and .tsx files
if [[ "$FILE_PATH" != *.ts && "$FILE_PATH" != *.tsx ]]; then
  exit 0
fi

# File must exist on disk
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Walk up from the file's directory to find the project root (package.json or tsconfig.json)
PROJECT_ROOT=$(dirname "$FILE_PATH")
while [[ "$PROJECT_ROOT" != "/" ]]; do
  if [[ -f "$PROJECT_ROOT/tsconfig.json" || -f "$PROJECT_ROOT/package.json" ]]; then
    break
  fi
  PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

# Must reach the filesystem root — no project found
if [[ "$PROJECT_ROOT" == "/" ]]; then
  exit 0
fi

# Must have a tsconfig.json specifically — not just any package.json
if [[ ! -f "$PROJECT_ROOT/tsconfig.json" ]]; then
  exit 0
fi

# Run tsc with a 10-second timeout
TSC_OUTPUT=$(cd "$PROJECT_ROOT" && timeout 10 npx --no-install tsc --noEmit 2>&1 | head -20 || true)
TSC_EXIT=${PIPESTATUS[0]:-0}

# timeout returns 124 on timeout expiry
if [[ "$TSC_EXIT" == "124" ]]; then
  echo "TypeScript check timed out (10s) for '$FILE_PATH' — run 'tsc --noEmit' manually to verify." >&2
  exit 2
fi

if [[ -n "$TSC_OUTPUT" && "$TSC_EXIT" != "0" ]]; then
  echo "TypeScript errors in project containing '$FILE_PATH':" >&2
  echo "$TSC_OUTPUT" >&2
  exit 2
fi

exit 0
