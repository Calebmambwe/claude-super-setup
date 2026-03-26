# Self-Improvement Engine: Comprehensive Brainstorm

## Vision

**"Better than Claude Code and Manus"**

Claude Code is the best AI coding assistant for individual file/task work. Manus is the best autonomous multi-agent system for complex research and execution. We want a system that:

1. Accumulates wisdom across sessions (neither Claude Code nor Manus does this by default)
2. Gets measurably better over time (benchmarks prove improvement)
3. Ships production-quality code from the start (templates + design tokens + CI/CD)
4. Handles full-stack projects end-to-end (from PRD to deployed application)
5. Operates 24/7 reliably (VPS + uptime architecture)

The gap we're filling: Claude Code forgets everything between sessions. Manus has no persistent skill store or improvement tracking. We build the layer that makes AI development compound.

---

## Current State Assessment

### What's Working
- BMAD workflow: research → PRD → architecture → sprint planning → dev stories
- Learning ledger: corrections are captured and retrieved cross-session
- VPS 24/7 operation: three-process reliability architecture
- Telegram dispatch: tasks sent and received reliably
- Skills system: SKILL.md format is solid, top-level skills exist

### What's Broken or Missing
- No benchmarks: no way to measure if we're getting better
- Skills aren't self-updating: success_rate never improves automatically
- Templates are outdated: Tailwind v3, NativeWind v3, no CI/CD, no a11y
- No design token system: colors are hardcoded everywhere
- No continuous improvement loop: learning is manual, not systematic
- Skill retrieval is primitive: keyword search only, no semantic matching
- No observability: can't trace what the agent did or why
- No mutation testing: test quality is unknown

### Key Gaps vs Claude Code
- Claude Code has Sonnet/Opus switching (we have this via opusplan)
- Claude Code has no skill persistence (we have this — advantage us)
- Claude Code has no improvement tracking (we have the ledger — advantage us)
- Claude Code has better file editing (we rely on Claude Code itself here)

### Key Gaps vs Manus
- Manus has KV-cache optimization (we need to implement this)
- Manus has progressive skill loading (we load full skills)
- Manus has Wide Research (we have single-agent research)
- Manus has better task orchestration (we're building this)
- We have better cost structure (running on VPS vs cloud)
- We have persistent improvement tracking (Manus doesn't have public ledger)

---

## 10+ Initiatives (Prioritized)

### P0: Must Have (Week 1-2)

**Initiative 1: Benchmark Framework**
- Priority: P0 | Effort: Medium | Impact: High
- Build the measurement layer for all improvement work
- Without this, we can't know if we're getting better
- Deliverable: benchmark-runner agent + score history + improvement curve dashboard

**Initiative 2: Skill Metadata Enhancement**
- Priority: P0 | Effort: Low | Impact: High
- Add tags, success_rate, usage_count to all 30+ existing skills
- This is the prerequisite for everything else (retrieval, quality scoring, evolution)
- Deliverable: Updated SKILL.md headers + skill quality scanner

**Initiative 3: Template Overhaul — web-shadcn-v4**
- Priority: P0 | Effort: Medium | Impact: High
- The `web-app` template is the most-used template. It needs Tailwind v4 + OKLCH tokens + CI/CD + a11y
- Deliverable: New `web-shadcn-v4` template + CI yml + .devcontainer

**Initiative 4: Fix Template Bugs**
- Priority: P0 | Effort: Low | Impact: High
- Fix RevenueCat paywall bug, NativeWind v3→v4 API update
- These are actively causing project scaffolding failures
- Deliverable: Fixed `mobile-expo-revenucat` and `mobile-nativewind` templates

### P1: Should Have (Week 2-3)

**Initiative 5: Design Token System**
- Priority: P1 | Effort: High | Impact: High
- W3C DTCG JSON → Style Dictionary v4 → CSS + Tailwind + iOS + Android
- Enables: consistent colors, dark mode, cross-platform consistency
- Deliverable: `tokens/` package + Style Dictionary config + CI transform step

**Initiative 6: Skill Semantic Retrieval**
- Priority: P1 | Effort: Medium | Impact: High
- Add vector embeddings to skill store for semantic search
- Currently skills are retrieved by keyword. Semantic retrieval finds relevant skills even when terminology doesn't match.
- Deliverable: Embedded skill store + hybrid retrieval (semantic + keyword)

**Initiative 7: CI/CD Standard Template**
- Priority: P1 | Effort: Low | Impact: High
- Every project needs CI. Create a standard GitHub Actions yml + Dependabot config
- Add to all 16 existing templates and all new templates
- Deliverable: `.github/workflows/ci.yml` template + Dependabot config template

**Initiative 8: Accessibility Framework**
- Priority: P1 | Effort: Medium | Impact: Medium
- WCAG 2.2 AA compliance built into all templates from day one
- eslint-plugin-jsx-a11y + axe-core + skip navigation + focus management
- Deliverable: Accessibility setup instructions + component patterns + test utilities

### P2: Nice to Have (Week 3-4)

**Initiative 9: Skill Auto-Evolution**
- Priority: P2 | Effort: High | Impact: High
- After a skill fails, automatically run CASCADE three-strategy debug
- Promotes skills that improve, deprecates skills that degrade
- Deliverable: skill-evolution agent + skill quality dashboard

**Initiative 10: Observability Layer**
- Priority: P2 | Effort: Medium | Impact: Medium
- OTel traces per task, metrics per tool call, structured logs
- Enables post-mortem analysis, performance optimization
- Deliverable: OTel setup + Grafana dashboard + JSONL local store

**Initiative 11: Continuous Improvement Loop**
- Priority: P2 | Effort: High | Impact: High
- Automated feedback collection → skill improvement → benchmark validation
- The self-sustaining flywheel
- Deliverable: Cron jobs + loop orchestrator + dashboard

**Initiative 12: Wide Research Agent**
- Priority: P2 | Effort: Medium | Impact: Medium
- Parallel multi-agent research following Manus Wide Research pattern
- Enhances `/bmad:research` with parallelism and synthesis
- Deliverable: wide-research agent + synthesis template

---

## New Templates to Build (6)

### Template 1: `web-shadcn-v4`
**Stack**: Next.js 15 + shadcn/ui + Tailwind v4 + OKLCH tokens
**Differentiators**: WCAG 2.2 AA, DESIGN.md, CI/CD, .devcontainer
**Replaces**: `web-app` (becomes primary web template)

### Template 2: `mobile-gluestack`
**Stack**: Expo SDK 54 + Gluestack UI v3 + NativeWind v4 + Expo Router
**Differentiators**: Universal components (iOS + Android + Web), OKLCH tokens
**Replaces**: `mobile-nativewind` (becomes primary mobile template)

### Template 3: `saas-complete`
**Stack**: Next.js + Stripe + NextAuth + Prisma + Shadcn Admin Dashboard + RBAC + Teams
**Differentiators**: Admin dashboard, role system, usage tracking, multi-tenancy
**Enhances**: `saas-starter` (becomes the "batteries included" version)

### Template 4: `ai-rag-complete`
**Stack**: Next.js + AI SDK v3 + pgvector + multi-provider + tool calling + ingestion
**Differentiators**: Multi-provider (Claude/OpenAI/Gemini/Ollama), full RAG pipeline, streaming
**Enhances**: `ai-ml-app` (becomes production-ready AI template)

### Template 5: `monorepo`
**Stack**: Turborepo + pnpm workspaces + apps/web + apps/api + packages/ui + packages/shared
**Differentiators**: Matrix CI, shared package publishing, changeset versioning
**Fills gap**: No monorepo template currently exists

### Template 6: `email-templates`
**Stack**: React Email + Resend + preview server + template library
**Differentiators**: Pre-built transactional email templates, live preview
**Fills gap**: No email template currently exists

---

## New Agents to Create (5)

### Agent 1: `benchmark-runner`
**Purpose**: Runs benchmark evaluations on scheduled basis, tracks improvement over time
**Triggers**: Cron (weekly for Tier 2, monthly for Tier 3)
**Outputs**: Score history JSON, improvement curve chart, regression alerts
**Key capability**: Runs tasks in sandboxed environments, compares to expected outputs

### Agent 2: `template-generator`
**Purpose**: Creates new stack templates from specs
**Triggers**: User command: `/new-template <name> <spec>`
**Inputs**: Stack spec (YAML), design token config, CI requirements
**Outputs**: Complete template directory following all standards

### Agent 3: `design-token-manager`
**Purpose**: Manages the design token pipeline from source to all output targets
**Triggers**: Token file changes, Figma webhook
**Inputs**: DTCG JSON token file, Style Dictionary config
**Outputs**: globals.css, tailwind.config, iOS Swift assets, Android XML

### Agent 4: `accessibility-auditor`
**Purpose**: Runs WCAG 2.2 compliance checks on UI code
**Triggers**: Pre-commit hook, CI step, on-demand command
**Inputs**: React component files, built HTML
**Outputs**: Violation report, remediation suggestions

### Agent 5: `skill-curator`
**Purpose**: Analyzes skill quality, evolves underperforming skills, creates new skills from patterns
**Triggers**: Post-session hook, weekly cron, manual `/curate-skills`
**Inputs**: Skill quality metrics, session logs, benchmark results
**Outputs**: Updated skill files, new skill files, deprecation list

---

## New Commands to Create

### `/benchmark [tier]`
Run the benchmark suite. Tier defaults to quick (Tier 1). Options: `--tier 2`, `--tier 3`.

### `/token-sync`
Pull latest token changes from Figma, run Style Dictionary transforms, commit updates.

### `/audit-a11y [path]`
Run accessibility audit on a directory. Outputs violation report and remediation priority list.

### `/curate-skills`
Invoke the skill-curator agent to analyze and evolve the skills database.

### `/new-template <name>`
Generate a new stack template using the template-generator agent.

### `/benchmark-history`
Show the improvement curve: benchmark scores over time, trend analysis.

---

## New Hooks to Create

### `post-error` Hook
**Trigger**: When a tool call returns an error
**Action**: Capture error type, tool, context, and retry count to error log
**Learning signal**: Feed error patterns to the skill curator

### `post-session` Hook
**Trigger**: When a session ends (user says goodbye or /reflect is run)
**Action**: Summarize session: what was built, what failed, corrections made
**Learning signal**: Automatic ledger entry from session summary

### `post-benchmark` Hook
**Trigger**: After benchmark-runner completes
**Action**: Update improvement curve, check for regressions, alert if score drops

### `pre-commit-mutation` Hook
**Trigger**: Before any commit to test-heavy files
**Action**: Run Stryker mutation tests on changed test files, warn if score drops

---

## Benchmark System Design (Summary)

Three-tier benchmark suite:
- Tier 1: 20-50 custom tasks from past work (< 5 min, regression only)
- Tier 2: SWE-bench Verified 50-task sample + LiveCodeBench 20 (weekly, 2-4 hrs)
- Tier 3: SWE-EVO sequences + custom multi-step (monthly, 4-8 hrs)

See `13-benchmark-framework-spec.md` for full spec.

---

## Continuous Improvement Loop Design (Summary)

```
Tasks → Execution → Learning Capture → Skill Update → Benchmark → Dashboard
  ↑                                                                       |
  └───────────────────────── Improvement signal ──────────────────────────┘
```

Cadences: In-session (seconds), Post-session (hours), Weekly (days), Monthly (weeks).

See `07-continuous-learning.md` for full design.
