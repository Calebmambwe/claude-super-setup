---
name: auto-ship
description: Build + Check + Ship in one pass — autonomous end-to-end pipeline
---

Build all tasks, run quality checks, and create a PR: $ARGUMENTS

## What This Does

Wraps `/auto-build-all` → `/check` → `/ship` into a single autonomous pipeline. For the full end-to-end flow including planning and task decomposition, run `/auto-plan` first, then `/auto-ship`.

Full chain: `/auto-plan` (plan + tasks) → `/auto-ship` (build + check + ship)

No logic duplication — each phase delegates to the existing command.

## Resume Support

If a previous `/auto-ship` run was interrupted, this command resumes automatically:
- Read `.claude/pipeline-checkpoint.json` if it exists
- Skip completed phases, resume from the last incomplete phase
- Completed tasks in `tasks.json` are always skipped (existing behavior)

To force a fresh run, delete `.claude/pipeline-checkpoint.json` first.

## Process

### Phase 1: Pre-flight

1. **Check for resume** — read `.claude/pipeline-checkpoint.json`. If it exists and matches current branch, resume from last incomplete phase. Report: "Resuming from Phase {n} ({phase name})."
2. **Verify tasks.json exists** — if missing: "No tasks.json found. Run `/auto-tasks` or `/init-tasks` first."
3. **Read AGENTS.md** if it exists — carry forward learned patterns and gotchas from prior sessions
4. **Check branch safety:**
   - If on `main` or `master` → auto-create a feature branch: `feat/auto-ship-{YYYYMMDD-HHmm}`
   - Push the new branch: `git push -u origin HEAD`
5. **Check for uncommitted changes** — if unstaged changes exist in non-test files: "You have uncommitted changes. Commit or stash them first."
6. **Write initial checkpoint:**
   ```json
   {"branch": "{branch}", "phase": 1, "started": "{ISO date}", "tasks_total": {n}}
   ```
7. **Count tasks and report:**
   ```
   ## Auto-Ship Pre-flight

   Branch: {branch-name}
   Tasks: {pending} pending, {completed} completed, {blocked} blocked
   Starting autonomous pipeline...
   ```
8. **Notify:**
   ```bash
   osascript -e 'display notification "Pre-flight complete. Starting build..." with title "Auto-Ship"' 2>/dev/null
   ```

### Phase 2: Plan + Build Loop

Run `/auto-build-all` — for each pending task, this runs the Ralph Loop:
1. Plan (architect agent analyzes task, reads AGENTS.md, explores codebase)
2. Implement (file-by-file, tests alongside)
3. Verify (code-reviewer agent checks acceptance criteria)
4. Fix (up to 2 cycles if verification found issues)

Tasks execute in dependency order with parallel execution for independent tasks.
Progress reported after each task. Stops after 3 consecutive failures.

**Update checkpoint:** `{"phase": 2, "tasks_completed": {n}}`

**After `/auto-build-all` completes, evaluate:**
- If **0 tasks completed** → STOP: "No tasks were completed. Review blocked reasons above."
- If **any tasks blocked** → report blocked tasks but continue to check/ship what was completed
- If **all tasks completed** → continue to Phase 2.25

**Notify:**
```bash
osascript -e 'display notification "Build complete: {n}/{total} tasks. Running coverage check..." with title "Auto-Ship"' 2>/dev/null
```

### Phase 2.25: Coverage Gate

Run coverage check on new code:
```bash
pnpm test -- --coverage 2>/dev/null
```

**Evaluate:**
- If coverage of new code >= 80% → continue
- If coverage < 80%:
  1. Run `/generate-tests` on the uncovered files (max 1 cycle)
  2. Re-run coverage
  3. If still < 80% → add WARNING to final report (not blocking, but flagged)

**Update checkpoint:** `{"phase": 2.25, "coverage": "{percent}%"}`

### Phase 2.5: Direct Verification

Run verification commands directly before the heavier agent-based check:
```
pnpm test && pnpm lint && pnpm typecheck
```
If any fail, attempt to fix (max 1 cycle) before proceeding to Phase 2.75.
This catches obvious issues early and saves time vs the full `/check` pipeline.

**Update checkpoint:** `{"phase": 2.5, "verify": "pass"}`

### Phase 2.75: Visual Verification

**This phase is MANDATORY if any completed tasks touched frontend files** (`.tsx`, `.jsx`, `.css`, `.html`, or files in `components/`, `pages/`, `app/`).

If frontend files were changed:
- Run `/visual-verify` to check for console errors and visual regressions
- If issues found, fix them (max 1 visual fix cycle)
- Report visual verification results in the final report

If NO frontend files were changed:
- Skip this phase
- Report: "Visual verification skipped — no frontend changes detected"

**Update checkpoint:** `{"phase": 2.75, "visual": "pass|skipped"}`

**Notify:**
```bash
osascript -e 'display notification "Verification complete. Running quality check..." with title "Auto-Ship"' 2>/dev/null
```

### Phase 3: Check Gate

Run `/check` on all branch changes (the check command auto-detects branch scope via `git diff main...HEAD`).

**Evaluate the verdict:**
- If **FAIL** (CRITICAL findings or test failures):
  - Attempt auto-fix: address each CRITICAL finding (max 2 fix cycles)
  - After each fix cycle, re-run `/check`
  - If still FAIL after 2 cycles → STOP:
    ```
    ## Auto-Ship Blocked

    /check found CRITICAL issues that could not be auto-fixed:
    {list of remaining critical findings}

    Fix these issues manually, then run /auto-ship again (completed tasks will be skipped).
    ```
  - If PASS after fixes → continue to Phase 4
- If **PASS** (warnings only) → continue to Phase 4

**Update checkpoint:** `{"phase": 3, "check": "pass"}`

### Phase 4: Ship

Run `/ship` — this handles:
- Staging relevant files
- Creating conventional commit(s)
- Pushing to remote
- Creating PR via `gh pr create`

**Update checkpoint:** `{"phase": 4, "pr": "{url}"}`

### Phase 4.5: Self-Review

Run the PR review toolkit on the created PR to catch diff-level issues:
- Use `pr-review-toolkit:review-pr` on the PR number
- Post review comments directly on the PR
- Flag any CRITICAL findings to the user

This catches holistic issues that file-level `/check` may miss (e.g., inconsistent patterns across files, missing migration steps, incomplete feature flag rollout).

**Update checkpoint:** `{"phase": 4.5, "review": "done"}`

**Notify:**
```bash
osascript -e 'display notification "PR created and self-reviewed. Pipeline complete!" with title "Auto-Ship" sound name "Purr"' 2>/dev/null
```

### Phase 5: Post-ship

1. **Log summary** to `~/.claude/logs/auto-ship.log`:
   ```
   [{timestamp}] project={project} branch={branch} tasks_completed={n} tasks_blocked={n} pr={url} verdict={PASS/FAIL} coverage={percent}%
   ```

2. **Log pipeline trace** to `~/.claude/logs/pipeline-trace.jsonl`:
   ```json
   {"pipeline":"auto-ship","branch":"{branch}","phases":{"preflight":{ms},"build":{ms},"coverage":{ms},"verify":{ms},"visual":{ms},"check":{ms},"ship":{ms},"review":{ms}},"tasks_completed":{n},"tasks_blocked":{n},"pr":"{url}","timestamp":"..."}
   ```

3. **Clean up checkpoint:** Delete `.claude/pipeline-checkpoint.json` (pipeline complete)

4. **Final report:**
   ```
   ## Auto-Ship Complete

   Branch: {branch-name}
   Tasks completed: {n}/{total}
   Tasks blocked: {n}
   Coverage: {percent}% (target: 80%)
   Check verdict: PASS
   PR: {url}
   Self-review: {n} comments posted

   Pipeline trace:
     Pre-flight      {duration}  ✓
     Build            {duration}  {completed}/{total} tasks
     Coverage         {duration}  {percent}%
     Verify           {duration}  ✓
     Visual           {duration}  {✓/skipped}
     Check            {duration}  {verdict}
     Ship             {duration}  PR #{number}
     Self-review      {duration}  {n} comments

   Total pipeline time: {total duration}

   {If blocked tasks:}
   Blocked tasks requiring attention:
   - Task {id}: {title} — {reason}

   {If coverage < 80%:}
   ⚠ Coverage below 80% target — consider adding tests before merge.

   VS Code:
   - GitHub PRs sidebar: see your PR, add reviewers, track status
   - GitHub Actions sidebar: watch CI run live, re-run if needed
   - GitLens: compare your branch against main for a final sanity check

   The PR is ready for human review.
   ```

## Safety Rules

- **NEVER run on main/master** — auto-creates a feature branch if detected
- **NEVER ship if /check has CRITICAL findings after 2 auto-fix cycles** — must be fixed manually
- **NEVER ship if 0 tasks completed** — nothing to ship
- **NEVER auto-merge** — always creates a PR for human review
- **NEVER commit .env files or secrets** — delegated to /ship's safety checks
- Blocked tasks are reported but don't prevent shipping completed work
- Visual verification is MANDATORY for frontend changes — not optional

## Rules

- This command is a pipeline orchestrator — it NEVER duplicates logic from sub-commands
- Each phase delegates entirely to its existing command
- If build or ship phases fail, report clearly and stop — don't try to recover
- The check phase has an auto-fix loop (max 2 cycles) before stopping
- ALWAYS write checkpoint after each phase for resume support
- ALWAYS log pipeline trace for observability
- ALWAYS send macOS notifications between major phases
- ALWAYS run self-review after PR creation
- If $ARGUMENTS is provided, pass it through as context to /auto-build-all
