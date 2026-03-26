#!/usr/bin/env bash
# model-router.sh — Task-type router for multi-model orchestration
#
# Reads config/model-routing.json, resolves provider+model for a task type,
# calls the correct provider client, implements fallback chain.
#
# Usage: scripts/model-router.sh --task-type <type> --prompt <text> [OPTIONS]
#
# Exit codes:
#   0 = Success
#   1 = Invalid arguments
#   5 = All providers failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${HOME}/config/model-routing.json"

# Source env
ENV_FILE="${HOME}/.claude/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

# ── Defaults ─────────────────────────────────────────────────────────────────
TASK_TYPE=""
PROMPT=""
PROMPT_FILE=""
PROVIDER_OVERRIDE=""
MODEL_OVERRIDE=""
OFFLINE=false
MAX_TOKENS=4096
TEMPERATURE="0.2"
TIMEOUT=30
SYSTEM_PROMPT=""

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-type)   TASK_TYPE="$2";        shift 2 ;;
    --prompt)      PROMPT="$2";           shift 2 ;;
    --prompt-file) PROMPT_FILE="$2";      shift 2 ;;
    --system)      SYSTEM_PROMPT="$2";    shift 2 ;;
    --provider)    PROVIDER_OVERRIDE="$2"; shift 2 ;;
    --model)       MODEL_OVERRIDE="$2";   shift 2 ;;
    --offline)     OFFLINE=true;          shift ;;
    --max-tokens)  MAX_TOKENS="$2";       shift 2 ;;
    --temperature) TEMPERATURE="$2";      shift 2 ;;
    --timeout)     TIMEOUT="$2";          shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# //' >&2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
if [[ -z "$TASK_TYPE" ]]; then
  echo "ERROR: --task-type is required. Options: planning, implementation, review, testing, triage, embedding, voice, image" >&2
  exit 1
fi

if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
  PROMPT=$(cat "$PROMPT_FILE")
fi
if [[ -z "$PROMPT" ]]; then
  echo "ERROR: --prompt or --prompt-file is required" >&2
  exit 1
fi

# Check offline mode env var
if [[ "${CLAUDE_OFFLINE:-}" == "1" ]]; then
  OFFLINE=true
fi

# ── Read config ──────────────────────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config not found at $CONFIG_FILE" >&2
  exit 1
fi

# Resolve provider:model for a route reference like "openrouter:code"
resolve_model() {
  local ref="$1"
  local provider="${ref%%:*}"
  local alias="${ref#*:}"

  # Look up actual model ID from provider's models map
  local model_id
  model_id=$(jq -r ".providers.${provider}.models.\"${alias}\" // empty" "$CONFIG_FILE" 2>/dev/null)

  if [[ -n "$model_id" ]]; then
    echo "${provider}|${model_id}"
  else
    echo "${provider}|${alias}"
  fi
}

# ── Build provider chain ────────────────────────────────────────────────────
build_chain() {
  local chain=()

  # 1. Explicit overrides
  if [[ -n "$PROVIDER_OVERRIDE" && -n "$MODEL_OVERRIDE" ]]; then
    chain+=("${PROVIDER_OVERRIDE}|${MODEL_OVERRIDE}")
    echo "${chain[*]}"
    return
  fi

  if [[ -n "$MODEL_OVERRIDE" ]]; then
    # Guess provider from model string
    if [[ "$MODEL_OVERRIDE" == claude-* ]]; then
      chain+=("anthropic|${MODEL_OVERRIDE}")
    elif [[ "$MODEL_OVERRIDE" == */* ]]; then
      chain+=("openrouter|${MODEL_OVERRIDE}")
    else
      chain+=("ollama|${MODEL_OVERRIDE}")
    fi
    echo "${chain[*]}"
    return
  fi

  # 2. Offline mode — ollama only
  if [[ "$OFFLINE" == "true" ]]; then
    local ollama_model
    ollama_model=$(jq -r ".providers.ollama.models.code // .providers.ollama.models.small // empty" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$ollama_model" ]]; then
      chain+=("ollama|${ollama_model}")
    fi
    echo "${chain[*]}"
    return
  fi

  # 3. Config-based routing
  local primary fallback local_fallback
  primary=$(jq -r ".routing.\"${TASK_TYPE}\".primary // empty" "$CONFIG_FILE" 2>/dev/null)
  fallback=$(jq -r ".routing.\"${TASK_TYPE}\".fallback // empty" "$CONFIG_FILE" 2>/dev/null)
  local_fallback=$(jq -r ".routing.\"${TASK_TYPE}\".local_fallback // empty" "$CONFIG_FILE" 2>/dev/null)

  if [[ -n "$primary" ]]; then
    chain+=("$(resolve_model "$primary")")
  fi
  if [[ -n "$fallback" ]]; then
    local fb_provider="${fallback%%:*}"
    local fb_enabled
    fb_enabled=$(jq -r ".providers.${fb_provider}.enabled // false" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$fb_enabled" == "true" ]]; then
      chain+=("$(resolve_model "$fallback")")
    fi
  fi
  if [[ -n "$local_fallback" ]]; then
    local lf_provider="${local_fallback%%:*}"
    local lf_enabled
    lf_enabled=$(jq -r ".providers.${lf_provider}.enabled // false" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$lf_enabled" == "true" ]]; then
      chain+=("$(resolve_model "$local_fallback")")
    fi
  fi

  echo "${chain[*]}"
}

# ── Call a provider ──────────────────────────────────────────────────────────
call_provider() {
  local provider="$1"
  local model="$2"

  case "$provider" in
    anthropic)
      # Use claude CLI for Anthropic calls
      local sys_args=""
      if [[ -n "$SYSTEM_PROMPT" ]]; then
        sys_args="--system-prompt"
      fi
      if [[ -n "$SYSTEM_PROMPT" ]]; then
        echo "$PROMPT" | claude -p --model "$model" $sys_args "$SYSTEM_PROMPT" 2>/dev/null | grep -v '^{$\|^  \|^}$\|descriptor:\|dataPoint'
      else
        echo "$PROMPT" | claude -p --model "$model" 2>/dev/null | grep -v '^{$\|^  \|^}$\|descriptor:\|dataPoint'
      fi
      return $?
      ;;
    openrouter)
      local extra_args=()
      extra_args+=(--model "$model")
      extra_args+=(--prompt "$PROMPT")
      extra_args+=(--task-type "$TASK_TYPE")
      extra_args+=(--max-tokens "$MAX_TOKENS")
      extra_args+=(--temperature "$TEMPERATURE")
      extra_args+=(--timeout "$TIMEOUT")
      if [[ -n "$SYSTEM_PROMPT" ]]; then
        extra_args+=(--system "$SYSTEM_PROMPT")
      fi
      bash "${SCRIPT_DIR}/openrouter-client.sh" "${extra_args[@]}"
      return $?
      ;;
    ollama)
      local ollama_url
      ollama_url=$(jq -r '.providers.ollama.base_url // "http://localhost:11434"' "$CONFIG_FILE" 2>/dev/null)

      local body
      body=$(jq -n --arg model "$model" --arg prompt "$PROMPT" --arg system "${SYSTEM_PROMPT:-}" '{
        model: $model,
        messages: (if $system != "" then [{role:"system",content:$system},{role:"user",content:$prompt}] else [{role:"user",content:$prompt}] end),
        stream: false
      }')

      local response
      response=$(curl -s --max-time "$TIMEOUT" "${ollama_url}/api/chat" -d "$body" 2>/dev/null) || return 3
      echo "$response" | jq -r '.message.content // empty' 2>/dev/null
      return $?
      ;;
    *)
      echo "ERROR: Unknown provider: $provider" >&2
      return 1
      ;;
  esac
}

# ── Execute with fallback chain ──────────────────────────────────────────────
CHAIN=$(build_chain)

if [[ -z "$CHAIN" ]]; then
  echo "ERROR: No providers configured for task type '$TASK_TYPE'" >&2
  exit 5
fi

last_error=""
for entry in $CHAIN; do
  provider="${entry%%|*}"
  model="${entry#*|}"

  result=$(call_provider "$provider" "$model" 2>/tmp/model-router-err-$$) && {
    if [[ -n "$result" ]]; then
      echo "$result"
      exit 0
    fi
  }
  last_error=$(cat /tmp/model-router-err-$$ 2>/dev/null || echo "empty response")
  rm -f /tmp/model-router-err-$$
done

echo "ERROR: All providers failed for task type '$TASK_TYPE'. Last error: $last_error" >&2
exit 5
