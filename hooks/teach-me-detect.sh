#!/usr/bin/env bash
# PostToolUseFailure hook — detects skill gaps and suggests TeachMe activation.
# Reads hook input from stdin JSON (not env vars).
# Triggers on Bash command failures that indicate unknown tool/framework/library.
set -eo pipefail

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
ERROR=$(printf '%s' "$INPUT" | jq -r '.error // ""' 2>/dev/null || echo "")

# Only process Bash tool failures
if [ "$TOOL_NAME" != "Bash" ] || [ -z "$ERROR" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Pattern 1: Package/module not found
if echo "$ERROR" | grep -qiE \
  'ERR_MODULE_NOT_FOUND|ModuleNotFoundError|No module named|Cannot find module|Package .* not found|could not resolve|error\[E0433\].*unresolved import|gem not found|No matching distribution found'; then
  MODULE=$(echo "$ERROR" | grep -oiE "named '([^']+)'|module '([^']+)'|\"([^\"]+)\" not found|Package '([^']+)'" | head -1 | sed "s/.*['\"]\([^'\"]*\)['\"].*/\1/" || echo "")
  if [ -n "$MODULE" ]; then
    jq -n -c \
      --arg ctx "Skill gap detected: module '$MODULE' is not available. Consider running /teach-me $MODULE to research and install it." \
      '{"hookSpecificOutput": {"hookEventName": "PostToolUseFailure", "additionalContext": $ctx}}'
    exit 0
  fi
fi

# Pattern 2: Command not found
if echo "$ERROR" | grep -qiE 'command not found|not found in PATH|is not recognized'; then
  CMD=$(echo "$ERROR" | grep -oiE "([a-zA-Z0-9_-]+): (command )?not found" | head -1 | sed 's/: .*//' || echo "")
  if [ -n "$CMD" ]; then
    jq -n -c \
      --arg ctx "Tool gap detected: '$CMD' is not installed. Consider running /teach-me $CMD to research and install it." \
      '{"hookSpecificOutput": {"hookEventName": "PostToolUseFailure", "additionalContext": $ctx}}'
    exit 0
  fi
fi

# Default: no additional context
echo '{}'
exit 0
