#!/usr/bin/env bash
# openrouter-client.sh — Unified OpenRouter API caller
# Usage: scripts/openrouter-client.sh --model <id> --prompt <text> [OPTIONS]
#
# Exit codes:
#   0 = Success (response on stdout)
#   1 = Auth error (missing/invalid API key)
#   2 = Model error (invalid model, quota exceeded)
#   3 = Network error (timeout, unreachable) after all retries
#   4 = Rate limit (HTTP 429) — caller should trigger fallback
set -euo pipefail

# ── Source API key ───────────────────────────────────────────────────────────
ENV_FILE="${HOME}/.claude/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  set -a; source "$ENV_FILE"; set +a
fi

API_KEY="${OPENROUTER_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  echo "ERROR: OPENROUTER_API_KEY not set. Add it to ~/.claude/.env.local" >&2
  exit 1
fi

API_URL="https://openrouter.ai/api/v1/chat/completions"
COST_LOG="${HOME}/.claude/logs/model-costs.jsonl"
mkdir -p "$(dirname "$COST_LOG")"

# ── Defaults ─────────────────────────────────────────────────────────────────
MODEL=""
PROMPT=""
PROMPT_FILE=""
TASK_TYPE="unknown"
STREAM=false
MAX_TOKENS=4096
TEMPERATURE="0.2"
TIMEOUT=30
RETRIES=3
DRY_RUN=false
SYSTEM_PROMPT=""

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)       MODEL="$2";       shift 2 ;;
    --prompt)      PROMPT="$2";      shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --system)      SYSTEM_PROMPT="$2"; shift 2 ;;
    --task-type)   TASK_TYPE="$2";   shift 2 ;;
    --stream)      STREAM=true;      shift ;;
    --max-tokens)  MAX_TOKENS="$2";  shift 2 ;;
    --temperature) TEMPERATURE="$2"; shift 2 ;;
    --timeout)     TIMEOUT="$2";     shift 2 ;;
    --retries)     RETRIES="$2";     shift 2 ;;
    --dry-run)     DRY_RUN=true;     shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# //' >&2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
if [[ -z "$MODEL" ]]; then
  echo "ERROR: --model is required" >&2
  exit 1
fi

if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
  PROMPT=$(cat "$PROMPT_FILE")
fi

if [[ -z "$PROMPT" ]]; then
  echo "ERROR: --prompt or --prompt-file is required" >&2
  exit 1
fi

# ── Build request body ───────────────────────────────────────────────────────
build_body() {
  local body
  if [[ -n "$SYSTEM_PROMPT" ]]; then
    body=$(jq -n \
      --arg model "$MODEL" \
      --arg prompt "$PROMPT" \
      --arg system "$SYSTEM_PROMPT" \
      --argjson max_tokens "$MAX_TOKENS" \
      --argjson temperature "$TEMPERATURE" \
      --argjson stream "$STREAM" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $system},
          {role: "user", content: $prompt}
        ],
        max_tokens: $max_tokens,
        temperature: $temperature,
        stream: $stream
      }')
  else
    body=$(jq -n \
      --arg model "$MODEL" \
      --arg prompt "$PROMPT" \
      --argjson max_tokens "$MAX_TOKENS" \
      --argjson temperature "$TEMPERATURE" \
      --argjson stream "$STREAM" \
      '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        max_tokens: $max_tokens,
        temperature: $temperature,
        stream: $stream
      }')
  fi
  echo "$body"
}

REQUEST_BODY=$(build_body)

# ── Dry run ──────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "curl -s --max-time $TIMEOUT '$API_URL' \\"
  echo "  -H 'Authorization: Bearer \$OPENROUTER_API_KEY' \\"
  echo "  -H 'Content-Type: application/json' \\"
  echo "  -H 'HTTP-Referer: https://github.com/Calebmambwe' \\"
  echo "  -d '$REQUEST_BODY'"
  exit 0
fi

# ── Call with retries ────────────────────────────────────────────────────────
log_cost() {
  local provider="openrouter"
  local input_tokens="${1:-0}"
  local output_tokens="${2:-0}"
  local cost_usd="${3:-0}"
  local latency_ms="${4:-0}"
  local error="${5:-}"
  local fallback_from="${6:-}"

  jq -n -c \
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg task_type "$TASK_TYPE" \
    --arg provider "$provider" \
    --arg model "$MODEL" \
    --argjson input_tokens "$input_tokens" \
    --argjson output_tokens "$output_tokens" \
    --arg cost_usd "$cost_usd" \
    --argjson latency_ms "$latency_ms" \
    --arg error "$error" \
    --arg fallback_from "$fallback_from" \
    '{ts: $ts, task_type: $task_type, provider: $provider, model: $model, input_tokens: $input_tokens, output_tokens: $output_tokens, cost_usd: $cost_usd, latency_ms: $latency_ms, error: $error, fallback_from: $fallback_from}' \
    >> "$COST_LOG"
}

attempt=0
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

while [[ $attempt -lt $RETRIES ]]; do
  attempt=$((attempt + 1))

  start_ns=$(date +%s%N)
  http_code=$(curl -s --max-time "$TIMEOUT" \
    -w "%{http_code}" \
    -o "$BODY_FILE" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://github.com/Calebmambwe" \
    -H "X-Title: AgentOS" \
    "$API_URL" \
    -d "$REQUEST_BODY" 2>/dev/null) || http_code="000"
  end_ns=$(date +%s%N)
  latency_ms=$(( (end_ns - start_ns) / 1000000 ))

  body=$(cat "$BODY_FILE" 2>/dev/null || echo "")

  # Network failure (curl returned no HTTP code)
  if [[ "$http_code" == "000" || -z "$http_code" ]]; then
    if [[ $attempt -lt $RETRIES ]]; then
      sleep $((attempt * 2))
      continue
    fi
    log_cost 0 0 "0" "$latency_ms" "network_error"
    echo "ERROR: Network error after $RETRIES retries" >&2
    exit 3
  fi

  case "$http_code" in
    200)
      # Check for OpenRouter error-in-200 pattern
      error_msg=$(echo "$body" | jq -r '.error.message // empty' 2>/dev/null)
      if [[ -n "$error_msg" ]]; then
        log_cost 0 0 "0" "$latency_ms" "$error_msg"
        echo "ERROR: $error_msg" >&2
        exit 2
      fi

      # Extract content and usage
      content=$(echo "$body" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
      input_tokens=$(echo "$body" | jq -r '.usage.prompt_tokens // 0' 2>/dev/null)
      output_tokens=$(echo "$body" | jq -r '.usage.completion_tokens // 0' 2>/dev/null)

      # Estimate cost
      total_tokens=$((input_tokens + output_tokens))
      cost_usd=$(echo "scale=6; $total_tokens * 0.000001" | bc 2>/dev/null || echo "0")

      log_cost "$input_tokens" "$output_tokens" "$cost_usd" "$latency_ms"
      echo "$content"
      exit 0
      ;;
    401|403)
      log_cost 0 0 "0" "$latency_ms" "auth_error_$http_code"
      echo "ERROR: Authentication failed (HTTP $http_code)" >&2
      exit 1
      ;;
    402)
      log_cost 0 0 "0" "$latency_ms" "quota_exceeded"
      echo "ERROR: Quota/credits exceeded (HTTP 402)" >&2
      exit 2
      ;;
    429)
      if [[ $attempt -lt $RETRIES ]]; then
        sleep $((attempt * 3))
        continue
      fi
      log_cost 0 0 "0" "$latency_ms" "rate_limited"
      echo "ERROR: Rate limited after $RETRIES retries (HTTP 429)" >&2
      exit 4
      ;;
    5*)
      if [[ $attempt -lt $RETRIES ]]; then
        sleep $((attempt * 2))
        continue
      fi
      log_cost 0 0 "0" "$latency_ms" "server_error_$http_code"
      echo "ERROR: Server error after $RETRIES retries (HTTP $http_code)" >&2
      exit 3
      ;;
    *)
      log_cost 0 0 "0" "$latency_ms" "unexpected_$http_code"
      echo "ERROR: Unexpected HTTP $http_code" >&2
      exit 3
      ;;
  esac
done
