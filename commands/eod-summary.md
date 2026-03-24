---
name: eod-summary
description: "End-of-day summary — work done, blockers, and tomorrow's plan"
---

Generate an end-of-day summary: $ARGUMENTS

## What This Does

Produces a structured end-of-day summary capturing what was accomplished, what's blocked, and what's planned for tomorrow. Designed to run at session end or via evening cron.

## Process

### Step 1: Work Done Today

Gather today's accomplishments from multiple sources:

**Git commits:**
```bash
git log --oneline --since="today 00:00" --author="$(git config user.email)" 2>/dev/null
```

**Task completions:**
Read `tasks.json` — find tasks where status changed to `completed` today (check git blame on tasks.json).

**PRs created/merged:**
```bash
TODAY=$(date -u +%Y-%m-%d)
gh pr list --state all --author @me --json number,title,state,createdAt,mergedAt 2>/dev/null | \
  jq --arg today "$TODAY" '[.[] | select((.createdAt | startswith($today)) or (.mergedAt // "" | startswith($today)))]'
```

**Pipeline runs:**
Read `~/.claude/logs/pipeline-trace.jsonl` for today's entries.

Format:
```
## Done Today

### Commits
- feat: add OAuth2 login flow (a1b2c3d)
- test: add auth service unit tests (d4e5f6g)
- fix: handle null avatar in profile (h7i8j9k)

### Tasks Completed
- [x] Task 3: OAuth2 integration (P0)
- [x] Task 4: Auth service tests (P1)

### PRs
- Created: #48 feat: OAuth2 login flow
- Merged: #47 feat: auth v2

### Pipelines
- Auto-ship: feat/oauth2 — 6/6 tasks, PR #48 created
```

### Step 2: Blockers

Identify current blockers from:

1. **Blocked tasks** in tasks.json (status: "blocked")
2. **Failed pipelines** in ghost-config.json or pipeline traces
3. **PRs with requested changes** from GitHub

Format:
```
## Blocked

| Item | Blocker | Action Needed |
|------|---------|---------------|
| Task 7: Rate limiting | Redis not configured in test env | Set up Redis in docker-compose |
| PR #45 | Changes requested by reviewer | Address feedback on error handling |
| Ghost run | Gate 2 blocked: too many high-risk tasks | Split into smaller sprints |
```

If nothing blocked: "No blockers — clear runway for tomorrow."

### Step 3: Tomorrow's Plan

Based on remaining tasks, open PRs, and calendar:

```
## Tomorrow

**Priority tasks:**
1. [P0] Task 5: Payment integration — critical path
2. [P1] Task 6: Email notifications — depends on Task 5
3. [P1] Address PR #45 feedback

**Calendar:**
- 10:00 Sprint Review
- 14:00 1:1 with lead

**Suggested approach:**
- Morning: knock out PR feedback (30 min), then Task 5
- Afternoon: Sprint Review prep, Task 6 if time
```

### Step 4: Metrics Snapshot

```
## Metrics

| Metric | Value |
|--------|-------|
| Commits today | 3 |
| Tasks completed | 2/8 (25%) |
| PRs created | 1 |
| PRs merged | 1 |
| Pipeline runs | 1 (success) |
| Learnings recorded | 2 |
```

### Step 5: Assemble Summary

```
# EOD Summary — {date}, {day of week}

{all sections from above}

---
Generated at {timestamp} by /eod-summary
```

## Telegram Delivery

When triggered via cron:
- Send to Telegram with mobile-friendly formatting
- If summary exceeds 4096 chars, split into: Done + Blocked (msg 1), Tomorrow + Metrics (msg 2)

## Cron Setup

Recommended cron: daily at 6:00 PM local time
```
/telegram-cron create "eod-summary" "0 18 * * 1-5" "/eod-summary"
```

(Weekdays only — skip weekends unless $ARGUMENTS includes `--include-weekends`)

## Rules

- ALWAYS pull from git log — it's the single source of truth for work done
- ALWAYS check for blocked tasks — surfacing blockers early is the #1 value
- NEVER fabricate accomplishments — if no commits today, say so honestly
- Keep the tomorrow section actionable — specific tasks, not vague goals
- If $ARGUMENTS contains a project path, scope to that project
- If running from Telegram, use bullet lists instead of tables for readability
- Include metrics — they help track velocity over time
