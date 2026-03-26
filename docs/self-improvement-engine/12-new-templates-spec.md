# New Stack Templates: Detailed Specifications

## Overview

Six new templates to build, covering the most common gaps in the current template library. Each spec defines: stack, directory structure, key files, design decisions, and acceptance criteria.

---

## Template 1: `web-shadcn-v4`

### Purpose
The primary modern web application template. Replaces `web-app` as the default for all new web projects. Focuses on production readiness from day one: typed, accessible, testable, and CI-enabled.

### Stack
```
Next.js 15.x (App Router, Turbopack)
TypeScript 5.x (strict mode)
Tailwind CSS v4 (CSS-first @theme)
shadcn/ui (latest, OKLCH token system)
Radix UI (via shadcn)
Vitest 2.x + @testing-library/react
Playwright 1.x (E2E)
ESLint + eslint-plugin-jsx-a11y
Prettier
pnpm workspaces
```

### Directory Structure
```
web-shadcn-v4/
├── .devcontainer/
│   ├── devcontainer.json
│   └── docker-compose.yml
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   ├── app/
│   │   ├── layout.tsx        # Root layout with providers
│   │   ├── page.tsx          # Home page
│   │   └── globals.css       # Tailwind v4 @theme + OKLCH tokens
│   ├── components/
│   │   ├── ui/               # shadcn/ui components (Button, Card, etc.)
│   │   └── layout/
│   │       ├── Header.tsx
│   │       ├── Footer.tsx
│   │       └── SkipNav.tsx   # Accessibility: skip to main content
│   ├── lib/
│   │   └── utils.ts          # cn() utility + shared helpers
│   └── test/
│       ├── setup.ts          # vitest setup + axe-core
│       └── utils.tsx         # render helper + a11y check
├── tests/
│   └── e2e/
│       └── home.spec.ts
├── tokens/
│   ├── tokens.json           # W3C DTCG source
│   └── style-dictionary.config.js
├── DESIGN.md
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── playwright.config.ts
└── next.config.ts
```

### Key File: `src/app/globals.css`
```css
@import "tailwindcss";

@theme {
  /* OKLCH color tokens — semantic layer */
  --color-background: oklch(1 0 0);
  --color-foreground: oklch(0.145 0 0);
  --color-primary: oklch(0.205 0 0);
  --color-primary-foreground: oklch(0.985 0 0);
  --color-secondary: oklch(0.97 0 0);
  --color-secondary-foreground: oklch(0.205 0 0);
  --color-muted: oklch(0.97 0 0);
  --color-muted-foreground: oklch(0.556 0 0);
  --color-accent: oklch(0.97 0 0);
  --color-accent-foreground: oklch(0.205 0 0);
  --color-destructive: oklch(0.577 0.245 27.325);
  --color-border: oklch(0.922 0 0);
  --color-input: oklch(0.922 0 0);
  --color-ring: oklch(0.205 0 0);

  /* Dark mode via @media or .dark class */
  --color-chart-1: oklch(0.646 0.222 41.116);
  --color-chart-2: oklch(0.6 0.118 184.704);

  /* Typography */
  --font-sans: "Inter Variable", ui-sans-serif, system-ui;
  --font-mono: "JetBrains Mono", ui-monospace;

  /* Spacing and radius */
  --radius: 0.625rem;
}
```

### Key File: `src/test/utils.tsx`
```typescript
import { render, RenderOptions } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { expect } from 'vitest';

expect.extend(toHaveNoViolations);

export async function renderAccessible(
  ui: React.ReactElement,
  options?: RenderOptions
) {
  const result = render(ui, options);
  const violations = await axe(result.container);
  expect(violations).toHaveNoViolations();
  return result;
}
```

### Acceptance Criteria
- [ ] `pnpm dev` starts without errors
- [ ] `pnpm build` succeeds with no TypeScript errors
- [ ] `pnpm test` runs and all tests pass
- [ ] `pnpm lint` passes with zero errors (including jsx-a11y)
- [ ] CI pipeline runs successfully on GitHub Actions
- [ ] WCAG 2.2 AA: axe-core finds zero violations on default pages
- [ ] OKLCH tokens visible in browser DevTools CSS variables
- [ ] Dark mode works via class-based toggle (`.dark` on `<html>`)

---

## Template 2: `mobile-gluestack`

### Purpose
The primary mobile template with universal components (iOS + Android + Web) using the latest NativeWind and Gluestack.

### Stack
```
Expo SDK 54
React Native 0.76
TypeScript 5.x (strict mode)
Expo Router v4 (file-based navigation)
Gluestack UI v3 (universal components)
NativeWind v4 (Tailwind for React Native)
Expo SecureStore (sensitive data)
Jest + @testing-library/react-native
```

### Directory Structure
```
mobile-gluestack/
├── app/
│   ├── _layout.tsx           # Root layout (GluestackProvider)
│   ├── (tabs)/
│   │   ├── _layout.tsx       # Tab navigation
│   │   ├── index.tsx         # Home tab
│   │   └── settings.tsx      # Settings tab
│   └── +not-found.tsx
├── components/
│   ├── ui/                   # Gluestack components (re-exported with theme)
│   │   ├── Button.tsx
│   │   ├── Text.tsx
│   │   └── Box.tsx
│   └── ThemedView.tsx
├── config/
│   └── gluestack-ui.config.ts  # Token configuration
├── assets/
│   ├── fonts/
│   └── images/
├── __tests__/
│   └── components/
├── app.json
├── babel.config.js
├── metro.config.js
├── package.json
└── tsconfig.json
```

### Key File: `config/gluestack-ui.config.ts`
```typescript
import { createConfig } from '@gluestack-ui/themed';

export const config = createConfig({
  aliases: {
    bg: 'backgroundColor',
    p: 'padding',
    px: 'paddingHorizontal',
    py: 'paddingVertical',
  },
  tokens: {
    colors: {
      primary: '#6200EE',
      'primary-foreground': '#FFFFFF',
      secondary: '#03DAC6',
      background: '#FFFFFF',
      foreground: '#1C1C1C',
      muted: '#F5F5F5',
      'muted-foreground': '#757575',
      destructive: '#B00020',
    },
    fontSizes: {
      sm: 14,
      md: 16,
      lg: 18,
      xl: 24,
      '2xl': 32,
    },
    space: {
      1: 4,
      2: 8,
      3: 12,
      4: 16,
      6: 24,
      8: 32,
    },
  },
});
```

### Acceptance Criteria
- [ ] Runs on iOS Simulator without errors
- [ ] Runs on Android Emulator without errors
- [ ] Expo Router navigation works (tabs + stack)
- [ ] Gluestack components render correctly on both platforms
- [ ] NativeWind className works on all core RN components
- [ ] TypeScript strict mode passes

---

## Template 3: `saas-complete`

### Purpose
A production-ready SaaS template with all the hard features pre-built: billing, authentication, RBAC, admin dashboard, and multi-tenancy foundations.

### Stack
```
Next.js 15 (App Router)
TypeScript strict
Tailwind v4 + shadcn/ui
NextAuth v5 (magic link + OAuth)
Prisma + PostgreSQL
Stripe (subscriptions + webhooks)
Admin dashboard (shadcn/ui table + charts)
RBAC (admin | member | viewer roles)
Resend (email)
Vitest + Playwright
GitHub Actions CI
```

### Directory Structure
```
saas-complete/
├── src/
│   ├── app/
│   │   ├── (marketing)/        # Public pages
│   │   │   ├── page.tsx        # Landing page
│   │   │   └── pricing/
│   │   ├── (auth)/             # Auth pages
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── (dashboard)/        # Protected user dashboard
│   │   │   ├── layout.tsx      # Auth check + sidebar
│   │   │   ├── page.tsx        # Dashboard home
│   │   │   └── settings/
│   │   ├── (admin)/            # Admin-only pages
│   │   │   ├── layout.tsx      # Admin role check
│   │   │   ├── users/          # User management table
│   │   │   └── metrics/        # Usage dashboard
│   │   └── api/
│   │       ├── auth/[...nextauth]/
│   │       ├── stripe/
│   │       │   └── webhook/    # Stripe webhook handler
│   │       └── trpc/[trpc]/
│   ├── lib/
│   │   ├── auth.ts             # NextAuth config
│   │   ├── db.ts               # Prisma client
│   │   ├── stripe.ts           # Stripe client + helpers
│   │   └── rbac.ts             # Role check utilities
│   └── server/
│       └── routers/            # tRPC routers
├── prisma/
│   └── schema.prisma
├── emails/
│   └── magic-link.tsx          # React Email template
└── ...standard files
```

### Key Feature: RBAC Implementation
```typescript
// lib/rbac.ts
export type Role = 'admin' | 'member' | 'viewer';

export const permissions = {
  admin: ['read', 'write', 'delete', 'manage-users', 'view-admin'],
  member: ['read', 'write'],
  viewer: ['read'],
} as const;

export function hasPermission(role: Role, permission: string): boolean {
  return permissions[role].includes(permission as never);
}

// Usage in route handlers:
// if (!hasPermission(session.user.role, 'manage-users')) {
//   return Response.json({ error: 'Forbidden' }, { status: 403 });
// }
```

### Acceptance Criteria
- [ ] Login with email magic link works end-to-end
- [ ] Stripe subscription checkout and webhook work
- [ ] RBAC: admin can see admin routes, member cannot
- [ ] Admin dashboard shows user list and basic metrics
- [ ] All CI checks pass

---

## Template 4: `ai-rag-complete`

### Purpose
Production-ready RAG (Retrieval-Augmented Generation) application with multi-provider support, tool calling, streaming, and a full document ingestion pipeline.

### Stack
```
Next.js 15 (App Router)
TypeScript strict
Tailwind v4 + shadcn/ui
AI SDK v3 (Vercel)
Multi-provider: Anthropic + OpenAI + Google + Ollama
pgvector (PostgreSQL)
Prisma
LangChain.js (document loaders)
Vitest
GitHub Actions CI
```

### Multi-Provider Configuration
```typescript
// lib/ai/providers.ts
import { anthropic } from '@ai-sdk/anthropic';
import { openai } from '@ai-sdk/openai';
import { google } from '@ai-sdk/google';
import { ollama } from 'ollama-ai-provider';

export const providers = {
  claude: anthropic('claude-sonnet-4-5'),
  gpt4o: openai('gpt-4o'),
  gemini: google('gemini-1.5-pro'),
  local: ollama('llama3.2'),
} as const;

export type ProviderKey = keyof typeof providers;

// Route by provider preference or availability
export async function getModel(preferred: ProviderKey = 'claude') {
  const apiKeys = {
    claude: process.env.ANTHROPIC_API_KEY,
    gpt4o: process.env.OPENAI_API_KEY,
    gemini: process.env.GOOGLE_API_KEY,
  };

  if (preferred in apiKeys && apiKeys[preferred as keyof typeof apiKeys]) {
    return providers[preferred];
  }

  // Fallback chain
  for (const [key, apiKey] of Object.entries(apiKeys)) {
    if (apiKey) return providers[key as ProviderKey];
  }

  return providers.local; // Ollama as final fallback
}
```

### Ingestion Pipeline
```
documents/            # Raw documents (PDF, MD, TXT, etc.)
     ↓
LangChain loaders     # Load and parse documents
     ↓
Text splitter         # Chunk into ~500 token segments
     ↓
Embedding model       # Generate vector embeddings
     ↓
pgvector              # Store chunks + embeddings
     ↓
Ready for RAG queries
```

### Acceptance Criteria
- [ ] Chat with documents works end-to-end (upload → ingest → query)
- [ ] Multi-provider switching works via environment variables
- [ ] Streaming responses work correctly
- [ ] Tool calling works (at minimum: web search or calculator)
- [ ] pgvector similarity search returns relevant documents

---

## Template 5: `monorepo`

### Purpose
Turborepo monorepo starter for projects that need multiple packages (web + API + shared).

### Stack
```
Turborepo 2.x
pnpm 9.x workspaces
apps/web: Next.js 15 (from web-shadcn-v4)
apps/api: Hono + Cloudflare Workers (from api-hono-edge)
packages/ui: Shared React components
packages/shared: Shared types + utilities
packages/config: Shared ESLint + TypeScript configs
GitHub Actions (matrix build: test all packages)
Changesets (version management)
```

### Directory Structure
```
monorepo/
├── apps/
│   ├── web/                  # Next.js frontend
│   └── api/                  # Hono API
├── packages/
│   ├── ui/                   # Shared component library
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── shared/               # Shared types and utils
│   │   ├── src/types/
│   │   ├── src/utils/
│   │   └── package.json
│   └── config/
│       ├── eslint/
│       └── typescript/
├── turbo.json
├── pnpm-workspace.yaml
├── .changeset/
│   └── config.json
└── package.json
```

### Key File: `turbo.json`
```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"]
    },
    "lint": {
      "outputs": []
    },
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

### Acceptance Criteria
- [ ] `pnpm build` builds all packages in correct dependency order
- [ ] `apps/web` can import from `packages/ui` and `packages/shared`
- [ ] CI matrix build tests all packages in parallel
- [ ] Changeset versioning creates correct changelogs

---

## Template 6: `email-templates`

### Purpose
Transactional email system with React Email + Resend, pre-built templates for common SaaS emails, and a local preview server.

### Stack
```
React Email 3.x
Resend SDK
TypeScript
Preview server (react-email dev)
Pre-built templates: welcome, magic-link, invoice, team-invite, password-reset
```

### Directory Structure
```
email-templates/
├── emails/
│   ├── welcome.tsx
│   ├── magic-link.tsx
│   ├── invoice.tsx
│   ├── team-invite.tsx
│   └── password-reset.tsx
├── components/
│   ├── EmailLayout.tsx       # Base layout (logo, footer, unsubscribe)
│   ├── Button.tsx            # CTA button
│   └── Divider.tsx
├── lib/
│   ├── send.ts               # Resend client + send helper
│   └── render.ts             # Server-side email rendering
├── preview/                  # Preview server config
└── package.json
```

### Key File: `lib/send.ts`
```typescript
import { Resend } from 'resend';
import { render } from '@react-email/render';

const resend = new Resend(process.env.RESEND_API_KEY);

export async function sendEmail<T extends Record<string, unknown>>({
  to,
  subject,
  template: Template,
  props,
}: {
  to: string;
  subject: string;
  template: React.ComponentType<T>;
  props: T;
}) {
  const html = render(<Template {...props} />);

  return resend.emails.send({
    from: process.env.EMAIL_FROM!,
    to,
    subject,
    html,
  });
}
```

### Acceptance Criteria
- [ ] `pnpm email:dev` starts preview server at localhost:3000
- [ ] All 5 templates render correctly in preview
- [ ] `sendEmail()` sends successfully via Resend API
- [ ] TypeScript strict mode passes
