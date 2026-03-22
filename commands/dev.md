---
name: dev
description: Unified development command — Plan + Build + Check + Ship in one flow with human gates
---
Execute the full development cycle for: $ARGUMENTS

## What This Does

This is the ONE command for end-to-end feature development. It chains `/plan → /build → /check → /ship` with human gates between each phase. You never need to remember the sequence — just `/dev <what you want>`.

## Flags

- `/dev --plan-only <description>` → Phase 1 only (plan and stop)
- `/dev --skip-plan <description>` → Phases 2-4 against existing specs
- `/dev --no-ship <description>` → Phases 1-3 only, skip PR creation

## Execution Flow

### Phase 1: PLAN
1. Run `/plan {description}`
2. Present the plan to the user
3. **GATE:** "Approve plan? [proceed / adjust / abort]"
   - **proceed** → move to Phase 2
   - **adjust** → re-plan with user feedback
   - **abort** → stop entirely

### Phase 2: BUILD
1. Run `/build` (uses plan artifacts from Phase 1)
2. Hooks auto-run tests + lint on every file edit
3. **GATE:** "Build complete. Proceed to quality check? [yes / fix something first]"
   - **yes** → move to Phase 3
   - **fix** → address the issue, then re-gate

### Phase 3: CHECK
1. Run `/check` (parallel: code-review + security + tests)
2. If **FAIL:** list findings, ask user to fix or let you fix, then re-run /check
3. If **PASS:** proceed
4. **GATE:** "Quality passed. Ship it? [yes / hold]"
   - **yes** → move to Phase 4
   - **hold** → stop here (user can run /ship manually later)

### Phase 4: SHIP
1. Run `/ship` (commit + push + PR)
2. Return PR URL

## Smart Routing

For tiny changes (1-2 files):
- Suggest: "This looks small — skip planning and go straight to build?"
- If user agrees: jump to Phase 2
- Even for tiny changes: run the Lightweight Audit first (component reuse + design token compliance). See `rules/consistency.md`.

## Output

Always end with:
```
## Dev Complete

Feature: {description}
Branch: {branch-name}
PR: {url}

Phases:
  Research: {conducted / not needed}
  Plan: {Quick Plan / Feature Spec / Full Pipeline}
  Build: {N files created, M modified, P tests added}
  Check: PASS (tests: X/X, lint: clean, security: clean)
  Ship: PR #{number} — {url}
```

## Rules
- ALWAYS pause between phases — never fully autonomous
- If /check hasn't been run, warn before /ship
- NEVER auto-merge PR — human reviews required
- For tiny changes: suggest skipping /plan, but don't skip without confirmation
- Each phase uses the appropriate skill/command — don't reimplement their logic here
- If any phase fails, offer to fix it rather than skipping
