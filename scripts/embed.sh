#!/usr/bin/env bash
# embed.sh — Generate embeddings via OpenRouter or Ollama
#
# Usage: scripts/embed.sh --text <text> [--model <model>] [--provider <openrouter|ollama>]
#
# Returns: JSON array of floats on stdout
# Exit codes: 0=success, 1=args, 2=provider error, 3=network error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${HOME}/config/model-routing.json"
COST_LOG="${HOME}/.claude/logs/model-costs.jsonl"

ENV_FILE="${HOME}/.claude/.env.local"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

mkdir -p "$(dirname "$COST_LOG")"

TEXT=""
MODEL=""
PROVIDER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)     TEXT="$2";     shift 2 ;;
    --model)    MODEL="$2";    shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    -h|--help)  sed -n '2,8p' "$0" | sed 's/^# //' >&2; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TEXT" ]]; then
  echo "ERROR: --text is required" >&2
  exit 1
fi

# Resolve provider and model from config
if [[ -z "$PROVIDER" ]]; then
  embed_primary=$(jq -r '.specialized.embedding.primary // "openrouter:embedding"' "$CONFIG_FILE" 2>/dev/null)
  PROVIDER="${embed_primary%%:*}"
fi
if [[ -z "$MODEL" ]]; then
  case "$PROVIDER" in
    openrouter) MODEL=$(jq -r '.providers.openrouter.models.embedding // "openai/text-embedding-3-small"' "$CONFIG_FILE" 2>/dev/null) ;;
    ollama)     MODEL="nomic-embed-text" ;;
    *)          MODEL="openai/text-embedding-3-small" ;;
  esac
fi

start_ns=$(date +%s%N)

case "$PROVIDER" in
  openrouter)
    API_KEY="${OPENROUTER_API_KEY:-}"
    if [[ -z "$API_KEY" ]]; then
      echo "ERROR: OPENROUTER_API_KEY not set" >&2
      exit 1
    fi
    response=$(curl -s --max-time 30 \
      "https://openrouter.ai/api/v1/embeddings" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg model "$MODEL" --arg input "$TEXT" '{model: $model, input: $input}')" \
      2>/dev/null) || { echo "ERROR: Network error" >&2; exit 3; }

    embedding=$(echo "$response" | jq -r '.data[0].embedding // empty' 2>/dev/null)
    if [[ -z "$embedding" ]]; then
      error=$(echo "$response" | jq -r '.error.message // "unknown error"' 2>/dev/null)
      echo "ERROR: $error" >&2
      exit 2
    fi
    echo "$embedding"
    ;;
  ollama)
    ollama_url=$(jq -r '.providers.ollama.base_url // "http://localhost:11434"' "$CONFIG_FILE" 2>/dev/null)
    response=$(curl -s --max-time 30 \
      "${ollama_url}/api/embed" \
      -d "$(jq -n --arg model "$MODEL" --arg input "$TEXT" '{model: $model, input: $input}')" \
      2>/dev/null) || { echo "ERROR: Ollama not reachable" >&2; exit 3; }

    embedding=$(echo "$response" | jq -r '.embeddings[0] // empty' 2>/dev/null)
    if [[ -z "$embedding" ]]; then
      echo "ERROR: Ollama embed failed" >&2
      exit 2
    fi
    echo "$embedding"
    ;;
  *)
    echo "ERROR: Unknown provider: $PROVIDER" >&2
    exit 1
    ;;
esac

end_ns=$(date +%s%N)
latency_ms=$(( (end_ns - start_ns) / 1000000 ))

# Log cost
jq -n -c \
  --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg task_type "embedding" \
  --arg provider "$PROVIDER" \
  --arg model "$MODEL" \
  --argjson latency_ms "$latency_ms" \
  '{ts: $ts, task_type: $task_type, provider: $provider, model: $model, input_tokens: 0, output_tokens: 0, cost_usd: "0.000001", latency_ms: $latency_ms, error: "", fallback_from: ""}' \
  >> "$COST_LOG"
