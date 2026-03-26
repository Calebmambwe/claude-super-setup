# Existing Template Upgrades

## Overview

All 16 existing templates need to be upgraded. This document provides specific upgrade instructions for each template, including exact files to add/modify, the rationale, and acceptance criteria.

---

## Universal Upgrades (Apply to All 16 Templates)

These changes apply to every template without exception.

### U1: Add .github/workflows/ci.yml

Every template must have a working CI pipeline.

**Action**: Copy from `17-ci-cd-template.md` and adapt for the template's language/stack.

**Minimum CI for all templates**:
```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install
        run: pnpm install --frozen-lockfile  # or npm/yarn depending on template
      - name: Lint
        run: pnpm lint
      - name: Type check
        run: pnpm typecheck  # skip for JS-only templates
      - name: Test
        run: pnpm test
      - name: Build
        run: pnpm build
```

**Files to add**:
- `.github/workflows/ci.yml`
- `.github/dependabot.yml` (see `17-ci-cd-template.md`)

### U2: Add .devcontainer/

Every template must have a reproducible development environment.

**Files to add**:

`.devcontainer/devcontainer.json`:
```json
{
  "name": "Dev Container",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:22",
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "22" },
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "postCreateCommand": "pnpm install",
  "customizations": {
    "vscode": {
      "extensions": ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode"]
    }
  },
  "forwardPorts": [3000, 3001]
}
```

For templates with databases (postgres, redis), add a `docker-compose.yml`:
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_DB: appdb
    ports:
      - "5432:5432"
```

### U3: Add DESIGN.md

Every template must document its design system.

**Template DESIGN.md**:
```markdown
# Design System

## Overview
This project uses [Design System Name] for UI components.

## Color Tokens
Colors are defined as CSS custom properties in `src/app/globals.css`.
Never hardcode hex values — always use token variables.

| Token | Usage |
|-------|-------|
| `--color-primary` | Main action color (buttons, links) |
| `--color-background` | Page background |
| `--color-foreground` | Default text color |

## Typography
- Sans-serif: Inter Variable
- Monospace: JetBrains Mono

## Spacing
Uses Tailwind spacing scale. Always use Tailwind utilities or CSS custom properties.

## Components
UI components are in `src/components/ui/`. Always use these before creating new ones.
```

### U4: Ensure Coverage Thresholds Are Set

Add or update test config to enforce minimum coverage.

**Vitest** (`vitest.config.ts`):
```typescript
coverage: {
  thresholds: { lines: 70, branches: 60, functions: 70 }
}
```

**Jest** (`jest.config.ts`):
```typescript
coverageThreshold: {
  global: { lines: 70, branches: 60, functions: 70, statements: 70 }
}
```

---

## Template-Specific Upgrades

### 1. `web-app` (Priority: Critical)

**Current state**: Next.js + Tailwind v3 + shadcn/ui + TypeScript

**Required changes**:

**1a. Migrate to Tailwind v4**
- Remove `tailwind.config.js`
- Remove `tailwind.config.ts`
- Add `@theme {}` block to `globals.css`
- Update `postcss.config.js` (Tailwind v4 uses different PostCSS config)

```diff
// Before (v3 tailwind.config.js):
module.exports = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: { extend: { colors: { primary: '#6200EE' } } }
}

// After (v4 globals.css):
// (No config file needed)
@import "tailwindcss";
@theme {
  --color-primary: oklch(0.428 0.174 303.6);
}
```

**1b. Migrate colors to OKLCH**
Replace all hex and hsl values in `globals.css` with OKLCH equivalents.

**1c. Add accessibility**
- Add `eslint-plugin-jsx-a11y` to `package.json`
- Update `.eslintrc.cjs` with jsx-a11y/recommended
- Add `SkipNav.tsx` component
- Add `<html lang="en">` to root layout if missing
- Add `:focus-visible` styles to `globals.css`

**1d. Add vitest-axe to tests**
- Add `vitest-axe` to `package.json`
- Update `src/test/setup.ts` to include axe expectations

**Files modified**: `package.json`, `globals.css`, `.eslintrc.cjs`, `src/app/layout.tsx`, `vitest.config.ts`
**Files added**: `.github/workflows/ci.yml`, `.github/dependabot.yml`, `.devcontainer/`, `DESIGN.md`, `src/components/layout/SkipNav.tsx`

---

### 2. `web-t3` (Priority: High)

**Current state**: T3 Stack (Next.js + tRPC + Prisma + NextAuth) — missing shadcn/ui

**Required changes**:

**2a. Add shadcn/ui**
```bash
npx shadcn init  # Initialize shadcn/ui
npx shadcn add button card input label  # Add common components
```

**2b. Update globals.css with OKLCH tokens**
T3's default `globals.css` uses HSL variables. Migrate to OKLCH.

**Files modified**: `src/styles/globals.css`, `tailwind.config.ts`
**Files added**: Universal upgrades (CI, devcontainer, DESIGN.md)

---

### 3. `saas-starter` (Priority: Critical)

**Current state**: Next.js + Stripe + NextAuth — missing admin dashboard and RBAC

**Required changes**:

**3a. Add Admin Dashboard**

Create `src/app/(admin)/` route group:
```
src/app/(admin)/
├── layout.tsx      # Check user.role === 'admin' or redirect
├── users/
│   └── page.tsx    # User management table (shadcn DataTable)
└── metrics/
    └── page.tsx    # Usage metrics (recharts or shadcn charts)
```

**3b. Add RBAC**

Add `role` column to User table in Prisma:
```prisma
model User {
  id    String @id @default(cuid())
  email String @unique
  role  Role   @default(MEMBER)
}

enum Role {
  ADMIN
  MEMBER
  VIEWER
}
```

Create `src/lib/rbac.ts`:
```typescript
export type Role = 'ADMIN' | 'MEMBER' | 'VIEWER';
export const permissions = {
  ADMIN: ['read', 'write', 'delete', 'manage-users'],
  MEMBER: ['read', 'write'],
  VIEWER: ['read'],
};
```

**3c. Add Usage Tracking**

Add Prisma model for usage events:
```prisma
model UsageEvent {
  id        String   @id @default(cuid())
  userId    String
  action    String
  metadata  Json?
  createdAt DateTime @default(now())
}
```

**Files added**: Admin route group, `src/lib/rbac.ts`, prisma migration for role + usage
**Files modified**: `prisma/schema.prisma`, `src/lib/auth.ts` (include role in session)

---

### 4. `ai-ml-app` (Priority: Critical)

**Current state**: Next.js + AI SDK — single provider (OpenAI), no RAG, no tool calling

**Required changes**:

**4a. Add Multi-Provider Support**

```typescript
// src/lib/ai/providers.ts (new file)
import { anthropic } from '@ai-sdk/anthropic';
import { openai } from '@ai-sdk/openai';
import { google } from '@ai-sdk/google';

export const providers = { claude: anthropic('...'), gpt4o: openai('...'), gemini: google('...') };
```

Update `.env.example` with all provider keys.

**4b. Add Tool Calling**

Add at least one built-in tool (calculator or weather) to demonstrate the pattern.

**4c. Add Ingestion Pipeline**

Add a `/api/ingest` endpoint that:
1. Accepts a document (PDF or text)
2. Chunks it
3. Generates embeddings
4. Stores in vector database (pgvector or simple JSON for template)

**Files added**: `src/lib/ai/providers.ts`, `src/app/api/ingest/route.ts`
**Files modified**: `src/app/api/chat/route.ts` (add multi-provider), `.env.example`

---

### 5. `mobile-nativewind` (Priority: High)

**Current state**: Expo + NativeWind v3 — using deprecated `styled()` wrapper API

**Required changes**:

**5a. Remove styled() wrappers**

Find all instances of `styled(View)`, `styled(Text)` etc. and replace with direct `className` prop usage.

```diff
- import { styled } from 'nativewind';
- const StyledView = styled(View);
- <StyledView className="flex-1" />

+ <View className="flex-1" />
```

**5b. Upgrade NativeWind to v4**

```bash
pnpm add nativewind@4.x tailwindcss@4.x
```

Update `babel.config.js`:
```js
module.exports = function(api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: ['nativewind/babel'],
  };
};
```

**5c. Bump Expo SDK to 54**

```bash
npx expo upgrade 54
```

**Files modified**: All component files (remove styled wrappers), `package.json`, `babel.config.js`, `metro.config.js`

---

### 6. `mobile-flutter` (Priority: High)

**Current state**: Flutter + Material 3 — using raw `Theme.of(context).colorScheme.primary` without a token abstraction layer

**Required changes**:

**6a. Add app_theme.dart with Material 3 tokens**

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // Reference palette (never use directly in UI)
  static const _primary40 = Color(0xFF6C28CC);
  static const _primary90 = Color(0xFFEFDEFF);

  // Semantic colors (use these in UI)
  static const primary = _primary40;
  static const onPrimary = Colors.white;
  static const primaryContainer = _primary90;
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
  );
}
```

**Files added**: `lib/theme/app_theme.dart`, `lib/theme/app_typography.dart`
**Files modified**: `lib/main.dart` (use AppTheme.light/dark)

---

### 7. `mobile-expo-revenucat` (Priority: High — Bug Fix)

**Current state**: RevenueCat v6 API — `purchasePackage()` is deprecated in v7+

**Required changes**:

**7a. Fix the Paywall purchase button**

```diff
// In PaywallScreen.tsx or wherever purchase is triggered:

- const { purchaserInfo } = await Purchases.purchasePackage(selectedPackage);

+ const { customerInfo } = await Purchases.purchase({
+   aPackage: selectedPackage,
+ });
```

**7b. Update RevenueCat SDK**

```bash
pnpm add react-native-purchases@7.x
```

**7c. Update customer info type name**

RevenueCat v7 renamed `PurchaserInfo` to `CustomerInfo`:
```diff
- import { PurchaserInfo } from 'react-native-purchases';
+ import { CustomerInfo } from 'react-native-purchases';
```

**Files modified**: `package.json`, `src/screens/PaywallScreen.tsx`, any file using `PurchaserInfo` type

---

### 8. `api-service` (Priority: Medium)

**Current state**: Express/Fastify + TypeScript — no structured logging, no OTel

**Required changes**:

**8a. Add structured logging**
```bash
pnpm add pino pino-pretty
```

Replace `console.log` with `pino` logger. All logs as JSON.

**8b. Add health check endpoints**
Add `/health/live`, `/health/ready` as per `06-uptime-architecture.md`.

**Files modified**: `src/app.ts`, `src/server.ts`
**Files added**: Universal upgrades + `src/routes/health.ts`

---

### 9. All Python Templates (`api-fastapi`)

**Required changes**:

**9a. Add mypy strict mode**
```ini
# mypy.ini
[mypy]
strict = True
```

**9b. Add ruff linting**
```bash
pip install ruff
```

```toml
# pyproject.toml
[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "UP", "B", "S"]
```

**Files modified**: `pyproject.toml`, `requirements-dev.txt`
**Files added**: `.github/workflows/ci.yml` (Python variant), `.devcontainer/`

---

## Upgrade Tracking

| Template | CI/CD | .devcontainer | DESIGN.md | Coverage | Template-Specific | Status |
|----------|-------|---------------|-----------|----------|-------------------|--------|
| web-app | | | | | Tailwind v4, OKLCH, a11y | |
| api-service | | | | | Structured logging, health | |
| mobile-app | | | | | Needs full replacement | |
| saas-starter | | | | | Admin, RBAC, usage | |
| ai-ml-app | | | | | Multi-provider, RAG | |
| web-t3 | | | | | Add shadcn/ui | |
| web-astro | | | | | Minor updates | |
| web-sveltekit | | | | | Minor updates | |
| web-remix | | | | | Minor updates | |
| api-fastapi | | | | | mypy strict, ruff | |
| api-hono-edge | | | | | Minor updates | |
| mobile-expo-revenucat | | | | | Fix paywall bug | |
| mobile-nativewind | | | | | v3 → v4 migration | |
| mobile-flutter | | | | | app_theme.dart | |
| chrome-extension | | | | | Minor updates | |
| cli-tool | | | | | Minor updates | |
