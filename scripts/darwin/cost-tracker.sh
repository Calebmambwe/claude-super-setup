#!/usr/bin/env bash
set -euo pipefail

# Darwin Cost Tracker — checks daily budget and returns whether more API calls are allowed
# Usage: bash scripts/darwin/cost-tracker.sh [--check] [--log --platform <name> --cost <usd>] [--report]

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[DARWIN-COST]${NC} $1" >&2; }

COST_FILE="$HOME/.claude/darwin/api-costs.jsonl"
mkdir -p "$(dirname "$COST_FILE")"
touch "$COST_FILE"

DAILY_BUDGET=2.00
PER_PLATFORM_BUDGET=0.75
MANUS_CREDIT_FLOOR=50

ACTION=""
PLATFORM=""
COST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) ACTION="check"; shift ;;
    --log) ACTION="log"; shift ;;
    --report) ACTION="report"; shift ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --cost) COST="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

ACTION="${ACTION:-check}"

# Get today's date
TODAY=$(date -u +%Y-%m-%d)

get_today_spend() {
  if [ ! -s "$COST_FILE" ]; then
    echo "0"
    return
  fi
  grep "\"$TODAY" "$COST_FILE" 2>/dev/null | jq -s '[.[].cost_usd] | add // 0' 2>/dev/null || echo "0"
}

get_platform_spend() {
  local P="$1"
  if [ ! -s "$COST_FILE" ]; then
    echo "0"
    return
  fi
  grep "\"$TODAY" "$COST_FILE" 2>/dev/null | jq -s --arg p "$P" '[.[] | select(.platform == $p) | .cost_usd] | add // 0' 2>/dev/null || echo "0"
}

case "$ACTION" in
  check)
    TOTAL_TODAY=$(get_today_spend)
    MANUS_TODAY=$(get_platform_spend "manus")
    GEMINI_TODAY=$(get_platform_spend "gemini")
    OPENAI_TODAY=$(get_platform_spend "openai")

    BUDGET_OK=true
    ALLOWED_PLATFORMS='["manus","gemini","openai"]'

    # Check total budget
    if (( $(echo "$TOTAL_TODAY >= $DAILY_BUDGET" | bc -l 2>/dev/null || echo 0) )); then
      BUDGET_OK=false
      ALLOWED_PLATFORMS='[]'
    else
      # Check per-platform
      ALLOWED=()
      for P in manus gemini openai; do
        P_SPEND=$(get_platform_spend "$P")
        if (( $(echo "$P_SPEND < $PER_PLATFORM_BUDGET" | bc -l 2>/dev/null || echo 1) )); then
          ALLOWED+=("\"$P\"")
        fi
      done
      ALLOWED_PLATFORMS="[$(IFS=,; echo "${ALLOWED[*]:-}")]"
    fi

    jq -n \
      --arg today "$TODAY" \
      --argjson total "$TOTAL_TODAY" \
      --argjson budget "$DAILY_BUDGET" \
      --argjson budget_ok "$($BUDGET_OK && echo true || echo false)" \
      --argjson allowed "$ALLOWED_PLATFORMS" \
      --argjson manus "$MANUS_TODAY" \
      --argjson gemini "$GEMINI_TODAY" \
      --argjson openai "$OPENAI_TODAY" \
      '{
        date: $today,
        total_spend_usd: $total,
        daily_budget_usd: $budget,
        budget_ok: $budget_ok,
        allowed_platforms: $allowed,
        per_platform: {manus: $manus, gemini: $gemini, openai: $openai}
      }'
    ;;

  log)
    if [ -z "$PLATFORM" ] || [ -z "$COST" ]; then
      echo "Usage: cost-tracker.sh --log --platform <name> --cost <usd>" >&2
      exit 1
    fi
    jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg platform "$PLATFORM" --argjson cost "$COST" \
      '{ts: $ts, platform: $platform, cost_usd: $cost}' >> "$COST_FILE"
    log "Logged $COST USD for $PLATFORM"
    ;;

  report)
    if [ ! -s "$COST_FILE" ]; then
      echo '{"total_all_time": 0, "total_today": 0, "entries": 0}'
      exit 0
    fi
    TOTAL_ALL=$(jq -s '[.[].cost_usd] | add // 0' "$COST_FILE" 2>/dev/null)
    TOTAL_TODAY=$(get_today_spend)
    ENTRIES=$(wc -l < "$COST_FILE" | tr -d ' ')
    jq -n --argjson all "$TOTAL_ALL" --argjson today "$TOTAL_TODAY" --argjson entries "$ENTRIES" \
      '{total_all_time_usd: $all, total_today_usd: $today, total_entries: $entries}'
    ;;
esac
