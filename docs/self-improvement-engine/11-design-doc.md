# Self-Improvement Engine: Design Document

## Document Information

| Field | Value |
|-------|-------|
| Author | Caleb Mambwe / Twendai Software Ltd |
| Status | Draft |
| Version | 1.0 |
| Date | 2025-03-25 |

---

## 1. Problem Statement

Claude Code and Manus are the current frontier of AI development assistance. They share a critical limitation: **they don't compound**. Every session starts fresh. Every project re-invents the same patterns. Every mistake can be repeated indefinitely.

The opportunity: build the layer that makes AI development compound. An agent system that gets measurably better with every task, carries wisdom across sessions, and ships consistently high-quality code through standardized templates and design systems.

The goal: in 6 months, our system should measurably outperform a fresh Claude Code session on the categories of tasks we do regularly. The benchmark framework will prove it.

---

## 2. Success Criteria

### Quantitative
- Task success rate (no manual intervention needed): > 85%
- Week-over-week benchmark score improvement: measurable positive trend
- Template quality: every scaffolded project has CI, a11y checks, design tokens
- Skill database growth: +2-5 new skills per week from real work
- KV-cache hit rate: > 80% (cost optimization)

### Qualitative
- Developer feels like the system "knows them" (past learnings applied)
- New projects start faster and with higher quality
- Regressions are caught automatically before they affect production

---

## 3. Self-Improvement Engine (Continuous Learning Loop)

### 3.1 Architecture

The self-improvement engine is a three-layer feedback system:

**Layer 1 — Fast Loop (seconds)**
In-session correction capture. When the user corrects the agent, the correction is immediately applied to the current session context AND recorded to the ledger.

**Layer 2 — Medium Loop (hours)**
Post-session synthesis. A `post-session` hook runs at session end, summarizing what was built, what failed, and what was learned. The summary is automatically recorded to the learning ledger.

**Layer 3 — Slow Loop (weeks)**
Benchmark-driven improvement. Weekly benchmark runs measure absolute capability. Results feed the skill curator, which identifies weak skills and evolves them using CASCADE three-strategy evolution.

### 3.2 Learning Ledger Schema

```typescript
interface Learning {
  id: string;               // UUID
  timestamp: string;        // ISO 8601
  type: 'correction' | 'success' | 'pattern' | 'skill-update';
  content: string;          // The learning itself
  context: {
    project_dir: string;    // Which project
    task: string;           // What was being done
    files_modified: string[]; // Which files were touched
  };
  confidence: number;       // 0.0 - 1.0
  tags: string[];           // For retrieval
  project_dir: string;      // Scoped to project (for project-specific retrieval)
}
```

### 3.3 Skills as the Compound Asset

Skills are the primary vehicle for accumulated intelligence. Unlike the learning ledger (which stores corrections and patterns), skills are executable procedures — they don't just know what to do, they guide the agent through doing it.

**Skills compound because**:
- Success cases update `success_rate` upward
- Failure cases trigger evolution that makes the skill better
- New edge cases are added to `failure_modes`
- Related skills link to each other via `related_skills`
- Over time, a mature skill is far better than a freshly written one

**Skill Quality Lifecycle**:
```
New Skill → quality: 0.5 (neutral)
After 10 successes → quality: 0.8
After first failure → evolution runs
After evolution + 5 more successes → quality: 0.9
After sustained failures → quality < 0.4 → deprecated
```

### 3.4 Hooks Implementation

New hooks to implement (in `hooks/` directory):

**`hooks/post-error.ts`**
```typescript
// Fires after any tool call error
interface ErrorHookEvent {
  tool: string;
  error: string;
  retry_count: number;
  file_context: string[];
  task_context: string;
}

export async function onError(event: ErrorHookEvent) {
  // Record error pattern
  if (event.retry_count >= 2) {
    await recordLearning({
      type: 'correction',
      content: `When using ${event.tool}: ${event.error}. Context: ${event.task_context}`,
      confidence: 0.85,
    });
  }
  // If retry_count >= 3: trigger controlled diversity (raise temperature)
}
```

**`hooks/post-session.ts`**
```typescript
export async function onSessionEnd(session: Session) {
  const summary = await generateSessionSummary(session);
  await recordLearning({
    type: 'pattern',
    content: summary.text,
    confidence: 0.7,
    context: { files_modified: summary.filesModified },
  });
}
```

---

## 4. Benchmark Framework

### 4.1 Purpose

The benchmark framework answers: "Is the system getting better?" Without measurement, there is no improvement — only activity.

### 4.2 Three-Tier Benchmark Suite

**Tier 1 — Regression Suite** (Daily)
- Source: Our own successful past tasks, converted to repeatable tests
- Format: Standard task JSON with expected output patch
- Size: 20-50 tasks
- Run time: < 5 minutes
- Pass threshold: 100% (any regression is a blocker)

**Tier 2 — Capability Benchmarks** (Weekly)
- Source: SWE-bench Verified (50-task sample), LiveCodeBench (20 tasks)
- Run time: 2-4 hours
- Score threshold: Must not decline week-over-week

**Tier 3 — Long-Horizon Benchmarks** (Monthly)
- Source: SWE-EVO sequences, custom multi-step tasks
- Run time: 4-8 hours
- Output: Sequence completion rate, error compounding analysis

### 4.3 Benchmark Runner Agent Design

The `benchmark-runner` agent:
1. Reads tasks from benchmark database
2. Creates isolated execution environment per task
3. Runs the agent (with skill loading) on each task
4. Compares output to expected output using a verifier
5. Records scores to `benchmark_history.json`
6. Generates improvement curve visualization
7. Alerts via Telegram if regression detected

---

## 5. New Stack Templates (6)

### 5.1 web-shadcn-v4

**Purpose**: Replace `web-app` as the primary modern web template.

**Stack**:
```
Next.js 15 (App Router)
+ shadcn/ui (latest)
+ Tailwind v4 (CSS-first @theme)
+ OKLCH color tokens
+ TypeScript strict mode
+ Vitest + Testing Library
+ Playwright (E2E)
+ eslint-plugin-jsx-a11y
+ Prettier
+ .devcontainer/
+ .github/workflows/ci.yml
+ DESIGN.md
```

**Key innovations vs current web-app**:
- OKLCH color system (mathematical, accessible by design)
- Tailwind v4 @theme (no more tailwind.config.js)
- WCAG 2.2 AA from day one (jsx-a11y + axe-core)
- DESIGN.md documents the design system

See `12-new-templates-spec.md` for full spec.

### 5.2 mobile-gluestack

**Purpose**: Replace `mobile-nativewind` with a modern universal component template.

**Stack**: Expo SDK 54 + Gluestack UI v3 + NativeWind v4 + Expo Router

### 5.3 saas-complete

**Purpose**: A true batteries-included SaaS template with all the hard parts done.

**Stack**: Next.js + Stripe + NextAuth + Prisma + Admin Dashboard + RBAC

### 5.4 ai-rag-complete

**Purpose**: Production-ready RAG application with multi-provider support.

**Stack**: Next.js + AI SDK v3 + pgvector + multi-provider + tool calling

### 5.5 monorepo

**Purpose**: Turborepo starter for multi-package projects.

**Stack**: Turborepo + pnpm + apps/web + apps/api + packages/ui

### 5.6 email-templates

**Purpose**: Transactional email system with preview.

**Stack**: React Email + Resend + preview server

---

## 6. Design Token System

### 6.1 Architecture

Single source of truth: `tokens/tokens.json` in W3C DTCG format.

Transform pipeline: Style Dictionary v4 → CSS + Tailwind + iOS + Android

Three token tiers:
- **Reference**: All available values (e.g., every shade of every color)
- **Semantic**: What tokens mean (e.g., "primary" = a specific reference token)
- **Component**: Component-specific overrides (rarely used)

### 6.2 Token File Structure

```
tokens/
├── tokens.json          # W3C DTCG source of truth
├── tokens.resolved.json # Fully resolved (generated, don't edit)
├── style-dictionary.config.js  # Transform config
└── outputs/
    ├── globals.css      # CSS custom properties (OKLCH)
    ├── tailwind.ts      # Tailwind v4 theme extension
    ├── ios/
    │   └── Colors.swift # iOS UIColor extensions
    └── android/
        └── colors.xml   # Android color resources
```

### 6.3 CI Integration

Every template's CI pipeline runs `pnpm tokens:build` to regenerate token outputs. If the output differs from committed output, the CI fails. This ensures token outputs are always in sync with the source.

---

## 7. Accessibility Framework

### 7.1 Target

WCAG 2.2 AA compliance for all web templates. WCAG 2.2 AA is the legal requirement in most jurisdictions (EU, US, Canada, Australia).

### 7.2 Three-Layer Approach

**Static Analysis**: `eslint-plugin-jsx-a11y` catches many issues at write time.

**Runtime Testing**: `axe-core` in Vitest catches issues that static analysis misses (contrast ratios, ARIA states).

**Integration Testing**: Playwright + axe integration catches full-page accessibility at the E2E level.

### 7.3 Non-Negotiable Requirements

Every React component in every template must have:
- All interactive elements have accessible labels (`aria-label` or visible text)
- All images have `alt` text
- Focus is visible (`:focus-visible` styles)
- Color is never the sole means of conveying information
- Contrast ratio ≥ 4.5:1 for normal text, 3:1 for large text

---

## 8. CI/CD Template Scaffolding

### 8.1 Standard CI Pipeline

Every project gets `.github/workflows/ci.yml` containing:
1. Install dependencies (`pnpm install --frozen-lockfile`)
2. Type check (`pnpm typecheck`)
3. Lint (`pnpm lint`)
4. Unit tests + coverage (`pnpm test:coverage`)
5. Coverage threshold check (70% lines minimum)
6. Build (`pnpm build`)
7. Accessibility audit (`pnpm audit:a11y`)

### 8.2 Dependabot Configuration

Every project gets `.github/dependabot.yml`:
- Automatic dependency update PRs
- Weekly schedule for npm packages
- Group updates by type (development, production, security)
- Auto-merge for patch updates passing CI

### 8.3 Branch Protection

Recommended branch protection rules (documented in README):
- Require PR reviews (at least 1)
- Require status checks to pass (ci.yml)
- No force push to main
- No direct push to main

---

## 9. Non-Goals

This design explicitly does NOT include:
- Fine-tuning any model (requires infrastructure beyond scope)
- Building a custom vector database (use existing MCP tools)
- Replacing Claude Code (we extend it, not replace it)
- Building a UI dashboard (Telegram + JSONL logs are sufficient)
- Multi-user support (single developer system)

---

## 10. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Benchmark harness is inaccurate | Medium | High | Use established benchmarks (SWE-bench) as primary, custom only for regression |
| Skill evolution breaks working skills | Low | High | Never modify skills in place — create new version, A/B test before promotion |
| Token pipeline breaks existing styles | Medium | Medium | Diff output before committing, require explicit review for breaking changes |
| CI/CD template doesn't work on all projects | Medium | Medium | Test on 3+ project types before adding to all templates |
| KV-cache optimization breaks cross-session context | Low | Medium | Test with and without cache, verify identical outputs |
