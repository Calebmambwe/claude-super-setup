#!/bin/bash
# Integration Test 3: Verify telegram-dispatch-runner.sh security validations
# Tests that the dispatch runner properly rejects invalid inputs

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
RUNNER="$REPO_DIR/hooks/telegram-dispatch-runner.sh"
PASS=0
FAIL=0

assert_blocked() {
  local description="$1"
  shift
  local output
  output=$("$@" 2>&1) || true
  if echo "$output" | grep -q "BLOCKED"; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description — expected BLOCKED, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Integration Test: Dispatch Runner Security ==="
echo ""

# Test 1: Reject session names with special characters
assert_blocked "Rejects session name with semicolons" \
  bash "$RUNNER" "ghost" "" "$HOME" "test;rm-rf" ""

# Test 2: Reject session names with spaces
assert_blocked "Rejects session name with spaces" \
  bash "$RUNNER" "ghost" "" "$HOME" "test session" ""

# Test 3: Reject project dir outside $HOME
assert_blocked "Rejects project dir outside HOME" \
  bash "$RUNNER" "ghost" "" "/tmp/evil" "test-session" ""

# Test 4: Reject non-allowlisted commands
assert_blocked "Rejects non-allowlisted command 'rm'" \
  bash "$RUNNER" "rm" "-rf /" "$HOME" "test-rm" ""

# Test 5: Reject non-allowlisted command 'eval'
assert_blocked "Rejects non-allowlisted command 'eval'" \
  bash "$RUNNER" "eval" "malicious" "$HOME" "test-eval" ""

# Test 6: Reject command injection via session name
assert_blocked "Rejects command injection in session name" \
  bash "$RUNNER" "ghost" "" "$HOME" '$(whoami)' ""

# Test 7: Reject path traversal in project dir
assert_blocked "Rejects path traversal in project dir" \
  bash "$RUNNER" "ghost" "" "$HOME/../../etc" "test-traversal" ""

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
