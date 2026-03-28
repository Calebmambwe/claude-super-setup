---
name: regression-gate
description: "Mandatory quality gate — tests the running app for broken links, dead routes, console errors, missing assets, and broken workflows. 3 tiers: smoke (30s), full (2min), exhaustive (5min). Blocks shipping if critical issues found."
---

Run the regression gate: $ARGUMENTS

## What This Does

Regression Gate is a mandatory quality gate that actually loads the app in a browser, clicks every link, checks every API route, and verifies every form — catching the bugs that linters and type checkers miss.

## Usage

```
/regression-gate                    # Auto-detect tier based on context
/regression-gate --tier 1           # Smoke test (30s)
/regression-gate --tier 2           # Full check (2min)
/regression-gate --tier 3           # Exhaustive (5min)
/regression-gate --project-dir /path/to/app
```

## Process

### Step 1: Determine Tier

If `$ARGUMENTS` specifies `--tier`, use that. Otherwise auto-detect:
- Inside `/check` → Tier 1
- Inside `/auto-ship` or `/dev` → Tier 2
- Inside `/ghost` or `/ghost-run` → Tier 3

### Step 2: Run the Gate

```bash
bash scripts/regression-gate.sh --tier {tier} --project-dir {project_dir}
```

The script auto-detects:
- Project type (Next.js, Vite, Node, static)
- Package manager (pnpm, bun, yarn, npm)
- Available port for dev server

### Step 3: Handle Results

**If PASS (exit 0):**
- Report results to the user
- Continue the pipeline

**If FAIL (exit 1):**
- Show the detailed failure report
- List each broken item with the specific fix needed
- **Block shipping** — do NOT proceed to commit/PR
- Attempt to fix the issues (max 1 fix cycle):
  1. For broken links: find the component with the broken href and fix it
  2. For 404 API routes: check if the route file exists and has the correct export
  3. For missing images: check if the file exists in public/ or if the path is wrong
  4. For console errors: check the browser console output and fix the root cause
  5. After fixing, re-run the gate at the same tier
  6. If still failing after 1 fix cycle, report to user and stop

### Step 4: Report

Display the structured results table showing:
- Each check category (links, API, images, forms, responsive, a11y)
- Count of items checked vs failures
- Final verdict (PASS/FAIL/WARN)

## Integration with Pipeline Commands

This gate is called automatically by these commands:

| Command | When | Tier |
|---------|------|------|
| `/check` | As the final verification step | 1 (smoke) |
| `/auto-ship` | After build, before commit | 2 (full) |
| `/ghost` | Before PR creation | 3 (exhaustive) |
| `/dev` | After build phase | 1 (smoke) |

## Rules

- NEVER skip the regression gate for projects with a dev server
- NEVER declare "done" if the gate fails
- If the gate reports CRITICAL issues, FIX them before shipping
- WARNINGS are informational — they don't block shipping
- The gate is additive — it doesn't replace existing checks (lint, typecheck, test)
- Skip with `--skip-gate` only for emergency deployments (requires explicit user approval)
