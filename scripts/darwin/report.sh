#!/usr/bin/env bash
set -euo pipefail

# Darwin Report Generator — formats run results into Telegram-friendly markdown and sends via triple-channel
# Usage: bash scripts/darwin/report.sh --analysis <path> [--heal <path>] [--intel-dir <path>] [--proposals <path>] [--mode <mode>]

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[DARWIN-REPORT]${NC} $1" >&2; }

ANALYSIS_FILE=""
HEAL_FILE=""
INTEL_DIR=""
PROPOSALS_FILE=""
MODE="scan"
SEND=true

while [ $# -gt 0 ]; do
  case "$1" in
    --analysis) ANALYSIS_FILE="$2"; shift 2 ;;
    --heal) HEAL_FILE="$2"; shift 2 ;;
    --intel-dir) INTEL_DIR="$2"; shift 2 ;;
    --proposals) PROPOSALS_FILE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --no-send) SEND=false; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

DARWIN_DIR="$HOME/.claude/darwin"
REPORT_DIR="$DARWIN_DIR/reports"
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/$(date +%Y%m%d).md"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- Build Report ---
{
  echo "# Darwin Report — $(date +%Y-%m-%d) ($MODE mode)"
  echo ""
  echo "Generated: $TIMESTAMP"
  echo ""

  # Self-Analysis section
  if [ -n "$ANALYSIS_FILE" ] && [ -f "$ANALYSIS_FILE" ]; then
    echo "## Self-Analysis"
    echo ""

    # Failure patterns
    FAILURE_COUNT=$(jq '.failure_patterns | length' "$ANALYSIS_FILE" 2>/dev/null || echo 0)
    if [ "$FAILURE_COUNT" -gt 0 ]; then
      echo "### Failure Patterns ($FAILURE_COUNT types)"
      jq -r '.failure_patterns[] | "- **\(.alert_type)**: \(.count)x (severity: \(.severity))"' "$ANALYSIS_FILE" 2>/dev/null
      echo ""
    fi

    # Learning gaps
    UNPROCESSED=$(jq '.unprocessed_learnings // 0' "$ANALYSIS_FILE" 2>/dev/null)
    if [ "$UNPROCESSED" -gt 0 ]; then
      echo "### Learning Gaps"
      echo "- $UNPROCESSED unprocessed learnings in ledger"
      REPEATED=$(jq '.repeated_corrections | length' "$ANALYSIS_FILE" 2>/dev/null || echo 0)
      if [ "$REPEATED" -gt 0 ]; then
        echo "- $REPEATED repeated corrections (same mistake recorded 2+ times)"
      fi
      echo ""
    fi

    # Service health
    echo "### Service Health"
    jq -r '.service_health | to_entries[] | "- **\(.key)**: \(.value)"' "$ANALYSIS_FILE" 2>/dev/null
    echo ""

    # Pipeline metrics
    echo "### Pipeline Metrics"
    jq -r '.pipeline_metrics | "- Success rate: \(.success_rate // "N/A")\n- Avg duration: \(.avg_duration_minutes // "N/A") min\n- Avg rework: \(.avg_rework_count // "N/A")"' "$ANALYSIS_FILE" 2>/dev/null
    echo ""

    # Unused agents
    UNUSED_COUNT=$(jq '.unused_agents | length' "$ANALYSIS_FILE" 2>/dev/null || echo 0)
    if [ "$UNUSED_COUNT" -gt 0 ]; then
      echo "### Unused Agents ($UNUSED_COUNT)"
      jq -r '.unused_agents[:5][] | "- \(.)"' "$ANALYSIS_FILE" 2>/dev/null
      if [ "$UNUSED_COUNT" -gt 5 ]; then
        echo "- ... and $(( UNUSED_COUNT - 5 )) more"
      fi
      echo ""
    fi
  fi

  # Self-Healing section
  if [ -n "$HEAL_FILE" ] && [ -f "$HEAL_FILE" ]; then
    echo "## Self-Healing"
    echo ""
    HEALED_COUNT=$(jq '.summary.healed_count // 0' "$HEAL_FILE" 2>/dev/null)
    FAILED_COUNT=$(jq '.summary.failed_count // 0' "$HEAL_FILE" 2>/dev/null)
    echo "- Healed: $HEALED_COUNT actions"
    echo "- Failed: $FAILED_COUNT actions"
    if [ "$HEALED_COUNT" -gt 0 ]; then
      jq -r '.healed[] | "  - \(.action): \(.target // .service // .file // "done")"' "$HEAL_FILE" 2>/dev/null
    fi
    echo ""
  fi

  # External Intel section
  if [ -n "$INTEL_DIR" ] && [ -d "$INTEL_DIR" ]; then
    # Find intel files modified today (not -newer dir which compares to dir mtime)
    INTEL_FILES=$(find "$INTEL_DIR" -name "*.json" -mtime -1 2>/dev/null | head -10)
    if [ -n "$INTEL_FILES" ]; then
      echo "## External Intelligence"
      echo ""
      for F in $INTEL_FILES; do
        PLAT=$(jq -r '.platform' "$F" 2>/dev/null || echo "unknown")
        TOPIC=$(jq -r '.topic' "$F" 2>/dev/null || echo "unknown")
        RESPONSE_LEN=$(jq -r '.response_text | length' "$F" 2>/dev/null || echo 0)
        echo "- **$PLAT** ($TOPIC): ${RESPONSE_LEN} chars"
      done
      echo ""
    fi
  fi

  # Cost section
  COST_REPORT=$(bash "$(dirname "$0")/cost-tracker.sh" --report 2>/dev/null || echo '{}')
  TODAY_COST=$(echo "$COST_REPORT" | jq '.total_today_usd // 0' 2>/dev/null || echo 0)
  echo "## Cost"
  echo "- Today: \$${TODAY_COST} (budget: \$2.00)"
  echo ""

} > "$REPORT_FILE"

log "Report saved to $REPORT_FILE"

# --- Build Telegram message (condensed, <4096 chars) ---
TELEGRAM_MSG="Darwin ($MODE) — $(date +%Y-%m-%d)"$'\n'$'\n'

if [ -n "$ANALYSIS_FILE" ] && [ -f "$ANALYSIS_FILE" ]; then
  TELEGRAM_MSG+="Self-Analysis:"$'\n'
  FAILURE_COUNT=$(jq '.failure_patterns | length' "$ANALYSIS_FILE" 2>/dev/null || echo 0)
  TELEGRAM_MSG+="- $FAILURE_COUNT alert types detected"$'\n'
  UNPROCESSED=$(jq '.unprocessed_learnings // 0' "$ANALYSIS_FILE" 2>/dev/null)
  TELEGRAM_MSG+="- $UNPROCESSED unprocessed learnings"$'\n'

  # Service health one-liner
  TG_HEALTH=$(jq -r '.service_health | to_entries | map("\(.key): \(.value)") | join(", ")' "$ANALYSIS_FILE" 2>/dev/null || echo "unknown")
  TELEGRAM_MSG+="- Services: $TG_HEALTH"$'\n'
  TELEGRAM_MSG+=$'\n'
fi

if [ -n "$HEAL_FILE" ] && [ -f "$HEAL_FILE" ]; then
  HEALED_COUNT=$(jq '.summary.healed_count // 0' "$HEAL_FILE" 2>/dev/null)
  TELEGRAM_MSG+="Self-Healing: $HEALED_COUNT actions taken"$'\n'$'\n'
fi

TELEGRAM_MSG+="Cost: \$${TODAY_COST:-0} today"

# --- Send via ghost-notify if available ---
if $SEND; then
  NOTIFY_SCRIPT=""
  for P in "$HOME/.claude/hooks/ghost-notify.sh" "$(dirname "$0")/../../hooks/ghost-notify.sh"; do
    if [ -f "$P" ]; then
      NOTIFY_SCRIPT="$P"
      break
    fi
  done

  if [ -n "$NOTIFY_SCRIPT" ]; then
    bash "$NOTIFY_SCRIPT" "phase" "$TELEGRAM_MSG" 2>/dev/null || warn "ghost-notify failed"
    log "Sent via ghost-notify"
  else
    # Direct Telegram send fallback
    TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"
    if [ -f "$TELEGRAM_ENV" ]; then
      BOT_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//' | tr -d '[:space:]')
      CHAT_ID=""
      if [ -f "$HOME/.claude/channels/telegram/access.json" ]; then
        CHAT_ID=$(jq -r '.allowFrom[0] // empty' "$HOME/.claude/channels/telegram/access.json" 2>/dev/null)
      fi
      if [ -z "$CHAT_ID" ]; then
        CHAT_ID=$(grep '^TELEGRAM_CHAT_ID=' "$HOME/.claude/.env.local" 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')
      fi

      if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
          --data-urlencode "chat_id=${CHAT_ID}" \
          --data-urlencode "text=${TELEGRAM_MSG}" > /dev/null 2>&1 || warn "Telegram send failed"
        log "Sent via Telegram directly"
      fi
    fi
  fi
fi

# Output the report path
echo "$REPORT_FILE"
