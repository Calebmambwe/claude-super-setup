---
name: build
description: Unified implementation command — auto-routes based on task size and available specs
---
Implement: $ARGUMENTS

## What This Does

This is the ONE command for all implementation. It replaces `/implement-design`, `/sdlc-meta-prompt`, `/milestone-prompts`, `/parallel-implement`, `/team-build`, and direct coding.

## Routing Logic

### Step 0: Check for Orchestrated Pipeline

If `tasks.json` exists in the project root with pending tasks:
- Suggest: "Found tasks.json with {N} pending tasks. Run `/auto-build` to execute the next task with the full Plan→Implement→Verify pipeline, or `/auto-build-all` to process all tasks autonomously."
- If the user's $ARGUMENTS match a specific task title, run `/auto-build` for that task.
- If no $ARGUMENTS provided, run `/auto-build` for the next pending task.

### Step 1: Assess What We're Building

Check for existing specs/plans in this order:
1. `specs/*.tasks.md` — task list exists? Use it.
2. `specs/*.plan.md` — plan exists? Use it.
3. `specs/*.spec.md` — spec exists? Use it.
4. `docs/*/design-doc.md` or `docs/design-doc-*.md` — design doc exists? Use it.
5. `docs/*/prd.md` or `docs/prd-*.md` — PRD exists? Use it.
6. Nothing found — assess $ARGUMENTS directly.

### Step 2: Route to the Right Approach

**Tiny (1-2 files, no spec needed):**
- Implement directly in this session
- Write code + tests together
- No sub-agents needed

**Small (3-5 files, spec exists):**
- Run /architect agent first to create implementation plan
- Implement file-by-file in dependency order
- Write tests alongside each file

**Medium (6-15 files, spec + tasks exist):**
- Read the task list from specs/*.tasks.md
- Implement tasks sequentially in dependency order
- Each task = one commit
- Run tests after each task

**Large (15+ files, or 4+ milestones):**
- Read the task list from specs/*.tasks.md
- Identify parallelizable task groups
- Use the Agent tool to spawn parallel worktree-isolated subagents
- Maximum 5 parallel agents
- Merge results, resolve conflicts, run verification

### Step 3: For All Sizes

Before writing code:
1. Read CLAUDE.md for project conventions
2. Explore existing code patterns (find similar features)
3. Verify dev environment works (tests pass, server starts)

After writing code:
1. Run tests
2. Run lint
3. Commit with conventional commit message

## VS Code Integration

### Error Lens (real-time feedback)
As code is written, `usernamehw.errorlens` shows TypeScript and ESLint errors inline on each line. The Claude Code VS Code extension reads these via `mcp__ide__getDiagnostics` and can fix them in the same turn — no separate `/check` cycle needed for type errors.

### Debugger (F5 for failing tests)
If a test fails during build, `.vscode/launch.json` has "Debug Current Test" pre-configured. The user can:
1. Open the failing test file
2. Set a breakpoint on the assertion
3. Press F5 → steps through both test and implementation
This is faster than asking Claude to debug blindly.

### VS Code Tasks (Ctrl+Shift+B)
`.vscode/tasks.json` has `dev`, `test`, `check`, and `build` tasks pre-configured. The user can run the dev server via `Ctrl+Shift+B` without leaving the editor. For Inngest projects, a compound `dev:full` task starts both Next.js and Inngest dev servers in parallel panels.

### Import Cost (bundle awareness)
`wix.vscode-import-cost` shows the gzip size of every import inline. If a dependency is added during build that's unexpectedly heavy, the user sees it immediately.

### REST Client (API testing)
For API route implementations, generate a `.http` file in `requests/` alongside the route. The `humao.rest-client` extension lets the user test the endpoint with one click — no Postman needed.

### Checkpoints (safety net)
The Claude Code VS Code extension creates checkpoints during `/build`. If the build goes in a wrong direction, the user can rewind to any prior state without `git stash` or `git reset`.

### Step 4: Report

```
## Build Complete

Files created: {N}
Files modified: {N}
Tests added: {N}
Tests passing: {all/N of M}

Commits:
- feat: {commit 1}
- test: {commit 2}
- ...

VS Code tips:
- Error Lens: check for remaining inline errors
- F5: debug any failing test with "Debug Current Test"
- Ctrl+Shift+B: run dev server
- Timeline: see file-by-file change progression

Next: Run /check to review before merging.
```

## Rules
- ALWAYS explore codebase before writing (read existing patterns)
- ALWAYS write tests alongside implementation
- ALWAYS commit after each logical unit of work
- If no spec exists and task is >2 files, suggest running /spec first
- If task list exists, follow it — don't improvise
- Use parallel agents only for 15+ file changes (it has overhead)
- For API routes: generate matching `.http` files in `requests/` for REST Client testing
- If the Claude Code VS Code extension is active, leverage `mcp__ide__getDiagnostics` to catch type errors without running `pnpm typecheck`
