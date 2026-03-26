---
name: self-improve
description: Master improvement loop — benchmark current state, evolve low-performing skills, benchmark again, and report the delta. Can be scheduled via /telegram-cron for continuous autonomous improvement.
---

Run the full self-improvement loop: $ARGUMENTS

## What This Does

Four-step loop that measures, improves, re-measures, and reports:

```
Step 1: /benchmark          → establish baseline (current state)
Step 2: /evolve-skills      → improve low-performing skills
Step 3: /benchmark          → measure after improvement
Step 4: Report delta        → before vs after comparison
```

## Process

### Step 0: Parse Arguments

Parse `$ARGUMENTS` for options:
- `--tier 1` — use only Tier 1 benchmarks (faster; default for scheduled runs)
- `--quick` — Tier 1 benchmarks only + skip skills with no recent failures
- `--full` — all benchmark tiers + all evolution candidates
- `--notify` — send Telegram summary when complete (requires Telegram bot configured)
- `--dry-run` — measure and diagnose but do NOT modify any skill files
- No arguments — defaults to `--tier 1` for responsiveness

### Step 1: Baseline Benchmark

Run the benchmark to capture current state before any changes.

```
Running pre-improvement benchmark...
```

Execute:
```bash
bash scripts/run-benchmark.sh --tier 1
```

(Use `--tier 2` as well if `--full` was passed.)

Read the latest entries from `benchmarks/history.jsonl` and capture:
- `pre_run_id` — the run ID just completed
- `pre_score` — overall score percentage
- `pre_pass_count` — number of tasks that passed
- `pre_fail_count` — number of tasks that failed
- `pre_regression_count` — regressions detected

If the baseline benchmark fails or returns 0 tasks, stop here and report:
> "Pre-improvement benchmark found no tasks. Check benchmarks/tasks/ and ensure Tier 1 tasks exist."

### Step 2: Skill Evolution

Run skill evolution targeting candidates identified from the benchmark results.

```
Running skill evolution...
```

Pass relevant flags through:
- `--dry-run` in `$ARGUMENTS` → pass `--dry-run` to `/evolve-skills`
- `--quick` → pass `--skip-unscored` equivalent (only evolve skills with confirmed failures)

The `/evolve-skills` command handles:
- Scanning all skills for quality metrics
- Identifying candidates (quality < 0.6 or high failure rate)
- Running the skill-curator agent on each candidate
- Promoting, holding, or reverting based on benchmark delta

Capture the evolution summary:
- Skills evolved: N
- Skills promoted: N
- Skills reverted: N
- Skills skipped (no coverage): N

If no candidates were found (all skills healthy), log:
> "All skills above quality threshold. No evolution needed."
And skip to Step 3 to confirm no regressions were introduced.

### Step 3: Post-Improvement Benchmark

Re-run the same benchmark tier to measure the effect of evolution.

```
Running post-improvement benchmark...
```

Execute the same benchmark as Step 1.

Read the latest entries and capture:
- `post_run_id`
- `post_score`
- `post_pass_count`
- `post_fail_count`
- `post_regression_count`

### Step 4: Delta Report

Compute the delta between pre and post:

```
delta_score    = post_score - pre_score
delta_pass     = post_pass_count - pre_pass_count
delta_fail     = post_fail_count - pre_fail_count
```

Display the full improvement report:

```markdown
## Self-Improvement Run Complete

**Timestamp:** <ISO>
**Mode:** <tier 1 / full / dry-run>

### Benchmark Delta

| Metric          | Before | After  | Delta    |
|-----------------|--------|--------|----------|
| Overall Score   | 74%    | 81%    | +7%      |
| Tasks Passed    | 6      | 8      | +2       |
| Tasks Failed    | 4      | 2      | -2       |
| Regressions     | 1      | 0      | -1       |

### Skill Evolution Summary

| Skill               | Action   | Old Score | New Score | Outcome  |
|---------------------|----------|-----------|-----------|----------|
| backend-architecture| refined  | 0.55      | 0.72      | PROMOTED |
| reflect             | augmented| 0.42      | 0.38      | REVERTED |

### Assessment

- **delta_score > 5%**: Significant improvement detected
- **delta_score -5% to +5%**: Marginal change — skills held for next cycle
- **delta_score < -5%**: Regression introduced — INVESTIGATE before next run

### Next Steps

- [ ] Review held skills manually: [list]
- [ ] Increase benchmark coverage for untestable skills
- [ ] Schedule next run: `/telegram-cron "0 3 * * 0" /self-improve --quick`
```

Determine the overall verdict:
- `IMPROVED` — delta_score > 5%
- `STABLE` — delta_score between -5% and +5%
- `REGRESSED` — delta_score < -5% (critical: alert the user)

If verdict is `REGRESSED`, display prominently:
```
WARNING: Overall score dropped by {|delta_score|}% after skill evolution.
Reverted skills may not have been sufficient. Run /benchmark --tier 1 to confirm
and inspect benchmarks/evolution-log.jsonl for failed strategies.
```

### Telegram Notification (if --notify)

If `--notify` was passed, send the condensed report via Telegram:

```
Self-Improve Complete
Score: 74% → 81% (+7%)
Evolved: 2 skills | Promoted: 1 | Reverted: 1
Verdict: IMPROVED
Run /benchmark-status for details.
```

Keep the message under 4096 characters. Truncate the skill table if needed.

## Scheduling with /telegram-cron

To run self-improvement on autopilot:

```
/telegram-cron "0 3 * * 0" /self-improve --quick --notify
```

This runs every Sunday at 3am, uses Tier 1 benchmarks only, and sends a Telegram summary when done.

For daily quick checks:
```
/telegram-cron "0 6 * * *" /self-improve --quick --notify
```

## Rules

- NEVER skip Step 1 (baseline) — delta is meaningless without a pre-measurement
- NEVER run in a dirty git state — changes to skill files should be reviewable
- If `--dry-run` is passed, run benchmarks normally but pass `--dry-run` to `/evolve-skills` — no skill files are modified
- Always write the full delta report even if no skills were evolved (confirms stability)
- If this is a scheduled run and verdict is `REGRESSED`, send an alert regardless of `--notify` flag
- This command is an orchestrator — it calls sub-commands, never reimplements their logic
