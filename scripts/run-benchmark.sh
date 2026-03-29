#!/usr/bin/env bash
set -eo pipefail

# Usage: ./scripts/run-benchmark.sh [--tier 1|2|3] [--task task-id]
# Runs benchmark tasks and records results to benchmarks/history.jsonl
#
# Examples:
#   ./scripts/run-benchmark.sh                    # Run all tasks
#   ./scripts/run-benchmark.sh --tier 1           # Run only tier 1 tasks
#   ./scripts/run-benchmark.sh --task reg-001     # Run a single task by ID

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASKS_DIR="$PROJECT_ROOT/benchmarks/tasks"
HISTORY_FILE="$PROJECT_ROOT/benchmarks/history.jsonl"

# --- Defaults ---
TIER_FILTER=""
TASK_FILTER=""

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER_FILTER="$2"
      shift 2
      ;;
    --task)
      TASK_FILTER="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--tier 1|2|3] [--task task-id]"
      echo ""
      echo "Options:"
      echo "  --tier 1|2|3    Run only tasks of the specified tier"
      echo "  --task task-id  Run only the task with the specified ID (e.g. reg-001)"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

# --- Validate dependencies ---
if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH. Install Claude Code first." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: 'jq' not found in PATH. Install jq first (brew install jq)." >&2
  exit 1
fi

# --- Setup ---
mkdir -p "$(dirname "$HISTORY_FILE")"
touch "$HISTORY_FILE"

RUN_ID="run-$(date -u +%Y%m%d-%H%M%S)"
RUN_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo ""
echo "============================================"
echo " Benchmark Runner"
echo " Run ID:    $RUN_ID"
echo " Timestamp: $RUN_TIMESTAMP"
[[ -n "$TIER_FILTER" ]] && echo " Tier:      $TIER_FILTER"
[[ -n "$TASK_FILTER" ]] && echo " Task:      $TASK_FILTER"
echo "============================================"
echo ""

# --- Collect tasks to run ---
TASK_FILES=()

for task_file in "$TASKS_DIR"/reg-*.json; do
  [[ -f "$task_file" ]] || continue

  task_id=$(jq -r '.id' "$task_file")
  task_tier=$(jq -r '.tier' "$task_file")

  # Apply filters
  if [[ -n "$TIER_FILTER" && "$task_tier" != "$TIER_FILTER" ]]; then
    continue
  fi
  if [[ -n "$TASK_FILTER" && "$task_id" != "$TASK_FILTER" ]]; then
    continue
  fi

  TASK_FILES+=("$task_file")
done

if [[ ${#TASK_FILES[@]} -eq 0 ]]; then
  echo "No tasks matched the specified filters. Check --tier and --task values."
  exit 1
fi

echo "Found ${#TASK_FILES[@]} task(s) to run."
echo ""

# --- Results tracking ---
TOTAL=0
PASSED=0
FAILED=0
REGRESSIONS=0
TOTAL_SCORE=0

declare -a RESULT_ROWS
declare -a REGRESSION_NOTES
declare -a FAILURE_NOTES

# --- Execute each task ---
for task_file in "${TASK_FILES[@]}"; do
  task_id=$(jq -r '.id' "$task_file")
  task_tier=$(jq -r '.tier' "$task_file")
  task_category=$(jq -r '.category' "$task_file")
  task_description=$(jq -r '.description' "$task_file")
  task_time_limit=$(jq -r '.time_limit_seconds' "$task_file")

  printf "Running %-20s [tier %s] %s ... " "$task_id" "$task_tier" "$task_category"

  START_TS=$(date +%s)

  # Invoke Claude with the task description
  # --dangerously-skip-permissions prevents the interactive trust prompt from
  # blocking the process (which caused 60s timeouts and false 14% scores).
  RAW_OUTPUT=""
  if ! RAW_OUTPUT=$(timeout "$task_time_limit" claude --print --dangerously-skip-permissions "$task_description" 2>/dev/null); then
    RAW_OUTPUT=""
  fi

  END_TS=$(date +%s)
  DURATION=$((END_TS - START_TS))

  # If output is empty (timeout or error), score 0 immediately — skip all checks.
  if [[ -z "$RAW_OUTPUT" ]]; then
    CONTAINS_MATCHED=()
    CONTAINS_MISSING=()
    NOT_CONTAINS_VIOLATIONS=()
    SYNTAX_VALID=true
    EARNED=0
    MAX_POINTS=$(jq '[.expected_output.contains // [] | length, .expected_output.not_contains // [] | length] | add' "$task_file" 2>/dev/null || echo 1)
    [[ "$(jq -r '.expected_output.validate_syntax // false' "$task_file")" == "true" ]] && MAX_POINTS=$((MAX_POINTS + 1))
    SCORE=0
    PASS="false"
    PASS_LABEL="FAIL"
    FAILURE_NOTES+=("$task_id: Score 0% — no output (timeout or error)")
    RESULT_ROWS+=("$(printf '| %-22s | %-20s | %3d%% | %-4s | %-16s | %ds |' \
      "$task_id" "$task_category" "$SCORE" "$PASS_LABEL" "-" "$DURATION")")
    echo "FAIL (0%) in ${DURATION}s [timeout/no output]"
    # Still write to history so regressions can be tracked
    CONTAINS_MATCHED_JSON="[]"
    CONTAINS_MISSING_JSON=$(jq '.expected_output.contains // []' "$task_file" 2>/dev/null || echo "[]")
    NOT_CONTAINS_VIOLATIONS_JSON="[]"
    VIOLATIONS_JSON=$(jq '[.expected_output.contains // [] | .[] | "missing: " + .] | . + (if .expected_output.validate_syntax then ["timeout/no output"] else [] end)' "$task_file" 2>/dev/null || echo '["timeout/no output"]')
    RESULT_JSON=$(jq -n \
      --arg run_id "$RUN_ID" \
      --arg task_id "$task_id" \
      --argjson tier "$task_tier" \
      --arg category "$task_category" \
      --argjson score 0 \
      --argjson pass false \
      --argjson regression false \
      --argjson duration "$DURATION" \
      --arg timestamp "$RUN_TIMESTAMP" \
      --argjson violations '["timeout/no output"]' \
      --argjson contains_matched "[]" \
      --argjson contains_missing "$CONTAINS_MISSING_JSON" \
      --argjson not_contains_violations "[]" \
      --argjson syntax_valid true \
      '{
        run_id: $run_id,
        task_id: $task_id,
        tier: $tier,
        category: $category,
        score: $score,
        pass: $pass,
        regression: $regression,
        duration_seconds: $duration,
        timestamp: $timestamp,
        violations: $violations,
        details: {
          contains_matched: $contains_matched,
          contains_missing: $contains_missing,
          not_contains_violations: $not_contains_violations,
          syntax_valid: $syntax_valid
        }
      }')
    echo "$RESULT_JSON" >> "$HISTORY_FILE"
    TOTAL=$((TOTAL + 1))
    FAILED=$((FAILED + 1))
    continue
  fi

  # --- Score: contains checks ---
  CONTAINS_MATCHED=()
  CONTAINS_MISSING=()
  CONTAINS_LIST=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && CONTAINS_LIST+=("$line")
  done < <(jq -r '.expected_output.contains[]?' "$task_file" 2>/dev/null || true)

  for check in "${CONTAINS_LIST[@]}"; do
    if echo "$RAW_OUTPUT" | grep -qF "$check"; then
      CONTAINS_MATCHED+=("$check")
    else
      CONTAINS_MISSING+=("$check")
    fi
  done

  # --- Score: not_contains checks ---
  NOT_CONTAINS_VIOLATIONS=()
  NOT_CONTAINS_LIST=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && NOT_CONTAINS_LIST+=("$line")
  done < <(jq -r '.expected_output.not_contains[]?' "$task_file" 2>/dev/null || true)

  for check in "${NOT_CONTAINS_LIST[@]}"; do
    if echo "$RAW_OUTPUT" | grep -qF "$check"; then
      NOT_CONTAINS_VIOLATIONS+=("$check")
    fi
  done

  # --- Score: syntax validation (optional) ---
  SYNTAX_VALID=true
  SYNTAX_ERROR=""
  HAS_SYNTAX_CHECK=$(jq -r '.expected_output.validate_syntax // false' "$task_file")
  SYNTAX_LANGUAGE=$(jq -r '.expected_output.language // ""' "$task_file")

  if [[ "$HAS_SYNTAX_CHECK" == "true" && -n "$RAW_OUTPUT" ]]; then
    TMP_CODE=$(mktemp)
    # Extract code block if present
    CODE_BLOCK=$(echo "$RAW_OUTPUT" | sed -n '/^```/,/^```$/p' | sed '/^```/d' | head -50)
    if [[ -n "$CODE_BLOCK" ]]; then
      echo "$CODE_BLOCK" > "$TMP_CODE"
    else
      echo "$RAW_OUTPUT" > "$TMP_CODE"
    fi

    case "$SYNTAX_LANGUAGE" in
      typescript|ts)
        if command -v npx &>/dev/null; then
          mv "$TMP_CODE" "${TMP_CODE}.ts"
          if ! npx --yes tsc --noEmit --strict --target ES2020 "${TMP_CODE}.ts" 2>/dev/null; then
            SYNTAX_VALID=false
            SYNTAX_ERROR="TypeScript syntax error"
          fi
          rm -f "${TMP_CODE}.ts"
        else
          rm -f "$TMP_CODE"
        fi
        ;;
      python|py)
        mv "$TMP_CODE" "${TMP_CODE}.py"
        if ! python3 -m py_compile "${TMP_CODE}.py" 2>/dev/null; then
          SYNTAX_VALID=false
          SYNTAX_ERROR="Python syntax error"
        fi
        rm -f "${TMP_CODE}.py"
        ;;
      bash|sh|shell)
        if ! bash -n "$TMP_CODE" 2>/dev/null; then
          SYNTAX_VALID=false
          SYNTAX_ERROR="Bash syntax error"
        fi
        rm -f "$TMP_CODE"
        ;;
      *)
        rm -f "$TMP_CODE"
        ;;
    esac
  fi

  # --- Calculate score ---
  MAX_POINTS=$(( ${#CONTAINS_LIST[@]} + ${#NOT_CONTAINS_LIST[@]} ))
  [[ "$HAS_SYNTAX_CHECK" == "true" ]] && MAX_POINTS=$((MAX_POINTS + 1))

  EARNED=0
  EARNED=$(( EARNED + ${#CONTAINS_MATCHED[@]} ))
  EARNED=$(( EARNED + ${#NOT_CONTAINS_LIST[@]} - ${#NOT_CONTAINS_VIOLATIONS[@]} ))
  [[ "$HAS_SYNTAX_CHECK" == "true" && "$SYNTAX_VALID" == "true" ]] && EARNED=$((EARNED + 1))

  # Protect against division by zero
  if [[ "$MAX_POINTS" -eq 0 ]]; then
    SCORE=100
  else
    SCORE=$(( (EARNED * 100) / MAX_POINTS ))
  fi

  PASS="false"
  PASS_LABEL="FAIL"
  if [[ "$SCORE" -ge 80 ]]; then
    PASS="true"
    PASS_LABEL="PASS"
  fi

  # --- Regression detection ---
  REGRESSION="false"
  REGRESSION_LABEL="-"

  PREV_SCORES=$(grep "\"task_id\": \"$task_id\"" "$HISTORY_FILE" 2>/dev/null | tail -3 | jq -r '.score' 2>/dev/null || true)

  if [[ -n "$PREV_SCORES" ]]; then
    PREV_COUNT=$(echo "$PREV_SCORES" | wc -l | tr -d ' ')
    if [[ "$PREV_COUNT" -ge 1 ]]; then
      ROLLING_SUM=0
      while IFS= read -r s; do
        ROLLING_SUM=$(echo "$ROLLING_SUM + $s" | bc 2>/dev/null || echo "$ROLLING_SUM")
      done <<< "$PREV_SCORES"
      ROLLING_AVG=$(echo "scale=1; $ROLLING_SUM / $PREV_COUNT" | bc 2>/dev/null || echo "0")
      DROP=$(echo "$ROLLING_AVG - $SCORE" | bc 2>/dev/null || echo "0")
      DROP_INT=${DROP%.*}
      if [[ "$DROP_INT" -gt 5 ]]; then
        REGRESSION="true"
        REGRESSION_LABEL="YES (-${DROP_INT}%)"
        REGRESSIONS=$((REGRESSIONS + 1))
        REGRESSION_NOTES+=("$task_id: Score dropped from ${ROLLING_AVG}% avg -> ${SCORE}% current.")
      fi
    fi
  fi

  # --- Build violations arrays for JSON ---
  VIOLATIONS_JSON="[]"
  if [[ ${#CONTAINS_MISSING[@]} -gt 0 || ${#NOT_CONTAINS_VIOLATIONS[@]} -gt 0 || "$SYNTAX_VALID" == "false" ]]; then
    VIOLATION_PARTS=()
    for m in "${CONTAINS_MISSING[@]}"; do
      VIOLATION_PARTS+=("\"missing: $m\"")
    done
    for v in "${NOT_CONTAINS_VIOLATIONS[@]}"; do
      VIOLATION_PARTS+=("\"forbidden: $v\"")
    done
    [[ "$SYNTAX_VALID" == "false" ]] && VIOLATION_PARTS+=("\"$SYNTAX_ERROR\"")
    VIOLATIONS_JSON="[$(IFS=,; echo "${VIOLATION_PARTS[*]}")]"
  fi

  # --- Build details JSON ---
  CONTAINS_MATCHED_JSON=$(printf '%s\n' "${CONTAINS_MATCHED[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  CONTAINS_MISSING_JSON=$(printf '%s\n' "${CONTAINS_MISSING[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  NOT_CONTAINS_VIOLATIONS_JSON=$(printf '%s\n' "${NOT_CONTAINS_VIOLATIONS[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

  # --- Write result to history.jsonl ---
  RESULT_JSON=$(jq -n \
    --arg run_id "$RUN_ID" \
    --arg task_id "$task_id" \
    --argjson tier "$task_tier" \
    --arg category "$task_category" \
    --argjson score "$SCORE" \
    --argjson pass "$PASS" \
    --argjson regression "$REGRESSION" \
    --argjson duration "$DURATION" \
    --arg timestamp "$RUN_TIMESTAMP" \
    --argjson violations "$VIOLATIONS_JSON" \
    --argjson contains_matched "$CONTAINS_MATCHED_JSON" \
    --argjson contains_missing "$CONTAINS_MISSING_JSON" \
    --argjson not_contains_violations "$NOT_CONTAINS_VIOLATIONS_JSON" \
    --argjson syntax_valid "$SYNTAX_VALID" \
    '{
      run_id: $run_id,
      task_id: $task_id,
      tier: $tier,
      category: $category,
      score: $score,
      pass: $pass,
      regression: $regression,
      duration_seconds: $duration,
      timestamp: $timestamp,
      violations: $violations,
      details: {
        contains_matched: $contains_matched,
        contains_missing: $contains_missing,
        not_contains_violations: $not_contains_violations,
        syntax_valid: $syntax_valid
      }
    }')

  echo "$RESULT_JSON" >> "$HISTORY_FILE"

  # --- Accumulate totals ---
  TOTAL=$((TOTAL + 1))
  TOTAL_SCORE=$((TOTAL_SCORE + SCORE))

  if [[ "$PASS" == "true" ]]; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    FAILURE_NOTES+=("$task_id: Score ${SCORE}% < 80% threshold. Missing: $(IFS=', '; echo "${CONTAINS_MISSING[*]:-none}")")
  fi

  RESULT_ROWS+=("$(printf '| %-22s | %-20s | %3d%% | %-4s | %-16s | %ds |' \
    "$task_id" "$task_category" "$SCORE" "$PASS_LABEL" "$REGRESSION_LABEL" "$DURATION")")

  echo "$PASS_LABEL ($SCORE%) in ${DURATION}s"
done

# --- Final summary ---
if [[ "$TOTAL" -gt 0 ]]; then
  OVERALL_SCORE=$(( TOTAL_SCORE / TOTAL ))
else
  OVERALL_SCORE=0
fi

echo ""
echo "============================================"
echo " Benchmark Run Report"
echo " Run ID:        $RUN_ID"
echo " Timestamp:     $RUN_TIMESTAMP"
echo " Tasks Run:     $TOTAL"
echo " Passed:        $PASSED"
echo " Failed:        $FAILED"
echo " Regressions:   $REGRESSIONS"
echo " Overall Score: ${OVERALL_SCORE}%"
echo "============================================"
echo ""
echo "Results:"
echo "| Task                   | Category             | Score | Pass | Regression       | Duration |"
echo "|------------------------|----------------------|-------|------|------------------|----------|"
for row in "${RESULT_ROWS[@]}"; do
  echo "$row"
done

if [[ ${#REGRESSION_NOTES[@]} -gt 0 ]]; then
  echo ""
  echo "Regressions Detected:"
  for note in "${REGRESSION_NOTES[@]}"; do
    echo "  - $note"
  done
fi

if [[ ${#FAILURE_NOTES[@]} -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for note in "${FAILURE_NOTES[@]}"; do
    echo "  - $note"
  done
fi

echo ""
if [[ "$REGRESSIONS" -gt 0 ]]; then
  echo "OVERALL: WARN -- $REGRESSIONS regression(s) detected."
elif [[ "$FAILED" -gt 0 ]]; then
  echo "OVERALL: FAIL -- $FAILED task(s) below pass threshold."
else
  echo "OVERALL: PASS -- All $TOTAL tasks passed."
fi
echo ""

# Exit code: use BENCHMARK_STRICT=1 to fail on task failures (default: always exit 0)
# The self-improve pipeline needs benchmarks to complete even when some tasks fail
if [[ "${BENCHMARK_STRICT:-0}" == "1" ]] && [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi

exit 0
