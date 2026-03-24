---
name: morning-brief
description: "Daily morning briefing — calendar, tasks, overnight results, and priorities"
---

Generate a morning briefing: $ARGUMENTS

## What This Does

Produces a structured morning briefing that combines calendar events, pending tasks, overnight pipeline results, and suggested priorities for the day. Designed to be the first command you run (or receive via cron) each morning.

## Process

### Step 1: Gather Calendar Events

Check for Google Calendar MCP availability:

1. If `mcp__claude_ai_Google_Calendar__gcal_list_events` is available: fetch today's events and tomorrow's early events
2. If unavailable: skip with note "Calendar integration not configured — add Google Calendar MCP via Claude settings"

Format:
```
## Today's Calendar ({date}, {day of week})

| Time | Event | Location/Link |
|------|-------|---------------|
| 09:00–09:30 | Standup | https://meet.google.com/xyz |
| 14:00–15:00 | Design Review | Conference Room B |

**Tomorrow early:** {any events before 10am tomorrow}
```

### Step 2: Overnight Pipeline Results

Check for Ghost Mode or pipeline results from overnight runs:

1. Read `~/.claude/ghost-config.json` — check if status is `complete`, `blocked_guardrail`, or `running`
2. Read `~/.claude/logs/pipeline-trace.jsonl` — find entries since yesterday 6pm
3. Read `~/.claude/logs/auto-ship.log` — check for completed PRs

Format:
```
## Overnight Results

| Pipeline | Branch | Status | PR | Notes |
|----------|--------|--------|----|-------|
| Ghost Mode | feat/auth-v2 | ✓ Complete | #47 | Ready for review |
| Auto-ship | fix/sync-bug | ✗ Blocked | — | Gate 2 failed: 4 high-risk tasks |

**Action needed:** {list any blocked pipelines requiring manual intervention}
```

If no overnight runs: "No overnight pipelines ran."

### Step 3: Task Status

Read `tasks.json` in the current project (or iterate known project directories):

```
## Active Tasks

**Project:** {project name}
Progress: {completed}/{total} ({percent}%)

**Next up (by priority):**
1. [P0] {task title} — {1-line description}
2. [P1] {task title} — {1-line description}
3. [P1] {task title} — {1-line description}

**Blocked:** {count} tasks need attention
```

If multiple projects have tasks.json, show each.

### Step 4: Open PRs

Check GitHub for open PRs across repos:

```bash
gh pr list --state open --author @me --json number,title,url,createdAt,reviewDecision 2>/dev/null
```

Format:
```
## Open PRs

| # | Title | Age | Review Status |
|---|-------|-----|---------------|
| #47 | feat: add auth v2 | 1d | Approved |
| #45 | fix: sync race condition | 3d | Changes requested |

**Stale PRs (>3 days):** {count}
```

### Step 5: Learning Ledger Summary

Check the learning ledger for recent entries:

```
mcp__learning__get_learning_stats()
mcp__learning__get_project_learnings(project_dir=current_dir, limit=3)
```

Format:
```
## Recent Learnings

- {latest learning 1}
- {latest learning 2}
- {latest learning 3}

Total: {count} learnings | {promoted} promoted
```

### Step 6: Suggested Priorities

Based on all gathered data, suggest the day's priorities:

```
## Suggested Priorities

1. **Review PR #47** — Ghost Mode completed overnight, PR ready
2. **Unblock Task 4** — Redis connection issue blocking rate limiting
3. **Design Review at 2pm** — Review mockups before meeting
4. **Continue Sprint 4** — 3 tasks remaining (P1)
```

Priority logic:
- Blocked pipelines first (they're burning compute)
- PRs with review requests (unblock others)
- Blocked tasks (manual intervention needed)
- Calendar prep (upcoming meetings)
- Next pending tasks by priority

### Step 7: Assemble Briefing

Output the complete briefing with a header:

```
# Morning Brief — {date}, {day of week}

Good morning! Here's your daily briefing.

{all sections from above}

---
Generated at {timestamp} by /morning-brief
```

## Telegram Delivery

When triggered via cron (`/telegram-cron`), the briefing is sent to Telegram:
- Use `mcp__plugin_telegram_telegram__reply` with the user's `chat_id`
- Keep formatting Telegram-compatible (no complex tables — use bullet lists)
- If the briefing exceeds 4096 chars (Telegram limit), split as:
    - Message 1: Overnight Results + Active Tasks + Open PRs (highest-value operational data first)
    - Message 2: Calendar + Recent Learnings + Suggested Priorities
- When inserting log-derived strings (branch names, commit messages, PR titles) into Telegram messages, use plain text mode (no parse_mode) to avoid MarkdownV2 injection

## Cron Setup

Recommended cron: daily at 7:00 AM local time
```
/telegram-cron create "morning-brief" "0 7 * * *" "/morning-brief"
```

## Rules

- NEVER block on missing integrations — skip sections with a note about what to configure
- ALWAYS show overnight results prominently — that's the highest-value section
- ALWAYS suggest priorities — don't just dump data, synthesize it
- Keep the briefing scannable — use tables and bullet points, not paragraphs
- If running via Telegram, format for mobile readability (short lines, no wide tables)
- If $ARGUMENTS contains a project path, validate it is an absolute path under ~/projects/ or the working directory before use. Reject paths containing ".." or resolving outside the allowed prefix
- Calendar section is optional — works without Google Calendar MCP
