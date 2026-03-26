#!/usr/bin/env bats
# Integration Test: Model Routing Configuration
# Tests that config/model-routing.json and related scripts are valid and complete

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CONFIG="$REPO_DIR/config/model-routing.json"

# ── Config file existence and validity ────────────────────────────────────────

@test "config/model-routing.json exists" {
  [ -f "$CONFIG" ]
}

@test "config/model-routing.json is valid JSON" {
  run jq empty "$CONFIG"
  [ "$status" -eq 0 ]
}

# ── Provider structure ────────────────────────────────────────────────────────

@test "all providers have enabled field" {
  run jq -e '
    .providers | to_entries | all(.value | has("enabled"))
  ' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "openrouter provider env_key points to OPENROUTER_API_KEY" {
  run jq -r '.providers.openrouter.env_key' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "OPENROUTER_API_KEY" ]
}

@test "openrouter models are non-empty strings" {
  run jq -e '
    .providers.openrouter.models | to_entries | all(
      .value | type == "string" and length > 0
    )
  ' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ── Routing task types ────────────────────────────────────────────────────────

@test "all routing task types have primary field" {
  run jq -e '
    .routing | to_entries | all(.value | has("primary"))
  ' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ── Fallback policy ───────────────────────────────────────────────────────────

@test "fallback_policy has conditions array" {
  run jq -e '.fallback_policy.conditions | type == "array" and length > 0' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ── Dual mode ─────────────────────────────────────────────────────────────────

@test "dual_mode config has judge field set to anthropic:opus" {
  run jq -r '.dual_mode.judge' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "anthropic:opus" ]
}

# ── Specialized routes ────────────────────────────────────────────────────────

@test "specialized.voice.primary exists" {
  run jq -e '.specialized.voice.primary | type == "string" and length > 0' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "specialized.embedding has primary and fallback" {
  run jq -e '.specialized.embedding | has("primary") and has("fallback")' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ── Cost tracking ─────────────────────────────────────────────────────────────

@test "cost_tracking.hard_limit_usd is a number" {
  run jq -e '.cost_tracking.hard_limit_usd | type == "number"' "$CONFIG"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ── Script existence and executability ───────────────────────────────────────

@test "scripts/openrouter-client.sh exists and is executable" {
  [ -f "$REPO_DIR/scripts/openrouter-client.sh" ]
  [ -x "$REPO_DIR/scripts/openrouter-client.sh" ]
}

@test "scripts/model-router.sh exists and is executable" {
  [ -f "$REPO_DIR/scripts/model-router.sh" ]
  [ -x "$REPO_DIR/scripts/model-router.sh" ]
}

# ── Script help flags ─────────────────────────────────────────────────────────

@test "openrouter-client.sh --help exits 0" {
  run "$REPO_DIR/scripts/openrouter-client.sh" --help
  [ "$status" -eq 0 ]
}

@test "model-router.sh --help exits 0" {
  run "$REPO_DIR/scripts/model-router.sh" --help
  [ "$status" -eq 0 ]
}
