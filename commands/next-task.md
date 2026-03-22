---
name: next-task
description: Pick and implement the next pending task from tasks.json
---

You are implementing the next task from `tasks.json`. Follow the Manus-style pipeline: Plan → Execute → Verify.

## Process

### Step 1: Load Context

1. Read `tasks.json` from the project root
2. Read `AGENTS.md` if it exists (learned patterns and gotchas)
3. Find the next task where `status` is `"pending"` and all `depends_on` tasks are `"completed"`
4. If no tasks remain, report completion and stop

### Step 2: Plan (Architect Phase)

Before writing any code:
1. Read ALL files listed in the task's `files` array
2. Read related files (imports, dependencies)
3. Understand the existing code structure
4. Plan the exact changes needed

### Step 3: Execute (Developer Phase)

1. Implement the changes file by file
2. Write tests alongside implementation (not after)
3. The auto-fix hook will catch build/type/lint errors automatically — fix them when reported
4. Follow patterns documented in AGENTS.md

### Step 4: Verify (Reviewer Phase)

1. Run ALL verification commands:
   - For Node: `pnpm test && pnpm lint && pnpm typecheck` (or detected equivalents)
   - For Python: `pytest && ruff check && mypy .`
2. Check each acceptance criterion from the task:
   - Can you demonstrate it works? (test output, build success, etc.)
   - If any criterion is not met, fix it before proceeding
3. If the task has been attempted `max_attempts` times and still fails:
   - Set status to `"blocked"`
   - Add a `"blocked_reason"` field explaining why
   - Move to the next task

### Step 5: Complete

1. Update `tasks.json`:
   - Set task status to `"completed"`
   - Increment `attempts` count
2. Update `AGENTS.md` if you discovered:
   - A new pattern or convention
   - A gotcha or pitfall
   - A useful workaround
3. Report what was done

## Output

```
## Task {id} Complete: {title}

Status: completed (attempt {n}/{max})
Files modified: {list}
Tests: {pass/fail count}

Acceptance criteria:
- [x] {criterion 1}
- [x] {criterion 2}

Learnings added to AGENTS.md: {yes/no}

Remaining: {n} tasks pending, {n} blocked
Next: Run /next-task to continue, or /ralph-loop "/next-task" for autonomous mode.
```

## Rules

- NEVER skip acceptance criteria verification
- ALWAYS read before writing
- ALWAYS run tests before marking complete
- If auto-fix hook reports errors, fix them immediately
- Log patterns to AGENTS.md — future iterations benefit from this
- If blocked, explain WHY clearly so a human can unblock it
