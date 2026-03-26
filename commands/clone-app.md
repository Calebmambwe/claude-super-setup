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

**Step 1.3: Template Discovery (BEFORE coding)**

Before generating any code, check if the target site has an open-source repo or downloadable template:

1. **GitHub search**: `WebSearch("{site name} website github repo open source")`
   - Many sites (Supabase, Vercel, Linear) have their marketing site in a public repo
   - If found: extract their `tailwind.config`, `globals.css`, font imports, and color tokens
   - Use these as the GROUND TRUTH for colors/typography — don't guess from screenshots

2. **Template marketplaces**: `WebSearch("{site name} template clone starter kit")`
   - Check: Vercel Templates, shadcn themes, Tailwind UI, GitHub topics
   - If an exact or near-exact template exists, use it as the starting scaffold

3. **Design system check**: `WebSearch("{site name} design system design tokens")`
   - Some companies publish their design system (e.g., Radix, Chakra, Material)
   - If found: import their exact tokens instead of approximating

**Store findings in `docs/clone/template-sources.md`** — this prevents re-research on iteration rounds.

**Step 1.4: Deep Content Analysis**

Use WebFetch to extract structured data:

```
WebFetch(url, "Extract ALL of the following as structured data:
1. SITE TYPE: landing page / SaaS / blog / e-commerce / docs / dashboard
2. EVERY PAGE SECTION in order: name, type, approximate height, key elements
3. COLOR PALETTE — BE EXACT:
   - Use browser DevTools computed styles, NOT visual approximation
   - Extract: primary, secondary, accent, background, text, border, muted, surface, card
   - For EACH color: exact hex (#3ECF8E not 'green'), RGB, and OKLCH conversion
   - Extract gradient definitions verbatim (e.g., 'linear-gradient(135deg, #3ECF8E, #2B9A66)')
   - Dark mode colors AND light mode colors if both exist
4. TYPOGRAPHY — BE EXACT:
   - Font families: exact names (e.g., 'Inter', 'Circular Std', 'SF Pro') — check @font-face and Google Fonts imports
   - Heading hierarchy: h1 size, h2 size, h3 size, h4 size (in px AND rem)
   - Body text: size, line-height, letter-spacing
   - Font weights used: 400, 500, 600, 700, etc.
   - Special typography: gradient text, monospace for code, decorative fonts
5. COMPONENT INVENTORY: every distinct UI component with their variants
6. NAVIGATION: all menu items and their destinations
7. INTERACTIONS: hover effects, animations, scroll triggers, modals, dropdowns
8. RESPONSIVE BEHAVIOR: how layout changes at mobile breakpoints
9. IMAGES/ICONS: what images are used, icon library (Lucide, Heroicons, custom SVGs)
10. TECH SIGNALS: framework, CSS library, component library signatures
11. SPACING SYSTEM: section padding, card padding, gap sizes — identify the scale (4px, 8px, etc.)")
```

**Step 1.5: Discover Internal Pages**

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

### Template Sources
- Open-source repo: {url or "none found"}
- Existing template: {url or "none found"}
- Design system: {url or "none found"}
- Files extracted: {tailwind.config, globals.css, etc.}

### Design Language (EXACT — not approximated)
- Theme: {dark/light/both}
- Primary: {exact hex} → OKLCH({value}) — source: {devtools/repo/screenshot}
- Secondary: {exact hex} → OKLCH({value})
- Accent: {exact hex} → OKLCH({value})
- Background: {exact hex} → OKLCH({value})
- Surface/Card: {exact hex} → OKLCH({value})
- Border: {exact hex} → OKLCH({value})
- Text primary: {exact hex} → OKLCH({value})
- Text muted: {exact hex} → OKLCH({value})
- Gradients: {verbatim gradient definitions}
- Font heading: {exact family} — weights: {list}
- Font body: {exact family} — size: {px}, line-height: {value}
- Font mono: {exact family} (for code blocks)
- Heading scale: h1={px}, h2={px}, h3={px}, h4={px}

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

- ALWAYS search for the site's open-source repo or downloadable template FIRST — use real CSS/config as ground truth
- ALWAYS screenshot with Playwright before generating code — never code from text analysis alone
- ALWAYS run through brainstorm → design-doc → auto-dev pipeline — never raw code generation
- ALWAYS use OKLCH color values extracted from the actual site
- ALWAYS run E2E tests after each milestone
- ALWAYS do visual comparison at the end (up to 3 fix iterations)
- NEVER copy copyrighted content verbatim — structural replicas with placeholder content
- NEVER use `initial={{ opacity: 0 }}` on above-fold content
- Use dark theme tokens (bg-slate-900, border-slate-700, text-white) NOT bg-white/5 for dark sites
- If Playwright is unavailable, fall back to WebFetch-only analysis with a warning
