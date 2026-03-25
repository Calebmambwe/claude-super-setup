#!/bin/bash
# Integration Test 2: Verify all JSON config files are valid
# Tests that config files parse correctly and have required fields

set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PASS=0
FAIL=0

assert_valid_json() {
  local file="$1"
  local description="$2"
  if [ ! -f "$file" ]; then
    echo "  ❌ $description — file missing: $file"
    FAIL=$((FAIL + 1))
    return
  fi
  if jq empty "$file" 2>/dev/null; then
    echo "  ✅ $description — valid JSON"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description — invalid JSON"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_field() {
  local file="$1"
  local field="$2"
  local description="$3"
  if [ ! -f "$file" ]; then
    echo "  ❌ $description — file missing"
    FAIL=$((FAIL + 1))
    return
  fi
  local value
  value=$(jq -r "$field" "$file" 2>/dev/null)
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    echo "  ✅ $description"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $description — field $field missing or null"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Integration Test: Config Validation ==="
echo ""

# Model routing config
assert_valid_json "$REPO_DIR/config/model-routing.json" "model-routing.json"
assert_json_field "$REPO_DIR/config/model-routing.json" ".version" "model-routing has version"
assert_json_field "$REPO_DIR/config/model-routing.json" ".providers.anthropic.models.opus" "model-routing has Anthropic opus model"
assert_json_field "$REPO_DIR/config/model-routing.json" ".providers.ollama.base_url" "model-routing has Ollama base_url"
assert_json_field "$REPO_DIR/config/model-routing.json" ".routing.planning.primary" "model-routing has planning route"
assert_json_field "$REPO_DIR/config/model-routing.json" ".routing.implementation.fallback" "model-routing has implementation fallback"

# Agent catalog
assert_valid_json "$REPO_DIR/agents/catalog.json" "agents/catalog.json"

# Config settings
assert_valid_json "$REPO_DIR/config/settings.json" "config/settings.json"

# Schema files
for schema in "$REPO_DIR"/schemas/*.json; do
  if [ -f "$schema" ]; then
    assert_valid_json "$schema" "$(basename "$schema")"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
