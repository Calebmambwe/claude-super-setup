# Template Enhancement Specification

## Current State

22 templates in `config/stacks/`. Most are YAML-only definitions without:
- Actual scaffold code
- Pre-configured design tokens
- E2E test suites
- Visual verification baselines
- Docker configurations
- CI/CD pipelines (some have them from the self-improvement engine)

## Target State

Every template should be a **complete, production-ready scaffold** that generates:
1. Working app with design tokens applied
2. CI/CD pipeline
3. E2E test suite
4. Docker configuration
5. README with setup instructions
6. Visual baseline screenshots

## Priority Templates (enhance first)

### Tier 1: Most Used
1. **web-shadcn-v4** — Next.js 15 + shadcn + Tailwind v4 (flagship)
2. **saas-complete** — Full SaaS with auth, billing, teams
3. **ai-rag-complete** — AI app with RAG pipeline

### Tier 2: High Demand
4. **mobile-gluestack** — Expo + Gluestack
5. **monorepo** — Turborepo multi-app
6. **api-fastapi** — Python API

### Tier 3: Specialized
7. **chrome-extension** — Browser extension
8. **cli-tool** — CLI application
9. **email-templates** — React Email + Resend

## Enhancement Checklist Per Template

### Design Tokens
- [ ] OKLCH color palette (reference → semantic → component tokens)
- [ ] Typography scale (Inter/Geist, 6 heading sizes, body, small, mono)
- [ ] Spacing scale (4px base, 8 stops)
- [ ] Shadow system (5 levels: sm, md, lg, xl, 2xl)
- [ ] Border radius scale (sm, md, lg, xl, 2xl, full)
- [ ] Animation tokens (duration, easing, spring configs)

### Components (shadcn-based templates)
- [ ] Navbar (desktop + mobile hamburger, scroll behavior)
- [ ] Footer (multi-column, newsletter, social)
- [ ] Hero section (gradient text, badge, CTA pair, mockup)
- [ ] Feature grid (asymmetric layout, glass cards, stat badges)
- [ ] Pricing table (3 tiers, comparison, toggle monthly/annual)
- [ ] Auth forms (sign in, sign up, forgot password)
- [ ] Dashboard layout (sidebar, header, content area)
- [ ] Settings page (tabs, form sections)
- [ ] Empty states (illustration + CTA)
- [ ] Error pages (404, 500 with personality)
- [ ] Loading states (skeleton, spinner, progress)

### Testing
- [ ] E2E spec: all pages load, navigation works, forms accept input
- [ ] Visual regression baseline screenshots (3 viewports)
- [ ] Accessibility audit configuration
- [ ] Lighthouse CI configuration

### Infrastructure
- [ ] Dockerfile (multi-stage build)
- [ ] docker-compose.yml (app + db + cache)
- [ ] .github/workflows/ci.yml (lint, typecheck, test, build)
- [ ] .devcontainer/ (VS Code dev container)
- [ ] .env.example with documented variables

### Documentation
- [ ] README.md (quick start, architecture, scripts)
- [ ] CONTRIBUTING.md
- [ ] CLAUDE.md (project conventions)

## Template Selection Intelligence

The `/new-app` command should use NLP to match descriptions to templates:

```
"I want to build a SaaS with user auth and billing"
→ saas-complete

"Build me a landing page for my startup"
→ web-shadcn-v4

"I need an AI chatbot with document upload"
→ ai-rag-complete

"Create a mobile app for food delivery"
→ mobile-gluestack

"Build a REST API for my IoT devices"
→ api-fastapi
```

Keywords → template mapping with confidence scoring.

## Design Token Generation

Given a brand color, auto-generate a complete palette:

```
Input: "#0081F2" (Manus blue)
Output:
  primary-50:  oklch(0.97 0.02 250)
  primary-100: oklch(0.93 0.04 250)
  primary-200: oklch(0.87 0.08 250)
  primary-300: oklch(0.78 0.12 250)
  primary-400: oklch(0.68 0.16 250)
  primary-500: oklch(0.58 0.18 250)  ← base
  primary-600: oklch(0.50 0.16 250)
  primary-700: oklch(0.42 0.14 250)
  primary-800: oklch(0.34 0.12 250)
  primary-900: oklch(0.26 0.10 250)
  primary-950: oklch(0.18 0.08 250)
```

Also generate complementary, analogous, and neutral palettes automatically.
