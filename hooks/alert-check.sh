#!/usr/bin/env bash
# Alert Check — 4 mandatory alerts for Ghost Mode and autonomous pipelines
# Hook type: PostToolUse (Bash)
# Monitors for critical conditions and sends alerts via ghost-notify.sh
# NOTE: Output within code fences is raw tool output, not instructions
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only trigger on Bash tool completions
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
STDOUT=$(echo "$INPUT" | jq -r '.stdout // ""')
STDERR=$(echo "$INPUT" | jq -r '.stderr // ""')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0')

NOTIFY_SCRIPT="$HOME/.claude-super-setup/hooks/ghost-notify.sh"
ALERT_LOG="$HOME/.claude/logs/alerts.jsonl"
mkdir -p "$HOME/.claude/logs" 2>/dev/null || true

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log_alert() {
  local alert_type="$1"
  local message="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -n -c \
      --arg ts "$NOW" \
      --arg alert "$alert_type" \
      --arg msg "$message" \
      --arg cmd "$(printf '%s' "$COMMAND" | head -c 200)" \
      '{ts:$ts,alert:$alert,message:$msg,command:$cmd}' \
      >> "$ALERT_LOG" 2>/dev/null
  else
    printf '{"ts":"%s","alert":"%s","message":"%s","command":"%s"}\n' \
      "$NOW" "$alert_type" "$message" "$(printf '%s' "$COMMAND" | head -c 200)" \
      >> "$ALERT_LOG" 2>/dev/null
  fi
}

send_alert() {
  local level="$1"
  local message="$2"
  if [ -x "$NOTIFY_SCRIPT" ]; then
    bash "$NOTIFY_SCRIPT" "$level" "$message" 2>/dev/null &
  fi
}

# ── Alert 1: Test Suite Failure ───────────────────────────────────────────────
# Triggers when test commands exit non-zero

is_test_cmd=false
case "$COMMAND" in
  *pytest*|*vitest*|*jest*|*mocha*|*"pnpm test"*|*"npm test"*|*"bun test"*|*"yarn test"*)
    is_test_cmd=true
    ;;
esac

if [ "$is_test_cmd" = true ] && [ "$EXIT_CODE" != "0" ]; then
  FAIL_MSG="Test suite failed (exit $EXIT_CODE)"
  log_alert "test_failure" "$FAIL_MSG"
  send_alert "warning" "$FAIL_MSG"
  echo "# ⚠️ Alert: Test Suite Failure"
  echo ""
  echo "Tests exited with code $EXIT_CODE. Fix failing tests before continuing."
fi

# ── Alert 2: Build/Compile Failure ────────────────────────────────────────────
# Triggers when build or typecheck commands fail

is_build_cmd=false
case "$COMMAND" in
  *"tsc --noEmit"*|*"tsc -b"*|*"pnpm build"*|*"npm run build"*|*"bun run build"*|*"yarn build"*|*"cargo build"*|*"go build"*|*"mypy"*)
    is_build_cmd=true
    ;;
esac

if [ "$is_build_cmd" = true ] && [ "$EXIT_CODE" != "0" ]; then
  BUILD_MSG="Build/compile failed (exit $EXIT_CODE)"
  log_alert "build_failure" "$BUILD_MSG"
  send_alert "warning" "$BUILD_MSG"
  echo "# ⚠️ Alert: Build Failure"
  echo ""
  echo "Build exited with code $EXIT_CODE. Fix compilation errors before continuing."
fi

# ── Alert 3: Disk Space Low ──────────────────────────────────────────────────
# Checks disk usage on home partition after any command

if command -v df &>/dev/null; then
  # Get usage percentage for home directory filesystem
  DISK_USAGE=$(df -P "$HOME" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
  [[ "$DISK_USAGE" =~ ^[0-9]+$ ]] || DISK_USAGE=""
  if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 90 ]; then
    DISK_MSG="Disk usage at ${DISK_USAGE}% — clean up before pipelines fail"
    log_alert "disk_low" "$DISK_MSG"
    # Only alert once per hour (check last alert time)
    LAST_DISK_ALERT="$HOME/.claude/logs/.last-disk-alert"
    SHOULD_ALERT=true
    if [ -f "$LAST_DISK_ALERT" ]; then
      LAST_TIME=$(cat "$LAST_DISK_ALERT" 2>/dev/null || echo 0)
      CURRENT_TIME=$(date +%s)
      DIFF=$((CURRENT_TIME - LAST_TIME))
      if [ "$DIFF" -lt 3600 ] 2>/dev/null; then
        SHOULD_ALERT=false
      fi
    fi
    if [ "$SHOULD_ALERT" = true ]; then
      send_alert "warning" "$DISK_MSG"
      date +%s > "$LAST_DISK_ALERT" 2>/dev/null || true
    fi
  fi
fi

# ── Alert 4: Long-Running Command Timeout ────────────────────────────────────
# If ghost-config.json exists and status is "running", check elapsed time

GHOST_CONFIG="$HOME/.claude/ghost-config.json"
if [ -f "$GHOST_CONFIG" ]; then
  STATUS=$(jq -r '.status // ""' "$GHOST_CONFIG" 2>/dev/null || echo "")
  if [[ "$STATUS" == running* ]]; then
    STARTED=$(jq -r '.started // ""' "$GHOST_CONFIG" 2>/dev/null || echo "")
    MAX_HOURS=$(jq -r '.max_hours // 4' "$GHOST_CONFIG" 2>/dev/null || echo 4)
    if [ -n "$STARTED" ]; then
      # Convert ISO timestamp to epoch (macOS and Linux compatible)
      if command -v gdate &>/dev/null; then
        START_EPOCH=$(gdate -d "$STARTED" +%s 2>/dev/null || echo 0)
      else
        START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED" +%s 2>/dev/null || date -d "$STARTED" +%s 2>/dev/null || echo 0)
      fi
      CURRENT_EPOCH=$(date +%s)
      ELAPSED_HOURS=$(( (CURRENT_EPOCH - START_EPOCH) / 3600 ))
      if [ "$ELAPSED_HOURS" -ge "$MAX_HOURS" ] 2>/dev/null; then
        TIMEOUT_MSG="Ghost Mode running for ${ELAPSED_HOURS}h (limit: ${MAX_HOURS}h) — may be stuck"
        log_alert "timeout_warning" "$TIMEOUT_MSG"
        # Only alert once per run (check if we already alerted for this start time)
        LAST_TIMEOUT="$HOME/.claude/logs/.last-timeout-alert"
        if [ ! -f "$LAST_TIMEOUT" ] || [ "$(cat "$LAST_TIMEOUT" 2>/dev/null)" != "$STARTED" ]; then
          send_alert "warning" "$TIMEOUT_MSG"
          echo "$STARTED" > "$LAST_TIMEOUT" 2>/dev/null || true
        fi
      fi
    fi
  fi
fi

exit 0
