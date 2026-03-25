#!/bin/bash
# Integration Test 5: Verify setup-vps.sh parses all flags correctly in dry-run mode
# Tests flag parsing and phase execution without making real changes

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
SETUP="$REPO_DIR/scripts/setup-vps.sh"
PASS=0
FAIL=0

assert_output_contains() {
  local description="$1"
  local pattern="$2"
  local output="$3"
  if echo "$output" | grep -qi "$pattern"; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description — pattern '$pattern' not found"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_not_contains() {
  local description="$1"
  local pattern="$2"
  local output="$3"
  if echo "$output" | grep -qi "$pattern"; then
    echo "  ❌ $description — pattern '$pattern' was found but should not be"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  fi
}

echo "=== Integration Test: setup-vps.sh Flag Parsing ==="
echo ""

# Test --help flag
HELP_OUT=$(bash "$SETUP" --help 2>&1) || true
assert_output_contains "--help shows usage" "Usage" "$HELP_OUT"
assert_output_contains "--help shows --with-ollama" "ollama" "$HELP_OUT"
assert_output_contains "--help shows --dry-run" "dry-run" "$HELP_OUT"

# Test --dry-run flag
DRY_OUT=$(bash "$SETUP" --dry-run 2>&1) || true
assert_output_contains "--dry-run shows DRY-RUN" "DRY-RUN" "$DRY_OUT"
assert_output_contains "--dry-run detects OS" "Detected OS" "$DRY_OUT"

# Test --skip-docker with --dry-run
SKIP_DOCKER_OUT=$(bash "$SETUP" --dry-run --skip-docker 2>&1) || true
assert_output_contains "--skip-docker skips docker" "skipped" "$SKIP_DOCKER_OUT"

# Test --with-ollama with --dry-run
OLLAMA_OUT=$(bash "$SETUP" --dry-run --with-ollama 2>&1) || true
assert_output_contains "--with-ollama shows Ollama phase" "Ollama" "$OLLAMA_OUT"

# Test --dry-run --with-ollama --skip-docker --skip-tailscale combined
COMBO_OUT=$(bash "$SETUP" --dry-run --with-ollama --skip-docker --skip-tailscale 2>&1) || true
assert_output_contains "Combined flags: dry-run works" "DRY-RUN" "$COMBO_OUT"
assert_output_contains "Combined flags: ollama present" "Ollama" "$COMBO_OUT"

# Test unknown flag rejection
UNKNOWN_OUT=$(bash "$SETUP" --unknown-flag 2>&1) || true
assert_output_contains "Unknown flag rejected" "Unknown" "$UNKNOWN_OUT"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
