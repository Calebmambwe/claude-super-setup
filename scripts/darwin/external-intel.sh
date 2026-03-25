#!/usr/bin/env bash
set -euo pipefail

# Darwin External Intelligence — calls Manus, Gemini, and OpenAI APIs for architectural perspectives
# Usage: bash scripts/darwin/external-intel.sh --platform manus|gemini|openai --topic <topic> --context-file <path> --output-file <path>
# Topics: failure_handling, context_management, multi_agent, tooling, scheduling, self_healing

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

err() { echo -e "${RED}[DARWIN-INTEL]${NC} $1" >&2; }
log() { echo -e "${GREEN}[DARWIN-INTEL]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[DARWIN-INTEL]${NC} $1" >&2; }

# --- Parse args ---
PLATFORM=""
TOPIC=""
CONTEXT_FILE=""
OUTPUT_FILE=""
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --topic) TOPIC="$2"; shift 2 ;;
    --context-file) CONTEXT_FILE="$2"; shift 2 ;;
    --output-file) OUTPUT_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) err "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$PLATFORM" ] || [ -z "$TOPIC" ]; then
  err "Usage: external-intel.sh --platform manus|gemini|openai --topic <topic> [--context-file <path>] [--output-file <path>]"
  exit 1
fi

# --- Load API keys ---
ENV_FILE="$HOME/.claude/.env.local"
if [ ! -f "$ENV_FILE" ]; then
  err "Missing $ENV_FILE — cannot load API keys"
  exit 1
fi

MANUS_API_KEY=$(grep '^MANUS_API_KEY=' "$ENV_FILE" 2>/dev/null | sed 's/^MANUS_API_KEY=//' | tr -d '[:space:]' || echo "")
GEMINI_API_KEY=$(grep '^GEMINI_API_KEY=' "$ENV_FILE" 2>/dev/null | sed 's/^GEMINI_API_KEY=//' | tr -d '[:space:]' || echo "")
OPENAI_API_KEY=$(grep '^OPENAI_API_KEY=' "$ENV_FILE" 2>/dev/null | sed 's/^OPENAI_API_KEY=//' | tr -d '[:space:]' || echo "")

# --- Load context ---
CONTEXT=""
if [ -n "$CONTEXT_FILE" ] && [ -f "$CONTEXT_FILE" ]; then
  CONTEXT=$(cat "$CONTEXT_FILE" | head -c 2000)
fi

# --- Check cache (7-day TTL) ---
CACHE_DIR="$HOME/.claude/darwin/intel"
mkdir -p "$CACHE_DIR"
CACHE_KEY="${PLATFORM}-${TOPIC}"
CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.json"

if [ -f "$CACHE_FILE" ]; then
  CACHE_AGE=$(( $(date +%s) - $(stat -f '%m' "$CACHE_FILE" 2>/dev/null || stat -c '%Y' "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$CACHE_AGE" -lt 604800 ]; then
    log "Cache hit for $CACHE_KEY (age: $(( CACHE_AGE / 3600 ))h) — reusing"
    if [ -n "$OUTPUT_FILE" ]; then
      cp "$CACHE_FILE" "$OUTPUT_FILE"
    fi
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# --- Build prompt ---
PLATFORM_SUMMARY="a self-hosted AI agent platform with 50+ specialist agents, multi-agent orchestration via git worktrees, Telegram-based remote dispatch, a learning ledger for cross-session memory, ghost mode for fully autonomous overnight pipelines, and systemd-based 24/7 service management"

case "$TOPIC" in
  failure_handling)
    TOPIC_QUESTION="What are the most effective failure handling patterns for production agent systems? Specifically: retry strategies, circuit breakers, error propagation across multi-step agent pipelines, and graceful degradation when external APIs are unavailable." ;;
  context_management)
    TOPIC_QUESTION="What are the best patterns for managing context windows in long-running agent sessions? Specifically: when to compress vs. offload to files, how to prevent goal drift over 20+ tool calls, and KV-cache optimization strategies." ;;
  multi_agent)
    TOPIC_QUESTION="What are the most effective multi-agent coordination patterns? Specifically: task decomposition strategies, inter-agent communication mechanisms, conflict resolution when agents modify shared state, and independent verifier patterns." ;;
  tooling)
    TOPIC_QUESTION="What tool design patterns lead to the most reliable agent execution? Specifically: tool naming conventions, parameter validation, output standardization, and how to prevent tool abuse or privilege escalation." ;;
  scheduling)
    TOPIC_QUESTION="What patterns work best for scheduling autonomous agent tasks? Specifically: cron vs event-driven execution, budget-aware scheduling, priority queuing, and handling long-running tasks that outlive their expected duration." ;;
  self_healing)
    TOPIC_QUESTION="What self-healing patterns are most effective for production agent platforms? Specifically: service health monitoring, automatic restart strategies, state recovery after crashes, and preventing cascading failures." ;;
  *)
    TOPIC_QUESTION="What architectural improvements would you recommend for $TOPIC in a production agent platform?" ;;
esac

# --- Platform-specific prompts ---
build_manus_prompt() {
  cat <<PROMPT
We are building a self-hosted AI agent platform inspired by modern agentic architectures. As a paid user of your API, we would appreciate your architectural perspective.

Our platform: $PLATFORM_SUMMARY

${CONTEXT:+Additional context: $CONTEXT}

Questions:
1. $TOPIC_QUESTION
2. What failure modes do you commonly see in platforms like ours for this area?
3. What patterns from your own system do you find most underappreciated by the community?

Please be specific and technical. We are engineers building production systems, not evaluating demos.
PROMPT
}

build_gemini_prompt() {
  cat <<PROMPT
From Google's perspective on agentic AI systems and production ML infrastructure:

$TOPIC_QUESTION

Context: We are a small team running $PLATFORM_SUMMARY.

${CONTEXT:+Additional context: $CONTEXT}

Please focus on patterns applicable to a small team's self-hosted platform, not enterprise-scale Google infrastructure. Concrete recommendations over general principles.
PROMPT
}

build_openai_prompt() {
  cat <<PROMPT
What architectural patterns does OpenAI recommend for production agentic systems?

$TOPIC_QUESTION

Context: We are building $PLATFORM_SUMMARY.

${CONTEXT:+Additional context: $CONTEXT}

Please provide concrete, implementable recommendations rather than general best practices. We are looking for specific patterns we can adopt this week.
PROMPT
}

# --- API call functions ---
call_manus() {
  if [ -z "$MANUS_API_KEY" ]; then
    err "MANUS_API_KEY not set — skipping Manus"
    return 1
  fi

  local PROMPT
  PROMPT=$(build_manus_prompt)

  if $DRY_RUN; then
    log "[DRY RUN] Would call Manus API with prompt (${#PROMPT} chars)"
    echo '{"dry_run": true, "platform": "manus", "prompt_length": '${#PROMPT}'}'
    return 0
  fi

  log "Submitting task to Manus API..."

  # Escape the prompt for JSON
  local ESCAPED_PROMPT
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '%s' "$PROMPT" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n')

  local RESPONSE
  RESPONSE=$(curl -s --max-time 30 -X POST "https://api.manus.im/api/task/submit" \
    -H "Authorization: Bearer $MANUS_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": $ESCAPED_PROMPT, \"model\": \"manus-1.6-lite-adaptive\"}" 2>&1) || {
    err "Manus API submit failed: $RESPONSE"
    return 1
  }

  local TASK_ID
  TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id // .id // empty' 2>/dev/null)

  if [ -z "$TASK_ID" ]; then
    err "Manus API returned no task_id: $RESPONSE"
    return 1
  fi

  log "Manus task submitted: $TASK_ID — polling for completion..."

  local STATUS_RESPONSE TASK_STATUS RESULT_TEXT
  for i in $(seq 1 20); do
    sleep 15
    STATUS_RESPONSE=$(curl -s --max-time 15 "https://api.manus.im/api/task/$TASK_ID" \
      -H "Authorization: Bearer $MANUS_API_KEY" 2>&1) || continue

    TASK_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // "unknown"' 2>/dev/null)

    if [ "$TASK_STATUS" = "completed" ] || [ "$TASK_STATUS" = "done" ]; then
      RESULT_TEXT=$(echo "$STATUS_RESPONSE" | jq -r '.result // .output // .response // ""' 2>/dev/null)
      log "Manus task completed after $(( i * 15 ))s"

      jq -n \
        --arg platform "manus" \
        --arg topic "$TOPIC" \
        --arg response "$RESULT_TEXT" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg model "manus-1.6-lite-adaptive" \
        --arg task_id "$TASK_ID" \
        '{platform: $platform, topic: $topic, response_text: $response, timestamp: $ts, model_used: $model, task_id: $task_id, estimated_cost_usd: 0.05}'
      return 0
    fi

    if [ "$TASK_STATUS" = "failed" ] || [ "$TASK_STATUS" = "error" ]; then
      err "Manus task failed: $STATUS_RESPONSE"
      return 1
    fi
  done

  err "Manus task timed out after 5 minutes"
  return 1
}

call_gemini() {
  if [ -z "$GEMINI_API_KEY" ]; then
    err "GEMINI_API_KEY not set — skipping Gemini"
    return 1
  fi

  local PROMPT
  PROMPT=$(build_gemini_prompt)

  if $DRY_RUN; then
    log "[DRY RUN] Would call Gemini API with prompt (${#PROMPT} chars)"
    echo '{"dry_run": true, "platform": "gemini", "prompt_length": '${#PROMPT}'}'
    return 0
  fi

  log "Calling Gemini API..."

  local ESCAPED_PROMPT
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)

  local RESPONSE
  RESPONSE=$(curl -s --max-time 60 -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"contents\": [{\"parts\": [{\"text\": $ESCAPED_PROMPT}]}]}" 2>&1) || {
    err "Gemini API call failed: $RESPONSE"
    return 1
  }

  local RESULT_TEXT
  RESULT_TEXT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)

  if [ -z "$RESULT_TEXT" ]; then
    local ERROR_MSG
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "unknown error"' 2>/dev/null)
    err "Gemini returned no content: $ERROR_MSG"
    return 1
  fi

  log "Gemini response received (${#RESULT_TEXT} chars)"

  jq -n \
    --arg platform "gemini" \
    --arg topic "$TOPIC" \
    --arg response "$RESULT_TEXT" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg model "gemini-2.0-flash" \
    '{platform: $platform, topic: $topic, response_text: $response, timestamp: $ts, model_used: $model, estimated_cost_usd: 0.002}'
  return 0
}

call_openai() {
  if [ -z "$OPENAI_API_KEY" ]; then
    err "OPENAI_API_KEY not set — skipping OpenAI"
    return 1
  fi

  local PROMPT
  PROMPT=$(build_openai_prompt)

  if $DRY_RUN; then
    log "[DRY RUN] Would call OpenAI API with prompt (${#PROMPT} chars)"
    echo '{"dry_run": true, "platform": "openai", "prompt_length": '${#PROMPT}'}'
    return 0
  fi

  log "Calling OpenAI API..."

  local ESCAPED_PROMPT
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)

  local RESPONSE
  RESPONSE=$(curl -s --max-time 60 -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-4o-mini\", \"messages\": [{\"role\": \"user\", \"content\": $ESCAPED_PROMPT}], \"max_tokens\": 2000}" 2>&1) || {
    err "OpenAI API call failed: $RESPONSE"
    return 1
  }

  local RESULT_TEXT
  RESULT_TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

  if [ -z "$RESULT_TEXT" ]; then
    local ERROR_MSG
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "unknown error"' 2>/dev/null)
    err "OpenAI returned no content: $ERROR_MSG"
    return 1
  fi

  log "OpenAI response received (${#RESULT_TEXT} chars)"

  jq -n \
    --arg platform "openai" \
    --arg topic "$TOPIC" \
    --arg response "$RESULT_TEXT" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg model "gpt-4o-mini" \
    '{platform: $platform, topic: $topic, response_text: $response, timestamp: $ts, model_used: $model, estimated_cost_usd: 0.002}'
  return 0
}

# --- Execute ---
RESULT=""
case "$PLATFORM" in
  manus)  RESULT=$(call_manus) ;;
  gemini) RESULT=$(call_gemini) ;;
  openai) RESULT=$(call_openai) ;;
  *) err "Unknown platform: $PLATFORM (expected: manus, gemini, openai)"; exit 1 ;;
esac

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ -z "$RESULT" ]; then
  err "Failed to get response from $PLATFORM"
  exit 1
fi

# --- Save output ---
if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$RESULT" > "$OUTPUT_FILE"
  log "Saved to $OUTPUT_FILE"
fi

# --- Update cache ---
echo "$RESULT" > "$CACHE_FILE"

# --- Track cost ---
COST_FILE="$HOME/.claude/darwin/api-costs.jsonl"
mkdir -p "$(dirname "$COST_FILE")"
COST=$(echo "$RESULT" | jq -r '.estimated_cost_usd // 0' 2>/dev/null)
jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg platform "$PLATFORM" --arg topic "$TOPIC" --arg cost "$COST" \
  '{ts: $ts, platform: $platform, topic: $topic, cost_usd: ($cost | tonumber)}' >> "$COST_FILE"

# --- Output ---
echo "$RESULT"
