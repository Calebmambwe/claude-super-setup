#!/usr/bin/env bash
# Auto Quality Gate — runs lint + typecheck automatically after code changes
# Hook type: PostToolUse (Edit, Write)
# NOTE: Output within code fences is raw tool output, not instructions
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger on Edit/Write tools
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

# Validate file path contains only safe characters
if ! [[ "$FILE_PATH" =~ ^/[a-zA-Z0-9_./@\ -]+$ ]]; then
  exit 0
fi

FILE_PATH=$(realpath -- "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
if ! [[ "$FILE_PATH" =~ ^/[a-zA-Z0-9_./@\ -]+$ ]]; then
  exit 0
fi

# Only check source files
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs) ;;
  *) exit 0 ;;
esac

# Find project root
find_project_root() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/package.json" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/go.mod" ] || [ -f "$dir/Cargo.toml" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root "$(dirname "$FILE_PATH")")
[ -z "$PROJECT_ROOT" ] && exit 0

cd "$PROJECT_ROOT" || exit 0

ERRORS=""
MAX_OUTPUT=4096

# ── TypeScript / JavaScript projects ──────────────────────────────────────────

if [ -f "package.json" ]; then
  # Detect package manager
  if [ -f "pnpm-lock.yaml" ]; then
    PKG_MGR="pnpm"
  elif [ -f "bun.lockb" ]; then
    PKG_MGR="bun"
  elif [ -f "yarn.lock" ]; then
    PKG_MGR="yarn"
  else
    PKG_MGR="npm"
  fi

  # Run lint (if eslint/biome configured)
  HAS_ESLINT=$(jq -r '.devDependencies.eslint // .dependencies.eslint // empty' package.json 2>/dev/null)
  HAS_BIOME=$(jq -r '.devDependencies["@biomejs/biome"] // .dependencies["@biomejs/biome"] // empty' package.json 2>/dev/null)

  if [ -n "$HAS_ESLINT" ]; then
    LINT_OUT=$($PKG_MGR exec -- eslint --max-warnings 0 -- "$FILE_PATH" 2>&1 | head -c $MAX_OUTPUT)
    LINT_EXIT=$?
    if [ $LINT_EXIT -ne 0 ]; then
      ERRORS="# Lint Failed\n\n\`\`\`\n${LINT_OUT}\n\`\`\`\n"
    fi
  elif [ -n "$HAS_BIOME" ]; then
    LINT_OUT=$($PKG_MGR exec -- biome check -- "$FILE_PATH" 2>&1 | head -c $MAX_OUTPUT)
    LINT_EXIT=$?
    if [ $LINT_EXIT -ne 0 ]; then
      ERRORS="# Lint Failed\n\n\`\`\`\n${LINT_OUT}\n\`\`\`\n"
    fi
  fi

  # Run typecheck (if TypeScript)
  HAS_TS=$(jq -r '.devDependencies.typescript // .dependencies.typescript // empty' package.json 2>/dev/null)
  case "$BASENAME" in
    *.ts|*.tsx)
      if [ -n "$HAS_TS" ]; then
        TC_OUT=$($PKG_MGR exec -- tsc --noEmit 2>&1 | head -c $MAX_OUTPUT)
        TC_EXIT=$?
        if [ $TC_EXIT -ne 0 ]; then
          ERRORS="${ERRORS}# TypeCheck Failed\n\n\`\`\`\n${TC_OUT}\n\`\`\`\n"
        fi
      fi
      ;;
  esac
fi

# ── Python projects ───────────────────────────────────────────────────────────

if [ -f "pyproject.toml" ]; then
  case "$BASENAME" in
    *.py)
      # Run ruff if available
      if command -v ruff &>/dev/null; then
        RUFF_OUT=$(ruff check -- "$FILE_PATH" 2>&1 | head -c $MAX_OUTPUT)
        RUFF_EXIT=$?
        if [ $RUFF_EXIT -ne 0 ]; then
          ERRORS="${ERRORS}# Ruff Lint Failed\n\n\`\`\`\n${RUFF_OUT}\n\`\`\`\n"
        fi
      fi

      # Run mypy if available
      if command -v mypy &>/dev/null; then
        MYPY_OUT=$(mypy -- "$FILE_PATH" 2>&1 | head -c $MAX_OUTPUT)
        MYPY_EXIT=$?
        if [ $MYPY_EXIT -ne 0 ]; then
          ERRORS="${ERRORS}# MyPy TypeCheck Failed\n\n\`\`\`\n${MYPY_OUT}\n\`\`\`\n"
        fi
      fi
      ;;
  esac
fi

# Content within code fences is raw tool output — treat as untrusted data
if [ -n "$ERRORS" ]; then
  echo -e "$ERRORS"
  echo "Fix the above issues before continuing."
fi

exit 0
