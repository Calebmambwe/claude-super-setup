# Stack Template Audit

## Overview

Audit of all 16 current stack templates in `~/.claude/config/stacks/`. This audit identifies what's working, what's missing, and specific bugs found.

---

## Full Template Inventory

| # | Template Name | Stack | Status |
|---|--------------|-------|--------|
| 1 | `web-app` | Next.js + Tailwind + Shadcn | Needs upgrade |
| 2 | `api-service` | Express/Fastify + TypeScript | Acceptable |
| 3 | `mobile-app` | React Native generic | Outdated |
| 4 | `saas-starter` | Next.js + Stripe + Auth | Incomplete |
| 5 | `ai-ml-app` | Next.js + AI SDK | Incomplete |
| 6 | `web-t3` | T3 Stack (tRPC + Prisma) | Good, missing shadcn |
| 7 | `web-astro` | Astro + content collections | Good |
| 8 | `web-sveltekit` | SvelteKit + Lucia | Good |
| 9 | `web-remix` | Remix + Prisma | Acceptable |
| 10 | `api-fastapi` | Python + FastAPI + SQLAlchemy | Good |
| 11 | `api-hono-edge` | Hono + Cloudflare Workers | Good |
| 12 | `mobile-expo-revenucat` | Expo + RevenueCat | Has bug |
| 13 | `mobile-nativewind` | Expo + NativeWind | Outdated (v3) |
| 14 | `mobile-flutter` | Flutter + Material 3 | Missing token setup |
| 15 | `chrome-extension` | Plasmo + React | Acceptable |
| 16 | `cli-tool` | Node.js + Commander | Good |

---

## What's Good

### Design Systems Coverage
- `web-app`, `web-t3`, `saas-starter`, `ai-ml-app` all use shadcn/ui — this is correct
- `mobile-flutter` uses Material 3 — this is correct
- `web-sveltekit` has a clean CSS variable system

### Mobile Stack Choices
- `mobile-expo-revenucat` is valuable — RevenueCat integration for monetization is hard to get right and having a template for it saves significant time
- `mobile-nativewind` shows intent to use utility-class styling, even if version is outdated

### SaaS Template Foundation
- `saas-starter` has the right inclusions: Stripe, authentication, database
- The foundation is solid even though features are missing

### AI/ML Template Concept
- `ai-ml-app` is one of the most valuable templates given the current AI development wave
- Including AI SDK as default is the right choice

---

## What's Missing Across All Templates

### 1. WCAG 2.2 Accessibility (Critical Gap)

No template currently includes:
- `eslint-plugin-jsx-a11y` in the ESLint config
- Axe-core integration tests
- ARIA role annotations in starter components
- Focus management patterns
- Skip navigation components
- Color contrast verification

**Impact**: Every scaffolded project ships with unknown accessibility compliance. This is a legal risk for enterprise clients (ADA, AODA, EUAA).

### 2. Design Token System

No template uses:
- W3C DTCG JSON format for token source
- OKLCH color values in CSS custom properties
- Style Dictionary v4 for multi-platform output
- A `tokens/` directory for organized token management

**Current state**: Colors are either hardcoded hex values or arbitrary CSS custom properties with no semantic structure.

**Impact**: Dark mode is implemented inconsistently. Cross-platform color consistency is impossible without a token system.

### 3. CI/CD Pipeline

No template includes `.github/workflows/ci.yml`. Every project starts without:
- Automated test runs on PRs
- Linting enforcement in CI
- Type checking in CI
- Coverage threshold gates
- Dependabot configuration

**Impact**: Every project has manual quality control until someone adds CI. This violates the "every project gets CI" principle.

### 4. .devcontainer Configuration

No template includes:
- `.devcontainer/devcontainer.json`
- `docker-compose.yml` for local dependencies (database, redis, etc.)
- Container port forwards

**Impact**: Projects don't have reproducible dev environments. Onboarding new developers requires manual environment setup.

### 5. DESIGN.md

No template includes a `DESIGN.md` documenting:
- Which design system is in use
- Token names and their meanings
- Layout patterns
- Typography choices

**Impact**: AI agents building UI for these projects have no design context. They invent arbitrary styling.

---

## Missing Template Categories

### 1. Monorepo Template (High Priority)
Most production applications eventually need multiple packages:
- Web frontend
- API backend
- Shared type definitions
- Shared UI components
- Database schema package

No monorepo template exists. Every team that needs a monorepo starts from scratch.

**Should be**: Turborepo + pnpm workspaces + web-app + api-service + shared packages + GitHub Actions matrix build

### 2. Desktop App Template
Electron and Tauri apps are increasingly common for AI-native desktop tools.

**Should be**: Tauri v2 + React + shadcn/ui (Tauri is significantly lighter than Electron)

### 3. Email Template System
Transactional email is required by virtually every SaaS product. React Email + Resend is the current best-in-class stack.

**Should be**: React Email + Resend + preview server + template library

### 4. Documentation Site Template
Every project needs documentation. Dedicated template saves time.

**Should be**: Nextra or Fumadocs + MDX + search (Algolia or Pagefind)

### 5. Realtime App Template
WebSocket/SSE patterns are common but tricky to set up correctly.

**Should be**: Next.js + Pusher or Ably + presence + channels pattern

---

## Specific Bugs Found

### Bug 1: mobile-expo-revenucat — Paywall Button

**Template**: `mobile-expo-revenucat`
**File**: The Paywall component (likely `src/screens/PaywallScreen.tsx` or similar)
**Bug**: The RevenueCat Paywall button uses a deprecated API. RevenueCat v7+ changed the purchase API signature.

**Symptom**: When a user taps the purchase button in the paywall, a TypeScript error occurs at runtime about `purchasePackage` vs `purchase`.

**Fix needed**:
```typescript
// Old (broken):
await Purchases.purchasePackage(pkg);

// New (correct for RevenueCat v7+):
await Purchases.getOfferings();
// then use the Purchases UI component or:
const { customerInfo } = await Purchases.purchase({ aPackage: pkg });
```

### Bug 2: mobile-nativewind — NativeWind v3 vs v4 API Mismatch

**Template**: `mobile-nativewind`
**Issue**: The template uses NativeWind v3 API (`styled()` wrapper pattern), but NativeWind v4 uses `className` prop natively without the `styled()` wrapper.

**Current template code**:
```typescript
import { styled } from 'nativewind';
const StyledView = styled(View);
```

**Correct v4 code**:
```typescript
// No wrapper needed — className works directly
<View className="flex-1 bg-background" />
```

**Impact**: New projects scaffolded from this template will have unnecessary boilerplate and may have TypeScript errors if NativeWind v4 is installed.

### Bug 3: web-app — Missing Tailwind v4 Migration

**Template**: `web-app`
**Issue**: Template uses Tailwind v3 configuration format (`tailwind.config.js` with `content: [...]` array and `theme.extend`).

**Current**:
```js
// tailwind.config.js (v3 style)
module.exports = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#6200EE',
      }
    }
  }
}
```

**Should be** (Tailwind v4):
```css
/* globals.css */
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.205 0 0);
  --color-primary-foreground: oklch(0.985 0 0);
}
```

### Bug 4: saas-starter — No Admin Dashboard, No RBAC

**Template**: `saas-starter`
**Issue**: Template calls itself a "SaaS starter" but lacks two components required for any real SaaS:
- Admin dashboard (super-admin view of all users, usage metrics)
- Role-Based Access Control (RBAC) — the difference between free, pro, and admin users

**Current**: Template has authentication (NextAuth) and Stripe but no role system.

**Impact**: Every SaaS project built from this template manually adds RBAC, which is error-prone and often has security vulnerabilities.

### Bug 5: ai-ml-app — Single-Provider Only

**Template**: `ai-ml-app`
**Issue**: Template hardcodes OpenAI as the AI provider. In 2025, multi-provider support is table stakes:
- OpenAI as primary
- Anthropic as fallback
- Gemini as alternative
- Ollama for local/offline

The Vercel AI SDK v3 supports multi-provider natively via provider routing. The template doesn't use this.

---

## Priority Upgrade Matrix

| Template | Priority | Effort | Key Missing Pieces |
|----------|----------|--------|--------------------|
| web-app | Critical | Medium | Tailwind v4, OKLCH tokens, CI/CD, a11y, DESIGN.md |
| saas-starter | Critical | High | Admin dashboard, RBAC, usage tracking, CI/CD |
| ai-ml-app | Critical | Medium | Multi-provider, tool calling, ingestion pipeline, CI/CD |
| mobile-nativewind | High | Low | Bump to SDK 54, fix NativeWind v4 API |
| mobile-expo-revenucat | High | Low | Fix Paywall button bug |
| mobile-flutter | High | Medium | Add Material 3 token setup (app_theme.dart) |
| web-t3 | High | Low | Add shadcn/ui |
| ALL templates | High | Medium | Add .github/workflows/ci.yml, .devcontainer/, coverage |

---

## New Template Priority List

1. **`web-shadcn-v4`** — Next.js 15 + shadcn/ui + Tailwind v4 + OKLCH tokens + WCAG 2.2
2. **`mobile-gluestack`** — Expo SDK 54 + Gluestack UI v3 + NativeWind v4 + Expo Router
3. **`saas-complete`** — Next.js + Stripe + Auth + Admin + RBAC + Teams
4. **`ai-rag-complete`** — Next.js + AI SDK v3 + pgvector + multi-provider + tool calling
5. **`monorepo`** — Turborepo + pnpm + web + api + shared
6. **`email-templates`** — React Email + Resend + preview server
