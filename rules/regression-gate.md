# Regression Gate Rules (Always Loaded)

## Non-Negotiable

After EVERY build that produces a web application (Next.js, React, Vite, or any project with a dev server), the regression gate MUST run before declaring "done" or shipping.

## When to Run

- After `/build` completes on a web project → run Tier 1 (smoke)
- After `/auto-ship` build phase → run Tier 2 (full)
- After `/ghost-run` build phase → run Tier 3 (exhaustive)
- After any task that modifies `.tsx`, `.jsx`, `.css`, `.html`, or API route files → run Tier 1

## How to Run

```bash
bash scripts/regression-gate.sh --tier {1|2|3} --project-dir {path}
```

Or use the command: `/regression-gate --tier {1|2|3}`

## Blocking Rules

- **CRITICAL issues (exit 1):** BLOCK shipping. Fix the issues and re-run.
- **WARNINGS (exit 0):** Allow shipping but report to user.
- **Max 1 fix cycle:** If issues persist after one fix attempt, stop and report.

## What It Checks

| Tier | Time | Checks |
|------|------|--------|
| 1 | 30s | Typecheck, lint, server starts, homepage loads, no console errors, no broken links |
| 2 | 2min | + All routes, API health, images, forms, responsive, basic a11y |
| 3 | 5min | + All pages, user flows, performance (<3s LCP), full a11y, no TODOs |

## Anti-Patterns

- [critical] NEVER ship a web app without running at least Tier 1
- [critical] NEVER ignore a CRITICAL failure from the gate
- [critical] NEVER say "the app is working" without evidence from the gate
- [pattern] If the gate can't start the dev server, check package.json scripts and port conflicts
