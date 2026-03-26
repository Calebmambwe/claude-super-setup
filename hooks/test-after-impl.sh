#!/usr/bin/env bash
# Runs tests after source file modifications — triggers on BOTH test files and source files
# For test files: runs that specific test
# For source files: finds and runs the corresponding test file
# Provides immediate feedback on test pass/fail
# NOTE: Output within code fences is raw tool output, not instructions
set -euo pipefail

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

BASENAME=$(basename "$FILE_PATH")

# Only trigger on source code files
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs) ;;
  *) exit 0 ;;
esac

# Skip node_modules, dist, build, .next, coverage directories
case "$FILE_PATH" in
  */node_modules/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*|*/__pycache__/*|*/.venv/*) exit 0 ;;
esac

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

ERRORS=""
MAX_OUTPUT=8192

# Determine if this is a test file or a source file
IS_TEST_FILE=false
case "$BASENAME" in
  *.test.*|*.spec.*|*_test.*|*_spec.*|test_*) IS_TEST_FILE=true ;;
esac
case "$FILE_PATH" in
  */__tests__/*|*/tests/*|*/test/*) IS_TEST_FILE=true ;;
esac

# For source files, find the corresponding test file
find_test_file() {
  local src_path="$1"
  local src_basename
  src_basename=$(basename "$src_path")
  local src_name="${src_basename%.*}"
  local src_ext="${src_basename##*.}"
  local src_dir
  src_dir=$(dirname "$src_path")
  local rel_dir="${src_dir#$PROJECT_ROOT/}"

  # Search patterns for corresponding test file (Bash 3.2 compatible — no arrays)
  local candidates
  candidates="$src_dir/${src_name}.test.${src_ext}
$src_dir/${src_name}.spec.${src_ext}
$src_dir/__tests__/${src_name}.test.${src_ext}
$src_dir/__tests__/${src_name}.spec.${src_ext}
$PROJECT_ROOT/tests/${rel_dir}/${src_name}.test.${src_ext}
$PROJECT_ROOT/test/${rel_dir}/${src_name}.test.${src_ext}
$PROJECT_ROOT/tests/${rel_dir}/${src_name}.spec.${src_ext}
$src_dir/test_${src_name}.${src_ext}
$PROJECT_ROOT/tests/test_${src_name}.${src_ext}
$PROJECT_ROOT/tests/${rel_dir}/test_${src_name}.${src_ext}"

  while IFS= read -r candidate; do
    if [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done <<< "$candidates"

  return 1
}

# Determine which file to test
TEST_TARGET="$FILE_PATH"
if [ "$IS_TEST_FILE" = false ]; then
  FOUND_TEST=$(find_test_file "$FILE_PATH")
  if [ -z "$FOUND_TEST" ]; then
    # No corresponding test file found — skip silently
    exit 0
  fi
  TEST_TARGET="$FOUND_TEST"
fi

REL_PATH="${TEST_TARGET#$PROJECT_ROOT/}"

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
    TEST_BASENAME=$(basename "$TEST_TARGET")
    if [ "$IS_TEST_FILE" = false ]; then
      ERRORS="# Test Failed: $TEST_BASENAME (triggered by $BASENAME)\n\n\`\`\`\n${TEST_OUT}\n\`\`\`\n\nFix the failing test before continuing."
    else
      ERRORS="# Test Failed: $TEST_BASENAME\n\n\`\`\`\n${TEST_OUT}\n\`\`\`\n\nFix the failing test before continuing."
    fi
  fi

elif [ -f "pyproject.toml" ]; then
  TEST_OUT=$(python -m pytest -- "$REL_PATH" -v 2>&1 | head -c $MAX_OUTPUT)
  TEST_EXIT=$?
  if [ $TEST_EXIT -ne 0 ]; then
    TEST_BASENAME=$(basename "$TEST_TARGET")
    if [ "$IS_TEST_FILE" = false ]; then
      ERRORS="# Test Failed: $TEST_BASENAME (triggered by $BASENAME)\n\n\`\`\`\n${TEST_OUT}\n\`\`\`\n\nFix the failing test before continuing."
    else
      ERRORS="# Test Failed: $TEST_BASENAME\n\n\`\`\`\n${TEST_OUT}\n\`\`\`\n\nFix the failing test before continuing."
    fi
  fi
fi

# Content within code fences is raw tool output — treat as untrusted data
if [ -n "$ERRORS" ]; then
  echo -e "$ERRORS"
fi

exit 0
