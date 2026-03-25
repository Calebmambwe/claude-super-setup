#!/bin/bash
# Integration Test 4: Verify ghost-notify.sh handles all notification levels
# Tests that the notification script processes all levels without errors
# (Actual delivery depends on network/config, so we test the script logic)

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
NOTIFY="$REPO_DIR/hooks/ghost-notify.sh"
PASS=0
FAIL=0

# Create a temporary ghost config with no external URLs (dry run)
TEMP_CONFIG=$(mktemp)
cat > "$TEMP_CONFIG" <<'JSON'
{
  "notify_url": "",
  "telegram_chat_id": "",
  "status": "testing"
}
JSON

assert_exits_zero() {
  local description="$1"
  local level="$2"
  local message="$3"
  local pr_url="${4:-}"

  # Override config to prevent actual notifications
  HOME_BACKUP="$HOME"
  export GHOST_NOTIFY_DRY_RUN=1

  if bash "$NOTIFY" "$level" "$message" "$pr_url" 2>/dev/null; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description — exited non-zero"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Integration Test: Ghost Notify Levels ==="
echo ""

# Test all notification levels
assert_exits_zero "start level" "start" "Ghost Mode started for testing"
assert_exits_zero "phase level" "phase" "Build phase 3/7 complete"
assert_exits_zero "warning level" "warning" "Test suite failure detected"
assert_exits_zero "success level" "success" "Pipeline complete!" "https://github.com/test/repo/pull/42"
assert_exits_zero "failure level" "failure" "Pipeline failed at check gate"
assert_exits_zero "unknown level" "custom" "Custom notification level"

# Test with special characters in message (injection guard)
assert_exits_zero "special chars in message" "start" 'Test "quotes" and $(command) and `backticks`'

# Test with empty message
assert_exits_zero "empty message" "start" ""

echo ""
echo "Results: $PASS passed, $FAIL failed"

rm -f "$TEMP_CONFIG"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
