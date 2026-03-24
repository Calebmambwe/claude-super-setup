---
name: telegram-parallel
description: Dispatch multiple tasks to run in parallel screen sessions — max 3 concurrent
---

Run multiple commands simultaneously in separate screen sessions.

## Usage

```
/parallel "/ghost 'dark mode'" "/check" "/auto-build task-3"
```

## Process

### Step 1: Parse Tasks

Extract each quoted command from $ARGUMENTS. Maximum 3 tasks. If more than 3 are provided, reject with an error explaining the limit.

### Step 2: Validate All Commands

For each command, classify using the same safety tiers as `/telegram-dispatch`:
- All must be SAFE (spawn tier). If any are BLOCKED or CONFIRM, reject the entire batch with an explanation.
- Check that no two tasks target the same project branch (would cause git conflicts).

### Step 3: Dispatch All

For each task:
1. Generate a unique session name: `parallel-<N>-<command>-<YYYYMMDD-HHMM>`
2. Add to `~/.claude/telegram-queue.json` with status "running"
3. Spawn via `telegram-dispatch-runner.sh`

### Step 4: Reply

Send a single summary message:
```
🚀 Parallel dispatch: 3 tasks launched

1. ⏳ /ghost "dark mode" → parallel-1-ghost-20260324-1400
2. ⏳ /check → parallel-2-check-20260324-1400
3. ⏳ /auto-build task-3 → parallel-3-auto-build-20260324-1400

Use /queue to track progress.
```

### Step 5: Completion

Each task completes independently. The dispatch runner sends individual Telegram notifications via the Bot API. The next time `/queue` runs (or the next Telegram message arrives), the dispatcher will also check for and report completions.
