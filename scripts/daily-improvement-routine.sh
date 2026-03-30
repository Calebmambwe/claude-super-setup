#!/usr/bin/env bash
set -euo pipefail

# Daily Improvement Routine — Comprehensive self-improvement pipeline
# Runs different phases at different times throughout the day.
# Each phase spawns a Claude session via the dispatch runner.
#
# Phases:
#   1. docs-scan     — Read Claude Code docs, extract new features
#   2. trend-research — Research latest AI/dev trends and tools
#   3. brainstorm    — Generate improvement ideas based on findings
#   4. auto-dev      — Implement the best improvement idea
#   5. benchmark     — Run benchmarks to measure impact
#   6. qwen-eval     — Evaluate Qwen3 Coder for SDLC integration
#
# Usage: daily-improvement-routine.sh <phase> [project_dir] [chat_id]

PHASE="${1:?Usage: daily-improvement-routine.sh <phase> [project_dir] [chat_id]}"
PROJECT_DIR="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
DEFAULT_CHAT_ID=$(grep -m1 '^TELEGRAM_CHAT_ID=' "$HOME/.claude/.env.local" 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]' || echo "")
[ -z "$DEFAULT_CHAT_ID" ] && DEFAULT_CHAT_ID=$(jq -r '.allowFrom[0] // ""' "$HOME/.claude/channels/telegram/access.json" 2>/dev/null || echo "")
CHAT_ID="${3:-$DEFAULT_CHAT_ID}"

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

REPORT_FILE="$LOG_DIR/daily-improvement-$(date +%Y-%m-%d)-${PHASE}.md"

# --- Telegram notification helper ---
notify() {
  local MSG="$1"
  local TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"
  local TOKEN=""

  if [ -f "$TELEGRAM_ENV" ]; then
    TOKEN=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//; s/[[:space:]]*#.*//; s/[[:space:]]*$//' || echo "")
  fi

  [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ] && return 0

  curl -s -o /dev/null -X POST \
    "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${MSG}" \
    --data-urlencode "parse_mode=Markdown" \
    --data-urlencode "disable_web_page_preview=true" \
    2>/dev/null || true
}

# --- Find claude binary ---
CLAUDE_BIN=""
if command -v claude &>/dev/null; then
  CLAUDE_BIN="claude"
elif [ -d "$HOME/.nvm/versions/node" ]; then
  # Find latest installed node version dynamically (no hardcoded version)
  LATEST_NODE=$(ls -1 "$HOME/.nvm/versions/node/" 2>/dev/null | sort -V | tail -1)
  if [ -n "$LATEST_NODE" ] && [ -f "$HOME/.nvm/versions/node/$LATEST_NODE/bin/claude" ]; then
    export PATH="$HOME/.nvm/versions/node/$LATEST_NODE/bin:$PATH"
    CLAUDE_BIN="claude"
  fi
fi

if [ -z "$CLAUDE_BIN" ]; then
  notify "Daily improvement ($PHASE): Claude binary not found"
  exit 1
fi

cd "$PROJECT_DIR"

case "$PHASE" in

  docs-scan)
    notify "Starting daily docs scan..."
    $CLAUDE_BIN -p --permission-mode auto \
      "You are running as an automated daily improvement agent. Do the following:

1. Fetch and read the Claude Code documentation at https://docs.anthropic.com/en/docs/claude-code/overview
2. Also check https://docs.anthropic.com/en/docs/claude-code/cli-usage and https://docs.anthropic.com/en/docs/claude-code/best-practices
3. Compare what you find against our current CLAUDE.md and skills setup
4. Identify NEW features, flags, or best practices we're not using yet
5. Write a concise report to $REPORT_FILE with:
   - New features discovered
   - Features we should adopt
   - Recommended changes to our setup
   - Priority ranking (high/medium/low)

Be thorough but concise. Focus on actionable improvements only." \
      > "$LOG_DIR/daily-docs-scan.log" 2>&1 || true

    # Send report summary via Telegram
    if [ -f "$REPORT_FILE" ]; then
      SUMMARY=$(head -50 "$REPORT_FILE" | head -c 3000)
      notify "📚 *Daily Docs Scan Complete*

$SUMMARY"
    else
      notify "📚 Docs scan finished but no report generated. Check logs."
    fi
    ;;

  trend-research)
    notify "Starting trend research..."
    $CLAUDE_BIN -p --permission-mode auto \
      "You are running as an automated daily improvement agent. Do the following:

1. Search the web for the latest trends in:
   - AI-assisted development tools and workflows
   - Claude Code updates, tips, community discoveries
   - New MCP servers and integrations
   - Agentic coding patterns and multi-agent workflows
   - Popular new dev tools (last 7 days)
2. Search for 'Qwen3 Coder' — latest benchmarks, use cases, how teams integrate it alongside Claude
3. Search for new shadcn/ui components, Tailwind updates, Next.js updates
4. Write a report to $REPORT_FILE with:
   - Top 5 trends worth investigating
   - Any new tools/MCP servers we should install
   - Qwen3 Coder latest findings and SDLC fit
   - Actionable recommendations for our setup

Focus on things directly applicable to our claude-super-setup system." \
      > "$LOG_DIR/daily-trend-research.log" 2>&1 || true

    if [ -f "$REPORT_FILE" ]; then
      SUMMARY=$(head -60 "$REPORT_FILE" | head -c 3000)
      notify "🔬 *Daily Trend Research Complete*

$SUMMARY"
    else
      notify "🔬 Trend research finished but no report generated. Check logs."
    fi
    ;;

  brainstorm)
    notify "Starting improvement brainstorm..."

    # Gather recent reports for context
    DOCS_REPORT="$LOG_DIR/daily-improvement-$(date +%Y-%m-%d)-docs-scan.md"
    TREND_REPORT="$LOG_DIR/daily-improvement-$(date +%Y-%m-%d)-trend-research.md"
    CONTEXT=""
    [ -f "$DOCS_REPORT" ] && CONTEXT="$CONTEXT\n\n--- DOCS SCAN ---\n$(cat "$DOCS_REPORT")"
    [ -f "$TREND_REPORT" ] && CONTEXT="$CONTEXT\n\n--- TREND RESEARCH ---\n$(cat "$TREND_REPORT")"

    $CLAUDE_BIN -p --permission-mode auto \
      "You are running as an automated daily improvement agent.

Context from today's research:
$CONTEXT

Based on the research above, run /brainstorm to generate a structured improvement brief for the claude-super-setup system. Focus on:

1. The single highest-impact improvement we can make today
2. It should be achievable in one auto-dev session (not a multi-day project)
3. Prefer improvements to: skills, hooks, templates, automation, or agent quality
4. Write the brief to docs/brainstorm/daily-improvement-$(date +%Y-%m-%d).md
5. Include clear acceptance criteria

If no research reports exist, brainstorm based on your knowledge of the system and recent git history." \
      > "$LOG_DIR/daily-brainstorm.log" 2>&1 || true

    BRIEF="docs/brainstorm/daily-improvement-$(date +%Y-%m-%d).md"
    if [ -f "$BRIEF" ]; then
      SUMMARY=$(head -40 "$BRIEF" | head -c 3000)
      notify "💡 *Daily Brainstorm Complete*

$SUMMARY"
    else
      notify "💡 Brainstorm session finished. Check logs for details."
    fi
    ;;

  auto-improve)
    notify "Starting auto-dev improvement cycle..."

    BRIEF="docs/brainstorm/daily-improvement-$(date +%Y-%m-%d).md"
    if [ ! -f "$BRIEF" ]; then
      notify "⚠️ No brainstorm brief found for today. Skipping auto-dev."
      exit 0
    fi

    $CLAUDE_BIN -p --permission-mode auto \
      "You are running as an automated daily improvement agent.

Read the improvement brief at $BRIEF and implement it using /auto-dev.

Rules:
- Create a feature branch: improvement/daily-$(date +%Y-%m-%d)
- Follow all existing patterns in CLAUDE.md
- Run tests and quality checks
- Create a PR with the changes
- If the improvement is too large, implement just the core piece

After implementation, write results to $REPORT_FILE" \
      > "$LOG_DIR/daily-auto-improve.log" 2>&1 || true

    if [ -f "$REPORT_FILE" ]; then
      SUMMARY=$(head -40 "$REPORT_FILE" | head -c 3000)
      notify "🚀 *Daily Auto-Improvement Complete*

$SUMMARY"
    else
      notify "🚀 Auto-improvement finished. Check logs and PRs."
    fi
    ;;

  benchmark-report)
    notify "Starting benchmark run..."
    $CLAUDE_BIN -p --permission-mode auto \
      "You are running as an automated daily improvement agent.

1. Run /benchmark to measure current agent quality
2. Run /benchmark-status to check trends
3. Compare today's scores with the previous run
4. Write a report to $REPORT_FILE with:
   - Current scores by category
   - Trend (improving/declining/stable)
   - Any regressions detected
   - Recommendations

Send the report summary." \
      > "$LOG_DIR/daily-benchmark.log" 2>&1 || true

    if [ -f "$REPORT_FILE" ]; then
      SUMMARY=$(head -40 "$REPORT_FILE" | head -c 3000)
      notify "📊 *Daily Benchmark Report*

$SUMMARY"
    else
      notify "📊 Benchmark run finished. Check logs for details."
    fi
    ;;

  qwen-eval)
    notify "Starting Qwen3 Coder SDLC evaluation..."
    $CLAUDE_BIN -p --permission-mode auto \
      "You are running as an automated daily improvement agent.

Research and evaluate Qwen3 Coder (qwen/qwen3-coder) for integration into our SDLC:

1. Search the web for latest Qwen3 Coder benchmarks, capabilities, and API access
2. Identify where it could fit in our pipeline:
   - As a faster/cheaper model for simple subagent tasks (linting, formatting, simple code gen)
   - As a code review second opinion alongside Claude
   - For test generation (parallel to Claude's test-writer-fixer)
   - For documentation generation
   - As a fallback when Claude API is rate-limited
3. Check if there's an OpenAI-compatible API endpoint we can use
4. Evaluate cost/speed/quality tradeoffs vs Claude Sonnet for subagent work
5. Write findings to $REPORT_FILE with:
   - Recommended SDLC integration points
   - API access method (local Ollama, cloud API, etc.)
   - Cost comparison
   - Implementation plan if viable
   - Risk assessment

Be practical — we only integrate if there's a clear advantage." \
      > "$LOG_DIR/daily-qwen-eval.log" 2>&1 || true

    if [ -f "$REPORT_FILE" ]; then
      SUMMARY=$(head -50 "$REPORT_FILE" | head -c 3000)
      notify "🤖 *Qwen3 Coder SDLC Evaluation*

$SUMMARY"
    else
      notify "🤖 Qwen eval finished. Check logs for details."
    fi
    ;;

  *)
    echo "Unknown phase: $PHASE"
    echo "Valid phases: docs-scan, trend-research, brainstorm, auto-improve, benchmark-report, qwen-eval"
    exit 1
    ;;
esac
