#!/usr/bin/env bash
# Blocks direct pushes to main/master branches
# PreToolUse hook — outputs decision JSON to stdout (NOT stderr)
set -eo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only check git push commands
if ! echo "$COMMAND" | grep -q 'git push'; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Check 1: Explicit branch name in push command
if echo "$COMMAND" | grep -qE 'git push.*(main|master)'; then
  echo '{"decision": "block", "reason": "Blocked: direct push to main/master. Use a feature branch + PR."}'
  exit 0
fi

# Check 2: Pushing HEAD while on main/master
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  echo "{\"decision\": \"block\", \"reason\": \"Blocked: you're on '$CURRENT_BRANCH'. Create a feature branch first.\"}"
  exit 0
fi

echo '{"decision": "allow"}'
exit 0
