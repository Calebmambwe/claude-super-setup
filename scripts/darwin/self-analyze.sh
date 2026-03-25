#!/usr/bin/env bash
set -euo pipefail

# Darwin Self-Analysis — mines logs, learning ledger, and pipeline metrics for platform health insights
# Usage: bash scripts/darwin/self-analyze.sh [--project-dir <path>] [--days <N>] [--output <path>]

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[DARWIN-ANALYZE]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[DARWIN-ANALYZE]${NC} $1" >&2; }

# --- Parse args ---
PROJECT_DIR="${PWD}"
DAYS=7
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

LOGS_DIR="$HOME/.claude/logs"
DARWIN_DIR="$HOME/.claude/darwin"
mkdir -p "$DARWIN_DIR/analysis"

# Calculate cutoff timestamp
if [[ "$(uname)" == "Darwin" ]]; then
  CUTOFF=$(date -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
else
  CUTOFF=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
fi

log "Analyzing platform health (last ${DAYS} days, cutoff: $CUTOFF)"

# --- Pass A: Failure Pattern Mining ---
log "Pass A: Mining failure patterns from alerts..."
FAILURE_PATTERNS="[]"
ALERTS_FILE="$LOGS_DIR/alerts.jsonl"
if [ -f "$ALERTS_FILE" ]; then
  FAILURE_PATTERNS=$(jq -s --arg cutoff "$CUTOFF" '
    [.[] | select(.timestamp >= $cutoff or .ts >= $cutoff)] |
    group_by(.alert // .type // .level) |
    map({
      alert_type: (.[0].alert // .[0].type // .[0].level // "unknown"),
      count: length,
      last_seen: (sort_by(.timestamp // .ts) | last | (.timestamp // .ts)),
      severity: (if length >= 5 then "high" elif length >= 3 then "medium" else "low" end)
    }) |
    sort_by(-.count)
  ' "$ALERTS_FILE" 2>/dev/null || echo "[]")
fi

# --- Pass B: Learning Ledger Gap Analysis ---
log "Pass B: Analyzing learning ledger..."
LEARNING_DB="$HOME/.claude/reflect/learnings.db"
UNPROCESSED_COUNT=0
REPEATED_CORRECTIONS="[]"

if [ -f "$LEARNING_DB" ] && command -v sqlite3 &>/dev/null; then
  UNPROCESSED_COUNT=$(sqlite3 "$LEARNING_DB" "SELECT COUNT(*) FROM learnings WHERE status = 'pending'" 2>/dev/null || echo 0)

  REPEATED_CORRECTIONS=$(sqlite3 -json "$LEARNING_DB" "
    SELECT content as pattern, count as occurrences, confidence, last_seen
    FROM learnings
    WHERE learning_type = 'correction' AND count >= 2 AND status != 'archived'
    ORDER BY count DESC
    LIMIT 10
  " 2>/dev/null || echo "[]")

  # Fallback if -json flag not supported
  if [ -z "$REPEATED_CORRECTIONS" ] || [ "$REPEATED_CORRECTIONS" = "" ]; then
    REPEATED_CORRECTIONS=$(sqlite3 "$LEARNING_DB" "
      SELECT json_group_array(json_object(
        'pattern', content,
        'occurrences', count,
        'confidence', confidence
      ))
      FROM learnings
      WHERE learning_type = 'correction' AND count >= 2 AND status != 'archived'
      ORDER BY count DESC
      LIMIT 10
    " 2>/dev/null || echo "[]")
  fi
fi

# --- Pass C: Agent Utilization Analysis ---
log "Pass C: Analyzing agent utilization..."
UNUSED_AGENTS="[]"
CATALOG_FILE="$PROJECT_DIR/agents/catalog.json"
TELEMETRY_FILE="$LOGS_DIR/telemetry.jsonl"

if [ -f "$CATALOG_FILE" ]; then
  ALL_AGENTS=$(jq -r '.agents[].name' "$CATALOG_FILE" 2>/dev/null | sort)

  if [ -f "$TELEMETRY_FILE" ]; then
    USED_AGENTS=$(jq -r '.agent // .subagent_type // empty' "$TELEMETRY_FILE" 2>/dev/null | sort -u)
    UNUSED_AGENTS=$(comm -23 <(echo "$ALL_AGENTS") <(echo "$USED_AGENTS") | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")
  else
    warn "No telemetry.jsonl found — cannot determine agent utilization"
    UNUSED_AGENTS=$(echo "$ALL_AGENTS" | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")
  fi
fi

# --- Pass D: Pipeline Velocity Analysis ---
log "Pass D: Analyzing pipeline velocity..."
PIPELINE_METRICS='{"avg_duration_minutes": null, "success_rate": null, "avg_rework_count": null}'
METRICS_FILE="$HOME/.claude/metrics.jsonl"

if [ -f "$METRICS_FILE" ]; then
  PIPELINE_METRICS=$(jq -s --arg cutoff "$CUTOFF" '
    [.[] | select((.timestamp // .ts // "") >= $cutoff)] |
    if length == 0 then
      {avg_duration_minutes: null, success_rate: null, avg_rework_count: null, total_runs: 0}
    else
      {
        avg_duration_minutes: ([.[].duration_minutes // .[].duration_ms / 60000 // null | select(. != null)] | if length > 0 then (add / length | . * 10 | round / 10) else null end),
        success_rate: (([.[] | select(.status == "success" or .status == "complete")] | length) / length | . * 100 | round / 100),
        avg_rework_count: ([.[].rework_count // .[].rework_iterations // null | select(. != null)] | if length > 0 then (add / length | . * 10 | round / 10) else null end),
        total_runs: length
      }
    end
  ' "$METRICS_FILE" 2>/dev/null || echo "$PIPELINE_METRICS")
fi

# --- Service Health Checks ---
log "Checking service health..."

check_service() {
  local NAME="$1"
  local CHECK="$2"
  if eval "$CHECK" 2>/dev/null; then
    echo "healthy"
  else
    echo "not_running"
  fi
}

TELEGRAM_HEALTH="unknown"
GHOST_HEALTH="not_running"
LEARNING_HEALTH="unknown"

# Telegram listener
if command -v systemctl &>/dev/null; then
  TELEGRAM_HEALTH=$(check_service "telegram" "systemctl --user is-active --quiet claude-telegram@\${USER}.service")
elif pgrep -f "channels.*plugin:telegram" &>/dev/null; then
  TELEGRAM_HEALTH="healthy"
elif screen -ls 2>/dev/null | grep -q "claude-telegram"; then
  TELEGRAM_HEALTH="healthy"
else
  TELEGRAM_HEALTH="not_running"
fi

# Ghost watchdog
if [ -f "$HOME/.claude/ghost-config.json" ]; then
  GHOST_STATUS=$(jq -r '.status // "unknown"' "$HOME/.claude/ghost-config.json" 2>/dev/null)
  if [ "$GHOST_STATUS" = "running" ]; then
    if pgrep -f "ghost-watchdog" &>/dev/null; then
      GHOST_HEALTH="healthy"
    else
      GHOST_HEALTH="dead_but_configured"
    fi
  else
    GHOST_HEALTH="$GHOST_STATUS"
  fi
fi

# Learning server
if [ -f "$LEARNING_DB" ]; then
  LEARNING_HEALTH="healthy"
fi

# --- Stale/blocked tasks ---
STALE_TASKS=0
BLOCKED_TASKS=0
TASKS_FILE="$PROJECT_DIR/tasks.json"
if [ -f "$TASKS_FILE" ]; then
  STALE_TASKS=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$TASKS_FILE" 2>/dev/null || echo 0)
  BLOCKED_TASKS=$(jq '[.tasks[] | select(.status == "blocked")] | length' "$TASKS_FILE" 2>/dev/null || echo 0)
fi

# --- Compile output ---
OUTPUT=$(jq -n \
  --argjson days "$DAYS" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg cutoff "$CUTOFF" \
  --argjson failure_patterns "$FAILURE_PATTERNS" \
  --argjson unprocessed_learnings "$UNPROCESSED_COUNT" \
  --argjson repeated_corrections "$REPEATED_CORRECTIONS" \
  --argjson unused_agents "$UNUSED_AGENTS" \
  --argjson pipeline_metrics "$PIPELINE_METRICS" \
  --arg telegram "$TELEGRAM_HEALTH" \
  --arg ghost "$GHOST_HEALTH" \
  --arg learning "$LEARNING_HEALTH" \
  --argjson stale_tasks "$STALE_TASKS" \
  --argjson blocked_tasks "$BLOCKED_TASKS" \
  '{
    period_days: $days,
    generated_at: $generated_at,
    cutoff: $cutoff,
    failure_patterns: $failure_patterns,
    unprocessed_learnings: $unprocessed_learnings,
    repeated_corrections: $repeated_corrections,
    unused_agents: $unused_agents,
    pipeline_metrics: $pipeline_metrics,
    service_health: {
      telegram_listener: $telegram,
      ghost_watchdog: $ghost,
      learning_server: $learning
    },
    stale_tasks: $stale_tasks,
    blocked_tasks: $blocked_tasks
  }')

# --- Save output ---
DEFAULT_OUTPUT="$DARWIN_DIR/analysis/$(date +%Y%m%d).json"
OUTPUT_FILE="${OUTPUT_FILE:-$DEFAULT_OUTPUT}"
mkdir -p "$(dirname "$OUTPUT_FILE")"
echo "$OUTPUT" > "$OUTPUT_FILE"
log "Analysis saved to $OUTPUT_FILE"

echo "$OUTPUT"
