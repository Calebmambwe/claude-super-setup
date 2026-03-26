#!/usr/bin/env bash
# dual-compare.sh — Parallel dual-model dispatcher with Opus auto-judge
#
# Runs the same prompt on two models simultaneously, then asks Opus to
# judge which output is better. Logs result to comparisons.jsonl.
#
# Usage: scripts/dual-compare.sh --prompt <text> [OPTIONS]
#
# Exit codes:
#   0 = Success (winning response on stdout, decision on stderr)
#   1 = Invalid arguments
#   5 = Both models failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${HOME}/config/model-routing.json"
COMPARE_LOG="${HOME}/.claude/logs/comparisons.jsonl"

mkdir -p "$(dirname "$COMPARE_LOG")"

# Source env
ENV_FILE="${HOME}/.claude/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

# ── Defaults ─────────────────────────────────────────────────────────────────
MODELS=""
TASK_TYPE="implementation"
PROMPT=""
PROMPT_FILE=""
NO_JUDGE=false
MAX_TOKENS=4096
TEMPERATURE="0.2"

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --models)     MODELS="$2";      shift 2 ;;
    --task-type)  TASK_TYPE="$2";   shift 2 ;;
    --prompt)     PROMPT="$2";      shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --no-judge)   NO_JUDGE=true;    shift ;;
    --max-tokens) MAX_TOKENS="$2";  shift 2 ;;
    --temperature) TEMPERATURE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# //' >&2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
  PROMPT=$(cat "$PROMPT_FILE")
fi
if [[ -z "$PROMPT" ]]; then
  echo "ERROR: --prompt or --prompt-file is required" >&2
  exit 1
fi

# Resolve models from config if not specified
if [[ -z "$MODELS" ]]; then
  model_a_ref=$(jq -r '.dual_mode.default_models[0] // "openrouter:code"' "$CONFIG_FILE" 2>/dev/null)
  model_b_ref=$(jq -r '.dual_mode.default_models[1] // "openrouter:general"' "$CONFIG_FILE" 2>/dev/null)

  # Resolve references to actual model IDs
  resolve() {
    local ref="$1"
    local provider="${ref%%:*}"
    local alias="${ref#*:}"
    jq -r ".providers.${provider}.models.\"${alias}\" // \"${alias}\"" "$CONFIG_FILE" 2>/dev/null
  }

  MODEL_A=$(resolve "$model_a_ref")
  MODEL_B=$(resolve "$model_b_ref")
else
  MODEL_A="${MODELS%%,*}"
  MODEL_B="${MODELS#*,}"
fi

if [[ "$MODEL_A" == "$MODEL_B" ]]; then
  echo "ERROR: Both models are the same ($MODEL_A). Use different models for comparison." >&2
  exit 1
fi

# ── Run both models in parallel ──────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

run_model() {
  local model="$1"
  local output_file="$2"
  local time_file="$3"
  local start_ns end_ns

  start_ns=$(date +%s%N)
  bash "${SCRIPT_DIR}/openrouter-client.sh" \
    --model "$model" \
    --prompt "$PROMPT" \
    --task-type "$TASK_TYPE" \
    --max-tokens "$MAX_TOKENS" \
    --temperature "$TEMPERATURE" \
    > "$output_file" 2>/dev/null || echo "ERROR" > "$output_file"
  end_ns=$(date +%s%N)
  echo $(( (end_ns - start_ns) / 1000000 )) > "$time_file"
}

# Run both in background
run_model "$MODEL_A" "$TMP_DIR/output_a" "$TMP_DIR/time_a" &
PID_A=$!
run_model "$MODEL_B" "$TMP_DIR/output_b" "$TMP_DIR/time_b" &
PID_B=$!

# Wait for both
wait $PID_A || true
wait $PID_B || true

OUTPUT_A=$(cat "$TMP_DIR/output_a")
OUTPUT_B=$(cat "$TMP_DIR/output_b")
TIME_A=$(cat "$TMP_DIR/time_a" 2>/dev/null || echo "0")
TIME_B=$(cat "$TMP_DIR/time_b" 2>/dev/null || echo "0")

# Check if both failed
if [[ "$OUTPUT_A" == "ERROR" && "$OUTPUT_B" == "ERROR" ]]; then
  echo "ERROR: Both models failed" >&2
  exit 5
fi

# If one failed, the other wins by default
if [[ "$OUTPUT_A" == "ERROR" ]]; then
  echo "WINNER=B ($MODEL_B) REASON=Model A ($MODEL_A) failed" >&2
  echo "$OUTPUT_B"
  # Log
  PROMPT_HASH=$(echo -n "$PROMPT" | sha256sum | cut -d' ' -f1)
  jq -n -c --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg task_type "$TASK_TYPE" --arg prompt_hash "sha256:$PROMPT_HASH" \
    --arg model_a "$MODEL_A" --arg model_b "$MODEL_B" --arg winner "B" \
    --arg reason "Model A failed" --argjson latency_a "$TIME_A" --argjson latency_b "$TIME_B" \
    '{ts: $ts, task_type: $task_type, prompt_hash: $prompt_hash, model_a: $model_a, model_b: $model_b, winner: $winner, reason: $reason, latency_a_ms: $latency_a, latency_b_ms: $latency_b}' \
    >> "$COMPARE_LOG"
  exit 0
fi

if [[ "$OUTPUT_B" == "ERROR" ]]; then
  echo "WINNER=A ($MODEL_A) REASON=Model B ($MODEL_B) failed" >&2
  echo "$OUTPUT_A"
  PROMPT_HASH=$(echo -n "$PROMPT" | sha256sum | cut -d' ' -f1)
  jq -n -c --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg task_type "$TASK_TYPE" --arg prompt_hash "sha256:$PROMPT_HASH" \
    --arg model_a "$MODEL_A" --arg model_b "$MODEL_B" --arg winner "A" \
    --arg reason "Model B failed" --argjson latency_a "$TIME_A" --argjson latency_b "$TIME_B" \
    '{ts: $ts, task_type: $task_type, prompt_hash: $prompt_hash, model_a: $model_a, model_b: $model_b, winner: $winner, reason: $reason, latency_a_ms: $latency_a, latency_b_ms: $latency_b}' \
    >> "$COMPARE_LOG"
  exit 0
fi

# ── No-judge mode ────────────────────────────────────────────────────────────
if [[ "$NO_JUDGE" == "true" ]]; then
  echo "=== Model A: $MODEL_A (${TIME_A}ms) ==="
  echo "$OUTPUT_A"
  echo ""
  echo "=== Model B: $MODEL_B (${TIME_B}ms) ==="
  echo "$OUTPUT_B"
  exit 0
fi

# ── Opus judges ──────────────────────────────────────────────────────────────
JUDGE_PROMPT="You are judging two code outputs for the same task. Pick the better one.

TASK: ${PROMPT:0:500}

OUTPUT A:
${OUTPUT_A:0:3000}

OUTPUT B:
${OUTPUT_B:0:3000}

Evaluate on: 1) Correctness 2) Code quality 3) Instruction following.
Respond in EXACTLY this format (one line):
WINNER=A|B REASON=<one sentence>"

JUDGE_RESULT=$(echo "$JUDGE_PROMPT" | claude -p --model claude-opus-4-6 2>/dev/null | grep -E '^WINNER=' | head -1) || JUDGE_RESULT=""

# Parse judge decision
if [[ -z "$JUDGE_RESULT" ]]; then
  # Judge failed — default to Model A (primary)
  WINNER="A"
  REASON="Judge did not return structured result; defaulting to Model A"
else
  WINNER=$(echo "$JUDGE_RESULT" | grep -oP 'WINNER=\K[AB]' || echo "A")
  REASON=$(echo "$JUDGE_RESULT" | grep -oP 'REASON=\K.*' || echo "No reason given")
fi

# Output winner
if [[ "$WINNER" == "A" ]]; then
  echo "WINNER=A ($MODEL_A) REASON=$REASON" >&2
  echo "$OUTPUT_A"
else
  echo "WINNER=B ($MODEL_B) REASON=$REASON" >&2
  echo "$OUTPUT_B"
fi

# ── Log comparison ───────────────────────────────────────────────────────────
PROMPT_HASH=$(echo -n "$PROMPT" | sha256sum | cut -d' ' -f1)
jq -n -c \
  --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg task_type "$TASK_TYPE" \
  --arg prompt_hash "sha256:$PROMPT_HASH" \
  --arg model_a "$MODEL_A" \
  --arg model_b "$MODEL_B" \
  --arg winner "$WINNER" \
  --arg reason "$REASON" \
  --argjson latency_a "$TIME_A" \
  --argjson latency_b "$TIME_B" \
  '{ts: $ts, task_type: $task_type, prompt_hash: $prompt_hash, model_a: $model_a, model_b: $model_b, winner: $winner, reason: $reason, latency_a_ms: $latency_a, latency_b_ms: $latency_b}' \
  >> "$COMPARE_LOG"
