---
name: auto-build-all
description: Run the orchestrated pipeline for ALL pending tasks using Ralph Loop
---

You are running the full orchestrated pipeline for all pending tasks in `tasks.json`. This is the "build the entire app while I sleep" mode.

## Process

### Step 1: Load and Validate

1. Read `tasks.json` — if missing, say: "No tasks.json found. Run /init-tasks first."
2. Read `AGENTS.md` if it exists
3. Count pending, completed, and blocked tasks
4. Verify dependency ordering is valid (no circular dependencies)
5. Build a **dependency graph** from `depends_on` fields

### Step 2: Plan Execution Strategy

Analyze the dependency graph and task metadata to determine execution strategy:

**Build dependency levels:**
- Level 0: tasks with no dependencies (or all dependencies completed)
- Level 1: tasks that depend only on Level 0 tasks
- Level N: tasks that depend on Level N-1 tasks

**Within each level, group by parallelizability:**
- Tasks with **no overlapping files** AND **risk: low/medium** → parallel candidates
- Tasks with **overlapping files** OR **risk: high** → sequential (must run one at a time)
- Maximum **3 parallel agents** at once (prevents resource contention)

**Priority ordering within groups:**
- P0 tasks execute before P1, P1 before P2
- Within same priority: tasks with more dependents go first (unblocks more work)

Report the execution plan:
```
## Execution Plan

Dependency levels: {count}
Parallel groups: {count}
Estimated parallelism: {max concurrent tasks}

Level 0 (no dependencies):
  Parallel group A: Task 1, Task 2, Task 3 (no file overlap)
  Sequential: Task 4 (high risk)
Level 1 (depends on L0):
  Parallel group B: Task 5, Task 6
  Sequential: Task 7 (overlaps with Task 5 files)
Level 2 (depends on L1):
  Sequential: Task 8 (integration verification)
```

### Step 3: Execute Tasks

For each dependency level, process all tasks before moving to the next level.

**Parallel execution** (tasks in the same parallel group):
- Use the Agent tool to spawn up to 3 concurrent `/auto-build` agents
- **MANDATORY: pass `isolation: "worktree"` to every parallel Agent call** — this gives each agent a fresh context window (~40% usage) and prevents file conflicts
- Example Agent call for parallel tasks:
  ```
  Agent(prompt: "/auto-build {task-id}", isolation: "worktree", run_in_background: true)
  ```
- Wait for all parallel agents to complete before proceeding
- Merge results: if any agent failed, report but continue with successful ones
- After merge, run `git diff --stat` to verify no conflicts were introduced

**Sequential execution** (high-risk tasks or file overlap):
- Run `/auto-build` directly (no agent, no worktree)
- Wait for completion before next task

**After each task/group completes:**
1. Report progress:
   ```
   Progress: {completed}/{total} tasks done, {blocked} blocked
   Just completed: Task {id} — {title} [{duration}]
   Next up: {next task or group description}
   ```
2. Log to pipeline trace: `~/.claude/logs/pipeline-trace.jsonl`
   ```json
   {"pipeline":"auto-build-all","task_id":{id},"status":"completed","duration_ms":{ms},"parallel":true,"timestamp":"..."}
   ```
3. Send macOS notification:
   ```bash
   osascript -e 'display notification "Task {id}/{total} complete: {title}" with title "Auto-Build"' 2>/dev/null
   ```

### Safety Limits

- **Max iterations**: 20 (prevents runaway loops)
- **Consecutive failures**: Stop after 3 consecutive blocked tasks (likely a systemic issue)
- **Context management**: Run `/compact` between dependency levels if context is getting large
- **Parallel limit**: Maximum 3 concurrent agents (configurable via task count)

### Step 4: Final Report

When all tasks are done (or limits reached):

```
## Auto-Build Complete

Project: {project name}
Duration: {total elapsed time}
Strategy: {n} dependency levels, {n} parallel groups

Results:
- Completed: {n} tasks
- Blocked: {n} tasks
- Remaining: {n} tasks
- Parallelized: {n} tasks ran in parallel (saved ~{estimated time saved})

Execution trace:
  Level 0: Task 1 ✓ (3m) | Task 2 ✓ (4m) | Task 3 ✓ (2m)  [parallel, 4m wall]
  Level 0: Task 4 ✓ (5m)  [sequential, high risk]
  Level 1: Task 5 ✓ (6m) | Task 6 ✓ (3m)  [parallel, 6m wall]
  Level 1: Task 7 ✗ blocked  [sequential]
  Level 2: Task 8 ✓ (4m)  [sequential, integration]

{If blocked tasks exist:}
Blocked tasks requiring attention:
- Task {id}: {title} — {blocked_reason}

Files modified across all tasks: {list}

AGENTS.md learnings added: {count}

Next steps:
{If all complete:} Run /check to review all changes before merging.
{If blocked:} Review blocked tasks, unblock them, then run /auto-build-all again.
```

## How to Run

The preferred way to run this is via the Ralph Loop:
```
/ralph-loop "/auto-build"
```

Or run manually by invoking `/auto-build` repeatedly.

## Rules

- ALWAYS preserve AGENTS.md learnings between iterations
- ALWAYS report progress after each task
- ALWAYS log each task completion to pipeline-trace.jsonl
- Stop on 3 consecutive failures — something systemic is wrong
- If context gets large, compact between dependency levels to stay under limits
- NEVER skip the verification step in /auto-build — quality gates matter
- Each task should be a self-contained unit of work
- High-risk tasks ALWAYS run sequentially, never in parallel
- Parallel tasks MUST use worktree isolation to prevent file conflicts
- P0 tasks execute before P1/P2 within the same dependency level
