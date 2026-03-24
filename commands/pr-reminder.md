---
name: pr-reminder
description: "Open PRs needing review — nudge stale PRs and track review status"
---

Check open PRs and send reminders: $ARGUMENTS

## What This Does

Scans all open PRs across repos, identifies those needing attention (stale, review requested, changes requested), and optionally sends reminder notifications via Telegram. Designed to run as a periodic cron job.

## Process

### Step 1: Fetch Open PRs

```bash
# Fetch PRs authored by user
gh pr list --state open --author @me \
  --json number,title,url,createdAt,updatedAt,reviewDecision,reviewRequests,isDraft,headRefName,additions,deletions \
  2>/dev/null

# Fetch PRs where review is requested from user
gh pr list --state open --search "review-requested:@me" \
  --json number,title,url,createdAt,updatedAt,reviewDecision,headRefName,author \
  2>/dev/null
```

### Step 2: Classify PRs

Classify each PR into categories:

**Needs Your Review** (others requesting your review):
```
## Needs Your Review

| # | Title | Author | Age | Size |
|---|-------|--------|-----|------|
| #52 | feat: payment webhooks | @teammate | 1d | +142/-23 |
| #49 | fix: auth token refresh | @teammate | 3d | +28/-5 |

⚠️ #49 has been waiting 3 days for your review
```

**Your PRs — Action Needed:**
```
## Your PRs — Action Needed

| # | Title | Status | Age | Action |
|---|-------|--------|-----|--------|
| #48 | feat: OAuth2 flow | Changes requested | 2d | Address review feedback |
| #45 | fix: sync bug | Approved | 5d | Ready to merge! |
```

**Your PRs — Waiting:**
```
## Your PRs — Waiting

| # | Title | Status | Age | Reviewers |
|---|-------|--------|-----|-----------|
| #50 | feat: notifications | Review pending | 1d | @reviewer1 |
```

**Draft PRs:**
```
## Drafts

| # | Title | Age | Branch |
|---|-------|-----|--------|
| #51 | wip: dashboard redesign | 4d | feat/dashboard-v2 |
```

### Step 3: Staleness Detection

Flag PRs based on age thresholds:

| Age | Status | Action |
|-----|--------|--------|
| < 1 day | Fresh | No action |
| 1–3 days | Normal | Standard reminder |
| 3–7 days | Stale | Prominent warning |
| > 7 days | Critical | Strong nudge — consider closing or splitting |

```
## Stale PR Alert

🔴 **Critical (>7 days):**
- #42 feat: user profiles — open 12 days, no reviews

🟡 **Stale (3–7 days):**
- #45 fix: sync bug — approved 5 days ago, not merged
- #49 fix: auth token — waiting for your review 3 days
```

### Step 4: PR Health Metrics

```
## PR Health

| Metric | Value | Target |
|--------|-------|--------|
| Open PRs (yours) | 4 | < 5 |
| Open PRs (review requested) | 2 | < 3 |
| Avg age (your PRs) | 3.2 days | < 2 days |
| Oldest PR | 12 days (#42) | < 7 days |
| PRs ready to merge | 1 (#45) | 0 (merge promptly) |
| Draft PRs | 1 | — |

**Overall:** 🟡 Watch — oldest PR exceeds 7-day threshold
```

### Step 5: Actionable Summary

```
## Actions

1. **Merge PR #45** — approved 5 days ago, just merge it
2. **Review PR #49** — @teammate waiting 3 days for your review
3. **Address feedback on #48** — changes requested 2 days ago
4. **Close or update #42** — 12 days stale, likely needs rebase
```

### Step 6: Assemble Report

```
# PR Reminder — {date}

{sections from above}

---
Generated at {timestamp} by /pr-reminder
```

## Telegram Delivery

When sent via Telegram:
- Lead with the action items (most important)
- Use emoji indicators: 🔴 critical, 🟡 stale, 🟢 fresh
- Include direct PR URLs for one-tap access
- Keep to a single message if possible (under 4096 chars)

Example Telegram message:
```
📋 PR Reminder — Mar 24

🔴 Merge #45 (approved 5d ago)
🟡 Review #49 for @teammate (3d)
🟡 Address #48 feedback (2d)
🔴 Close/update #42 (12d stale)

4 open PRs | Avg age: 3.2d
```

## Cron Setup

Recommended: twice daily (morning + afternoon)
```
/telegram-cron add "0 9 * * 1-5: /pr-reminder"
/telegram-cron add "0 14 * * 1-5: /pr-reminder"
```

## Arguments

- No arguments: check current repo
- `--all-repos`: check all repos the user has open PRs on
- `--notify`: send Telegram notification even if no stale PRs (confirmation)
- `--threshold <days>`: override stale threshold (default: 3)

## Rules

- ALWAYS lead with actions — what should the user DO, not just data
- ALWAYS include PR URLs — one-tap access from Telegram
- ALWAYS flag "ready to merge" PRs prominently — approved PRs sitting unmerged waste reviewer time
- NEVER nag about draft PRs — they're explicitly work-in-progress
- NEVER send empty reminders unless `--notify` flag is set — respect notification hygiene
- Keep Telegram messages under 4096 chars — split if needed
- If no open PRs: "All clear — no open PRs. Nice work!"
- Sort actions by urgency: merge-ready > review-requested > changes-requested > stale
