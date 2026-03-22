# Brainstorm: claude-super-setup Improvements

**Date:** 2026-03-21
**Informed by:** Research Brief (`docs/research/research-brief.md`)
**Method:** SCAMPER + Six Thinking Hats for each major category
**Goal:** Generate a wide option space for improvements, then filter to the top 25 ideas.

---

## Category 1: Portability & Installation

### Current State
All config lives in `~/.claude/` with no install script, no versioning, no backup, no uninstall. Setting up on a new machine requires manually copying files.

### Ideas (Unfiltered)

| # | Idea | Approach |
|---|------|----------|
| 1.1 | **One-line installer** | `curl -fsSL https://raw.githubusercontent.com/user/claude-super-setup/main/install.sh \| bash` |
| 1.2 | **GNU Stow symlinks** | Use stow to manage symlinks from repo to ~/.claude/. `stow -t ~/.claude config/` |
| 1.3 | **Direct symlink install** | `ln -sf` from repo directories to ~/.claude/ paths. Simplest approach. |
| 1.4 | **Copy-mode install** | Deep copy with rsync. For machines where symlinks cause issues (e.g., some Docker setups). |
| 1.5 | **Homebrew formula** | `brew install claude-super-setup` — manages versioning, updates via `brew upgrade`. |
| 1.6 | **npm package** | `npx claude-super-setup install` — leverages npm's global install infrastructure. |
| 1.7 | **Backup before install** | Automatically archive existing ~/.claude/ to `~/.claude-backup-{timestamp}/` before overwriting. |
| 1.8 | **--dry-run flag** | Show what would be changed without changing anything. Essential for trust. |
| 1.9 | **--mode flag** | `--mode=symlink` (default) or `--mode=copy`. Symlink = instant updates on git pull. |
| 1.10 | **Personal override layer** | `user-overrides/` directory with templates for personal CLAUDE.md additions, settings.local.json. |
| 1.11 | **Uninstall script** | `uninstall.sh` that removes symlinks/copies and optionally restores backup. |
| 1.12 | **Health check post-install** | After install, run verification: all expected files exist, hooks are executable, settings.json is valid. |
| 1.13 | **Dotfiles integration** | Compatibility with chezmoi/yadm — treat claude-super-setup as a dotfiles module. |
| 1.14 | **Version pinning** | `.claude-super-setup-version` file that the installer checks. Prevents accidental downgrades. |
| 1.15 | **Selective install** | `--modules=core,web-templates,mobile-templates,agents` — install only what you need. |

### Best Ideas (Top 5)
1. **1.3 Direct symlink install** with **1.7 backup** and **1.8 --dry-run** — simplest, most reliable. GNU Stow adds unnecessary dependency.
2. **1.10 Personal override layer** — critical for separating shared vs personal config.
3. **1.11 Uninstall script** — must-have for trust and clean removal.
4. **1.12 Health check post-install** — catches broken installs immediately.
5. **1.15 Selective install** — useful for teams that only want templates or only want agents.

---

## Category 2: Autonomous CI/CD

### Current State
No CI/CD. No validation. No versioning. Configs can drift silently. No automated improvement process.

### Ideas (Unfiltered)

| # | Idea | Approach |
|---|------|----------|
| 2.1 | **shellcheck all hooks** | `shellcheck hooks/*.sh` in CI. Catches syntax errors, quoting issues, undefined variables. |
| 2.2 | **markdownlint commands/agents/rules** | `markdownlint-cli2 commands/ agents/ rules/` — consistent markdown formatting. |
| 2.3 | **YAML schema validation** | JSON Schema for stack templates. `ajv validate -s schema.json -d config/stacks/*.yaml`. |
| 2.4 | **actionlint workflows** | `actionlint .github/workflows/*.yml` — catch workflow syntax errors. |
| 2.5 | **Inventory assertions** | Assert expected counts: ≥70 commands, ≥40 agents, ≥12 hooks, ≥16 rules. Catches accidental deletions. |
| 2.6 | **Agent front-matter validation** | Every agent .md must have: name, description, model, tools. Custom validator script. |
| 2.7 | **Command front-matter validation** | Every command .md must have a title and description section. |
| 2.8 | **Broken link checker** | Cross-reference check: if command X references agent Y, agent Y must exist. |
| 2.9 | **release-please automation** | Conventional commits → automatic CHANGELOG generation → GitHub Release → semver tag. |
| 2.10 | **Claude Code Action PR reviews** | Every PR to the config repo gets reviewed by Claude for quality, consistency, and potential issues. |
| 2.11 | **Scheduled improvement runs** | Weekly cron: Claude Code Action analyzes the setup, identifies stale agents/templates, proposes improvements as PRs. |
| 2.12 | **Drift detection** | Compare local ~/.claude/ against repo HEAD. Report files that have been modified locally but not committed. |
| 2.13 | **Template smoke tests** | For each stack template YAML, validate that all referenced files in starter_files have valid content. |
| 2.14 | **Hook dry-run tests** | Run each hook with mock input to verify it doesn't throw syntax errors or crash. |
| 2.15 | **Diff-based PR summaries** | CI bot comments on PRs: "This PR adds 3 new agents, modifies 1 hook, adds 2 templates." |
| 2.16 | **Dependabot for tool versions** | Track versions of shellcheck, markdownlint, ajv, actionlint in CI and auto-update. |
| 2.17 | **Autonomous template updates** | Scheduled: check if framework versions in templates are outdated (e.g., Next.js 15 → 16). Propose update PRs. |
| 2.18 | **Agent quality scoring** | Scheduled: score each agent by prompt length, specificity, tool list, model tier. Flag low-quality agents. |

### Best Ideas (Top 5)
1. **2.1-2.5 Core validation suite** — shellcheck + markdownlint + YAML schema + actionlint + inventory. This is the foundation.
2. **2.9 release-please** — automated versioning with zero maintenance.
3. **2.10-2.11 Claude Code Action** — PR reviews + weekly improvement proposals. The "self-improving config repo" innovation.
4. **2.12 Drift detection** — catches local modifications that haven't been committed. Run via CI or as a local command.
5. **2.17 Autonomous template updates** — framework versions go stale; automated detection + update PRs keep templates current.

---

## Category 3: New Website Templates

### Current State
Only `web-app.yaml` (Next.js 15 + Supabase). Covers full-stack React apps but nothing else.

### Ideas (Unfiltered)

| # | Template | Stack | Best For |
|---|----------|-------|----------|
| 3.1 | **web-astro.yaml** | Astro 5 + Tailwind + content collections + Cloudflare Pages | Content sites, marketing pages, blogs, documentation |
| 3.2 | **web-t3.yaml** | Next.js 15 + tRPC + Prisma + NextAuth.js + Tailwind | Opinionated full-stack apps with type-safe API |
| 3.3 | **web-sveltekit.yaml** | SvelteKit 2 + Tailwind + Lucia auth + Drizzle | Performance-first apps, smaller bundle size |
| 3.4 | **web-remix.yaml** | Remix + Vite + Tailwind + Cloudflare Workers | Edge-first full-stack apps with progressive enhancement |
| 3.5 | **web-nuxt.yaml** | Nuxt 3 + Vue 3 + Tailwind + Supabase | Vue ecosystem apps |
| 3.6 | **web-tanstack.yaml** | TanStack Start + TanStack Router + Vite | React apps without Next.js framework lock-in |
| 3.7 | **web-fresh.yaml** | Fresh (Deno) + Tailwind | Deno ecosystem, no build step, islands architecture |
| 3.8 | **web-analog.yaml** | Analog (Angular meta-framework) + Tailwind | Angular ecosystem |

### Best Ideas (Top 4 — prioritized by market demand)
1. **3.1 Astro 5** — fastest-growing framework for content sites. Different use case from Next.js (content vs. apps). Cloudflare Pages deployment.
2. **3.2 T3 Stack** — most requested opinionated full-stack stack. tRPC gives end-to-end type safety that our current Next.js template lacks.
3. **3.3 SvelteKit** — growing market share, fundamentally different reactivity model, smaller bundles. Appeals to performance-sensitive developers.
4. **3.4 Remix** — Cloudflare Workers edge deployment is a different paradigm from Vercel. Progressive enhancement philosophy.

### Deferred
- 3.5 Nuxt (Vue market share declining vs React/Svelte)
- 3.6 TanStack Start (too new, unstable API)
- 3.7 Fresh (Deno ecosystem too small)
- 3.8 Analog (Angular meta-framework market too small)

---

## Category 4: New Mobile Templates

### Current State
Only `mobile-app.yaml` (Expo + TypeScript + Supabase). Basic template with Expo Router and AsyncStorage.

### Ideas (Unfiltered)

| # | Template | Stack | Best For |
|---|----------|-------|----------|
| 4.1 | **mobile-nativewind.yaml** | Expo + NativeWind (Tailwind for RN) + Expo Router + Supabase | Developers who know Tailwind and want consistent web/mobile styling |
| 4.2 | **mobile-flutter.yaml** | Flutter 3 + Dart + Supabase + Riverpod | Cross-platform with strong community, different ecosystem from RN |
| 4.3 | **mobile-expo-revenucat.yaml** | Expo + RevenueCat + Expo Router + Supabase | Apps with subscriptions / in-app purchases |
| 4.4 | **mobile-expo-offline.yaml** | Expo + WatermelonDB + React Query + Expo Router | Offline-first apps with local-first data |
| 4.5 | **mobile-expo-ai.yaml** | Expo + AI SDK + Expo Router + Supabase | Mobile apps with LLM integration (chat, assistants) |
| 4.6 | **mobile-capacitor.yaml** | Capacitor + Next.js/React + Tailwind | Wrap existing web apps for mobile distribution |

### Best Ideas (Top 3)
1. **4.1 Expo + NativeWind** — massive demand. Tailwind CSS for React Native means web developers can build mobile apps with familiar styling. Include Expo Router v4, Reanimated, Gesture Handler.
2. **4.2 Flutter + Supabase** — completely different ecosystem from React Native. Captures Flutter developers. Riverpod for state management (modern, testable).
3. **4.3 Expo + RevenueCat** — monetization template. RevenueCat handles subscription complexity across iOS/Android. High-value template for indie developers.

### Deferred
- 4.4 Offline-first (niche use case)
- 4.5 AI mobile app (can be added to any template as needed)
- 4.6 Capacitor (wrapper approach, not native-first)

---

## Category 5: Specialized Templates

### Current State
No specialized templates exist. All templates are generic framework scaffolds.

### Ideas (Unfiltered)

| # | Template | Stack | Best For |
|---|----------|-------|----------|
| 5.1 | **saas-starter.yaml** | Next.js 15 + Supabase Auth + Stripe + Tailwind + shadcn/ui + Resend | SaaS apps with auth, billing, email, and dashboard |
| 5.2 | **ai-ml-app.yaml** | Next.js 15 + AI SDK (Vercel) + Supabase + pgvector + Tailwind | AI-powered apps with RAG, chat, embeddings |
| 5.3 | **chrome-extension.yaml** | TypeScript + Vite + React + Tailwind + Chrome Extension Manifest V3 | Browser extensions with popup, content scripts, background workers |
| 5.4 | **cli-tool.yaml** | TypeScript + Commander.js + Vitest + tsup (bundler) | CLI tools with argument parsing, help text, testing |
| 5.5 | **cli-tool-python.yaml** | Python + Click + Rich + pytest + uv | Python CLI tools with rich output and testing |
| 5.6 | **discord-bot.yaml** | TypeScript + discord.js + Hono (API) + Supabase | Discord bots with slash commands and API backend |
| 5.7 | **electron-app.yaml** | Electron + React + Vite + Tailwind | Desktop apps with web technologies |
| 5.8 | **monorepo.yaml** | Turborepo + Next.js + Hono API + shared packages | Monorepo with frontend, backend, and shared code |
| 5.9 | **landing-page.yaml** | Astro + Tailwind + Framer Motion + Resend | Marketing landing pages with animations and email capture |

### Best Ideas (Top 4)
1. **5.1 SaaS Starter** — highest demand template. Auth (Supabase), billing (Stripe), email (Resend), dashboard with shadcn/ui. Saves weeks of setup for every SaaS project.
2. **5.2 AI/ML App** — AI is the dominant use case for new apps. RAG pipeline with pgvector, streaming chat with AI SDK, embeddings. Template includes vector store setup.
3. **5.3 Chrome Extension** — underserved category. Manifest V3 is confusing; a template with proper content script, popup, and background worker scaffolding is high-value.
4. **5.4 CLI Tool (TypeScript)** — common need, tedious to set up. Commander.js + tsup bundler + Vitest testing. Includes bin field in package.json, GitHub Actions for npm publish.

### Deferred
- 5.5 Python CLI (lower priority, can add later)
- 5.6 Discord bot (niche)
- 5.7 Electron (declining, consider Tauri instead)
- 5.8 Monorepo (complex, defer to v2)
- 5.9 Landing page (Astro template partially covers this)

---

## Category 6: Backend Templates

### Current State
Only `api-service.yaml` (Hono + Drizzle + PostgreSQL). Node.js-only.

### Ideas (Unfiltered)

| # | Template | Stack | Best For |
|---|----------|-------|----------|
| 6.1 | **api-fastapi.yaml** | FastAPI + Python + SQLAlchemy + Alembic + PostgreSQL | Python APIs, AI/ML backends, data services |
| 6.2 | **api-hono-edge.yaml** | Hono + Cloudflare Workers + D1 (SQLite at edge) + Drizzle | Edge-first APIs, zero cold start, global distribution |
| 6.3 | **api-express.yaml** | Express 5 + TypeScript + Prisma + PostgreSQL | Traditional Node.js APIs (largest ecosystem) |
| 6.4 | **api-go.yaml** | Go + Chi router + sqlc + PostgreSQL | High-performance APIs, systems programming |
| 6.5 | **api-elixir.yaml** | Phoenix + Elixir + Ecto + PostgreSQL | Real-time APIs, WebSocket-heavy apps, LiveView |

### Best Ideas (Top 2)
1. **6.1 FastAPI + Python** — essential for AI/ML projects. Our RideFund Mobile backend uses FastAPI. SQLAlchemy + Alembic for ORM and migrations. Include Pydantic models, structured logging, Docker multi-stage build.
2. **6.2 Hono + Cloudflare Workers** — edge variant of our existing Hono template. D1 for SQLite at edge (no external database needed). Zero cold start. Different deployment model worth having as a separate template.

### Deferred
- 6.3 Express (legacy, Hono is the successor)
- 6.4 Go (need Go-specific rules and agents first)
- 6.5 Elixir (niche ecosystem)

---

## Category 7: Agent Ecosystem Integration

### Current State
40+ agents across 8 departments. No external agent imports. No marketplace. Manual model assignment. No preset teams. No capability tagging.

### Ideas (Unfiltered)

| # | Idea | Source | Impact |
|---|------|--------|--------|
| 7.1 | **Import language specialists** | VoltAgent (20+), everything-claude (per-language reviewers) | Cover Go, Rust, Java, Swift, Kotlin, PHP, Ruby, Elixir |
| 7.2 | **Import data/AI agents** | VoltAgent (ML pipeline builder, data engineer) | Support AI/ML development workflows |
| 7.3 | **Import infrastructure agents** | wshobson (Kubernetes, Terraform, AWS, GCP) | Support cloud infrastructure management |
| 7.4 | **Import mobile specialists** | senaiverse (7 RN agents: accessibility, performance, security) | Mobile-specific quality agents |
| 7.5 | **4-tier model routing** | wshobson design | haiku (trivial) → sonnet (standard) → opus (review/plan) → custom |
| 7.6 | **Agent catalog (catalog.json)** | New design | Registry with capabilities, model tier, team membership, source |
| 7.7 | **Preset team compositions** | wshobson preset teams | `review`, `debug`, `feature`, `fullstack`, `mobile`, `security`, `research` |
| 7.8 | **Auto model routing** | oh-my-claudecode | Dynamic model selection based on task complexity at runtime |
| 7.9 | **Agent capability tags** | New design | Tags like `typescript`, `python`, `security`, `performance`, `mobile`, `ai` |
| 7.10 | **Agent health checks** | New design | Canary prompts that validate agent output structure and quality |
| 7.11 | **Agent versioning** | New design | Semantic versions on agents, deprecation warnings, migration paths |
| 7.12 | **Party Mode** | BMAD official | Multiple agent personas collaborate in single session for design reviews |
| 7.13 | **Agent marketplace install** | VoltAgent pattern | `claude plugin marketplace add` equivalent for community agents |
| 7.14 | **Architect verification for Ralph** | oh-my-claudecode | Add architect validation step to Ralph loop completion |
| 7.15 | **Progressive disclosure** | wshobson skills | Agent prompts reveal info incrementally to save tokens |

### Best Ideas (Top 7)
1. **7.6 Agent catalog** — foundation for everything else. JSON registry that maps agent name → capabilities, model tier, team membership, source (core/community/project).
2. **7.5 4-tier model routing** — immediate token savings. Every agent gets a model tier: `haiku` (simple tasks like formatting), `sonnet` (standard development), `opus` (architecture, review, planning), `custom` (specialized models).
3. **7.7 Preset teams** — pre-configured agent compositions:
   - `review`: code-reviewer + security-auditor + test-analyzer
   - `frontend`: frontend-dev + ui-designer + tdd-test-writer + whimsy-injector
   - `backend`: backend-dev + architect + security-auditor
   - `fullstack`: architect + backend-dev + frontend-dev + test-writer-fixer
   - `mobile`: mobile-app-builder + ui-designer + test-writer-fixer
   - `research`: researcher + trend-researcher + feedback-synthesizer
   - `security`: security-auditor + code-reviewer + silent-failure-hunter
4. **7.1 Language specialists** — import/adapt 8-10 language-specific agents for Go, Rust, Java, Swift, Kotlin, Ruby, PHP, Elixir.
5. **7.2 Data/AI agents** — import ML pipeline builder, data engineer, prompt engineer agents for AI/ML workflows.
6. **7.4 Mobile specialists** — import senaiverse's accessibility, performance, security agents for React Native.
7. **7.9 Capability tags** — enable agent discovery: "find me agents that know about `typescript` and `security`."

### Deferred
- 7.8 Auto model routing (complex runtime logic, defer to v2)
- 7.10 Agent health checks (defer until catalog is stable)
- 7.11 Agent versioning (premature until import process is defined)
- 7.12 Party Mode (experimental, defer to v2)
- 7.13 Marketplace install (needs community adoption first)
- 7.14 Architect verification (Ralph plugin modification, defer)
- 7.15 Progressive disclosure (skill format change, defer to v2)

---

## Category 8: Developer Experience

### Current State
No shell completion. No migration guides. No cross-machine learning sync. No agent discovery command. Learning system is single-machine.

### Ideas (Unfiltered)

| # | Idea | Impact |
|---|------|--------|
| 8.1 | **Shell completion** | Tab completion for all 70+ commands. ZSH/Bash completion scripts generated from command front-matter. |
| 8.2 | **Command discovery** | `css` or `/commands` — list all commands with descriptions, grouped by category. |
| 8.3 | **Agent discovery** | `/agents` — list all agents with capabilities, model tier, department. Filter by tag. |
| 8.4 | **Migration guide** | `UPGRADING.md` — how to upgrade from v1 to v2. What changed, what to back up, manual steps. |
| 8.5 | **Cross-machine learning sync** | Export/import learnings between machines. Store learnings in git (anonymized) or sync via cloud. |
| 8.6 | **Setup wizard** | Interactive installer: "Which templates do you want? Which agents? What model do you use?" |
| 8.7 | **Dashboard command** | `/dashboard` — show setup health: installed agents, available templates, learning count, last consolidation, CI status. |
| 8.8 | **Template browser** | `/templates` — interactive browser showing all available stack templates with descriptions and previews. |
| 8.9 | **Config diff** | `claude-super-setup diff` — show differences between local config and repo HEAD. |
| 8.10 | **Auto-update** | `claude-super-setup update` — git pull + re-run install to pick up changes. |

### Best Ideas (Top 4)
1. **8.2 Command discovery** — `/commands` that lists all 70+ commands grouped by category with descriptions. Low effort, high value.
2. **8.3 Agent discovery** — `/agents` with capability filtering. Especially valuable after importing community agents.
3. **8.4 Migration guide** — `UPGRADING.md` is essential for any versioned project. Must ship with v1.0.
4. **8.10 Auto-update** — `claude-super-setup update` that pulls latest and re-symlinks. Simple wrapper around git pull.

---

## Filtered Top 25 Ideas (Ranked)

| Rank | ID | Idea | Category | Impact | Effort | Uniqueness |
|------|-----|------|----------|--------|--------|------------|
| 1 | 1.3 | Direct symlink installer (install.sh) | Portability | HIGH | LOW | HIGH |
| 2 | 2.1-2.5 | Core CI validation suite | CI/CD | HIGH | MEDIUM | HIGH |
| 3 | 2.11 | Scheduled Claude improvement runs | CI/CD | HIGH | MEDIUM | VERY HIGH |
| 4 | 5.1 | SaaS Starter template | Specialized | HIGH | MEDIUM | HIGH |
| 5 | 7.6 | Agent catalog (catalog.json) | Agents | HIGH | MEDIUM | HIGH |
| 6 | 7.5 | 4-tier model routing | Agents | HIGH | LOW | MEDIUM |
| 7 | 3.1 | Astro 5 template | Web | HIGH | LOW | HIGH |
| 8 | 6.1 | FastAPI + Python template | Backend | HIGH | MEDIUM | HIGH |
| 9 | 4.1 | Expo + NativeWind template | Mobile | HIGH | LOW | HIGH |
| 10 | 2.9 | release-please automation | CI/CD | MEDIUM | LOW | MEDIUM |
| 11 | 7.7 | Preset agent teams | Agents | HIGH | LOW | MEDIUM |
| 12 | 3.2 | T3 Stack template | Web | HIGH | MEDIUM | HIGH |
| 13 | 5.2 | AI/ML App template | Specialized | HIGH | HIGH | HIGH |
| 14 | 1.10 | Personal override layer | Portability | HIGH | LOW | MEDIUM |
| 15 | 2.10 | Claude Code Action PR reviews | CI/CD | MEDIUM | LOW | MEDIUM |
| 16 | 4.2 | Flutter + Supabase template | Mobile | MEDIUM | MEDIUM | HIGH |
| 17 | 3.3 | SvelteKit template | Web | MEDIUM | MEDIUM | HIGH |
| 18 | 5.3 | Chrome Extension template | Specialized | MEDIUM | MEDIUM | VERY HIGH |
| 19 | 7.1 | Import language specialist agents | Agents | HIGH | MEDIUM | MEDIUM |
| 20 | 1.11 | Uninstall script | Portability | MEDIUM | LOW | MEDIUM |
| 21 | 3.4 | Remix template | Web | MEDIUM | MEDIUM | HIGH |
| 22 | 5.4 | CLI Tool template | Specialized | MEDIUM | LOW | HIGH |
| 23 | 6.2 | Hono + Cloudflare Workers template | Backend | MEDIUM | LOW | HIGH |
| 24 | 4.3 | Expo + RevenueCat template | Mobile | MEDIUM | MEDIUM | VERY HIGH |
| 25 | 8.2 | Command discovery (/commands) | DX | MEDIUM | LOW | MEDIUM |

---

## Ideas to Defer or Reject

| Idea | Reason to Defer |
|------|-----------------|
| GNU Stow install | Adds unnecessary dependency; direct symlinks are simpler and more portable |
| Homebrew formula | Requires Homebrew Tap maintenance; defer until significant community adoption |
| npm package install | Conflates Node.js dependency with shell config management |
| Nuxt 3 template | Vue ecosystem declining vs React/Svelte; limited demand |
| TanStack Start template | Too new, unstable API surface |
| Express template | Legacy; Hono is the spiritual successor with Web Standards |
| Go/Elixir templates | Need language-specific rules, agents, and hooks first |
| Auto model routing | Complex runtime logic; start with static 4-tier assignment |
| Party Mode | Experimental in BMAD; defer until proven pattern |
| Agent marketplace | Needs community adoption before infrastructure makes sense |
| Agent versioning | Premature until import/adaptation process is defined |
| Cross-machine learning sync | Privacy concerns, requires server component or encrypted git storage |
| Setup wizard | Interactive installers don't work well in CI or scripted environments; defer |
| Electron template | Declining; Tauri is the successor but ecosystem too young |
| Monorepo template | Complex, requires Turborepo expertise, defer to v2 |
| Offline-first mobile | Niche use case, WatermelonDB is complex to template |
