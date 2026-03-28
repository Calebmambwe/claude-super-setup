---
name: auto-develop
description: "Fully autonomous pipeline — raw idea to shipped PR with zero human gates. Chains research → brief → design → plan → build → check → ship → reflect."
---

Fully autonomous development pipeline for: $ARGUMENTS

## What This Does

`/auto-develop` is the "senior engineer brain" — it chains the **complete SDLC** with zero human gates, from a raw idea to a shipped PR. It knows which phases to skip based on existing project state.

```
/auto-develop "build habit tracker with streaks"
  ├── Phase 0: Detect project state (skip completed phases)
  ├── Phase 1: /bmad:research → market + technical research
  ├── Phase 2: /brainstorm → structured feature brief
  ├── Phase 3: /design-doc → full architecture + design doc
  ├── Phase 4: /auto-plan → tasks.json from design doc
  ├── Phase 5: /auto-build-all → Ralph Loop per task
  ├── Phase 6: /check → code review + security + tests
  ├── Phase 7: /ship → conventional commit + PR
  └── Phase 8: /reflect → capture learnings
```

## Arguments

- Feature description (required): what to build
- `--skip-research` — skip market/technical research (Phase 1)
- `--skip-design` — skip design doc generation (Phase 3)
- `--from-brief <path>` — use an existing brief instead of generating one
- `--project-dir <path>` — target project directory (default: cwd)
- `--budget <usd>` — max API spend (default: 50)
- `--telegram` — enable Telegram progress notifications
- `--resume` — resume from last checkpoint

## Process

### Step 0: Resource Audit (Non-Negotiable)

Before anything, complete the Resource Audit from `rules/consistency.md`:
- Check if a matching stack template exists in `~/.claude/config/stacks/`
- Check if relevant skills apply (design-system, backend-architecture, docker)
- Read AGENTS.md if present in the project
- Search the project for existing components/patterns to reuse

Autonomous does not mean reckless. The audit is a PRECONDITION.

### Step 1: Parse Arguments

Extract feature description, flags, and options from $ARGUMENTS.

If $ARGUMENTS is empty, ask the user what to build. Do NOT proceed with an empty feature description.

### Step 2: Detect Project State

Read the project directory to determine which phases to skip:

```
docs/{feature}/research.md exists  → skip Phase 1 (research)
docs/{feature}/brief.md exists     → skip Phase 1 + 2 (research + brief)
docs/{feature}/design-doc.md exists → skip Phase 1 + 2 + 3 (through design)
tasks.json exists with pending tasks → skip through Phase 4, go to build
All tasks in tasks.json complete    → skip through Phase 5, go to check
```

Derive the feature kebab-case name from the description for path lookups.

If `--resume` flag is set, read `~/.claude/auto-develop-checkpoint.json` for the last completed phase and resume from the next one.

### Step 3: Execute Pipeline

For each phase that wasn't skipped:

**Phase 1: Research** (if needed)
```
Run /bmad:research with the feature description
Save output to docs/{feature}/research.md
Notify: "Research complete. Found N insights."
```

**Phase 2: Brainstorm** (if needed)
```
Run /brainstorm with the feature description
Save output to docs/{feature}/brief.md
Notify: "Brief created: {feature name}"
```

**Phase 3: Design Doc** (if needed)
```
Run /design-doc with the feature description
Save output to docs/{feature}/design-doc.md
Notify: "Design doc complete. N milestones planned."
```

**Phase 4: Plan + Tasks**
```
Run /auto-plan with the feature description
This generates tasks.json from the design doc
Notify: "Plan ready. N tasks across M milestones."
```

**Phase 5: Build All Tasks**
```
Run /auto-build-all
Ralph Loop per task: implement → test → fix (max 3 attempts per task)
Notify per task: "Task N/M complete: {title}"
If a task fails 3 times, mark it blocked and continue to next task.
```

**Phase 5.5: Visual Verification Pipeline** (MANDATORY if .tsx/.jsx/.css/.html files changed)
```
Run all 3 visual tools in sequence:
  a. /visual-verify — console errors, network failures, layout checks, basic interactions
  b. /visual-regression — screenshot comparison at mobile/tablet/desktop viewports
  c. visual-tester agent — deep interactive UI verification of completed task flows
If any tool reports CRITICAL issues, fix (max 1 cycle) and re-run that tool only.
Skip this phase entirely if no frontend files were changed.
Notify: "Visual verification complete: {pass/N issues found}"
```

**Phase 6: Quality Gate**
```
Run /check
3-gate review: correctness + security + tests
If FAIL: auto-fix up to 3 times, then pause
If all 3 fix attempts fail, stop the pipeline and notify.
```

**Phase 7: Ship**
```
Run /ship
Conventional commit + push + PR
Notify: "PR created: {url}"
```

**Phase 8: Reflect**
```
Run /reflect
Capture session learnings to ledger
Notify: "Pipeline complete. N learnings recorded."
```

### Step 4: Checkpointing

After each phase completes, save a checkpoint:

```json
{
  "feature": "habit tracker with streaks",
  "project_dir": "/path/to/project",
  "last_completed_phase": 3,
  "phase_results": {
    "1": {"status": "complete", "output": "docs/habit-tracker/research.md"},
    "2": {"status": "complete", "output": "docs/habit-tracker/brief.md"},
    "3": {"status": "complete", "output": "docs/habit-tracker/design-doc.md"}
  },
  "started_at": "2026-03-24T10:00:00Z",
  "updated_at": "2026-03-24T10:45:00Z"
}
```

Write to `~/.claude/auto-develop-checkpoint.json`.

### Step 5: Error Handling

- If any phase fails 3 times: **stop**, notify via Telegram (if --telegram), save checkpoint
- Resume with: `/auto-develop --resume` (reads checkpoint and continues from last completed phase)
- All phase outputs are saved to disk — the pipeline is fully resumable
- If a phase produces no output (e.g., research returns nothing useful), log a warning and continue

### Step 6: Notifications

If `--telegram` flag is set OR if running inside a Telegram session:

1. At pipeline start: "Starting /auto-develop: {feature}"
2. At each phase transition: "Phase N complete: {summary}"
3. At pipeline end: "Pipeline complete! PR: {url}" (new message, not edit — triggers push)
4. On failure: "Pipeline paused at Phase N: {error}. Resume with /auto-develop --resume"

If not in Telegram, use macOS notification:
```bash
osascript -e 'display notification "Phase N complete" with title "auto-develop" sound name "Glass"' 2>/dev/null || true
```

### Final Report

After all phases complete, output a summary:

```
## /auto-develop Complete

Feature: {description}
Phases: {completed}/{total} ({skipped} skipped)
Tasks: {completed}/{total} ({blocked} blocked)
Check: {PASS/FAIL}
PR: {url}

Pipeline trace:
  Research        {duration}  {✓/skipped}
  Brainstorm      {duration}  {✓/skipped}
  Design Doc      {duration}  {✓/skipped}
  Plan + Tasks    {duration}  ✓ ({N} tasks)
  Build All       {duration}  {completed}/{total} tasks
  Visual Verify   {duration}  {✓/skipped} (verify + regression + tester)
  Check           {duration}  {verdict}
  Ship            {duration}  PR #{number}
  Reflect         {duration}  {n} learnings

Total: {total duration}
```

## Rules

- If $ARGUMENTS is empty, ask the user what to build — do NOT proceed blind
- NEVER skip the check gate (Phase 6) — quality is non-negotiable
- NEVER skip the resource audit (Step 0) — consistency is non-negotiable
- This command is a pipeline orchestrator — it NEVER duplicates logic from sub-commands
- Each sub-command (/bmad:research, /brainstorm, /design-doc, /auto-plan, etc.) owns its own logic
- All notification channels fail silently (|| true) to prevent blocking the pipeline
- Checkpoint after every phase for resumability
- If /auto-build-all has blocked tasks, proceed to /check with what was built
- If /check fails after 3 auto-fix attempts, STOP and notify — do not force-ship broken code
- The `--budget` flag is advisory — stop if estimated remaining cost would exceed it
