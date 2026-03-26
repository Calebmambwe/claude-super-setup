# Super Claude Code: Vision Document

## The Goal

Make claude-super-setup the **best autonomous app builder in existence** — surpassing Cursor, Same.new, Bolt, Lovable, and v0 in output quality while maintaining the flexibility of a CLI-first workflow.

## What "Best" Means

1. **Generated apps look indistinguishable from hand-crafted premium products** — not "AI-generated looking"
2. **Zero dead links, zero console errors, zero visual bugs** on first generation
3. **Mobile-first by default** — every generated app works perfectly on phones
4. **Full-stack from one command** — auth, database, API, frontend, deployment
5. **Self-healing pipeline** — catches and fixes its own mistakes automatically
6. **Visual verification** — screenshots and compares against expectations
7. **Enterprise-grade** — accessible, secure, performant, tested

## Core Principles

### 1. Pipeline Over Prompting
Never generate code from a raw prompt. Always: Scan/Research → Brief → Design Doc → Tasks → Build → Verify → Fix → Ship. Every step adds precision.

### 2. Ground Truth Over Approximation
When cloning: use the actual source repo's CSS/config. When building: use Context7 for library docs. Never guess API signatures, color values, or font names.

### 3. Design System as Law
Every generated component MUST use design tokens. No hardcoded hex values. No arbitrary spacing. The design system enforces visual consistency automatically.

### 4. Test at Every Step
After every file write: typecheck. After every component: visual snapshot. After every page: E2E test. After every build: full test suite. Continuous verification, not end-of-pipeline testing.

### 5. Mobile-First Always
Start with mobile layout. Add breakpoints up. Test on 390px viewport. Every animation must work without JS (noscript fallback). Every touch target must be 44px+.

### 6. Self-Improvement Loop
Track what fails. Record learnings. Evolve skills. Benchmark regularly. The system gets better with every project it builds.

## Architecture: The Super Builder Pipeline

```
User Input (prompt, URL, or spec)
    │
    ▼
┌─────────────────────────────────────────┐
│  Phase 0: RESEARCH                       │
│  - Context7 for library docs             │
│  - WebSearch for patterns/templates      │
│  - Source repo discovery (for clones)    │
│  - Design token extraction               │
└────────────────┬────────────────────────┘
                 │
    ▼
┌─────────────────────────────────────────┐
│  Phase 1: PLAN                           │
│  - Brief generation                      │
│  - Design doc with Mermaid diagrams      │
│  - Component inventory                   │
│  - Task decomposition (max 15)           │
│  - Human approval gate                   │
└────────────────┬────────────────────────┘
                 │
    ▼
┌─────────────────────────────────────────┐
│  Phase 2: SCAFFOLD                       │
│  - Template selection (22+ templates)    │
│  - Design token application              │
│  - CI/CD setup                           │
│  - Dev container setup                   │
│  - Git init + branch                     │
└────────────────┬────────────────────────┘
                 │
    ▼
┌─────────────────────────────────────────┐
│  Phase 3: BUILD (Ralph Loop per task)    │
│  For each task:                          │
│    1. Plan the implementation            │
│    2. Write code (design system enforced)│
│    3. Typecheck + lint                   │
│    4. Run tests                          │
│    5. Visual snapshot                    │
│    6. If fail → fix (max 3 attempts)     │
│    7. Mark complete                      │
│  Parallel execution where safe           │
└────────────────┬────────────────────────┘
                 │
    ▼
┌─────────────────────────────────────────┐
│  Phase 4: VERIFY                         │
│  - Full E2E test suite                   │
│  - Visual regression (all viewports)     │
│  - Accessibility audit (WCAG 2.2 AA)    │
│  - Security scan (OWASP Top 10)          │
│  - Performance check (Lighthouse)        │
│  - Dead link check                       │
│  - Console error check                   │
│  - Mobile responsiveness check           │
└────────────────┬────────────────────────┘
                 │
    ▼
┌─────────────────────────────────────────┐
│  Phase 5: FIX (up to 3 iterations)       │
│  - Auto-fix every finding from Phase 4   │
│  - Re-run verification after fixes       │
│  - If still failing → escalate to human  │
└────────────────┬────────────────────────┘
                 │
    ▼
┌─────────────────────────────────────────┐
│  Phase 6: SHIP                           │
│  - Code review (Opus agent)              │
│  - Commit with conventional message      │
│  - Create PR with full description       │
│  - Deploy preview                        │
│  - Send Telegram notification            │
│  - Record learnings                      │
└─────────────────────────────────────────┘
```

## Key Enhancements Needed

### A. Design Quality Engine
- Premium design system with OKLCH tokens, layered shadows, glass effects
- Component library with 50+ polished variants (not default shadcn)
- Animation library (SSR-safe Framer Motion patterns)
- Typography scale generator
- Color palette generator from any brand color

### B. Smart Template System
- 22+ templates covering every use case
- Each template includes: design tokens, CI/CD, E2E tests, Docker, README
- Template preview gallery (visual, not text)
- Auto-selection from natural language description

### C. Hook System
- Pre-write: design system compliance check
- Post-write: typecheck + lint
- Pre-commit: test suite
- Post-build: visual snapshot
- Error detection: auto-fix loop
- Budget guard: token/tool-call limits

### D. Visual Verification Pipeline
- Playwright screenshots at 3 viewports (390px, 768px, 1440px)
- Side-by-side comparison with reference screenshots
- DOM structure validation
- Accessibility tree check
- Console error capture
- Dead link detection

### E. Self-Healing Pipeline
- Error classification (syntax, type, runtime, visual)
- Auto-fix strategies per error type
- Max 3 retry attempts per task
- Escalation to human on persistent failures
- Learning from fixes (record to ledger)

### F. Full-Stack Generation
- Auth scaffold (Clerk/NextAuth/Supabase)
- Database schema + migrations (Drizzle/Prisma)
- API layer (server actions / tRPC / REST)
- Email templates (React Email + Resend)
- Payment integration (Stripe)
- File upload (S3/Supabase Storage)
- Real-time features (WebSocket/SSE)

### G. Collaboration System
- Mac + VPS parallel execution
- Task dispatch and result collection
- Shared learning ledger
- Telegram progress updates
- Human-in-the-loop testing with error capture
