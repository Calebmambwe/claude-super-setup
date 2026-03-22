---
name: ghost-status
description: Show Ghost Mode progress dashboard
---

## What This Does

Reads Ghost Mode config, pipeline checkpoint, and logs to display a real-time progress dashboard.

## Process

### Step 1: Check if Ghost Mode is Active

Read `~/.claude/ghost-config.json`. If it doesn't exist, report:
```
Ghost Mode is not active. Start with: /ghost "feature description"
```

### Step 2: Read State Files

Read these files (if they exist):
1. `~/.claude/ghost-config.json` — ghost config (feature, trust, budget, status, started)
2. `.claude/pipeline-checkpoint.json` (in the project dir from config) — current pipeline phase
3. `tasks.json` (in the project dir) — task list and completion status
4. The most recent `~/.claude/logs/ghost-*.log` file — recent log output

### Step 3: Calculate Metrics

- **Elapsed time**: current time minus `started` from config
- **Remaining time**: `max_hours` minus elapsed
- **Budget used**: check if `--max-budget-usd` tracking is in logs
- **Watchdog PID**: read from `~/.claude/ghost-watchdog.pid`
- **Watchdog alive**: check if PID is still running via `kill -0 $PID`
- **Screen session**: check `screen -ls` for ghost session

### Step 4: Display Dashboard

```
## Ghost Mode Dashboard

### Status
Feature:       {feature description}
Status:        {status from config: starting|running|complete|blocked_guardrail|timeout|exhausted}
Trust Level:   {trust}
Branch:        {branch}
Watchdog PID:  {pid} ({alive|dead})
Screen:        {screen session name} ({attached|detached|not found})

### Timing
Started:       {started timestamp}
Elapsed:       {hours}h {minutes}m
Remaining:     {hours}h {minutes}m
Budget:        ${budget} USD

### Pipeline Progress
{If checkpoint exists:}
Current Phase: {phase name from checkpoint}
Phase Details: {any extra checkpoint data}

{If tasks.json exists:}
### Tasks
| # | Title | Status | Priority |
|---|-------|--------|----------|
| 1 | {title} | {pending|in_progress|completed|blocked} | {priority} |
| 2 | ... | ... | ... |

Completed: {n}/{total} ({percent}%)

### Recent Log (last 20 lines)
```
{last 20 lines from ghost log file}
```

### Emergency Controls
- Stop:    touch ~/.claude/ghost-stop
- Attach:  screen -r {screen-name}
- Kill:    kill {watchdog-pid}
- Resume:  /ghost-status (re-check after any intervention)
```

## Rules

- This is a READ-ONLY command — it NEVER modifies state
- If config references a project_dir, read checkpoint and tasks from that directory
- If log file is large, only show last 20 lines
- Always show emergency controls
- If watchdog PID is dead but status isn't terminal, flag it as an anomaly
