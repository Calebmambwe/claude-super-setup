---
name: dashboard
description: Observability dashboard — unified view of pipeline status, telemetry, alerts, and system health
---

Observability Dashboard — aggregates telemetry, alerts, pipeline status, and system health into a single view.

## When to Use

- After a Ghost Mode or autonomous pipeline run to review what happened
- When monitoring system health and resource usage
- When debugging pipeline failures or stuck tasks
- Via Telegram: `/dashboard` or "show me the dashboard"

## Process

### Step 1: Gather Data Sources

Read the following files (skip any that don't exist):

1. **Pipeline status**: `~/.claude/ghost-config.json` — current pipeline state
2. **Task progress**: `tasks.json` in the current project — task completion
3. **Telemetry**: `~/.claude/logs/telemetry.jsonl` — last 100 lines
4. **Alerts**: `~/.claude/logs/alerts.jsonl` — last 50 lines
5. **Model costs**: `~/.claude/logs/model-costs.jsonl` — last 50 lines
6. **Queue**: `~/.claude/telegram-queue.json` — recent dispatched tasks
7. **Metrics**: `metrics.jsonl` in the current project — pipeline metrics

### Step 2: Compute Aggregates

From telemetry data, compute:
- **Tool usage breakdown**: count of each tool type (read/write/exec/agent/mcp) in last 24h
- **Active time**: first-to-last event span in current session
- **Files touched**: unique file paths from write events

From alerts data, compute:
- **Alert count by type**: test_failure, build_failure, disk_low, timeout_warning
- **Unresolved alerts**: alerts in last 2h with no subsequent success

From task data, compute:
- **Task progress**: completed/total, blocked count
- **Estimated remaining**: based on average task duration from metrics

### Step 3: System Health Check

Run quick health checks:
- **Disk usage**: `df -h $HOME` — report percentage
- **Running sessions**: `screen -ls 2>/dev/null` — count active dispatch sessions
- **Ghost status**: from ghost-config.json status field
- **Ollama status**: if model-routing.json has ollama.enabled=true, check `curl -s http://localhost:11434/api/tags`
- **Budget**: from ghost-config.json budget_usd or model-costs.jsonl

### Step 3b: Model Routing Aggregates

From `~/.claude/logs/model-costs.jsonl` (last 24h entries), compute:
- **Per-provider call count and total cost**: group by `provider`, sum `cost_usd`, count rows
- **Top models by call count**: group by `model`, count rows, sort descending, take top 5
- **Fallback event count**: count rows where `fallback_from` is non-empty string

From `~/.claude/logs/comparisons.jsonl` (if it exists), compute:
- **Total comparisons**: total row count
- **Win rate per model**: group by winning model, count wins / total comparisons × 100

### Step 4: Format Dashboard Output

Present as a structured dashboard:

```
╔══════════════════════════════════════════════════════╗
║                 OBSERVABILITY DASHBOARD              ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  📊 Pipeline Status                                  ║
║  ├─ Status: [running/complete/blocked/idle]           ║
║  ├─ Branch: feat/current-branch                      ║
║  ├─ Phase:  build (3/7 tasks)                        ║
║  └─ Uptime: 2h 15m                                   ║
║                                                      ║
║  📋 Task Progress                                    ║
║  ├─ Completed: 5/8 ████████░░░░ 62%                  ║
║  ├─ In Progress: 1                                   ║
║  ├─ Blocked: 0                                       ║
║  └─ Est. Remaining: ~45m                             ║
║                                                      ║
║  🔧 Tool Usage (24h)                                 ║
║  ├─ Read:    142  ████████████                       ║
║  ├─ Write:    38  ████                               ║
║  ├─ Exec:     27  ███                                ║
║  ├─ Agent:    12  █                                  ║
║  └─ MCP:       8  █                                  ║
║                                                      ║
║  🚨 Alerts                                           ║
║  ├─ Test failures:  2 (last: 14m ago)                ║
║  ├─ Build failures: 0                                ║
║  ├─ Disk warnings:  0                                ║
║  └─ Timeout alerts: 0                                ║
║                                                      ║
║  💻 System Health                                    ║
║  ├─ Disk: 67% used (45GB free)                       ║
║  ├─ Sessions: 2 active (screen)                      ║
║  ├─ Ollama: offline                                  ║
║  └─ Budget: $12.50 / $50.00 remaining                ║
║                                                      ║
║  📡 Recent Queue                                     ║
║  ├─ /ghost "dark mode"    ✅ 45m ago                  ║
║  ├─ /check                ⏳ running (12m)            ║
║  └─ /auto-ship            ⏸ pending                  ║
║                                                      ║
║  🤖 Model Routing (24h)                              ║
║  ├─ Providers                                        ║
║  │   ├─ openrouter:  142 calls  $0.0312              ║
║  │   └─ anthropic:    18 calls  $0.2150              ║
║  ├─ Top Models                                       ║
║  │   ├─ qwen/qwen3-coder        87 calls             ║
║  │   ├─ claude-3-5-sonnet       45 calls             ║
║  │   └─ gpt-4o-mini             28 calls             ║
║  ├─ Fallbacks: 3 events                              ║
║  └─ Comparisons: 12 total  (sonnet: 67% win rate)    ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

### Step 5: Telegram Formatting

When called from Telegram (via `/dashboard` command), use a condensed version that fits Telegram's 4096-char limit:

```
📊 Dashboard

Pipeline: ✅ running (build phase, 3/7 tasks)
Branch: feat/ghost-hardening
Uptime: 2h 15m

Tasks: 5/8 done (62%), 0 blocked
Est. remaining: ~45m

Alerts (2h): 2 test failures, 0 build, 0 disk
Budget: $37.50 remaining

Queue: 1 running, 1 pending

Models (24h): openrouter 142/$0.03 · anthropic 18/$0.22
Top: qwen3-coder(87) sonnet(45) gpt-4o-mini(28)
Fallbacks: 3 · Comparisons: 12 (sonnet 67% win)
```

## Rules

1. **Never block on missing data** — if a file doesn't exist, show "N/A" for that section
2. **Respect budget privacy** — only show budget info if ghost-config.json exists
3. **Timestamp everything** — show "as of HH:MM UTC" at the bottom
4. **Keep it scannable** — the dashboard is for quick status checks, not deep analysis
5. **Telegram version is condensed** — strip the box drawing, use emoji prefixes
