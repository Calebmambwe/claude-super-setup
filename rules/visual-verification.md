---
description: Enforce visual verification pipeline for all frontend changes across all projects
globs: ["**/*.tsx", "**/*.jsx", "**/*.css", "**/*.html", "**/*.vue", "**/*.svelte"]
---

# Visual Verification Rules (All Projects)

## Non-Negotiable Rule

When ANY pipeline command (`/auto-dev`, `/auto-ship`, `/auto-develop`, `/dev`, `/check`, `/ghost`) touches frontend files (`.tsx`, `.jsx`, `.css`, `.html`, `.vue`, `.svelte`, or files in `components/`, `pages/`, `app/` directories), the **3-tool visual verification pipeline** is MANDATORY:

1. **`/visual-verify`** — Launch app, navigate pages, check console errors, network failures, take screenshots, test basic interactions
2. **`/visual-regression`** — Screenshot comparison at 3 viewports (mobile 375px, tablet 768px, desktop 1440px) against baselines
3. **`visual-tester` agent** — Deep interactive UI verification: test user flows, forms, modals, tooltips, responsive behavior

## When to Run

| Pipeline Command | Visual Phase | Condition |
|-----------------|-------------|-----------|
| `/auto-ship` | Phase 2.75 | If .tsx/.jsx/.css/.html files changed |
| `/auto-dev` | Delegated to /auto-ship Phase 2.75 | If .tsx/.jsx/.css/.html files changed |
| `/auto-develop` | Phase 5.5 (between build and check) | If .tsx/.jsx/.css/.html files changed |
| `/dev` | Phase 2.5 (between build and check) | If .tsx/.jsx/.css/.html files changed |
| `/check` | Agent 6 (parallel with other agents) | If frontend files in scope |
| `/ghost` / `/ghost-run` | Delegated to /auto-ship Phase 2.75 | If .tsx/.jsx/.css/.html files changed |

## Fix Protocol

- If any tool reports CRITICAL issues: fix (max 1 cycle), re-run ONLY the failed tool
- If fix fails: report clearly in final output, do NOT block pipeline (warn instead)
- NEVER skip visual verification to save time — visual bugs are user-facing bugs

## Skip Conditions

Visual verification is SKIPPED only when:
- No frontend files were modified (backend-only changes)
- The project has no dev server (CLI tools, libraries, API-only services)
- Playwright MCP tools are not available (report warning and suggest installation)

## Anti-Patterns

- [critical] NEVER ship frontend changes without running all 3 visual tools
- [critical] NEVER run only `/visual-verify` and skip `/visual-regression` — viewport regressions are invisible at single resolution
- [critical] NEVER skip the `visual-tester` agent for interactive changes (forms, modals, navigation)
