---
name: ghost
description: Fully autonomous overnight pipeline — go to sleep, wake up to a PR
---

Ghost Mode — autonomous overnight pipeline for: $ARGUMENTS

## What This Does

Launches a fully autonomous, self-healing pipeline that survives terminal closes, macOS sleep, API rate limits, and process crashes. No human gates — guardrails replace manual approval.

```
/ghost "feature" --budget 20 --hours 8 --trust conservative --notify-url https://ntfy.sh/my-topic
/ghost "feature" --telegram   # enables Telegram notifications + inbound task channel
```

## Process

### Step 1: Parse Arguments

Extract from $ARGUMENTS:
- **Feature description** (required) — the first quoted or unquoted string
- `--trust` — `conservative` (default), `balanced`, or `aggressive`
- `--budget` — USD limit (default: 20)
- `--hours` — max wall-clock hours (default: 8)
- `--notify-url` — ntfy.sh topic URL for push notifications (optional)
- `--telegram` — enable Telegram notifications and inbound task channel (optional)
- `--telegram-chat-id` — override Telegram chat ID (default: auto-detect from access.json)
- `--max-tasks` — maximum task count (default: 10)

If no feature description is provided, ask the user what to build and stop.

### Step 2: Pre-flight Checks

Run ALL checks. If ANY critical check fails, report and stop.

**Critical (must pass):**
1. `ANTHROPIC_API_KEY` is set — run `echo $ANTHROPIC_API_KEY | head -c 5` to verify (never print full key)
2. `gh auth status` passes — needed for PR creation
3. Disk space >= 2GB — run `df -g . | tail -1 | awk '{print $4}'`
4. No `~/.claude/ghost-stop` file exists — remove stale stop file or abort
5. Not on `main` or `master` branch
6. `screen` is available — `command -v screen`
7. `jq` is available — `command -v jq`
8. `claude` CLI is available — `command -v claude`

**Advisory (warn but continue):**
1. `caffeinate` available (macOS sleep prevention)
2. No existing ghost screen session running

### Step 3: Create Branch

Auto-create and checkout a feature branch:
```bash
BRANCH="feat/ghost-$(date +%Y%m%d-%H%M)"
git checkout -b "$BRANCH"
git push -u origin "$BRANCH"
```

### Step 4: Write Config

Write `~/.claude/ghost-config.json`:
```json
{
  "feature": "{parsed feature description}",
  "trust": "{trust level}",
  "budget_usd": {budget},
  "max_hours": {hours},
  "max_tasks": {max_tasks},
  "notify_url": "{notify_url or empty string}",
  "telegram_enabled": "{true if --telegram flag, false otherwise}",
  "telegram_chat_id": "{chat_id from --telegram-chat-id or auto-detected from access.json}",
  "project_dir": "{current working directory}",
  "branch": "{branch name}",
  "started": "{ISO 8601 timestamp}",
  "session_id": null,
  "pr_url": null,
  "status": "starting"
}
```

### Step 5: Launch Watchdog

Run:
```bash
bash ~/.claude/hooks/ghost-watchdog.sh &
```

This launches a `screen` session that:
- Prevents macOS sleep via `caffeinate`
- Runs Claude in `--dangerously-skip-permissions` mode
- Restarts on crash (up to 5 attempts with exponential backoff)
- Detects rate limits and applies 5-minute backoff
- Checks `ghost-stop` file before each restart
- Sends notifications via ntfy.sh + osascript

### Step 6: Report

Display the pre-flight report:

```
## Ghost Mode Activated

Feature:      {description}
Trust Level:  {conservative|balanced|aggressive}
Budget:       ${budget} USD
Time Limit:   {hours} hours
Branch:       {branch}
Notifications: {ntfy URL or "local only (osascript)"}
Telegram:     {enabled (chat_id: XXX) or "disabled"}

The pipeline is now running autonomously.
You can safely close this terminal and go to sleep.

### Monitor
- Status:  /ghost-status
- Attach:  screen -r ghost-{project}
- Logs:    tail -f ~/.claude/logs/ghost-*.log

### Emergency Stop
  touch ~/.claude/ghost-stop

### How It Works
1. Plans the feature (auto-approved via {trust} guardrails)
2. Decomposes into tasks (auto-approved via {trust} guardrails)
3. Builds all tasks using parallel worktree agents (isolation: "worktree") for independent tasks
4. Runs /regression-gate --tier 3 (exhaustive: all pages, API health, forms, performance, full a11y)
5. Runs visual verification pipeline (if frontend files changed):
   - /visual-verify (console errors, network, layout)
   - /visual-regression (3-viewport screenshot diff)
   - visual-tester agent (interactive UI flows)
6. Runs quality checks (quality-gate team: 6 parallel agents with worktree isolation)
7. Creates PR and self-reviews
8. Sends push notification with PR link

Sweet dreams.
```

## Rules

- NEVER run Ghost Mode on main/master — always create a feature branch
- NEVER skip pre-flight checks — they prevent costly failures mid-pipeline
- ALWAYS write config BEFORE launching watchdog
- ALWAYS show emergency stop instructions
- If the user hasn't configured ntfy.sh, warn that notifications are local-only
- If `--telegram` is set, auto-detect chat_id from `~/.claude/channels/telegram/access.json` (first allowFrom entry) unless `--telegram-chat-id` overrides it
- If `--telegram` is set but no bot token found in `~/.claude/channels/telegram/.env`, warn and fall back to other channels
- When Telegram is enabled, the watchdog launches Claude with `--channels plugin:telegram@claude-plugins-official`, allowing inbound messages from Telegram to reach the running session
- This command is a launcher — it NEVER runs the pipeline itself
