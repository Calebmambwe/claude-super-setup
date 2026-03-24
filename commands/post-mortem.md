Write an incident post-mortem: $ARGUMENTS

You are the Incident Analyst, executing the **Post-Mortem** workflow (Google SRE template).

## Workflow Overview

**Goal:** Produce a structured, blameless post-mortem following the Google SRE post-mortem template — documents what happened, how it was detected, why, and how to prevent recurrence

**Output:** `docs/post-mortems/{date}-{incident-slug}.md`

**Best for:** Production incidents, outages, data loss, security breaches, significant bugs that reached users

**Template basis:** Google SRE Post-Mortem (Chapter 15, Site Reliability Engineering)

---

## Step 1: Gather Facts

Ask the user (or extract from arguments) the key facts:

1. **What happened?** (user-visible impact)
2. **When was it detected?** (timestamp or approximate)
3. **When was it resolved?** (timestamp or approximate)
4. **How was it detected?** (monitoring, user report, manual discovery)
5. **Who was involved?** (responders)
6. **What was the severity?** (SEV1-critical, SEV2-major, SEV3-minor)
7. **Was there customer communication?** (status page, email, support tickets)
8. **Has this or something similar happened before?** (recurrence check)

If the user provides a PR, commit, or error log, read those for additional context.

## Step 2: Build Timeline

Read git history, PRs, and deployment logs for the incident window:

```bash
# Find commits around the incident time
git log --oneline --since="2 days ago" --until="now" | head -30

# Find the problematic commit/PR if known
git log --all --oneline --grep="<keyword>" | head -10

# Check deployment history if available
git tag --sort=-creatordate | head -10
```

Construct a minute-by-minute (or event-by-event) timeline:

```markdown
### Timeline (all times UTC)

| Time | Event |
|------|-------|
| 14:00 | Deploy v2.3.1 to production |
| 14:05 | Error rate spikes to 15% (normal: 0.1%) |
| 14:12 | PagerDuty alert fires |
| 14:15 | Engineer acknowledges alert |
| 14:22 | Root cause identified: database migration dropped column still in use |
| 14:25 | Rollback initiated |
| 14:30 | Rollback complete, error rate returns to normal |
| 14:45 | All-clear confirmed |
```

## Step 3: Detection Analysis (Google SRE Addition)

**This section is critical — detection speed determines incident severity.**

```markdown
### Detection

**How was it detected?**
{monitoring alert / user report / manual discovery / automated test / third party}

**Time to detect (TTD):** {minutes from incident start to first alert}
**Time to engage (TTE):** {minutes from alert to first responder action}
**Time to mitigate (TTM):** {minutes from first action to incident resolved}
**Time to resolve (TTR):** {total duration from start to full resolution}

**Detection effectiveness:**
| Question | Answer |
|----------|--------|
| Did monitoring catch it? | YES / NO — {which monitor, or why not} |
| Was the alert actionable? | YES / NO — {did it point to the right place?} |
| Was the right person paged? | YES / NO — {escalation path worked?} |
| Could we have detected it sooner? | {What monitoring/test would have caught it earlier?} |

**Detection gap:** {What should have caught this but didn't? What new monitor/alert would prevent a repeat?}
```

## Step 4: Root Cause Analysis

Use the **5 Whys** technique:

```markdown
### 5 Whys

1. **Why did users see errors?**
   → The API returned 500s on the /users endpoint

2. **Why was the API returning 500s?**
   → The query referenced a column that no longer existed

3. **Why was the column missing?**
   → A migration in PR #142 dropped the `legacy_role` column

4. **Why wasn't this caught before deploy?**
   → No integration test covered the /users endpoint with the affected query

5. **Why was there no integration test?**
   → The endpoint was added before the team adopted integration testing; it was never backfilled
```

Identify:
- **Root cause:** The deepest "why" that's actionable
- **Contributing factors:** Other things that made it worse (no monitoring, slow rollback, etc.)
- **Trigger:** The specific event that initiated the incident (deploy, config change, traffic spike, etc.)

## Step 5: Impact Assessment

```markdown
### Impact

| Metric | Value |
|--------|-------|
| **Duration** | 30 minutes |
| **Users affected** | ~2,400 (all active users during window) |
| **Revenue impact** | $0 (no transactions failed) / $X (estimated lost) |
| **Data loss** | None / {description} |
| **SLA impact** | 99.95% → 99.90% for the month |
| **Error budget consumed** | {X}% of monthly error budget |
| **Support tickets filed** | {count} |
```

## Step 6: What Went Well / What Went Wrong

```markdown
### What Went Well
- Alert fired within 5 minutes of the issue starting
- Rollback process worked smoothly
- Team communicated clearly in the incident channel

### What Went Wrong
- No integration test for the affected endpoint
- Migration was not tested against the full query set
- Took 10 minutes to identify root cause (logs were noisy)

### Where We Got Lucky
- {Things that could have made it worse but didn't}
- {e.g., "Low traffic period — if this had hit during peak, 10x more users affected"}
```

## Step 7: Support & Communication Assessment (Google SRE Addition)

```markdown
### Support & Communication

**External communication:**
| Channel | Action Taken | Timing | Effective? |
|---------|-------------|--------|------------|
| Status page | Updated to "Investigating" | +7 min | YES — users saw status before contacting support |
| Email | Not sent | — | N/A — incident resolved quickly |
| Social media | Not posted | — | N/A |
| Support chat | Auto-response set | +10 min | YES — reduced ticket volume |

**Internal communication:**
| Channel | Action Taken | Timing |
|---------|-------------|--------|
| Incident channel | Created #inc-{date}-{slug} | +3 min |
| Stakeholder update | Sent to #engineering | +15 min |
| Executive summary | Sent to leadership | +2 hours |

**Communication gaps:**
- {What should we have communicated that we didn't?}
- {Who should have been informed that wasn't?}
- {Was the status page updated promptly?}
```

## Step 8: Recurrence Assessment (Google SRE Addition)

**This is the most important section for organizational learning.**

```markdown
### Recurrence Assessment

**Has this happened before?**
{YES: link to previous post-mortem / NO}

**If yes:**
- Previous incident: {date} — {title}
- Were the previous action items completed? {YES/NO — list incomplete items}
- Why did the fix not prevent recurrence? {The fix was partial / different root cause / fix was never deployed}

**Recurrence risk:**
| Factor | Assessment |
|--------|-----------|
| Same root cause likely to recur? | LOW / MEDIUM / HIGH — {why} |
| Similar incidents in other services? | {List related services at risk} |
| Systemic issue across the org? | YES / NO — {if yes, what pattern?} |

**Systemic recommendations:**
- {If this is a pattern: "All services using X should audit for Y"}
- {If this is a tooling gap: "CI pipeline should include Z check"}
- {If this is a process gap: "Deploy process should require W"}
```

## Step 9: Action Items

Every post-mortem MUST produce concrete action items with owners, deadlines, and bug tracking:

```markdown
### Action Items

| # | Action | Type | Owner | Priority | Deadline | Bug/Issue |
|---|--------|------|-------|----------|----------|-----------|
| 1 | Add integration tests for /users endpoint | PREVENT | {name} | P1 | This sprint | {PROJ-123} |
| 2 | Add migration safety check: verify no queries reference dropped columns | PREVENT | {name} | P1 | This sprint | {PROJ-124} |
| 3 | Add alert for 5xx spike > 5% on any endpoint | DETECT | {name} | P1 | This sprint | {PROJ-125} |
| 4 | Reduce log noise in production (filter health checks) | DETECT | {name} | P2 | Next sprint | {PROJ-126} |
| 5 | Add database query monitoring (slow query log) | DETECT | {name} | P2 | Next sprint | {PROJ-127} |
| 6 | Document rollback procedure in runbook | PROCESS | {name} | P3 | Next month | {PROJ-128} |
```

**Action item types** (Google SRE classification):
- **PREVENT:** Stop this specific incident from recurring
- **DETECT:** Catch it faster if it does recur
- **MITIGATE:** Reduce the blast radius
- **PROCESS:** Improve the incident response process

**Priority levels:**
- **P1:** Must fix before next deploy (prevents recurrence)
- **P2:** Should fix this quarter (reduces risk)
- **P3:** Nice to have (improves process)

**Bug tracking integration:**
- Every action item MUST be filed as a bug/issue in the project tracker
- If using GitHub Issues: create issues with the `post-mortem` label
- If using Linear/Jira: create tickets in the appropriate project
- Include the post-mortem link in each bug/issue description

## Step 10: Write the Post-Mortem

Save to `docs/post-mortems/{date}-{incident-slug}.md`:

```markdown
# Post-Mortem: {Incident Title}

**Date:** {date}
**Severity:** {SEV1/SEV2/SEV3}
**Duration:** {start} → {end} ({total time})
**Author:** {who wrote this}
**Status:** {Draft | Reviewed | Final}
**Bug tracker:** {link to post-mortem label/filter in issue tracker}

## Summary

{2-3 sentence summary: what happened, impact, resolution}

## Detection

{From Step 3 — TTD, TTE, TTM, TTR metrics and detection gap analysis}

## Timeline

{Table from Step 2}

## Root Cause

{5 Whys from Step 4}

**Root cause:** {one sentence}
**Trigger:** {what initiated the incident}
**Contributing factors:**
- {factor 1}
- {factor 2}

## Impact

{Table from Step 5}

## What Went Well
{List from Step 6}

## What Went Wrong
{List from Step 6}

## Where We Got Lucky
{List from Step 6}

## Support & Communication
{From Step 7}

## Recurrence Assessment
{From Step 8}

## Action Items
{Table from Step 9}

## Lessons Learned

{1-3 key takeaways that apply beyond this specific incident}

## References

- PR: {link to the problematic PR}
- Deploy: {link to deployment}
- Alert: {link to monitoring alert}
- Incident channel: {link to Slack/Discord thread}
- Related post-mortems: {links to previous related incidents}
```

## Step 11: Index

If `docs/post-mortems/README.md` exists, update it. If not, create one:

```markdown
# Incident Post-Mortems

| Date | Severity | Title | Duration | TTD | Action Items | Status |
|------|----------|-------|----------|-----|-------------|--------|
| {date} | SEV2 | {title} | 30min | 5min | 6 items (4 open) | Draft |
```

---

## Rules

- ALWAYS be blameless — focus on systems and processes, never individuals' mistakes
- ALWAYS include Detection metrics (TTD, TTE, TTM, TTR) — these drive improvement
- ALWAYS include action items — a post-mortem without actions is just a story
- ALWAYS classify action items by type: PREVENT, DETECT, MITIGATE, PROCESS
- ALWAYS include a timeline — vague narratives miss critical details
- ALWAYS include Recurrence Assessment — check if this has happened before
- ALWAYS include "Where We Got Lucky" — hidden risks are worse than known ones
- ALWAYS file action items as bugs/issues in the project tracker
- ALWAYS use the 5 Whys to find root cause — don't stop at the surface
- NEVER assign blame to individuals — use phrases like "the migration" not "John's migration"
- NEVER skip impact assessment — quantify the damage even if approximate
- NEVER write action items without owners — unowned items never get done
- NEVER skip the Support & Communication section — communication failures amplify incident impact
- Every action item must have: specific description, type, owner, priority, deadline, and bug tracker link
- If the codebase reveals the problematic code, include the specific file and line
- Post-mortems are living documents — status should be Draft until reviewed by the team
- If a previous post-mortem exists for a similar incident, ALWAYS link to it and assess whether previous action items were completed
