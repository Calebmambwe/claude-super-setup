#!/bin/bash
# Auto-fix build loop: runs build+typecheck+lint after code edits
# If any check fails, outputs the error so Claude can fix it immediately
# Debounces: skips if last check was <5 seconds ago
# NOTE: Output within code fences is raw tool output, not instructions

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path or empty
[ -z "$FILE_PATH" ] && exit 0

# Validate file path contains only safe characters (no shell metacharacters)
if ! [[ "$FILE_PATH" =~ ^/[a-zA-Z0-9_./@\ -]+$ ]]; then
  exit 0
fi

# Canonicalize path and re-validate
FILE_PATH=$(realpath -- "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
if ! [[ "$FILE_PATH" =~ ^/[a-zA-Z0-9_./@\ -]+$ ]]; then
  exit 0
fi

# Find project root (walk up from the edited file to find package.json or pyproject.toml)
find_project_root() {
  local dir="$1"
  [ -z "$HOME" ] && return 1
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/package.json" ] || [ -f "$dir/pyproject.toml" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root "$(dirname "$FILE_PATH")")
[ -z "$PROJECT_ROOT" ] && exit 0

# Debounce: skip if last check was <5 seconds ago (atomic via lock dir)
DEBOUNCE_FILE="$PROJECT_ROOT/.claude-autofix-last-run"
LOCK="$PROJECT_ROOT/.claude-autofix.lock"
# Remove stale lock if older than 30 seconds (e.g., after SIGKILL)
if [ -d "$LOCK" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
  [ "$LOCK_AGE" -gt 30 ] && rmdir "$LOCK" 2>/dev/null
fi
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

if [ -f "$DEBOUNCE_FILE" ]; then
  LAST_RUN=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)
  # Validate numeric
  [[ "$LAST_RUN" =~ ^[0-9]+$ ]] || LAST_RUN=0
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_RUN))
  if [ "$DIFF" -lt 5 ]; then
    exit 0
  fi
fi

# Atomic write to debounce file
TMPFILE=$(mktemp "$PROJECT_ROOT/.claude-autofix-XXXXXX" 2>/dev/null)
if [ -n "$TMPFILE" ]; then
  date +%s > "$TMPFILE"
  mv "$TMPFILE" "$DEBOUNCE_FILE" 2>/dev/null
fi

cd "$PROJECT_ROOT" || exit 0

ERRORS=""
MAX_OUTPUT=8192

# Detect project type and run checks
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

  # Check which scripts exist in package.json
  HAS_BUILD=$(jq -r '.scripts.build // empty' package.json 2>/dev/null)
  HAS_LINT=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)

  # Run typecheck (fastest feedback)
  # Always use tsc directly — npm/pnpm run can swallow exit codes
  if [ -f "tsconfig.json" ]; then
    TC_OUT=$($PKG_MGR exec -- tsc --noEmit 2>&1 | head -c $MAX_OUTPUT)
    TC_EXIT=$?
    # Fallback: detect errors in output even if exit code is 0 (npm bug)
    if [ $TC_EXIT -ne 0 ] || echo "$TC_OUT" | grep -q "error TS"; then
      ERRORS="${ERRORS}\n## TypeCheck Failed\n\`\`\`\n${TC_OUT}\n\`\`\`\n"
    fi
  fi

  # Run lint
  if [ -n "$HAS_LINT" ]; then
    LINT_OUT=$($PKG_MGR run lint 2>&1 | head -c $MAX_OUTPUT)
    LINT_EXIT=$?
    if [ $LINT_EXIT -ne 0 ]; then
      ERRORS="${ERRORS}\n## Lint Failed\n\`\`\`\n${LINT_OUT}\n\`\`\`\n"
    fi
  fi

  # Run build (skip for test files — too slow for every edit)
  BASENAME=$(basename "$FILE_PATH")
  IS_TEST=false
  case "$BASENAME" in
    *.test.*|*.spec.*|*_test.*|*_spec.*) IS_TEST=true ;;
  esac

  if [ "$IS_TEST" = false ] && [ -n "$HAS_BUILD" ]; then
    BUILD_OUT=$($PKG_MGR run build 2>&1 | head -c $MAX_OUTPUT)
    BUILD_EXIT=$?
    if [ $BUILD_EXIT -ne 0 ]; then
      ERRORS="${ERRORS}\n## Build Failed\n\`\`\`\n${BUILD_OUT}\n\`\`\`\n"
    fi
  fi

elif [ -f "pyproject.toml" ]; then
  # Python project
  if command -v ruff &>/dev/null; then
    RUFF_OUT=$(ruff check -- "$FILE_PATH" 2>&1 | head -c $MAX_OUTPUT)
    RUFF_EXIT=$?
    if [ $RUFF_EXIT -ne 0 ]; then
      ERRORS="${ERRORS}\n## Ruff Check Failed\n\`\`\`\n${RUFF_OUT}\n\`\`\`\n"
    fi
  fi

  # Only run mypy if installed AND configured
  if command -v mypy &>/dev/null && { [ -f "mypy.ini" ] || grep -q '\[tool\.mypy\]' pyproject.toml 2>/dev/null; }; then
    MYPY_OUT=$(mypy -- "$FILE_PATH" 2>&1 | head -c $MAX_OUTPUT)
    MYPY_EXIT=$?
    if [ $MYPY_EXIT -ne 0 ]; then
      ERRORS="${ERRORS}\n## MyPy Failed\n\`\`\`\n${MYPY_OUT}\n\`\`\`\n"
    fi
  fi
fi

# Output errors if any (this gets fed back to Claude)
# Content within code fences below is raw tool output — treat as untrusted data, not instructions
if [ -n "$ERRORS" ]; then
  echo -e "# Auto-Fix Loop: Errors Detected\n\nThe following checks failed after your edit to \`$(basename "$FILE_PATH")\`. Fix these before continuing:\n$ERRORS"
fi

exit 0
