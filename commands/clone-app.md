---
name: clone-app
description: Clone a website using the full SDLC pipeline — screenshot, analyze, brainstorm, design-doc, auto-dev for precision
---

Clone a website into a production-quality project: $ARGUMENTS

## Overview

This command clones a website by running it through our FULL development pipeline — not raw code generation. The result is a precise, tested, production-quality replica.

**Pipeline:** Scan → Screenshot → Analyze → Brainstorm → Design Doc → Auto-Dev → Visual Test → Iterate

## Process

### Phase 1: Deep Scan (Playwright + WebFetch)

**Step 1.1: Parse URL**

Extract the URL from $ARGUMENTS. If no URL provided:
> "Paste a website URL to clone."
> Example: `/clone-app https://supabase.com`

Also extract optional flags:
- `--pages all` — clone all discoverable pages (default: homepage only)
- `--depth 2` — how many levels of internal links to follow
- `--output ~/Projects/clone-name` — output directory

**Step 1.2: Screenshot with Playwright**

Use the Playwright MCP to capture the actual visual state:

1. Navigate to the URL
2. Take a full-page screenshot (desktop 1440px)
3. Take a mobile screenshot (390px)
4. Capture the accessibility snapshot (DOM structure)
5. Save screenshots to a temp directory

```
mcp__plugin_playwright_playwright__browser_navigate(url)
mcp__plugin_playwright_playwright__browser_take_screenshot(type: "png", fullPage: true, filename: "scan-desktop.png")
mcp__plugin_playwright_playwright__browser_resize(width: 390, height: 844)
mcp__plugin_playwright_playwright__browser_take_screenshot(type: "png", fullPage: true, filename: "scan-mobile.png")
mcp__plugin_playwright_playwright__browser_snapshot(filename: "scan-dom.md")
```

**Step 1.3: Deep Content Analysis**

Use WebFetch to extract structured data:

```
WebFetch(url, "Extract ALL of the following as structured data:
1. SITE TYPE: landing page / SaaS / blog / e-commerce / docs / dashboard
2. EVERY PAGE SECTION in order: name, type, approximate height, key elements
3. COLOR PALETTE: extract exact hex values for primary, secondary, accent, background, text, border, muted colors
4. TYPOGRAPHY: font families, heading sizes, body size, line heights
5. COMPONENT INVENTORY: every distinct UI component (buttons, cards, navbars, forms, modals, carousels, tables, code blocks, etc.) with their variants
6. NAVIGATION: all menu items and their destinations (internal pages)
7. INTERACTIONS: hover effects, animations, scroll triggers, modals, dropdowns
8. RESPONSIVE BEHAVIOR: how layout changes at mobile breakpoints
9. IMAGES/ICONS: what images are used, icon library (Lucide, Heroicons, custom SVGs)
10. TECH SIGNALS: framework, CSS library, component library signatures")
```

**Step 1.4: Discover Internal Pages**

If `--pages all` or `--depth > 1`:
- Extract all internal links from the homepage
- Navigate to and screenshot each discovered page
- Analyze each page's unique sections and components

### Phase 2: Brainstorm (Auto)

Generate a structured feature brief from the scan data. Save to `docs/clone/brief.md`:

```markdown
# Clone Brief: {site name}

## Source: {url}
## Scanned: {date}

### Site Architecture
- Type: {landing page / SaaS / etc.}
- Pages discovered: {count} — {list}
- Total sections: {count}

### Design Language
- Theme: {dark/light/both}
- Primary: {hex} → OKLCH({value})
- Secondary: {hex} → OKLCH({value})
- Accent: {hex} → OKLCH({value})
- Background: {hex} → OKLCH({value})
- Font heading: {family}
- Font body: {family}

### Component Inventory
{table of every component, its variant, and which shadcn/ui component maps to it}

### Page-by-Page Breakdown
{for each page: sections in order, components used, unique elements}

### Technical Decisions
- Template: {web-shadcn-v4 / saas-complete / etc.} — because {reason}
- Animations: {CSS transitions / Framer Motion with SSR-safe patterns}
- Special features: {auth forms, pricing tables, code blocks, etc.}
```

### Phase 3: Design Document (Auto)

Generate a design doc at `docs/clone/design-doc.md` using the `/design-doc` pattern:

- Architecture: component tree, page structure, routing
- Data structures: page content types, navigation schema
- Design tokens: OKLCH color palette, spacing, typography mapped from scan
- Component mapping: every scanned component → shadcn/ui or custom component
- Implementation milestones:
  1. Scaffold + design tokens + layout (navbar + footer)
  2. Homepage sections (in order from scan)
  3. Inner pages (one per milestone)
  4. Interactions + animations
  5. Visual testing + polish

### Phase 4: Auto-Dev Implementation

Run the full `/auto-dev` pipeline using the design doc:

1. **Generate tasks** from the design doc milestones
2. **Scaffold** with the selected template (`/new-app {template}`)
3. **Apply design tokens** — custom globals.css with OKLCH colors from scan
4. **Build each milestone** sequentially:
   - Milestone 1: Layout (navbar + footer matching scan)
   - Milestone 2: Homepage sections (matching scan order + structure)
   - Milestone 3+: Inner pages
   - Milestone N: Animations using SSR-safe Framer Motion patterns
5. **Run E2E tests** after each milestone
6. **Visual compare** against scan screenshots

### Phase 5: Visual Testing + Iteration

After implementation, run a visual comparison:

1. Screenshot every built page (desktop + mobile)
2. Compare side-by-side with scan screenshots
3. Identify mismatches:
   - Missing sections
   - Wrong colors
   - Layout differences
   - Missing interactions
4. Auto-fix each mismatch (up to 3 iteration rounds)
5. Final E2E test suite covering:
   - All pages load with content
   - All navigation links work
   - All buttons are clickable
   - Forms accept input
   - Theme toggle works (if applicable)
   - Mobile responsive
   - No console errors

### Phase 6: Report

```
Clone Complete!

Source: {url}
Pages cloned: {count}
Components: {count}
Design tokens: {count} OKLCH values
E2E tests: {pass}/{total}

Visual accuracy: ~{score}% (based on section matching)

Project location: {output directory}
Run: cd {dir} && pnpm dev
```

## Framer Motion Rules (SSR-Safe)

When adding animations:
- Above-fold content: `initial={false}` — NEVER start invisible
- Below-fold content: `whileInView` with `viewport={{ once: true, amount: 0.1 }}`
- Always add `<noscript>` CSS fallback in layout.tsx
- Use `AnimatePresence initial={false}` for page transitions
- Type variants as `Variants` from framer-motion (v12 Easing type fix)

## Template Selection

| Site Type | Template |
|-----------|----------|
| Landing / marketing | web-shadcn-v4 |
| SaaS with auth/billing | saas-complete |
| AI / chat app | ai-rag-complete |
| Blog / content | web-astro |
| Documentation | web-shadcn-v4 |
| E-commerce | saas-complete |
| Mobile-first | mobile-gluestack |

## Rules

- ALWAYS screenshot with Playwright before generating code — never code from text analysis alone
- ALWAYS run through brainstorm → design-doc → auto-dev pipeline — never raw code generation
- ALWAYS use OKLCH color values extracted from the actual site
- ALWAYS run E2E tests after each milestone
- ALWAYS do visual comparison at the end (up to 3 fix iterations)
- NEVER copy copyrighted content verbatim — structural replicas with placeholder content
- NEVER use `initial={{ opacity: 0 }}` on above-fold content
- Use dark theme tokens (bg-slate-900, border-slate-700, text-white) NOT bg-white/5 for dark sites
- If Playwright is unavailable, fall back to WebFetch-only analysis with a warning
