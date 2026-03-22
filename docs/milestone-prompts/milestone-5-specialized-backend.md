# Milestone 5: Specialized & Backend Templates

## Section 1: Task Summary

**What:** Create 6 new stack templates: 4 specialized application templates and 2 backend API templates.

**Templates to create:**
1. `saas-starter.yaml` — Next.js 15 + Supabase Auth + Stripe + Resend + shadcn/ui
2. `ai-ml-app.yaml` — Next.js 15 + Vercel AI SDK + Supabase + pgvector
3. `chrome-extension.yaml` — TypeScript + Vite + React + Chrome Manifest V3
4. `cli-tool.yaml` — TypeScript + Commander.js + tsup + chalk
5. `api-fastapi.yaml` — FastAPI + Python + SQLAlchemy + Alembic + PostgreSQL
6. `api-hono-edge.yaml` — Hono + Cloudflare Workers + D1 (SQLite) + Drizzle

**In scope:**
- YAML template files following the canonical format
- Schema validation for all 6
- Framework-specific starter files, CLAUDE.md, AGENTS.md

**Out of scope:**
- Production deployment automation
- Payment processing logic (Stripe template provides setup only)
- ML model training pipelines (AI template provides inference/RAG only)

**Definition of done:**
- [ ] 6 new YAML files in `config/stacks/`
- [ ] All 6 validate against JSON Schema
- [ ] SaaS template includes auth, billing, email, and dashboard scaffolding
- [ ] AI/ML template includes RAG pipeline with pgvector and streaming chat
- [ ] Chrome extension template includes popup, content script, and background worker
- [ ] CLI template includes argument parsing, help generation, and npm publish config
- [ ] FastAPI template follows Route→Service→Repository pattern
- [ ] Hono Edge template uses D1 SQLite and Workers-compatible APIs

## Section 2: Project Background

**Canonical references:**
- Web templates: `config/stacks/web-app.yaml`
- API templates: `config/stacks/api-service.yaml`
- These are the most complex templates in the set — especially SaaS and AI/ML

**Special considerations:**
- Chrome extension has no server — different commands (no `dev server` per se, uses browser extension loading)
- CLI tool publishes to npm — include `bin` field in package.json
- FastAPI uses Python — different tooling (uv, pytest, ruff, mypy)
- Hono Edge uses Cloudflare Workers — different deployment model (wrangler)

## Section 3: Current Task Context

M1 and M2 complete. Parallel with M3, M4, M6, M7.

## Section 4: Design Document Reference

See `docs/design/design-document.md`:
- Section 3.1: Stack template schema
- Section 4.5: Template specifications table

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read both `config/stacks/web-app.yaml` and `config/stacks/api-service.yaml`
2. Use Context7 for: Stripe API (checkout sessions, webhooks), Resend API, Vercel AI SDK (streaming, tools), pgvector setup
3. Use Context7 for: Chrome Extension Manifest V3 APIs, Commander.js, tsup bundler
4. Use Context7 for: FastAPI + SQLAlchemy async patterns, Alembic migration setup
5. Use Context7 for: Cloudflare Workers D1 SQLite API, Wrangler configuration
6. Review Chrome MV3 migration patterns (background script → service worker)

## Section 6: Implementation Instructions

### Template-specific guidance

**saas-starter.yaml:**
- Start from web-nextjs but add: Supabase Auth (email/password + OAuth), Stripe (checkout + webhooks + customer portal), Resend (transactional email)
- Starter files:
  - `src/lib/stripe.ts` — Stripe client initialization
  - `src/app/api/webhooks/stripe/route.ts` — Stripe webhook handler
  - `src/app/(dashboard)/layout.tsx` — authenticated dashboard layout
  - `src/app/(auth)/login/page.tsx` — login page with Supabase Auth
  - `src/components/shared/pricing-card.tsx` — pricing display component
- CLAUDE.md: document auth flow, billing flow, webhook verification
- AGENTS.md gotchas: Stripe webhook signature verification, Supabase RLS policies, Resend rate limits

**ai-ml-app.yaml:**
- Start from web-nextjs but add: AI SDK (`ai` package from Vercel), pgvector extension for Supabase
- Starter files:
  - `src/app/api/chat/route.ts` — streaming chat endpoint with AI SDK
  - `src/lib/ai.ts` — AI provider configuration (Anthropic/OpenAI)
  - `src/lib/embeddings.ts` — text embedding generation
  - `src/lib/vector-store.ts` — pgvector query helpers
  - `src/components/shared/chat.tsx` — chat UI component with streaming
  - `src/app/api/ingest/route.ts` — document ingestion endpoint
- SQL: include migration for pgvector extension and embeddings table
- AGENTS.md gotchas: streaming response format, token limits, embedding dimensions must match model

**chrome-extension.yaml:**
- Unique structure — no server, no framework router
- Starter files:
  - `manifest.json` — Manifest V3 with permissions, content_scripts, action, background
  - `src/popup/index.tsx` — popup UI (React)
  - `src/popup/index.html` — popup HTML entry
  - `src/content/index.ts` — content script injected into pages
  - `src/background/index.ts` — service worker (background)
  - `src/shared/storage.ts` — chrome.storage.local wrapper
  - `vite.config.ts` — multi-entry build (popup + content + background)
- Commands: `dev` = Vite build watch, `build` = production build, `test` = vitest
- No `dev server` in traditional sense — load unpacked extension from dist/
- AGENTS.md gotchas: MV3 service workers have 5-min idle timeout, content scripts run in isolated world

**cli-tool.yaml:**
- Minimal template for Node.js CLI tools
- Starter files:
  - `src/index.ts` — main entry with Commander.js program definition
  - `src/commands/hello.ts` — sample command
  - `src/lib/config.ts` — config file handling (XDG base dirs)
  - `src/__tests__/hello.test.ts` — command test
  - `tsup.config.ts` — bundler config (ESM output, banner with shebang)
- package.json must include: `"bin": {"tool-name": "./dist/index.js"}`, `"type": "module"`
- Commands: `dev` = tsx watch, `build` = tsup, `test` = vitest
- AGENTS.md gotchas: shebang must be in bundled output, use `process.exit()` codes correctly

**api-fastapi.yaml:**
- Python stack — different conventions entirely
- Starter files:
  - `src/main.py` — FastAPI app with CORS, lifespan
  - `src/routes/health.py` — health endpoint
  - `src/services/__init__.py` — service layer
  - `src/repositories/__init__.py` — repository layer
  - `src/models/base.py` — SQLAlchemy base model
  - `src/schemas/common.py` — Pydantic response envelope
  - `src/core/config.py` — Pydantic Settings for env validation
  - `src/core/database.py` — async SQLAlchemy session
  - `alembic.ini` + `alembic/env.py` — migration config
  - `tests/test_health.py` — pytest test
  - `Dockerfile` — multi-stage with uv
  - `pyproject.toml` — project config with uv
- Commands: `dev` = uv run uvicorn, `test` = uv run pytest, `lint` = uv run ruff check, `typecheck` = uv run mypy
- AGENTS.md gotchas: async SQLAlchemy requires `AsyncSession`, Alembic with async needs special env.py

**api-hono-edge.yaml:**
- Edge variant of existing Hono template
- Key difference: Cloudflare Workers runtime (not Node.js), D1 SQLite (not PostgreSQL)
- Starter files:
  - `src/index.ts` — Hono app with Cloudflare Workers entry
  - `src/routes/health.ts` — health endpoint
  - `wrangler.toml` — Cloudflare Workers config with D1 binding
  - `src/db/schema.ts` — Drizzle schema for D1
  - `src/db/index.ts` — Drizzle client with D1 binding
- Commands: `dev` = wrangler dev, `deploy` = wrangler deploy, `test` = vitest
- AGENTS.md gotchas: D1 is SQLite not PostgreSQL (different SQL syntax), Workers have 128MB memory limit, no Node.js APIs (use Web Standards)

### Git workflow
- Branch: `feature/specialized-backend-templates`
- One commit per template: `feat: add {name} stack template`

## Section 7: Final Reminders

- Validate each YAML against schema
- Use Context7 for EVERY library — especially Stripe, AI SDK, pgvector, Chrome MV3
- FastAPI template must use Python conventions (snake_case, Pydantic, type hints)
- Chrome extension is fundamentally different from web apps — no server, no router
- CLI tool must include shebang handling in tsup config
- AI/ML template embedding dimensions must match the model being used (document this)
- SaaS Stripe webhook handler MUST verify signatures — security critical
