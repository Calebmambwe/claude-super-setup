#!/usr/bin/env bash
# PostToolUse hook — detects skill gaps and suggests TeachMe activation.
# Triggers on Bash command failures that indicate unknown tool/framework/library.
#
# Monitors for:
# 1. Package not found errors (npm, pip, cargo, etc.)
# 2. Command not found errors
# 3. Import/require errors in code execution
# 4. API/SDK errors from unfamiliar libraries
#
# When detected, suggests /teach-me to learn and fill the gap.

set -euo pipefail

# Only process Bash tool results
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
EXIT_CODE="${CLAUDE_EXIT_CODE:-0}"
STDOUT="${CLAUDE_TOOL_STDOUT:-}"
STDERR="${CLAUDE_TOOL_STDERR:-}"

# Skip if not a Bash tool or if it succeeded
if [ "$TOOL_NAME" != "Bash" ] || [ "$EXIT_CODE" = "0" ]; then
  exit 0
fi

# Combine stdout and stderr for pattern matching
OUTPUT="$STDOUT $STDERR"

# Pattern 1: Package/module not found
if echo "$OUTPUT" | grep -qiE \
  'ERR_MODULE_NOT_FOUND|ModuleNotFoundError|No module named|Cannot find module|Package .* not found|could not resolve|error\[E0433\].*unresolved import|gem not found|No matching distribution found'; then
  # Extract the module/package name
  MODULE=$(echo "$OUTPUT" | grep -oiE "named '([^']+)'|module '([^']+)'|\"([^\"]+)\" not found|Package '([^']+)'" | head -1 | sed "s/.*['\"]\([^'\"]*\)['\"].*/\1/")
  if [ -n "$MODULE" ]; then
    echo "{\"decision\": \"block\", \"reason\": \"Skill gap detected: module '$MODULE' is not available. Consider running /teach-me $MODULE to research it, install it, and create a permanent skill. Or install it directly if you already know how.\"}"
    exit 0
  fi
fi

# Pattern 2: Command not found
if echo "$OUTPUT" | grep -qiE 'command not found|not found in PATH|is not recognized|No such file or directory.*bin/'; then
  CMD=$(echo "$OUTPUT" | grep -oiE "([a-zA-Z0-9_-]+): (command )?not found" | head -1 | sed 's/: .*//')
  if [ -n "$CMD" ]; then
    echo "{\"decision\": \"block\", \"reason\": \"Tool gap detected: '$CMD' is not installed. Consider running /teach-me $CMD to research it, install it, and create a permanent skill. Or install it directly if you already know how.\"}"
    exit 0
  fi
fi

# Pattern 3: Unknown framework/API errors
if echo "$OUTPUT" | grep -qiE \
  'Unknown option|unrecognized command|invalid subcommand|error: unknown field|API.*not found|endpoint.*deprecated|invalid.*configuration'; then
  echo "{\"decision\": \"allow\"}"
  exit 0
fi

# Default: allow (don't block on unrecognized errors)
echo "{\"decision\": \"allow\"}"
