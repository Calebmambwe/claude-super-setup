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

> Enterprise Agent Platform Sprint 6 (FINAL): Polish, documentation, and release. All 8 pillars shipped across 6 sprints — this sprint closes the platform with documentation accuracy, install validation, and changelog.

### Key Constraints

- Must build on existing architecture — extend, don't replace
- Must not break existing functionality (Ghost Mode, Telegram, overnight.sh)
- Solo developer — leverage AI agents for implementation
- All documentation must reflect actual current state (counts, paths, URLs)

### Success Criteria

- [x] README.md updated with full feature list, correct URLs, accurate counts
- [x] docs/FEATURES.md marking all features complete
- [x] AGENTS.md updated with Sprint 6 section and all sprint patterns
- [x] CHANGELOG.md created from git history
- [x] install.sh handles agents/teams/, catalog.json, and schemas/
- [x] inventory-check.sh passes all validation
- [x] docs/enterprise-agent-platform/brief.md status set to Complete

### Non-Goals (Explicit)

- Implementing Smart Hub Tauri frontend (spec only)
- Implementing URI handler VS Code extension (docs only)
- Running server code or API implementations
- Adding new features — this is a polish-only sprint

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
