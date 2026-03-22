---
name: metrics
description: Log and display agentic development metrics
---
Log metrics for the current session or display metrics summary.

## Usage
- /metrics log -- Log current session metrics to ~/.claude/metrics.jsonl
- /metrics summary -- Display summary of recent metrics
- /metrics summary 7d -- Display summary for last 7 days

## JSONL Schema (~/.claude/metrics.jsonl)

Each entry follows this schema (append-only):
```json
{
  "timestamp": "2026-03-04T14:30:00Z",
  "job_id": "J-2026-000123",
  "event": "job_complete",
  "project": "project-name",
  "feature": "feature-name",
  "phases": {
    "spec_minutes": 15,
    "plan_minutes": 10,
    "implement_minutes": 45,
    "verify_minutes": 12,
    "review_minutes": 8
  },
  "agents_used": 3,
  "worktrees_used": 2,
  "rework_count": 1,
  "model_cost_usd": 4.50,
  "ci_minutes": 8,
  "human_minutes": 15,
  "total_minutes": 90,
  "outcome": "merged"
}
```

## Log Action
Collect from the current session:
1. Estimate time spent in each phase from conversation timestamps
2. Count agents invoked (check Agent tool calls)
3. Count worktrees created (check git worktree list)
4. Count rework iterations (code revised after review feedback)
5. Estimate model cost from token usage ($3/MTok input, $15/MTok output for Opus; $0.80/$4 for Sonnet)
6. Estimate human time (time between your outputs and user responses)

Generate a unique job_id: `J-{YYYY}-{6-digit-sequence}`
Set outcome to one of: `merged`, `in_progress`, `abandoned`, `blocked`

Append the JSONL entry to `~/.claude/metrics.jsonl` using:
```bash
echo '{"timestamp":"...","job_id":"...","event":"job_complete",...}' >> ~/.claude/metrics.jsonl
```

## Summary Action
Read `~/.claude/metrics.jsonl` and compute:

### Key Metrics
- **Lead time**: Average total_minutes across completed jobs
- **Cost per feature**: Average model_cost_usd
- **Rework rate**: Average rework_count / total jobs as percentage
- **Human time %**: Average (human_minutes / total_minutes) * 100
- **Agent utilization**: Average agents_used per job

### Phase Breakdown
- Average minutes per phase (spec, plan, implement, verify, review)
- Identify bottleneck phase (highest average)

### Trend Analysis
- Compare last 5 jobs vs previous 5: improving or degrading?
- Flag if any metric deviates >50% from its mean

### Display Format
```
Metrics Summary (last {N} jobs, {date range})
--------------------------------------------
Lead time:      {avg} min (range: {min}-{max})
Cost/feature:   ${avg} (range: ${min}-${max})
Rework rate:    {pct}%
Human time:     {pct}% of total
Agent usage:    {avg} agents/job

Phase Breakdown (avg minutes):
  Spec:       {n} min
  Plan:       {n} min
  Implement:  {n} min  {<-- bottleneck if highest}
  Verify:     {n} min
  Review:     {n} min

Trend: {improving|stable|degrading} over last 10 jobs
```

If `$ARGUMENTS` includes a duration (e.g., `7d`, `30d`), filter entries to that window.
Default: all entries.
