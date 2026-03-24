---
name: weekly-health
description: "Weekly health check — all projects status, metrics, and trends"
---

Generate a weekly health report: $ARGUMENTS

## What This Does

Produces a comprehensive weekly health report across all active projects. Covers task velocity, PR throughput, pipeline reliability, learning trends, and project-level status. Designed for Sunday evening or Monday morning review.

## Process

### Step 1: Discover Active Projects

Find all projects with recent activity:

```bash
# Find git repos with commits in the last 7 days
for dir in ~/projects/* ~/claude_super_setup; do
  if [ -d "$dir/.git" ]; then
    count=$(git -C "$dir" log --oneline --since="7 days ago" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      echo "$dir|$count"
    fi
  fi
done
```

Also check `~/.claude/logs/` for pipeline activity mentioning project directories.

### Step 2: Per-Project Status

For each active project:

```
## Project: {project name}

**Branch:** {current branch}
**Sprint:** {extract from tasks.json feature field if available}

### Task Progress
| Status | Count |
|--------|-------|
| Completed | 6 |
| In Progress | 1 |
| Pending | 3 |
| Blocked | 1 |

Progress: 6/11 (55%) — {on track / behind / ahead}

### This Week's Commits
{count} commits by {authors}
Key changes:
- feat: OAuth2 integration (3 commits)
- fix: sync race condition (2 commits)
- test: auth service coverage (1 commit)

### PRs This Week
| # | Title | Status | Review |
|---|-------|--------|--------|
| #48 | feat: OAuth2 | Open | Pending review |
| #47 | feat: auth v2 | Merged | Approved |

### Pipeline Runs
| Date | Type | Result | Duration |
|------|------|--------|----------|
| Mon | Auto-ship | ✓ Pass | 26m |
| Wed | Ghost Mode | ✗ Blocked | 12m |
| Fri | Auto-ship | ✓ Pass | 31m |

Reliability: 2/3 (67%)
```

### Step 3: Aggregate Metrics

```
## Weekly Metrics (All Projects)

| Metric | This Week | Last Week | Trend |
|--------|-----------|-----------|-------|
| Commits | 18 | 12 | ↑ +50% |
| Tasks completed | 8 | 5 | ↑ +60% |
| PRs created | 4 | 3 | ↑ +33% |
| PRs merged | 3 | 2 | ↑ +50% |
| Pipeline runs | 6 | 4 | ↑ +50% |
| Pipeline success rate | 83% | 75% | ↑ +8pp |
| Avg pipeline duration | 28m | 35m | ↓ -20% (better) |
| Learnings recorded | 5 | 3 | ↑ +67% |
| Ghost Mode runs | 2 | 1 | ↑ |

**Velocity trend:** {increasing / stable / declining}
```

For "Last Week" data: check git log `--since="14 days ago" --until="7 days ago"`.

### Step 4: Health Indicators

```
## Health Indicators

| Indicator | Status | Details |
|-----------|--------|---------|
| Task velocity | 🟢 Good | 8 tasks/week (target: 5) |
| PR cycle time | 🟡 Watch | Avg 2.1 days (target: 1 day) |
| Pipeline reliability | 🟢 Good | 83% success (target: 80%) |
| Blocked tasks | 🔴 Action | 2 tasks blocked > 3 days |
| Stale PRs | 🟡 Watch | 1 PR open > 5 days |
| Test coverage | 🟢 Good | 84% (target: 80%) |
| Learning capture | 🟢 Good | 5 new learnings |
```

Health thresholds:
- 🟢 Good: meeting or exceeding target
- 🟡 Watch: within 20% of target
- 🔴 Action: below target, needs intervention

### Step 5: Blockers & Risks

```
## Blockers & Risks

### Active Blockers
1. **Task 7 (Project A):** Redis not configured — blocked 4 days
   → Action: Add Redis to docker-compose this week

### Emerging Risks
- PR #45 has been in review for 5 days — may go stale
- Sprint 4 has 3 tasks remaining with 2 days left
- Ghost Mode blocked twice this week — may need trust level adjustment
```

### Step 6: Recommendations

```
## Recommendations

1. **Unblock Redis dependency** — 2 tasks in Project A are waiting on this
2. **Review PR #45** — it's been open 5 days, review or close
3. **Increase pipeline parallelism** — 83% success rate allows safe parallel builds
4. **Run /consolidate** — 5 unreviewed learnings from this week
```

### Step 7: Assemble Report

```
# Weekly Health Report — Week of {start_date}

{all sections from above}

---
Generated at {timestamp} by /weekly-health
```

## Telegram Delivery

When sent via Telegram:
- Send as 3 messages: (1) Per-project summaries, (2) Metrics + Health, (3) Blockers + Recommendations
- Use emoji status indicators (they render well on mobile)
- Link to PRs with full URLs

## Cron Setup

Recommended cron: Sunday 8:00 PM or Monday 7:00 AM
```
/telegram-cron create "weekly-health" "0 20 * * 0" "/weekly-health"
```

## Rules

- ALWAYS show trends (this week vs last week) — flat numbers are less useful
- ALWAYS include health indicators with actionable thresholds
- ALWAYS end with recommendations — don't just report, advise
- NEVER include projects with zero activity — they clutter the report
- Keep per-project sections concise — 10 lines max each
- If $ARGUMENTS specifies a project, show only that project (but still include aggregate metrics)
- If no "last week" data exists (first run), show "—" for comparison and note "First weekly report"
- Pipeline reliability below 60% should trigger a prominent warning
