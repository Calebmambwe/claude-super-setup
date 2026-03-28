#!/bin/bash
# sandbox-router.sh — PreToolUse hook for Bash commands
#
# Intercepts dangerous commands and blocks them with instructions
# to use the sandbox MCP tools instead. This ensures untrusted
# code runs in Docker, not on the host machine.
#
# Trigger: PreToolUse on Bash tool

set -euo pipefail

# Parse tool input from Claude Code
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$TOOL_INPUT" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null)
if [ -z "$COMMAND" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Commands that are ALWAYS safe on host (never route to sandbox)
SAFE_PATTERNS=(
  "^git "
  "^docker "
  "^gh "
  "^brew "
  "^claude "
  "^code "
  "^cursor "
  "^open "
  "^pbcopy"
  "^pbpaste"
  "^cat "
  "^ls"
  "^pwd"
  "^cd "
  "^echo "
  "^which "
  "^mkdir "
  "^cp "
  "^mv "
  "^chmod "
  "^chown "
  "^head "
  "^tail "
  "^wc "
  "^sort "
  "^grep "
  "^find "
  "^sed "
  "^awk "
  "^diff "
  "^lsof "
  "^ps "
  "^kill "
  "^pkill "
  "^pnpm test"
  "^pnpm lint"
  "^pnpm typecheck"
  "^pnpm build"
  "^npm test"
  "^npm run lint"
  "^npm run build"
  "^pytest"
  "^ruff "
  "^mypy "
  "^npx next"
  "^npx tsc"
)

for pattern in "${SAFE_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo '{"decision": "allow"}'
    exit 0
  fi
done

# Commands that SHOULD run in the sandbox
SANDBOX_PATTERNS=(
  "pip install"
  "pip3 install"
  "npm install"
  "npx [^tn]"
  "pnpm add "
  "pnpm install"
  "yarn add"
  "yarn install"
  "python3? [^ ]*\.py"
  "node [^ ]*\.js"
  "bun run"
  "deno run"
  "curl.*\| *bash"
  "curl.*\| *sh"
  "wget.*\| *bash"
  "wget.*\| *sh"
  "playwright "
  "puppeteer"
  "cargo run"
  "go run"
  "make "
  "cmake "
  "gcc "
  "g\+\+ "
  "javac "
  "java "
  "rustc "
)

for pattern in "${SANDBOX_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    # Log the routed command
    echo "[$(date -Iseconds)] ROUTED: $COMMAND" >> ~/.claude/sandbox-audit.log 2>/dev/null || true

    cat <<ENDJSON
{"decision": "block", "reason": "This command should run in the sandbox for safety. Use the sandbox MCP tool instead:\n\nmcp__sandbox__sandbox_exec(command=\"$COMMAND\")\n\nThe sandbox has Python, Node.js, and full internet access. Start it first with mcp__sandbox__sandbox_start() if not already running."}
ENDJSON
    exit 0
  fi
done

# Default: allow everything else
echo '{"decision": "allow"}'
