#!/bin/bash
# Block writes to critical configuration files
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

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
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "{\"decision\": \"block\", \"reason\": \"Protected file: $FILE_PATH matches '$pattern'. Use the package manager or environment tools instead.\"}" >&2
    exit 2
  fi
done

exit 0
