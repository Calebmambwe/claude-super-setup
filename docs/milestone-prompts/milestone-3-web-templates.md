# Milestone 3: Web Templates

## Section 1: Task Summary

**What:** Create 4 new web stack templates in YAML format, following the exact pattern of the existing `web-nextjs.yaml` template.

**Templates to create:**
1. `web-astro.yaml` — Astro 5 + Tailwind + content collections + Cloudflare Pages
2. `web-t3.yaml` — Next.js 15 + tRPC + Prisma + NextAuth.js + Tailwind
3. `web-sveltekit.yaml` — SvelteKit 2 + Tailwind + Lucia auth + Drizzle ORM
4. `web-remix.yaml` — Remix + Vite + Tailwind + Cloudflare Workers

**In scope:**
- YAML template file for each (init_commands, directories, starter_files, commands, claude_md, agents_md)
- Each template must validate against `schemas/stack-template.schema.json`
- Each template must include env validation (Zod/equivalent), test setup, and smoke test

**Out of scope:**
- Devcontainer configuration (defer)
- Docker configuration (only for templates that need it)
- Database setup (except Prisma in T3 which needs it)

**Definition of done:**
- [ ] 4 new YAML files in `config/stacks/`
- [ ] All 4 validate against the JSON Schema
- [ ] Each has complete: init_commands, directories, starter_files, commands, env_example, claude_md, agents_md
- [ ] Framework versions are pinned to latest stable
- [ ] CLAUDE.md content includes project-specific conventions
- [ ] AGENTS.md content includes stack-specific gotchas

## Section 2: Project Background

**Canonical reference:** Read `config/stacks/web-app.yaml` — this is the gold standard. Every new template must match its structure exactly: same YAML fields, same level of detail in starter_files, same quality of CLAUDE.md and AGENTS.md content.

**Template schema fields (all required):** name, description, short_label, init_commands, directories, starter_files, commands (dev, test, build, lint, typecheck), env_example, claude_md, agents_md

**Optional fields:** package_json_scripts, gitignore_extra, devcontainer

## Section 3: Current Task Context

M1 (Scaffold) and M2 (Install) are complete. This milestone can run in parallel with M4, M5, M6, M7.

## Section 4: Design Document Reference

See `docs/design/design-document.md`:
- Section 3.1: Stack template YAML schema
- Section 4.5: Template specifications table (framework, dependencies, deployment, differentiator)

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read `config/stacks/web-app.yaml` — the canonical template format
2. Read `schemas/stack-template.schema.json` — validation schema
3. Use Context7 to verify current stable versions: Astro 5, tRPC, Prisma, NextAuth, SvelteKit 2, Lucia auth, Remix
4. Use Context7 for each framework's project setup commands and configuration patterns
5. Check Cloudflare Pages/Workers deployment patterns for Astro and Remix

## Section 6: Implementation Instructions

### Architecture constraints
- Every template must include Zod for env validation (or equivalent for non-TS stacks)
- Every template must include a testing setup with at least a smoke test
- Every template must include typecheck and lint commands
- Use the same coding conventions as the existing web-app.yaml
- Pin framework versions in init_commands
- AGENTS.md must include real gotchas (not generic advice)

### Template-specific guidance

**web-astro.yaml:**
- Astro 5 with `@astrojs/tailwind`, `@astrojs/cloudflare` adapters
- Content collections for blog/docs patterns
- Include a sample content collection schema
- Deployment: Cloudflare Pages (wrangler)
- Gotcha: Astro components are `.astro` files, not JSX — note this in AGENTS.md

**web-t3.yaml:**
- Use `create-t3-app` as init command
- tRPC for type-safe API calls (no REST endpoints)
- Prisma for ORM with PostgreSQL
- NextAuth.js for authentication
- Gotcha: tRPC routers are NOT API routes — they share types end-to-end

**web-sveltekit.yaml:**
- SvelteKit 2 with Vite
- Lucia auth for authentication (lightweight, modern)
- Drizzle ORM for database
- Gotcha: Svelte uses `$:` reactivity, not useState/useEffect

**web-remix.yaml:**
- Remix with Vite (not classic compiler)
- Cloudflare Workers adapter for edge deployment
- Drizzle ORM with D1 (SQLite at edge)
- Gotcha: Remix uses loader/action pattern, not getServerSideProps

### Ordered build list

For each template:
1. Research current stable versions via Context7
2. Write the YAML file following web-app.yaml structure exactly
3. Validate against schema
4. Review CLAUDE.md content for accuracy
5. Review AGENTS.md gotchas for real, non-obvious issues

### Git workflow
- Branch: `feature/web-templates`
- Commit per template: `feat: add {template-name} stack template`

## Section 7: Final Reminders

- Validate each YAML against `schemas/stack-template.schema.json` before committing
- Use Context7 for EVERY framework — do NOT guess API signatures or configuration
- AGENTS.md gotchas must be real issues, not generic advice like "read the docs"
- Ensure env_example has all required variables
- Test that init_commands are correct by mentally walking through them
- Do NOT add boilerplate comments — keep starter files clean and minimal
