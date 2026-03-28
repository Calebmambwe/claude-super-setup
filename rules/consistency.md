---
description: Enforce resource audit before any implementation — skills, templates, components, patterns
globs: ["**/*"]
---

# Resource Consistency Rules

Before writing ANY code, run the Resource Audit matching your task size. This is a PRECONDITION, not a suggestion.

## Full Audit (tasks touching 3+ files)

Run ALL four checks in order. Do not write code until complete.

### 1. Skills Check
Does this task involve UI, backend architecture, or Docker?
- UI work → read `~/.claude/skills/design-system/SKILL.md` first
- Backend structure → read `~/.claude/skills/backend-architecture/SKILL.md` first
- Containers → read `~/.claude/skills/docker/SKILL.md` first
- BMAD workflow → read `~/.claude/skills/bmad/core/bmad-master/SKILL.md` first

### 2. Templates Check
Is this a new project, feature doc, or SDLC artifact?
- New app/service → check `~/.claude/config/stacks/` for a matching template BEFORE scaffolding
  Available: `web-app`, `api-service`, `mobile-app`, `saas-starter`, `ai-ml-app`, `web-t3`, `web-astro`, `web-sveltekit`, `web-remix`, `api-fastapi`, `api-hono-edge`, `mobile-expo-revenucat`, `mobile-nativewind`, `mobile-flutter`, `chrome-extension`, `cli-tool`
  Action: read the matching `.yaml` and use it as your starting point
- New PRD/architecture/brief → read the matching BMAD template first:
  `~/.claude/config/bmad/templates/prd.md`, `architecture.md`, `tech-spec.md`, `product-brief.md`
- New SDLC prompt → read `~/.claude/config/prompts/` first (brainstorm-brief, design-document, milestone-prompts, single-implementation, reverse-documentation)

### 3. Component / Pattern Check
Search THIS project for existing implementations before creating new ones:
- Existing components: `Grep pattern="ComponentName|similar-concept" glob="**/*.tsx"`
- Existing utilities: `Grep pattern="function.*similar" glob="**/*.ts"`
- Existing routes/API patterns: `ls src/routes/ src/api/ src/controllers/ 2>/dev/null`
- If a match exists: EXTEND or REUSE it — do NOT create a parallel implementation

### 3b. UI Library Check (UI work only)
Before creating ANY icon, animation, or interactive component:
- Icons → use Lucide, Phosphor (`@phosphor-icons/react`), Tabler (`@tabler/icons-react`), or Heroicons ONLY. Never generate custom SVG icons.
- List/table transitions → use AutoAnimate (`@formkit/auto-animate`) before writing custom animation code
- Scroll animations → use GSAP ScrollTrigger for scroll-driven sequences, Motion (Framer) for React state
- Micro-animations → use `tailwindcss-motion` CSS utilities before JS animation
- Date pickers/comboboxes → use Ark UI (`@ark-ui/react`) before building custom
- Dashboard charts → use Tremor (`@tremor/react`) before building custom
- Landing page effects → check Aceternity UI (ui.aceternity.com) and Magic UI (magicui.design) before building custom
- Page sections → check shadcnblocks (shadcnblocks.com) for existing blocks before building custom
- Full reference: `docs/research/ui-libraries-reference.md`

### 3c. shadcn/skills Check (projects with components.json)
If the project has a `components.json` file, shadcn/skills is available:
- ALWAYS run `pnpm dlx shadcn@latest docs <component>` before implementing any shadcn component
- ALWAYS run `pnpm dlx shadcn@latest diff` to check for registry drift before modifying components
- Use `--dry-run` flag when adding components to preview changes
- Use `pnpm dlx shadcn@latest info --json` to understand project config (base library, aliases, icon library)
- Follow composition rules: `gap-*` not `space-*`, `size-*` not `w-*`+`h-*`, semantic colors only
- If shadcn/skills not installed: `pnpm dlx skills add shadcn/ui`

### 3d. next-browser Check (Next.js 16+ projects)
If the project uses Next.js 16+, next-browser provides AI agent DevTools:
- Use `next-browser tree` to inspect component trees when debugging UI
- Use `next-browser ppr lock/unlock` to analyze static shell coverage
- If not installed: `pnpm dlx skills add vercel-labs/next-browser`
- Ensure `logging.browserToTerminal: true` in next.config.ts for terminal error forwarding

### 4. AGENTS.md Check
- If AGENTS.md exists: read it in full (project-specific gotchas and patterns)
- If absent: create one after the first non-trivial task

## Lightweight Audit (tiny changes: 1-2 files)

Even for small changes, check two things:
1. **Component reuse** — search the project for existing components/utilities that do what you need. If one exists, use it. Never duplicate.
2. **Design token compliance** (UI changes only) — colors, spacing, and radius values MUST come from the design system. Never hardcode hex values or arbitrary pixel values.

## Anti-Patterns (NEVER DO)

- [critical] NEVER scaffold a new project without reading the matching stack template from `~/.claude/config/stacks/`
- [critical] NEVER build a UI component without reading `~/.claude/skills/design-system/SKILL.md`
- [critical] NEVER create a duplicate component — search the project before creating
- [critical] NEVER hardcode colors, fonts, or spacing that exist in the design system tokens
- [critical] NEVER write a BMAD artifact (PRD, architecture, brief) without reading the matching template
- [critical] NEVER write an SDLC prompt from scratch — derive from `~/.claude/config/prompts/`
- [critical] NEVER ignore project AGENTS.md — it contains hard-won lessons from prior sessions
- [critical] NEVER use AI-generated, custom SVG, or emoji-style icons — only approved icon libraries (Lucide, Phosphor, Tabler, Heroicons)
- [critical] NEVER build custom date pickers, comboboxes, or charts — use Ark UI or Tremor
- [critical] NEVER skip checking Aceternity UI / Magic UI / shadcnblocks before building landing page sections from scratch
- [critical] NEVER implement a shadcn component without running `shadcn docs <component>` first — the API may have changed in CLI v4
- [critical] NEVER use `space-x-*`/`space-y-*` with flex layouts — use `gap-*` (enforced by shadcn/skills)
- [critical] NEVER use raw Tailwind colors in shadcn projects — use semantic tokens (`bg-primary`, `text-muted-foreground`)

## Enforcement

If you find yourself writing code without having completed the applicable audit, STOP immediately. Complete the audit. Then resume.

This applies to ALL pipeline modes: `/plan`, `/build`, `/dev`, `/auto-dev`, `/auto-build`, `/ghost-run`. No exemptions. The audit adds minutes. Inconsistent output costs hours.
