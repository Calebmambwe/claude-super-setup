#!/usr/bin/env bash
# Block writes to critical configuration files
# PreToolUse hook — outputs decision JSON to stdout (NOT stderr)
set -eo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# If no file path, allow
if [ -z "$FILE_PATH" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

PROTECTED_PATTERNS=(
  ".env"
  ".env.local"
  ".env.production"
  ".env.development"
  ".env.staging"
  "package-lock.json"
  "pnpm-lock.yaml"
  "yarn.lock"
  "bun.lockb"
  ".git/"
  "node_modules/"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/CLAUDE.md"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "{\"decision\": \"block\", \"reason\": \"Protected file: $FILE_PATH matches '$pattern'. Use the package manager or environment tools instead.\"}"
    exit 0
  fi
done

echo '{"decision": "allow"}'
exit 0
