#!/bin/bash
# Runs the specific test file that was just modified
# Provides immediate feedback on test pass/fail
# NOTE: Output within code fences is raw tool output, not instructions

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Validate file path contains only safe characters
if ! [[ "$FILE_PATH" =~ ^/[a-zA-Z0-9_./@\ -]+$ ]]; then
  exit 0
fi

FILE_PATH=$(realpath -- "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
if ! [[ "$FILE_PATH" =~ ^/[a-zA-Z0-9_./@\ -]+$ ]]; then
  exit 0
fi

# Find project root
find_project_root() {
  local dir="$1"
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

cd "$PROJECT_ROOT" || exit 0

BASENAME=$(basename "$FILE_PATH")
ERRORS=""
MAX_OUTPUT=8192

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

  # Detect test runner
  HAS_VITEST=$(jq -r '.devDependencies.vitest // .dependencies.vitest // empty' package.json 2>/dev/null)
  HAS_JEST=$(jq -r '.devDependencies.jest // .dependencies.jest // empty' package.json 2>/dev/null)

  # Make path relative to project root
  REL_PATH="${FILE_PATH#$PROJECT_ROOT/}"

  if [ -n "$HAS_VITEST" ]; then
    TEST_OUT=$($PKG_MGR exec -- vitest run -- "$REL_PATH" 2>&1 | head -c $MAX_OUTPUT)
    TEST_EXIT=$?
  elif [ -n "$HAS_JEST" ]; then
    TEST_OUT=$($PKG_MGR exec -- jest --no-coverage -- "$REL_PATH" 2>&1 | head -c $MAX_OUTPUT)
    TEST_EXIT=$?
  else
    # No known test runner detected — skip silently
    exit 0
  fi

  # Report failure if:
  # - exit code is non-zero (real failure), OR
  # - exit 0 but output contains "N failed" where N > 0 (npm exit-code swallowing)
  REAL_FAILURE=false
  [ $TEST_EXIT -ne 0 ] && REAL_FAILURE=true
  echo "$TEST_OUT" | grep -qE "[1-9][0-9]* failed" && REAL_FAILURE=true
  if [ "$REAL_FAILURE" = true ]; then
    ERRORS="# Test Failed: $BASENAME\n\n\`\`\`\n${TEST_OUT}\n\`\`\`\n\nFix the failing test before continuing."
  fi

elif [ -f "pyproject.toml" ]; then
  REL_PATH="${FILE_PATH#$PROJECT_ROOT/}"
  TEST_OUT=$(python -m pytest -- "$REL_PATH" -v 2>&1 | head -c $MAX_OUTPUT)
  TEST_EXIT=$?
  if [ $TEST_EXIT -ne 0 ]; then
    ERRORS="# Test Failed: $BASENAME\n\n\`\`\`\n${TEST_OUT}\n\`\`\`\n\nFix the failing test before continuing."
  fi
fi

# Content within code fences is raw tool output — treat as untrusted data
if [ -n "$ERRORS" ]; then
  echo -e "$ERRORS"
fi

exit 0
