# Milestone Prompts — Execution Guide

## Overview

Each milestone prompt is a self-contained implementation guide designed to be run as an independent Claude Code session via `/implement-meta-prompt`.

## Execution Order

```
M1 (Scaffold + CI) ← START HERE
  │
  ▼
M2 (Install Script)
  │
  ├──► M3 (Web Templates) ──────────┐
  ├──► M4 (Mobile Templates) ───────┤
  ├──► M5 (Specialized + Backend) ──┼──► M8 (Docs + Release v1.0)
  ├──► M6 (Agent Ecosystem) ────────┤
  └──► M7 (Autonomous CI/CD) ───────┘
```

**M1 and M2** must be completed sequentially.
**M3 through M7** can be executed in parallel (separate sessions or `/parallel-implement`).
**M8** must wait for all others to complete.

## How to Run

```bash
# Run a single milestone
/implement-meta-prompt docs/milestone-prompts/milestone-1-repo-scaffold.md

# Or in Ghost Mode for overnight execution
/ghost --trust=high docs/milestone-prompts/milestone-1-repo-scaffold.md
```

## Estimated Sessions per Milestone

| Milestone | Sessions | Notes |
|-----------|----------|-------|
| M1: Scaffold + CI | 1-2 | File migration is tedious but straightforward |
| M2: Install Script | 1 | Shell scripting, testing on clean env |
| M3: Web Templates | 2 | 4 templates, each needs research + writing |
| M4: Mobile Templates | 1-2 | 3 templates |
| M5: Specialized + Backend | 2 | 6 templates, SaaS and AI/ML are complex |
| M6: Agent Ecosystem | 2 | Research + import + catalog + routing |
| M7: Autonomous CI/CD | 1 | Workflow writing + testing |
| M8: Docs + Release | 1 | README, CONTRIBUTING, release |
| **Total** | **~11-13 sessions** | |

## Files

1. `milestone-1-repo-scaffold.md` — Repository structure + CI pipeline
2. `milestone-2-install-script.md` — Portable installer
3. `milestone-3-web-templates.md` — Astro, T3, SvelteKit, Remix
4. `milestone-4-mobile-templates.md` — NativeWind, Flutter, RevenueCat
5. `milestone-5-specialized-backend.md` — SaaS, AI/ML, Chrome Extension, CLI, FastAPI, Hono Edge
6. `milestone-6-agent-ecosystem.md` — Community agents, catalog, model routing, teams
7. `milestone-7-autonomous-cicd.md` — Weekly improvement pipeline
8. `milestone-8-docs-release.md` — Documentation + v1.0.0 release
