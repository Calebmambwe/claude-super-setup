# PROJECT_ANCHOR.md — Attention Anchoring System

**Pattern source:** Manus.ai context engineering — "re-read todo.md every iteration"
**Purpose:** Prevent goal drift in long autonomous runs by providing a stable anchor document

---

## What This File Does

This file is the **attention anchor** for the current project. During autonomous pipeline runs (`/auto-build`, `/auto-ship`, `/ghost-run`), agents MUST re-read this file before each task iteration to keep goals, constraints, and acceptance criteria in active attention.

LLMs suffer "lost in the middle" — facts 50K+ tokens back are recalled poorly. This file acts as a forced re-read point that keeps critical context in the active attention window.

## How It Works

### For `/auto-build` (single task)

Before each reasoning step in the Ralph Loop:
1. Re-read this file (PROJECT_ANCHOR.md)
2. Re-read the current task's `acceptance_criteria` from tasks.json
3. Verify your next action aligns with both

### For `/auto-build-all` (all tasks)

Before starting each new task:
1. Re-read this file
2. Re-read the specific task being started
3. Check if earlier task results changed the plan

### For `/ghost-run` (full pipeline)

Re-read at each gate checkpoint:
1. Before Gate 1 (plan approval)
2. Before Gate 2 (task approval)
3. Before each task in the build phase
4. Before the check gate

## Anchor Content

The following sections should be populated per-sprint or per-feature. They form the "stable prefix" that agents re-read.

### Current Goal

> {One sentence describing what this sprint/feature achieves}
>
> Example: "Enterprise Agent Platform Sprint 4: Add personal assistant commands and Manus agent patterns"

### Key Constraints

- Must build on existing architecture — extend, don't replace
- Must not break existing functionality (Ghost Mode, Telegram, overnight.sh)
- Solo developer — leverage AI agents for implementation
- {Add project-specific constraints here}

### Success Criteria

- [ ] All new commands follow the existing SKILL.md / command pattern
- [ ] All new agents follow agents/core/*.md pattern
- [ ] AGENTS.md updated with new patterns and gotchas
- [ ] No regressions in existing commands
- {Add sprint-specific criteria here}

### Non-Goals (Explicit)

- {Things that are tempting but out of scope}
- {Prevents scope creep during long autonomous runs}

---

## Rules for Agents

1. **Re-read frequency:** Every task iteration, every gate checkpoint. Non-negotiable.
2. **Never modify this file during a build** — it's read-only during execution. Only `/plan` or manual edits update it.
3. **If your next action contradicts the anchor:** STOP. Re-read the anchor. If still contradictory, flag to the orchestrator.
4. **Keep this file under 100 lines** — it must be fast to re-read. Brevity is a feature.
5. **Update at sprint boundaries** — stale anchors cause drift, which is worse than no anchor.

## Integration Points

| Command | When to Re-Read | What to Check |
|---------|----------------|---------------|
| `/auto-build` | Before each Ralph Loop iteration | Current Goal + task acceptance criteria |
| `/auto-build-all` | Before starting each task | Current Goal + task dependencies |
| `/auto-ship` | Before check gate | Success Criteria checklist |
| `/ghost-run` | Every gate checkpoint | Full anchor |
| `/plan` | At plan start (to populate) | Update anchor content for new sprint |
