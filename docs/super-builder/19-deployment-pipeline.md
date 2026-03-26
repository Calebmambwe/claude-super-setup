# Deployment Pipeline Specification

## Overview

Every generated app should be deployable from the moment it's created. The pipeline handles CI/CD, preview deployments, production releases, and monitoring.

## CI/CD Pipeline (GitHub Actions)

### Standard Pipeline (all templates)

```yaml
name: CI
on:
  push:
    branches: [main, 'feat/**']
  pull_request:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile

      - name: TypeScript
        run: pnpm typecheck

      - name: Lint
        run: pnpm lint

      - name: Unit Tests
        run: pnpm test

      - name: Build
        run: pnpm build

  e2e:
    needs: quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: npx playwright install --with-deps

      - name: E2E Tests
        run: pnpm test:e2e

      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/

  deploy-preview:
    needs: [quality, e2e]
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}

  deploy-production:
    needs: [quality, e2e]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
```

### Docker Pipeline (self-hosted)

```yaml
  docker:
    needs: quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## Deployment Targets

| Target | Use Case | Setup Command |
|--------|----------|--------------|
| Vercel | Frontend + serverless | `vercel link && vercel deploy` |
| Railway | Full-stack + database | `railway init && railway up` |
| Fly.io | Docker containers | `fly launch && fly deploy` |
| Supabase | Database + auth + storage | `supabase init && supabase db push` |
| Cloudflare | Edge workers | `wrangler deploy` |

## Preview Deployments

Every PR gets a preview deployment:
1. CI builds the app
2. Deploys to preview URL (Vercel auto-generates)
3. Comment on PR with preview link
4. Run E2E tests against preview URL
5. Screenshot comparison against main branch

## Monitoring (Post-Deploy)

### Health Check
```typescript
// app/api/health/route.ts — auto-generated
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.COMMIT_SHA?.slice(0, 7) ?? 'dev',
  });
}
```

### Error Tracking
- Sentry integration (auto-configured in templates)
- Source maps uploaded during build
- Alert on new error types

### Uptime Monitoring
- Health endpoint pinged every 60s
- Alert on 3 consecutive failures
- Status page integration (optional)

## Rollback Strategy

If deployment causes issues:
1. Automatic: Vercel/Railway instant rollback to previous deployment
2. Manual: `git revert <commit> && git push` → triggers new deployment
3. Emergency: `/rollback PR#42` command reverts merge and redeploys
