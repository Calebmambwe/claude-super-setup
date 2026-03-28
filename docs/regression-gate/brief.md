# Feature Brief: Regression Gate

**Date:** 2026-03-28
**Status:** Brief
**Author:** Caleb Mambwe
**Feature Name:** `regression-gate`

---

## Problem

Claude delivers apps with broken links, dead workflows, missing pages, half-wired features, console errors, and broken API routes. There is no automated quality gate that catches these before declaring "done." The user receives apps that look complete but fall apart on first interaction — broken navigation, 404 pages, forms that don't submit, images that don't load, APIs that return 500s.

Current checks (`/check`) run code review and security audit but **never actually load the app in a browser** to verify it works. The visual verification tools exist but are optional and often skipped.

## Solution

Build a **mandatory regression gate** — a tiered automated testing engine that runs at different depths depending on the pipeline stage. Uses Playwright for browser testing and curl for API testing. **Blocks shipping if any critical issue is found.**

### 3-Tier Architecture

```
Tier 1: SMOKE (30s) — runs in /check
  ├── TypeScript/lint/build passes
  ├── Dev server starts without errors
  ├── Homepage loads (200 status)
  ├── Zero console errors on page load
  └── No broken internal links (href="#" or href="" excluded)

Tier 2: FULL (2min) — runs in /auto-ship
  ├── Everything in Tier 1
  ├── ALL routes return 200 (crawl sitemap or route manifest)
  ├── ALL API endpoints respond (health check each /api/* route)
  ├── ALL images/assets load (no 404s)
  ├── ALL forms have action handlers (no dead forms)
  ├── Navigation flow works (click every nav link, verify page loads)
  ├── Responsive check at 375px, 768px, 1440px (no horizontal scroll)
  └── Basic accessibility (no missing alt text, no empty buttons)

Tier 3: EXHAUSTIVE (5min) — runs in /ghost
  ├── Everything in Tier 2
  ├── Full user flows (signup → dashboard → action → logout)
  ├── Form submission + validation (submit with empty/invalid data)
  ├── Auth flow (login, protected routes redirect, logout)
  ├── Edge cases (rapid clicks, back button, refresh mid-flow)
  ├── Performance (LCP < 3s, no layout shift > 0.1)
  ├── Full WCAG 2.2 AA accessibility audit
  └── API error handling (send bad data, verify graceful error responses)
```

### Integration Points

| Pipeline Command | Gate Tier | Blocking? |
|-----------------|-----------|-----------|
| `/check` | Tier 1 (smoke) | Yes — fails the check |
| `/auto-ship` | Tier 2 (full) | Yes — blocks shipping |
| `/ghost` / `/ghost-run` | Tier 3 (exhaustive) | Yes — blocks PR creation |
| `/dev` | Tier 1 (smoke) | Yes — after build phase |
| `/visual-verify` | Tier 2 (full) | Standalone — reports only |

### How It Works

```
1. Detect project type (Next.js, React, API-only, static)
2. Start dev server if not running (pnpm dev / npm run dev)
3. Wait for server ready (poll health endpoint)
4. Run tier-appropriate checks via Playwright + curl
5. Collect results into structured report
6. If CRITICAL issues found → BLOCK with detailed failure report
7. If WARNINGS only → WARN but allow shipping
8. Generate report at docs/{project}/regression-report.md
```

### Output Format

```
╔══════════════════════════════════════════╗
║  REGRESSION GATE — Tier 2 (Full)        ║
╠══════════════════════════════════════════╣
║  Links:        42 checked, 0 broken     ║
║  API Routes:   8 checked, 0 failing     ║
║  Console:      0 errors, 2 warnings     ║
║  Images:       15 loaded, 0 missing     ║
║  Forms:        3 checked, 0 dead        ║
║  Navigation:   12 links, all working    ║
║  Responsive:   3 viewports, no issues   ║
║  Accessibility: 0 critical, 1 warning   ║
╠══════════════════════════════════════════╣
║  VERDICT: ✅ PASS (0 critical, 3 warns) ║
╚══════════════════════════════════════════╝
```

## Target User

Caleb (solo developer) — receives apps from Claude via `/auto-dev`, `/ghost`, `/auto-ship`. Needs confidence that delivered apps actually work before reviewing.

## Core Constraints

- Must work with Next.js, React, and API-only projects (auto-detect)
- Must use Playwright MCP tools (already installed)
- Must not require any manual configuration — auto-discovers routes, links, forms
- Must complete Tier 1 in <30s, Tier 2 in <2min, Tier 3 in <5min
- Must integrate into existing pipeline commands without breaking them

## Tech Stack

- **Browser testing:** Playwright MCP tools (browser_navigate, browser_snapshot, browser_console_messages, browser_click)
- **API testing:** curl with structured output parsing
- **Link crawling:** Playwright DOM snapshot → extract all `<a href>` + `<img src>`
- **Form detection:** Playwright snapshot → find `<form>` elements, verify they have handlers
- **Responsive:** Playwright browser_resize at 3 breakpoints
- **Accessibility:** axe-core via Playwright evaluate, or Playwright snapshot analysis
- **Server management:** Detect package.json scripts, start dev server, wait for ready

## Out of Scope (v1)

- E2E testing of third-party integrations (Stripe, OAuth providers)
- Visual regression screenshot comparison (handled by /visual-regression)
- Load/stress testing
- Database seeding for test data
- Mobile native app testing
- Cross-browser testing (Chromium only)

## Success Metrics

- Zero broken links shipped in any project
- Zero console errors on any page
- Zero 404 API routes
- All forms functional (no dead forms)
- Regression gate blocks 90%+ of broken builds before human review
- Average run time: Tier 1 <30s, Tier 2 <2min, Tier 3 <5min

## Implementation Plan

### Phase 1: Core Engine + Tier 1 (Day 1)
- `scripts/regression-gate.sh` — main orchestrator
- Server detection and startup
- Link checker (crawl all `<a href>`)
- Console error detector
- Build/typecheck verification
- Integration into `/check` command

### Phase 2: Tier 2 Checks (Day 2)
- API route health checker
- Image/asset verification
- Form handler detection
- Navigation flow tester
- Responsive breakpoint checker
- Basic accessibility checks
- Integration into `/auto-ship`

### Phase 3: Tier 3 + Pipeline Integration (Day 3)
- User flow runner (configurable per project)
- Performance metrics (LCP, CLS)
- Full accessibility audit
- Integration into `/ghost`
- PostToolUse hook for auto-run after builds
- Structured report generation

---

## PR/FAQ: Regression Gate

### Press Release

**LUSAKA, March 2026** — Twendai Software today announced Regression Gate, a mandatory quality gate that automatically tests every app Claude builds before shipping. Starting immediately, developers can trust that every delivered app has zero broken links, zero console errors, and every feature works end-to-end.

Every developer using AI agents to build apps has experienced the same frustration: Claude says "done," you open the app, and half the links are broken, forms don't submit, and there are console errors everywhere. You spend more time fixing the "finished" app than it would have taken to build it yourself. The problem isn't that Claude can't code — it's that Claude doesn't test what it builds from the user's perspective.

"I used to dread opening the apps Claude built for me," said a solo developer. "Now Regression Gate catches everything before I even see it. Last week it blocked a build that had 7 broken links and a form that submitted to nowhere. Claude fixed all of them automatically before I even knew about them."

Regression Gate works in three tiers: a 30-second smoke test during development, a 2-minute full check before shipping, and a 5-minute exhaustive audit for overnight Ghost Mode builds. It uses Playwright to actually load every page, click every link, submit every form, and verify every API route responds. If anything fails, it blocks the build and tells Claude exactly what to fix.

Unlike linters and type checkers that only verify code structure, Regression Gate tests the actual running application from a user's perspective. It finds the bugs that only appear when you actually use the app — the ones that make AI-built software feel unfinished.

To get started, Regression Gate activates automatically in all pipeline commands. No configuration needed.

### Frequently Asked Questions

**Q: Who is this for?**
A: Solo developers and teams using Claude's autonomous pipelines (/auto-dev, /ghost, /auto-ship) who need confidence that delivered apps actually work.

**Q: How is this different from running tests?**
A: Unit tests verify code logic. Regression Gate verifies the actual running application — it opens the browser, clicks links, submits forms, and checks API responses. It catches the 80% of bugs that only appear when you actually use the app.

**Q: What does it cost?**
A: Zero — uses Playwright (already installed) and curl. No API keys, no external services.

**Q: What if it blocks a build incorrectly?**
A: Warnings never block. Only CRITICAL issues (broken links, console errors, 404 routes) block. You can override with `--skip-gate` flag for emergency deployments.

**Q: When will it be available?**
A: Tier 1 (smoke) ships in 1 day. Full integration in 3 days.

**Q: How long will this take to build?**
A: 3 phases over 3 days. Phase 1 delivers immediate value (Tier 1 smoke test).

**Q: What are the biggest risks?**
A: 1) Server startup detection may fail for non-standard setups. 2) Playwright may not be available on VPS. 3) Dynamic routes (auth-protected pages) need special handling.

**Q: What are we NOT building?**
A: No visual regression (screenshot comparison), no load testing, no cross-browser testing, no mobile native testing, no third-party integration testing.

**Q: How will we measure success?**
A: 1) Zero broken links shipped. 2) Zero console errors shipped. 3) Gate blocks 90%+ of broken builds. 4) Tier 1 completes in <30s.

**Q: What's the rollback plan?**
A: The gate is an additive check — removing it just means removing the hook. All existing functionality continues unchanged.
