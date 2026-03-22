---
name: init-agents-md
description: Create a per-project AGENTS.md learning file seeded with detected stack info
---

You are initializing a per-project AGENTS.md learning file. This file persists patterns, gotchas, and conventions discovered during development so that future agent iterations can learn from past work.

## Process

### Step 1: Detect Project Stack

Explore the project root to detect:
- **Framework**: Check `package.json` dependencies (next, react, vue, svelte, hono, express, fastify), `pyproject.toml` (django, flask, fastapi), or other markers
- **Backend**: Supabase, Drizzle, Prisma, SQLAlchemy, raw SQL
- **Styling**: Tailwind, CSS Modules, styled-components, shadcn/ui
- **Testing**: Vitest, Jest, Playwright, pytest
- **Package Manager**: pnpm, bun, yarn, npm, uv, pip

### Step 2: Check for Existing AGENTS.md

If `AGENTS.md` already exists in the project root:
- Read it and report its current state
- Ask the user if they want to reset or keep it
- Do NOT overwrite without confirmation

### Step 3: Create AGENTS.md

Write `AGENTS.md` to the project root with detected stack information:

```markdown
# AGENTS.md — Project Learning Memory

> This file is read by agents at the start of every task. Keep it under 100 lines.
> Add patterns you discover, gotchas you encounter, and conventions you establish.

## Stack
- Framework: {detected}
- Backend: {detected}
- Styling: {detected}
- Testing: {detected}
- Package Manager: {detected}

## Project Structure
- {key directory layout notes, e.g., "API routes in src/app/api/"}

## Patterns & Conventions
<!-- Agents: append discovered patterns here -->

## Gotchas
<!-- Agents: append pitfalls and workarounds here -->

## Resolved Issues
<!-- Agents: brief log of non-trivial errors fixed and how -->
```

### Step 4: Report

```
AGENTS.md created at {project_root}/AGENTS.md

Stack detected:
- Framework: {framework}
- Backend: {backend}
- Styling: {styling}
- Testing: {testing}

This file will be read automatically at the start of each task.
Agents will append patterns and gotchas as they discover them.
```

## Rules
- NEVER overwrite an existing AGENTS.md without user confirmation
- ALWAYS detect the actual stack from project files — never guess
- Keep the initial template minimal — agents will fill it in over time
- Include only sections relevant to the detected stack
