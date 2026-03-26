---
name: production-ready
description: Audit, harden, and prepare a codebase for production deployment with a readiness report and DEPLOY.md
---
Prepare this project for production deployment: $ARGUMENTS

You are the **Release Engineer**, executing the **Production Readiness** workflow.

## Workflow Overview

**Goal:** Systematically audit, clean, harden, and prepare a codebase for production deployment — transforming "it works on my machine" into "it ships safely to users."

**Output:** `docs/production-readiness-report-{date}.md` + inline fixes applied + `DEPLOY.md` generated

**Best for:** Running as the FINAL gate before first deployment or major release. Complements `/security-audit`, `/perf-audit`, and `/deps-audit` by combining their critical checks with deployment-specific concerns.

---

## Phase 1: Discovery & Stack Detection

### Step 1: Detect Project Stack

```bash
# Detect package manager and runtime
ls package.json pnpm-lock.yaml yarn.lock package-lock.json bun.lockb 2>/dev/null
ls pyproject.toml requirements.txt Pipfile setup.py 2>/dev/null
ls go.mod Cargo.toml 2>/dev/null

# Detect framework
grep -l "next" package.json 2>/dev/null
grep -l "express\|fastify\|hono\|koa" package.json 2>/dev/null
grep -l "fastapi\|django\|flask" pyproject.toml requirements.txt 2>/dev/null

# Detect infrastructure
ls Dockerfile docker-compose*.yml 2>/dev/null
ls vercel.json netlify.toml fly.toml render.yaml railway.json app.yaml 2>/dev/null
ls .github/workflows/*.yml 2>/dev/null
ls terraform/ pulumi/ cdk/ 2>/dev/null

# Detect existing configs
ls .env .env.example .env.local .env.production 2>/dev/null
ls sentry.*.ts sentry.*.js next.config.* 2>/dev/null
```

Record the detected stack:
- **Runtime:** (Node.js / Python / Go / Rust)
- **Framework:** (Next.js / Express / FastAPI / etc.)
- **Package manager:** (pnpm / uv / etc.)
- **Deployment target:** (Vercel / Docker / Fly.io / AWS / etc.)
- **Database:** (PostgreSQL / MySQL / MongoDB / SQLite / etc.)
- **CI/CD:** (GitHub Actions / GitLab CI / etc.)

### Step 2: Ask the User About Their Production Services

Use AskUserQuestion to gather required context. Ask about:

**Question 1 — Authentication provider:**
- Clerk
- Auth.js / NextAuth
- Supabase Auth
- Custom JWT
- Other

**Question 2 — Payment processing (if applicable):**
- Stripe
- Lemon Squeezy
- None
- Other

**Question 3 — Deployment target:**
- Vercel
- Docker / VPS
- AWS (ECS / Lambda)
- Fly.io
- Railway
- Other

**Question 4 — Which production services do you need configured?** (multi-select)
- Error monitoring (Sentry)
- Analytics (PostHog / Plausible / Vercel Analytics)
- Email (Resend / SendGrid)
- File storage (S3 / Cloudflare R2)
- Rate limiting (Upstash / Redis)
- Feature flags (LaunchDarkly / Flagsmith)

---

## Phase 2: Code Cleanup

Systematically find and remove code that should never reach production.

### Step 1: Dead Code & Debug Artifacts

```bash
# Console statements (JS/TS)
grep -rn "console\.\(log\|debug\|info\|warn\|trace\|dir\|table\|time\|timeEnd\|count\|group\|groupEnd\|profile\)" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ app/ lib/ 2>/dev/null | grep -v "node_modules" | grep -v "logger\." | grep -v "// production"

# Print statements (Python)
grep -rn "print(" --include="*.py" src/ app/ 2>/dev/null | grep -v "node_modules" | grep -v "__pycache__" | grep -v "# keep"

# Debugger statements
grep -rn "debugger\b" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ app/ 2>/dev/null
grep -rn "breakpoint()\|pdb\.\|ipdb\.\|import pdb" --include="*.py" src/ app/ 2>/dev/null

# TODO / FIXME / HACK / XXX comments
grep -rn "TODO\|FIXME\|HACK\|XXX\|TEMP\|TEMPORARY" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" src/ app/ lib/ 2>/dev/null | grep -v "node_modules"

# Commented-out code blocks (3+ consecutive commented lines)
grep -rn "^[[:space:]]*//" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ app/ 2>/dev/null | grep -v "node_modules" | head -50
```

For EACH finding:
1. Show the file, line, and context to the user
2. Ask: **Remove, Keep (with justification comment), or Skip?**
3. Replace `console.log` with proper logger calls where appropriate
4. Convert legitimate TODOs into GitHub Issues with `gh issue create`

### Step 2: Unused Dependencies & Imports

```bash
# Unused exports/imports (TS/JS)
npx knip --no-exit-code 2>/dev/null || npx ts-prune 2>/dev/null

# Unused Python imports
python3 -m pyflakes src/ app/ 2>/dev/null

# Check for unused dependencies in package.json
npx depcheck 2>/dev/null
```

Remove confirmed unused dependencies. For ambiguous cases, ask the user.

### Step 3: Type Safety & Lint Compliance

```bash
# TypeScript strict check
npx tsc --noEmit 2>&1 | head -50

# ESLint with zero warnings target
npx eslint . --max-warnings 0 2>&1 | head -50

# Python type checking
python3 -m mypy src/ app/ --ignore-missing-imports 2>/dev/null | head -50

# Python lint
python3 -m ruff check src/ app/ 2>/dev/null | head -50
```

Fix all errors. For warnings, fix or suppress with justification comments.

---

## Phase 3: Environment & Secrets Audit

### Step 1: Hardcoded Secrets Scan

```bash
# API keys, tokens, passwords in code
grep -rn "sk_live\|pk_live\|sk_test\|pk_test" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.env" . 2>/dev/null | grep -v node_modules
grep -rn "AKIA[0-9A-Z]\{16\}" . 2>/dev/null | grep -v node_modules
grep -rn "password\s*=\s*[\"'].\+" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules | grep -v ".env" | grep -v "test"
grep -rn "Bearer [a-zA-Z0-9_\-]\{20,\}" . 2>/dev/null | grep -v node_modules

# Check .gitignore covers sensitive files
cat .gitignore 2>/dev/null | grep -E "\.env|\.pem|\.key|credentials|secret"

# Check if .env is tracked by git
git ls-files --error-unmatch .env .env.local .env.production 2>/dev/null
```

If ANY secret is found in code: **STOP and alert the user immediately.** Rotate the exposed key.

### Step 2: Environment Variable Completeness

```bash
# Extract all env var references from code
grep -roh "process\.env\.\w\+" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ app/ lib/ 2>/dev/null | sort -u
grep -roh "os\.environ\[.\+\]\|os\.getenv(\"\w\+\")" --include="*.py" src/ app/ 2>/dev/null | sort -u

# Compare with .env.example
cat .env.example 2>/dev/null
```

Generate or update `.env.example` to include ALL referenced env vars with:
- Descriptive comments explaining each var
- Placeholder values (never real secrets)
- Required vs optional markers
- Links to where to obtain each key

**Template for .env.example:**
```bash
# ============================================
# Application
# ============================================
NODE_ENV=production
PORT=3000
# Public URL of your deployed app
NEXT_PUBLIC_APP_URL=https://your-domain.com

# ============================================
# Database
# ============================================
# Connection string for PostgreSQL
# Get from: your hosting provider's dashboard
DATABASE_URL=postgresql://user:password@host:5432/dbname

# ============================================
# Authentication (Clerk)
# ============================================
# Get from: https://dashboard.clerk.com → API Keys
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...

# ============================================
# Error Monitoring (Sentry)
# ============================================
# Get from: https://sentry.io → Settings → Client Keys
SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
SENTRY_AUTH_TOKEN=sntrys_...

# ============================================
# Payments (Stripe) — optional
# ============================================
# Get from: https://dashboard.stripe.com/apikeys
# STRIPE_SECRET_KEY=sk_live_...
# STRIPE_WEBHOOK_SECRET=whsec_...
# NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### Step 3: Environment Validation at Startup

Check if the project validates env vars at startup. If not, create a validation module:

**TypeScript (Zod):**
```typescript
// src/env.ts
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  DATABASE_URL: z.string().url(),
  // ... all required vars
});

export const env = envSchema.parse(process.env);
```

**Python (Pydantic):**
```python
# src/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    # ... all required vars

    class Config:
        env_file = ".env"

settings = Settings()
```

---

## Phase 4: Security & Infrastructure Hardening

### Step 1: HTTP Security Headers

Check for and implement security headers:

```bash
# Check for helmet (Express) or next.config.js headers
grep -rn "helmet\|securityHeaders\|Content-Security-Policy" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.mjs" . 2>/dev/null | grep -v node_modules
```

Ensure these headers are set:
- [ ] `Strict-Transport-Security` (HSTS)
- [ ] `Content-Security-Policy` (CSP)
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY` (unless embeds needed)
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` (disable unused browser features)

### Step 2: CORS Configuration

```bash
grep -rn "cors\|Access-Control-Allow-Origin" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules
```

Verify:
- [ ] CORS origin is NOT `*` in production (whitelist specific domains)
- [ ] Credentials mode is configured correctly
- [ ] Preflight caching is set (`Access-Control-Max-Age`)

### Step 3: Rate Limiting

```bash
grep -rn "rateLimit\|rate.limit\|throttle\|RateLimiter\|slowDown" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules
```

If missing, implement rate limiting on:
- [ ] Authentication endpoints (strict: 5-10 req/min)
- [ ] API endpoints (moderate: 100-200 req/min)
- [ ] Public endpoints (lenient: 500+ req/min)

### Step 4: Database Production Config

```bash
# Check for connection pooling
grep -rn "pool\|connectionLimit\|max_connections\|poolSize" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules

# Check for pending migrations
npx prisma migrate status 2>/dev/null
npx drizzle-kit check 2>/dev/null
python3 -m alembic current 2>/dev/null
```

Verify:
- [ ] Connection pooling is configured (not unlimited connections)
- [ ] All migrations are applied
- [ ] Database has proper indexes for frequent queries
- [ ] SSL/TLS is enforced for database connections in production

### Step 5: Graceful Shutdown

```bash
grep -rn "SIGTERM\|SIGINT\|graceful\|shutdown\|beforeExit\|on.*close" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules | grep -v test
```

If missing, implement graceful shutdown that:
- Stops accepting new requests
- Finishes in-flight requests (with timeout)
- Closes database connections
- Flushes logs and metrics
- Exits with code 0

---

## Phase 5: Observability & Monitoring

### Step 1: Error Monitoring (Sentry)

Based on the user's answer in Phase 1, set up error monitoring:

```bash
# Check if Sentry is already configured
grep -rn "sentry\|Sentry\|@sentry" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules
ls sentry.*.config.* instrumentation.ts 2>/dev/null
```

If Sentry is needed but not configured:
1. Install: `pnpm add @sentry/nextjs` (or appropriate SDK)
2. Run: `npx @sentry/wizard@latest -i nextjs` (or appropriate framework)
3. Verify: source maps upload is configured
4. Ask user for their Sentry DSN or guide them to create a project

### Step 2: Structured Logging

```bash
# Check for logging library
grep -rn "winston\|pino\|bunyan\|morgan\|structlog\|loguru" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules
```

If no structured logger exists:
1. Install a production logger (pino for Node.js, structlog for Python)
2. Create a logger module that outputs JSON in production, pretty in development
3. Replace remaining `console.log` calls with the logger
4. Include request ID, timestamp, level, and context in every log line

### Step 3: Health Check Endpoint

```bash
grep -rn "health\|healthz\|readyz\|livez" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" . 2>/dev/null | grep -v node_modules | grep -v test
```

If missing, create a health endpoint at `GET /api/health` that returns:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2026-02-28T12:00:00Z",
  "checks": {
    "database": "ok",
    "redis": "ok"
  }
}
```

The endpoint should:
- Return 200 when healthy, 503 when degraded
- Check database connectivity
- Check external service reachability
- NOT expose sensitive internal details

---

## Phase 6: Deployment Readiness & Documentation

### Step 1: Production Build Verification

```bash
# Build the project
pnpm build 2>&1 || npm run build 2>&1 || python3 -m build 2>&1

# Check bundle size (frontend)
npx @next/bundle-analyzer 2>/dev/null || ls -lh .next/static/chunks/*.js 2>/dev/null | sort -k5 -h | tail -10
ls -lh dist/ build/ .next/ 2>/dev/null
```

Verify:
- [ ] Production build succeeds with zero errors
- [ ] No TypeScript errors (`tsc --noEmit`)
- [ ] Bundle size is reasonable (< 200KB initial JS for web apps)
- [ ] Environment-specific code is properly tree-shaken

### Step 2: Test Suite Verification

```bash
# Run full test suite
pnpm test --coverage 2>/dev/null || npm test -- --coverage 2>/dev/null || pytest --cov 2>/dev/null

# Check for skipped tests
grep -rn "\.skip\|xit\|xdescribe\|@pytest\.mark\.skip\|@unittest\.skip" --include="*.test.*" --include="*.spec.*" --include="test_*" . 2>/dev/null | grep -v node_modules
```

Verify:
- [ ] All tests pass
- [ ] Coverage meets threshold (>= 80% for critical paths)
- [ ] No tests are skipped without a linked issue
- [ ] E2E tests cover critical user flows (signup, login, core action, payment)

### Step 3: CI/CD Pipeline Verification

```bash
ls .github/workflows/*.yml 2>/dev/null
cat .github/workflows/*.yml 2>/dev/null | head -100
```

Verify the CI pipeline includes:
- [ ] Lint step
- [ ] Type check step
- [ ] Test step (with coverage)
- [ ] Build step
- [ ] Security scan (Snyk / Trivy / npm audit)
- [ ] Deploy step (staging → production)
- [ ] Branch protection rules are set (`gh api repos/{owner}/{repo}/branches/main/protection`)

If CI is missing, run `/ci-setup` first.

### Step 4: Generate DEPLOY.md

Create `DEPLOY.md` at the project root with deployment instructions tailored to the detected stack and deployment target. Include:

```markdown
# Deployment Guide

## Prerequisites
- [ ] All environment variables set (see `.env.example`)
- [ ] Database provisioned and migrations applied
- [ ] Domain configured with DNS
- [ ] SSL certificate provisioned

## Environment Variables
[Auto-generated table from .env.example with descriptions and where to get each key]

## Deployment Steps

### First Deploy
1. [Stack-specific steps]
2. [Database migration command]
3. [Seed data if applicable]
4. [Verify health endpoint]

### Subsequent Deploys
1. [CI/CD triggered by merge to main]
2. [Migration strategy]
3. [Rollback procedure]

## Rollback Procedure
1. [How to revert to previous version]
2. [Database rollback if applicable]
3. [Cache invalidation if applicable]

## Monitoring
- Error tracking: [Sentry dashboard URL placeholder]
- Logs: [Log aggregation URL placeholder]
- Uptime: [Status page URL placeholder]
- Analytics: [Analytics dashboard URL placeholder]

## Runbook: Common Issues
| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 502 Bad Gateway | App crashed on startup | Check logs, verify env vars |
| Slow responses | Database connection pool exhausted | Scale pool or add read replica |
| High error rate | External service degraded | Check Sentry, enable fallbacks |
```

### Step 5: Generate Production Readiness Report

Create `docs/production-readiness-report-{date}.md`:

```markdown
# Production Readiness Report

**Project:** {project-name}
**Date:** {date}
**Stack:** {detected-stack}
**Deployment Target:** {target}

## Summary

| Category | Status | Issues Found | Issues Fixed |
|----------|--------|-------------|-------------|
| Code Cleanup | PASS/FAIL | N | N |
| Environment & Secrets | PASS/FAIL | N | N |
| Security Hardening | PASS/FAIL | N | N |
| Observability | PASS/FAIL | N | N |
| Testing | PASS/FAIL | N | N |
| CI/CD | PASS/FAIL | N | N |
| Documentation | PASS/FAIL | N | N |

## Overall Verdict: READY / NOT READY

## Remaining Action Items
- [ ] [Action item with owner and priority]
- [ ] ...

## Detailed Findings
[Per-phase findings with file paths and line numbers]
```

### Step 6: Pre-Deploy Checklist Confirmation

Present the final checklist to the user via AskUserQuestion:

**"Have you completed these external setup steps?"** (multi-select)
- [ ] Domain DNS configured
- [ ] SSL certificate provisioned (or auto-SSL enabled)
- [ ] Production database provisioned
- [ ] All API keys obtained and set in deployment environment
- [ ] Error monitoring project created (Sentry)
- [ ] Billing/payment webhooks configured (if applicable)
- [ ] Team notified of deployment plan
- [ ] Rollback plan reviewed

---

## Rules

- ALWAYS detect the stack automatically before asking questions — show the user you already understand their project.
- ALWAYS ask about production services (auth, payments, monitoring) — never assume.
- ALWAYS scan for hardcoded secrets BEFORE any other step — a leaked key is the highest-priority finding.
- ALWAYS generate both DEPLOY.md and the readiness report — one is for operators, the other is for auditors.
- ALWAYS validate that the production build succeeds — if it doesn't build, nothing else matters.
- ALWAYS create `.env.example` with descriptive comments and "where to get this" links for every variable.
- ALWAYS implement env validation at startup (Zod for TS, Pydantic for Python) — apps should crash loudly on missing config, not fail silently at runtime.
- NEVER remove console.log calls that are wrapped in a proper logger — only remove raw console.* calls.
- NEVER commit fixes to the main branch directly — create a `chore/production-ready` branch for all changes.
- NEVER mark the project as READY if any FAIL categories remain — be honest in the report.
- NEVER skip the graceful shutdown check — ungraceful shutdowns cause data loss and dropped requests in production.
- NEVER set CORS to `*` in production configuration — always whitelist specific origins.
- NEVER auto-delete TODO comments without user confirmation — some may be intentional tech debt the user is tracking.
- If `/security-audit` or `/perf-audit` has been run recently, READ its report instead of re-running those checks — avoid duplicate work.
- Prefer fixing issues inline over just reporting them — this command is about making the app ready, not just auditing it.
