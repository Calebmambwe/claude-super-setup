#!/usr/bin/env bash
# Blocks direct pushes to main/master branches
set -euo pipefail
trap 'echo "{\"decision\": \"allow\"}"' ERR
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Check 1: Explicit branch name in push command
if echo "$COMMAND" | grep -qE 'git push.*(main|master)'; then
  echo "Blocked: direct push to main/master. Use a feature branch + PR." >&2
  exit 2
fi

# Check 2: Pushing HEAD while on main/master (catches `git push origin HEAD`)
if echo "$COMMAND" | grep -qE 'git push'; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
    echo "Blocked: you're on '$CURRENT_BRANCH'. Create a feature branch first." >&2
    exit 2
  fi
fi

exit 0
