# Agent Ecosystem Map and Quality Assessment

**Date:** 2026-03-28
**Total agents:** ~68 across 12 departments

---

## Model Tier Distribution

| Tier | Count | Used For |
|------|-------|---------|
| opus | ~15 | architect, orchestrator, backend-dev, code-reviewer, security-auditor, researcher, darwin, api-architect, backend-architect, teach-me |
| sonnet | ~40 | frontend-dev, verifier, tdd-test-writer, test-writer-fixer, all testing/marketing agents, studio-coach |
| haiku | ~5 | doc-verifier, joker, instagram-curator, twitter-engager, whimsy-injector |

---

## Tier 1: Core Engineering (Quality Backbone)

| Agent | Model | maxTurns | Assessment | Key Strength |
|-------|-------|----------|------------|-------------|
| orchestrator | opus | 30 | EXCELLENT | Central quality enforcer, structured escalation |
| architect | opus | plan mode | EXCELLENT | Principal-engineer-grade planning, decision frameworks |
| backend-dev | opus | 30 | EXCELLENT | Route/Service/Repository layering, Context7 enforced |
| code-reviewer | opus | 25 | EXCELLENT | 9-category checklist, OWASP Top 10, frontend-specific |
| security-auditor | opus | 25 | EXCELLENT | Beyond basic OWASP, OAuth/JWT/CSP specifics |
| verifier | sonnet | 20 | EXCELLENT | Fresh context (memory: none), adversarial review |
| tdd-test-writer | sonnet | worktree | GOOD | RED phase enforcement, worktree isolation |
| frontend-dev | sonnet | - | EXCELLENT | CWV targets, Server/Client boundary, animations |

---

## Tier 2: Specialized Engineering

| Agent | Model | Assessment | Notes |
|-------|-------|------------|-------|
| researcher | opus | EXCELLENT | Strict Context7 protocol, 5-min time limit |
| darwin | opus | IMPRESSIVE | 5 operating modes, external AI platform integration |
| teach-me | opus | EXCELLENT | 5-phase self-teaching loop, spawns sub-agents |
| doc-verifier | haiku | GOOD | Cost-optimal for lookup task |
| env-doctor | sonnet | GOOD | Self-referential cost awareness |
| skill-curator | sonnet | GOOD | Weighted quality scoring system |

---

## Team Presets

| Preset | Trigger | Agents | Assessment |
|--------|---------|--------|------------|
| review.json | Cmd+Shift+R | code-reviewer + security-auditor parallel, then verifier | EXCELLENT |
| feature.json | Cmd+Shift+F | architect > tdd-test-writer > backend-dev + frontend-dev parallel > verify | EXCELLENT |
| debug.json | Cmd+Shift+D | env-doctor + researcher parallel > test-writer-fixer | GOOD |
| darwin.json | cron | darwin > researcher > darwin proposals > verifier > self-heal | GOOD |

---

## Benchmark System

- 15 regression tasks (reg-001 to reg-015), tiers 1-3
- Current pass rate: ~55% (early-phase data, system just set up)
- Regression detection: >5% drop from rolling 3-run average
- Evolution log: 1 entry at 73% score

---

## Issues Found

1. **Benchmark pass rate low (55%)** — early calibration phase
2. **marketing/language-specialist agents orphaned** — no team membership, no invoked_by
3. **Overlap: frontend-developer vs frontend-dev** — frontend-dev is superior, frontend-developer is weaker duplicate
4. **Overlap: backend-architect vs architect** — architect is more rigorous
5. **skill-curator missing frontmatter** — structural bug, not loadable as proper agent
6. **visual-tester missing tools list** — references Playwright MCP but not declared
7. **AGENTS.md at 89 lines** — over 80-line consolidation trigger
