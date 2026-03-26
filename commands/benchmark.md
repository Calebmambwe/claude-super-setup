---
name: benchmark
description: Run the benchmark suite to measure agent quality and detect regressions
---

Run the agent benchmark suite: $ARGUMENTS

## Process

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for options:
- `--tier 1|2|3` — Run only tasks of this tier (default: all tiers)
- `--task <task-id>` — Run a specific task only
- `--quick` — Run only Tier 1 tasks (fast smoke test)
- No arguments — run all benchmark tasks

### Step 2: Check Prerequisites

Verify the benchmark framework is set up:
```bash
ls benchmarks/tasks/*.json 2>/dev/null | head -1
```

If no tasks found: "Benchmark tasks not found. Expected at benchmarks/tasks/*.json"

### Step 3: Run Benchmarks

Execute the benchmark runner:

```bash
bash scripts/run-benchmark.sh $FLAGS
```

Where `$FLAGS` are the parsed tier/task flags from Step 1.

### Step 4: Display Results

After the runner completes, read and display the results:

1. Read the latest entry from `benchmarks/history.jsonl` (last line)
2. Display summary table:
   - Total tasks | Passed | Failed | Score %
   - Per-task results with pass/fail
   - Any regressions detected (score drop >5% from average)
3. If regressions detected, highlight them prominently

### Step 5: Recommendations

Based on results:
- If score > 90%: "Agent quality: Excellent"
- If score 70-90%: "Agent quality: Good — review failed tasks"
- If score < 70%: "Agent quality: Needs improvement — review failures and update skills"
- If regressions detected: "REGRESSION DETECTED — investigate before shipping"

## Rules

- Always show individual task results, not just the aggregate score
- Highlight regressions in red/bold
- Log the run to benchmarks/history.jsonl (the runner does this automatically)
- If a task times out, mark as FAIL with "timeout" reason
- Never modify benchmark task definitions during a run
