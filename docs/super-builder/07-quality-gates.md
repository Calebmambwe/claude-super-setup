# 07 — Quality Gates

## Overview

Quality gates are the non-negotiable checkpoints that code must pass before advancing to the next pipeline phase. This document defines every gate, what it checks, how it is enforced, and what the failure response is.

The guiding principle: gates should be fast, specific, and actionable. A gate that says "something is wrong" is useless. A gate that says "line 42 in Button.tsx uses a hardcoded hex color — change to var(--color-primary)" is useful.

---

## Gate Architecture

```
[Write/Edit] → Gate 1: Pre-write     (blocks bad input before disk write)
     │
     ▼
[File on disk] → Gate 2: Post-write   (type check, format, lint on each file)
     │
     ▼
[Task done] → Gate 3: Pre-commit     (full test suite, visual regression)
     │
     ▼
[Branch ready] → Gate 4: Pre-PR      (security, code review, accessibility)
     │
     ▼
[Merged] → Gate 5: Post-deploy      (smoke tests, monitoring, rollback sentinel)
```

---

## Gate 1: Pre-Write

**Trigger:** `PreToolUse` on `Write|Edit|MultiEdit`
**Mode:** Blocking (exit 2 halts the tool call)
**Target audience:** Claude (the message goes back into its context)

### 1A — Sensitive File Guard

**What it checks:** Is the target file path in the protected list?

Protected paths:
- `.env`, `.env.local`, `.env.production`, `.env.staging`
- `package-lock.json`, `yarn.lock`, `bun.lockb`
- `.git/` (any path containing this)

Exceptions (allowed):
- `.env.example`, `.env.sample`, `.env.test`

**Response on failure:** Exit 2. Message: "Write to [path] blocked. This file is protected. If you need to update environment variables, edit .env.example and document the new variable."

### 1B — Design System Compliance Gate

**What it checks:** Does the content being written violate design token rules?

Rules enforced:

| Violation | Pattern | Allowed alternative |
|-----------|---------|-------------------|
| Hardcoded hex (non-black/white) | `#[0-9a-f]{3,8}` | `var(--color-*)` or Tailwind color class |
| Raw z-index ≥ 10 | `z-index: \d{2,}` | Tailwind `z-10`, `z-20`, `z-50` |
| Magic pixel value | `padding: 17px` | Tailwind spacing or `--spacing-*` |
| Raw opacity fraction | `opacity: 0.35` | Tailwind `opacity-35` or `--opacity-*` |
| Hardcoded font stack | `font-family: Arial` | `var(--font-sans)` or Tailwind font class |

**File scope:** `.ts`, `.tsx`, `.css`, `.scss`, `.module.css`

**Exempt files:** `tailwind.config.*`, `tokens.ts`, `theme.ts`, `design-system/*`

**Response on failure:** Exit 2. Message lists each violation with the specific value found and the correct alternative.

### 1C — Component Reuse Warning

**What it checks:** When creating a new component file, does a component with a similar name already exist?

**Mode:** Warning only (exit 1 — Claude sees it, execution continues)

**Response on warning:** "Similar component found at [path]. Consider extending it rather than creating a new one. If you are creating a variant, suffix with the variant name (e.g., ButtonOutline, ButtonGhost)."

### 1D — TypeScript `any` Ban

**What it checks:** Does the content being written contain `any` type usage?

Pattern to flag:
- `: any` (type annotation)
- `as any` (type assertion)
- `<any>` (generic)
- `(any)` in JSDoc

**Exceptions:** `// eslint-disable-next-line @typescript-eslint/no-explicit-any` (deliberate, documented)

**Response on failure:** Exit 2. Message: "TypeScript `any` detected at [location]. Use `unknown` + a type guard, or define a proper interface. `any` disables type safety for all downstream callers."

---

## Gate 2: Post-Write

**Trigger:** `PostToolUse` on `Write|Edit|MultiEdit`
**Mode:** Non-blocking (exit 1 — errors fed to Claude as context)
**Purpose:** Catch errors immediately after each file write, while the context is fresh

### 2A — Auto-Formatter

**Tool:** Prettier
**Config:** `.prettierrc` in project root
**Timing:** Async (does not block next tool call)

```bash
pnpm prettier --write "$FILE_PATH"
```

No failure action needed — Prettier always succeeds or is a no-op.

### 2B — TypeScript Incremental Check

**Tool:** `tsc --noEmit --incremental`
**Scope:** The project (not just the changed file — imports cascade)
**Timing:** Async with 60s timeout

```bash
pnpm tsc --noEmit --skipLibCheck 2>&1 | head -30
```

**Response on failure:** Exit 1. The first 30 lines of TypeScript error output are injected into Claude's context as `PostToolUseFailure.additionalContext`. Claude's next turn will fix the errors before proceeding.

### 2C — ESLint Check

**Tool:** ESLint
**Config:** `.eslintrc` or `eslint.config.js` in project root
**Timing:** Async with 30s timeout
**Scope:** The changed file only (faster than full project)

```bash
pnpm eslint "$FILE_PATH" --max-warnings 0 2>&1 | head -20
```

**Response on failure:** Exit 1 with lint errors in context. Claude will fix the lint issues before moving to the next file.

---

## Gate 3: Pre-Commit

**Trigger:** Git pre-commit hook (`/.git/hooks/pre-commit`) or manually via `/check`
**Mode:** Blocking (non-zero exit blocks the commit)
**Purpose:** Ensure the full task output is coherent before any code is committed

### 3A — Full Test Suite

**Tool:** Vitest (TypeScript projects) / pytest (Python projects)
**Command:**
```bash
pnpm test --run --reporter=verbose
```

**Pass criteria:** All tests pass. Coverage does not drop below the baseline in `vitest.config.ts` (typically 80%).

**Response on failure:** List of failing tests with file paths and line numbers. The commit is blocked. Do not proceed until tests pass.

### 3B — TypeScript Full Check

**Tool:** `tsc --noEmit`
**Command:**
```bash
pnpm typecheck
```

**Pass criteria:** Zero TypeScript errors.

**Response on failure:** Full tsc error output. Commit blocked.

### 3C — Lint Full Check

**Tool:** ESLint
**Command:**
```bash
pnpm lint
```

**Pass criteria:** Zero errors, zero warnings (strict mode).

### 3D — Visual Regression Check

**Tool:** Playwright snapshot comparison
**Command:**
```bash
pnpm playwright test --project=visual
```

**Pass criteria:** All screenshots match baseline within configured threshold (`maxDiffPixels: 50`, `threshold: 0.2`).

**Viewports tested:**
- 375 × 812 (Mobile S)
- 768 × 1024 (Tablet)
- 1440 × 900 (Desktop)

**Response on failure:**
1. Report which components have visual diffs
2. Save diff images to `.playwright/diffs/`
3. If the change is intentional: run `pnpm playwright test --update-snapshots` to update baseline
4. If the change is a regression: revert the visual change before committing

### 3E — No Debug Artifacts

**Tool:** Grep
**Command:**
```bash
grep -rn "console\.log\|debugger\|TODO.*REMOVE\|FIXME.*COMMIT" src/ --include="*.ts" --include="*.tsx"
```

**Pass criteria:** Zero matches.

**Response on failure:** List the files and line numbers containing debug artifacts. Remove before committing.

---

## Gate 4: Pre-PR

**Trigger:** Before creating a GitHub PR. Invoked by `/check` or automatically by `/ship`.
**Mode:** All gates must pass before PR is created.

### 4A — Security Audit

**Tool:** `semgrep` or `npm audit`
**Commands:**
```bash
# Dependency vulnerabilities
pnpm audit --audit-level=moderate

# Static code security scan
npx semgrep --config=p/typescript --config=p/react --error
```

**Pass criteria:**
- Zero high or critical dependency vulnerabilities
- Zero semgrep errors in security rulesets

**Response on failure:**
- Dependency vulnerabilities: run `pnpm audit fix` for auto-fixable issues. For non-auto-fixable: document in PR description with a remediation timeline.
- Semgrep findings: fix before PR. No exceptions for high/critical.

### 4B — AI Code Review

**Tool:** Claude agent (prompt hook) or `gh` + an agent call
**What it checks:**
- Logic correctness (does the implementation match the spec?)
- Edge case handling (null, undefined, empty array, network failure)
- Performance anti-patterns (N+1 queries, unnecessary re-renders, missing memoization)
- Naming and readability (is the code self-documenting?)

**Format of review output:**
```
CRITICAL (blocks PR):
  - [file:line] Description of critical issue

WARNING (must document if not fixed):
  - [file:line] Description of warning

SUGGESTION (optional improvement):
  - [file:line] Description of suggestion
```

**Pass criteria:** Zero CRITICAL findings.

### 4C — Accessibility Audit

**Tool:** axe-core via Playwright
**Command:**
```bash
pnpm playwright test --project=a11y
```

**What it checks:**
- WCAG 2.2 Level AA compliance
- All images have alt text
- All form inputs have labels
- Color contrast ratio ≥ 4.5:1 (normal text), ≥ 3:1 (large text)
- Interactive elements are keyboard-accessible
- Focus indicators are visible
- ARIA roles are used correctly

**Pass criteria:** Zero critical or serious violations. Moderate violations are documented in the PR.

**Playwright test structure:**
```typescript
import { checkA11y } from 'axe-playwright';

test.describe('Accessibility audit', () => {
  const routes = ['/', '/login', '/dashboard', '/settings'];

  for (const route of routes) {
    test(`${route} passes WCAG 2.2 AA`, async ({ page }) => {
      await page.goto(route);
      await checkA11y(page, undefined, {
        runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'],
        detailedReport: true,
      });
    });
  }
});
```

### 4D — Bundle Size Gate

**Tool:** `bundlesize` or `next build` with bundle analysis
**Command:**
```bash
pnpm build
pnpm bundlesize
```

**Thresholds (TypeScript/React project defaults):**
| Asset | Max size (gzipped) |
|-------|-------------------|
| Initial JS bundle | 200 KB |
| CSS bundle | 50 KB |
| Largest page bundle | 150 KB |

**Response on failure:** Investigate what caused the bundle increase. Common causes: importing entire libraries instead of named exports, dynamic imports not code-splitting, assets not optimized.

### 4E — Dead Link Check (if documentation changed)

**Tool:** `linkcheck` or `broken-link-checker`

Only fires when files in `docs/`, `README.md`, or `*.md` are modified.

```bash
npx broken-link-checker http://localhost:3000 --recursive --ordered
```

**Pass criteria:** Zero broken internal links (4xx, 5xx). External links are warned but do not block.

---

## Gate 5: Post-Deploy

**Trigger:** After merge to main + successful CI deployment
**Mode:** Observational + automatic rollback trigger on critical failure

### 5A — Smoke Tests

**Tool:** Playwright against the deployed URL
**What it tests:** The 5 most critical user journeys (defined per project):

Template smoke test suite:
```typescript
test.describe('Smoke tests — [environment]', () => {
  test('home page loads', async ({ page }) => {
    await page.goto(process.env.DEPLOY_URL!);
    await expect(page).toHaveTitle(/expected title/);
    await expect(page.getByRole('main')).toBeVisible();
  });

  test('authentication flow works', async ({ page }) => {
    // login → dashboard → logout
  });

  test('primary CTA is clickable and functional', async ({ page }) => {
    // The main action the product exists to enable
  });

  test('error pages render correctly', async ({ page }) => {
    await page.goto(`${process.env.DEPLOY_URL}/nonexistent-page`);
    await expect(page.getByText('404')).toBeVisible();
  });
});
```

**Pass criteria:** All 5 smoke tests pass within 30 seconds.

**Response on failure:**
1. Fire immediate Telegram alert
2. If 2+ smoke tests fail: trigger automatic rollback (revert the merge commit)
3. If 1 smoke test fails: alert + manual review within 30 minutes

### 5B — Core Web Vitals Monitoring

**Tool:** Lighthouse CI
**Command (in CI post-deploy step):**
```bash
npx lhci autorun --upload.target=temporary-public-storage
```

**Thresholds:**
| Metric | Target | Failure threshold |
|--------|--------|------------------|
| LCP | ≤ 2.5s | > 4.0s |
| CLS | ≤ 0.1 | > 0.25 |
| FID/INP | ≤ 200ms | > 500ms |
| Performance score | ≥ 85 | < 70 |
| Accessibility score | ≥ 95 | < 85 |

**Response on threshold breach:** Telegram alert with specific metrics and comparison to previous deploy. No automatic rollback — requires human decision.

### 5C — Error Rate Monitoring

**Integration:** Sentry / OpenTelemetry (project-specific setup)

Post-deploy window: monitor for 15 minutes after deploy.

Alert conditions:
- Error rate spikes > 5% above pre-deploy baseline
- New error type appears with > 10 occurrences in 5 minutes
- P99 API response time increases > 200ms

**Response on alert:** Telegram message. If error rate > 20% above baseline: automatic rollback.

### 5D — Rollback Sentinel

The rollback sentinel is a background process running for 30 minutes post-deploy. It:

1. Polls smoke tests every 5 minutes
2. Monitors error rate
3. Compares Core Web Vitals to baseline

Rollback trigger conditions (automatic):
- Smoke test failure rate > 40%
- Error rate > 20% above pre-deploy baseline
- Server returning 5xx on > 5% of requests

Rollback procedure:
```bash
# Revert the PR merge commit
git revert -m 1 <merge-commit-sha> --no-edit
git push origin main

# Re-run deployment with reverted code
# Notify team via Telegram
```

---

## Gate Summary Table

| Gate | Phase | Blocking | Tools | Failure Response |
|------|-------|---------|-------|-----------------|
| 1A Sensitive file | Pre-write | Yes | Script | Block + explain |
| 1B Design system | Pre-write | Yes | Python script | Block + specific fix |
| 1C Component reuse | Pre-write | Warning | Bash/find | Warn, continue |
| 1D TypeScript any | Pre-write | Yes | Regex | Block + type alternative |
| 2A Auto-format | Post-write | No | Prettier | Silent fix |
| 2B TypeScript check | Post-write | No (context) | tsc | Errors in Claude context |
| 2C ESLint | Post-write | No (context) | ESLint | Errors in Claude context |
| 3A Test suite | Pre-commit | Yes | Vitest/pytest | Block, list failures |
| 3B TypeScript full | Pre-commit | Yes | tsc | Block, error list |
| 3C Lint full | Pre-commit | Yes | ESLint | Block, error list |
| 3D Visual regression | Pre-commit | Yes | Playwright | Block + diff images |
| 3E Debug artifacts | Pre-commit | Yes | Grep | Block, list locations |
| 4A Security audit | Pre-PR | Yes (high/crit) | semgrep, npm audit | Block or document |
| 4B AI code review | Pre-PR | Yes (critical) | Claude agent | CRITICAL blocks PR |
| 4C Accessibility | Pre-PR | Yes (critical) | axe-core | Block on critical violations |
| 4D Bundle size | Pre-PR | Yes | bundlesize | Block if over threshold |
| 4E Dead links | Pre-PR (docs) | Yes | linkcheck | Block on broken links |
| 5A Smoke tests | Post-deploy | Rollback | Playwright | Alert + auto-rollback on 2+ fail |
| 5B Core Web Vitals | Post-deploy | Alert | Lighthouse CI | Alert, manual decision |
| 5C Error rate | Post-deploy | Rollback | Sentry/OTel | Alert + auto-rollback on >20% |
| 5D Rollback sentinel | 30min window | Rollback | Custom | Auto-rollback on threshold |

---

## Gate Configuration Per Project Type

Not every project needs every gate. Default sets by project type:

### TypeScript/React Web App
All gates: 1A, 1B, 1C, 1D, 2A, 2B, 2C, 3A, 3B, 3C, 3D, 3E, 4A, 4B, 4C, 4D, 5A, 5B, 5C, 5D

### API Service (no UI)
Remove: 1B, 3D, 4C, 4D, 5B
Keep: 1A, 1C, 1D, 2B, 2C, 3A, 3B, 3C, 3E, 4A, 4B, 5A, 5C, 5D

### CLI Tool
Remove: 1B, 3D, 4C, 4D, 5A, 5B, 5C, 5D
Keep: 1A, 1D, 2B, 2C, 3A, 3B, 3C, 3E, 4A, 4B

### Mobile App (React Native)
Replace Playwright with Detox for 3D, 5A
Replace Lighthouse with Mobile Lighthouse for 5B
Keep all others

---

## Fast-Path Override

For tiny changes (1–2 files, no UI, trivial fix), gates 3D, 4B, 4C, and 4D may be skipped with explicit human approval. To mark a change as fast-path:

```
# In the commit message:
fix: correct typo in error message [fast-path: skip visual,a11y,bundle]
```

The pipeline reads the commit message and adjusts which gates fire. Fast-path cannot skip: 1A (security), 3A (tests), 4A (security audit), 5A (smoke tests).

---

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Why Your AI Agent Needs a Quality Gate](https://dev.to/yurukusa/why-your-ai-agent-needs-a-quality-gate-not-just-tests-42eo)
- [Autonomous Quality Gates — Augment Code](https://www.augmentcode.com/guides/autonomous-quality-gates-ai-powered-code-review)
- [AI-Assisted QA: Visual Regression Testing](https://www.newtarget.com/web-insights-blog/visual-regression-testing/)
- [Playwright Visual Comparisons](https://playwright.dev/docs/test-snapshots)
- [How VS Code Builds with AI](https://code.visualstudio.com/blogs/2026/03/13/how-VS-Code-Builds-with-AI)
- [How AI Agents Automated Our QA](https://openobserve.ai/blog/autonomous-qa-testing-ai-agents-claude-code/)
- [Building a QA Workflow with AI Agents](https://autonomyai.io/technology/building-a-qa-workflow-with-ai-agents-to-catch-ui-regressions/)
- [AI Agents in CI/CD — Mabl](https://www.mabl.com/blog/ai-agents-cicd-pipelines-continuous-quality)
- Context7 library ID: `/disler/claude-code-hooks-mastery`
