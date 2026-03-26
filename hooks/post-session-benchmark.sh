#!/usr/bin/env bash
set -euo pipefail

# post-session-benchmark.sh
# SessionEnd hook: runs a quick sample of 3 random Tier 1 benchmark tasks.
# Compares scores to the rolling average of the last 3 runs.
# Alerts on regression > 10%. Always logs to benchmarks/history.jsonl.
# Runs async — does NOT block session end.

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASKS_DIR="$PROJECT_ROOT/benchmarks/tasks"
HISTORY_FILE="$PROJECT_ROOT/benchmarks/history.jsonl"
ALERTS_FILE="$HOME/.claude/logs/alerts.jsonl"
SESSION_LOG="$HOME/.claude/logs/sessions.log"
SAMPLE_SIZE=3
TASK_TIMEOUT=30

# --- Ensure required dirs exist ---
mkdir -p "$(dirname "$HISTORY_FILE")"
mkdir -p "$(dirname "$ALERTS_FILE")"

# --- Validate dependencies ---
if ! command -v claude &>/dev/null; then
  echo "[post-session-benchmark] SKIP: 'claude' CLI not found in PATH" >> "$SESSION_LOG"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "[post-session-benchmark] SKIP: 'jq' not found in PATH" >> "$SESSION_LOG"
  exit 0
fi

# --- Find all Tier 1 tasks ---
TIER1_TASKS=()
for task_file in "$TASKS_DIR"/reg-*.json; do
  [[ -f "$task_file" ]] || continue
  tier=$(jq -r '.tier // 0' "$task_file" 2>/dev/null || echo "0")
  if [[ "$tier" == "1" ]]; then
    TIER1_TASKS+=("$task_file")
  fi
done

TOTAL_TIER1=${#TIER1_TASKS[@]}

if [[ "$TOTAL_TIER1" -eq 0 ]]; then
  echo "[post-session-benchmark] SKIP: no Tier 1 tasks found in $TASKS_DIR" >> "$SESSION_LOG"
  exit 0
fi

# --- Select random sample ---
# Shuffle and pick up to SAMPLE_SIZE tasks
SELECTED_TASKS=()
if [[ "$TOTAL_TIER1" -le "$SAMPLE_SIZE" ]]; then
  SELECTED_TASKS=("${TIER1_TASKS[@]}")
else
  # Use sort -R for randomness (portable across macOS and Linux)
  mapfile -t SHUFFLED < <(printf '%s\n' "${TIER1_TASKS[@]}" | sort -R)
  for i in $(seq 0 $((SAMPLE_SIZE - 1))); do
    SELECTED_TASKS+=("${SHUFFLED[$i]}")
  done
fi

# --- Run benchmark on selected tasks ---
RUN_ID="post-session-$(date -u +%Y%m%d-%H%M%S)"
RUN_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TOTAL_SCORE=0
TASK_COUNT=0
REGRESSION_COUNT=0
REGRESSION_DETAILS=()

for task_file in "${SELECTED_TASKS[@]}"; do
  task_id=$(jq -r '.id' "$task_file")
  task_description=$(jq -r '.description' "$task_file")
  task_category=$(jq -r '.category' "$task_file")

  # Run the task with timeout
  RAW_OUTPUT=""
  if ! RAW_OUTPUT=$(timeout "$TASK_TIMEOUT" claude --print "$task_description" 2>/dev/null); then
    RAW_OUTPUT=""
  fi

  # Score: contains checks
  CONTAINS_MATCHED=0
  CONTAINS_TOTAL=0
  while IFS= read -r check; do
    [[ -z "$check" ]] && continue
    CONTAINS_TOTAL=$((CONTAINS_TOTAL + 1))
    if echo "$RAW_OUTPUT" | grep -qF "$check" 2>/dev/null; then
      CONTAINS_MATCHED=$((CONTAINS_MATCHED + 1))
    fi
  done < <(jq -r '.expected_output.contains[]?' "$task_file" 2>/dev/null || true)

  # Score: not_contains checks
  NOT_CONTAINS_PASSED=0
  NOT_CONTAINS_TOTAL=0
  while IFS= read -r check; do
    [[ -z "$check" ]] && continue
    NOT_CONTAINS_TOTAL=$((NOT_CONTAINS_TOTAL + 1))
    if ! echo "$RAW_OUTPUT" | grep -qF "$check" 2>/dev/null; then
      NOT_CONTAINS_PASSED=$((NOT_CONTAINS_PASSED + 1))
    fi
  done < <(jq -r '.expected_output.not_contains[]?' "$task_file" 2>/dev/null || true)

  MAX_POINTS=$((CONTAINS_TOTAL + NOT_CONTAINS_TOTAL))
  EARNED=$((CONTAINS_MATCHED + NOT_CONTAINS_PASSED))

  if [[ "$MAX_POINTS" -eq 0 ]]; then
    SCORE=100
  else
    SCORE=$(( (EARNED * 100) / MAX_POINTS ))
  fi

  PASS="false"
  [[ "$SCORE" -ge 80 ]] && PASS="true"

  # --- Regression detection: compare against last 3 runs for this task ---
  REGRESSION="false"
  PREV_SCORES=""
  if [[ -f "$HISTORY_FILE" ]]; then
    PREV_SCORES=$(grep "\"task_id\": \"$task_id\"" "$HISTORY_FILE" 2>/dev/null \
      | tail -3 \
      | jq -r '.score' 2>/dev/null \
      || true)
  fi

  if [[ -n "$PREV_SCORES" ]]; then
    PREV_COUNT=$(echo "$PREV_SCORES" | grep -c '[0-9]' || echo "0")
    if [[ "$PREV_COUNT" -ge 1 ]]; then
      ROLLING_SUM=0
      while IFS= read -r s; do
        [[ -z "$s" || "$s" == "null" ]] && continue
        ROLLING_SUM=$(( ROLLING_SUM + s ))
      done <<< "$PREV_SCORES"
      ROLLING_AVG=$(( ROLLING_SUM / PREV_COUNT ))
      DROP=$(( ROLLING_AVG - SCORE ))

      # Alert threshold: >10% regression
      if [[ "$DROP" -gt 10 ]]; then
        REGRESSION="true"
        REGRESSION_COUNT=$((REGRESSION_COUNT + 1))
        REGRESSION_DETAILS+=("$task_id: avg=${ROLLING_AVG}% -> current=${SCORE}% (drop=${DROP}%)")
      fi
    fi
  fi

  # --- Write result to history.jsonl ---
  jq -n \
    --arg run_id "$RUN_ID" \
    --arg task_id "$task_id" \
    --arg category "$task_category" \
    --argjson score "$SCORE" \
    --argjson pass "$PASS" \
    --argjson regression "$REGRESSION" \
    --arg timestamp "$RUN_TIMESTAMP" \
    --arg source "post-session-benchmark" \
    '{
      run_id: $run_id,
      task_id: $task_id,
      tier: 1,
      category: $category,
      score: $score,
      pass: $pass,
      regression: $regression,
      timestamp: $timestamp,
      source: $source
    }' >> "$HISTORY_FILE"

  TOTAL_SCORE=$((TOTAL_SCORE + SCORE))
  TASK_COUNT=$((TASK_COUNT + 1))
done

# --- Compute overall score for this sample ---
if [[ "$TASK_COUNT" -gt 0 ]]; then
  OVERALL_SCORE=$(( TOTAL_SCORE / TASK_COUNT ))
else
  OVERALL_SCORE=0
fi

# --- Log session summary ---
SUMMARY="[post-session-benchmark] run=$RUN_ID tasks=$TASK_COUNT score=${OVERALL_SCORE}% regressions=$REGRESSION_COUNT"
echo "$SUMMARY" >> "$SESSION_LOG"

# --- Alert on regressions ---
if [[ "$REGRESSION_COUNT" -gt 0 ]]; then
  ALERT_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Build details string for alert
  DETAILS_JSON="["
  for detail in "${REGRESSION_DETAILS[@]}"; do
    DETAILS_JSON+="\"$detail\","
  done
  DETAILS_JSON="${DETAILS_JSON%,}]"

  jq -n \
    --arg timestamp "$ALERT_TIMESTAMP" \
    --arg run_id "$RUN_ID" \
    --arg level "WARN" \
    --arg message "Post-session benchmark regression detected" \
    --argjson regression_count "$REGRESSION_COUNT" \
    --argjson overall_score "$OVERALL_SCORE" \
    --argjson details "$DETAILS_JSON" \
    '{
      timestamp: $timestamp,
      run_id: $run_id,
      level: $level,
      message: $message,
      regression_count: $regression_count,
      overall_score: $overall_score,
      details: $details,
      source: "post-session-benchmark"
    }' >> "$ALERTS_FILE"

  # macOS notification
  osascript -e "display notification \"${REGRESSION_COUNT} regression(s) detected. Score: ${OVERALL_SCORE}%\" with title \"Benchmark Alert\" sound name \"Basso\"" 2>/dev/null || true
fi
