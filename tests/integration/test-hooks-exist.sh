#!/bin/bash
# Integration Test 1: Verify all required hooks exist and are executable
# Tests the hook infrastructure is complete after install

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0
FAIL=0

assert_hook() {
  local hook="$1"
  local path="$REPO_DIR/hooks/$hook"
  if [ -f "$path" ]; then
    if [ -x "$path" ]; then
      echo "  ✅ $hook (exists, executable)"
      PASS=$((PASS + 1))
    else
      echo "  ❌ $hook (exists, NOT executable)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ❌ $hook (MISSING)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Integration Test: Hook Infrastructure ==="
echo ""

# Core hooks
assert_hook "test-after-impl.sh"
assert_hook "auto-quality-gate.sh"
assert_hook "telemetry.sh"
assert_hook "alert-check.sh"
assert_hook "ghost-notify.sh"
assert_hook "ghost-watchdog.sh"
assert_hook "ghost-monitor.sh"
assert_hook "telegram-dispatch-runner.sh"
assert_hook "branch-guard.sh"
assert_hook "protect-files.sh"
assert_hook "read-before-write.sh"
assert_hook "session-start.sh"
assert_hook "session-end.sh"
assert_hook "auto-fix-loop.sh"
assert_hook "auto-learn.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
