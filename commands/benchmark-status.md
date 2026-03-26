---
name: benchmark-status
description: Show benchmark score history, trends, and regression alerts
---

Show benchmark status and trends: $ARGUMENTS

## Process

### Step 1: Load History

Read `benchmarks/history.jsonl` — each line is a JSON object with:
```json
{
  "timestamp": "ISO-8601",
  "tier": "all",
  "total": 10,
  "passed": 8,
  "failed": 2,
  "score": 80.0,
  "tasks": [...]
}
```

If file is empty or missing: "No benchmark history yet. Run /benchmark first."

### Step 2: Display Current Score

Show the latest run:
```
Benchmark Status
================
Last run: {timestamp}
Score: {score}% ({passed}/{total} passed)
Tier: {tier}
```

### Step 3: Show Trend

If 3+ runs exist, show the trend:
```
Score Trend (last 5 runs):
  Run 1: 70% ▁
  Run 2: 75% ▃
  Run 3: 80% ▅
  Run 4: 85% ▇
  Run 5: 80% ▅ ← regression
```

Calculate: improving / stable / declining based on linear trend.

### Step 4: Regression Alerts

Check for regressions:
- Compare latest score to rolling 3-run average
- If drop > 5%: "REGRESSION ALERT: Score dropped from {avg}% to {latest}%"
- List specific tasks that regressed (passed before, failed now)

### Step 5: Failed Task Details

For each failed task in the latest run, show:
- Task ID, category, description
- What was expected vs what was missing

## Rules

- Show at most 10 historical runs
- Always show the trend direction (improving/stable/declining)
- Highlight regressions prominently
- If no history, suggest running /benchmark
