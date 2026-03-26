# Clone Pipeline V2: Same.new-Level Accuracy

## Problem

Current /clone-app produces sites that look "AI-generated" — wrong colors, missing sections, basic layouts, invisible content on mobile. Same.new achieves ~95% visual accuracy. We need to match that.

## Root Causes of Low Accuracy

1. **Color approximation** — guessing colors from screenshots instead of extracting from source
2. **Font mismatch** — using generic fonts instead of discovering the actual typeface
3. **Missing visual elements** — text-only sections without mockups, illustrations, gradients
4. **Basic layouts** — uniform grids instead of asymmetric, editorial layouts
5. **No iteration loop** — single-pass generation without visual comparison and fixing
6. **SSR animation bugs** — Framer Motion making content invisible over slow connections

## Solution: 7-Phase Pipeline

### Phase 1: Deep Scan (Playwright + WebFetch + Source Discovery)

**Step 1: Source repo discovery** (NEW — highest impact)
```
WebSearch("{site name} github repo open source")
WebSearch("{site name} design system design tokens")
WebSearch("{site name} website template clone")
```
If found: extract tailwind.config, globals.css, font imports → GROUND TRUTH

**Step 2: Playwright visual capture**
- Desktop 1440px full-page screenshot
- Tablet 768px full-page screenshot
- Mobile 390px full-page screenshot
- Accessibility snapshot (DOM tree)
- Network requests (font files, CSS files, API calls)

**Step 3: WebFetch deep extraction**
- All CSS custom properties with computed values
- Font families (from @font-face and Google Fonts imports)
- Exact hex colors for every element
- Gradient definitions (verbatim)
- Spacing system (section padding, card padding, gaps)
- Component inventory with variants

**Step 4: Tech stack detection**
- Framework (Next.js, Nuxt, Astro, etc.)
- CSS framework (Tailwind, styled-components, CSS modules)
- Component library (shadcn, Radix, Ant Design, Material)
- Icon library (Lucide, Heroicons, custom SVGs)

### Phase 2: Brief Generation

Auto-generate a structured brief from scan data:
- Site architecture (pages, sections per page)
- Design language (colors, fonts, spacing — EXACT values)
- Component inventory (mapped to shadcn/ui equivalents)
- Template sources (if open-source repo found)
- Technical decisions (framework, SSR strategy, animation approach)

### Phase 3: Design Document

Full design doc with:
- Mermaid diagrams (component tree, page structure)
- Data structures (navigation schema, content types)
- Design tokens (OKLCH palette generated from extracted colors)
- Component mapping (every scanned component → implementation plan)
- Milestones (ordered by dependency)

### Phase 4: Auto-Dev Implementation

Build each milestone using the Ralph Loop:
1. Scaffold with selected template
2. Apply design tokens from scan
3. Build layout (navbar + footer matching scan exactly)
4. Build each page section (matching scan order and structure)
5. Add animations (SSR-safe patterns only)
6. Run E2E tests after each milestone

### Phase 5: Visual Comparison

After implementation:
1. Screenshot every built page (desktop + tablet + mobile)
2. Compare side-by-side with scan screenshots
3. Score each section: layout match, color match, typography match
4. Generate fix list prioritized by visual impact

### Phase 6: Auto-Fix Iteration (up to 3 rounds)

For each mismatch:
- Wrong color → update token value
- Missing section → add section
- Wrong layout → restructure grid
- Missing animation → add with SSR-safe pattern
- Wrong font → update import
- Wrong spacing → adjust padding/margin

Re-screenshot after fixes, compare again. Max 3 rounds.

### Phase 7: Final Verification

- All pages load (no blank screens)
- No console errors
- No dead links
- All navigation works
- All forms accept input
- Mobile responsive (390px viewport)
- Accessibility (no critical violations)
- Performance (Lighthouse > 90)

## Key Technical Patterns

### Color Extraction Priority
1. Source repo CSS files (highest accuracy)
2. Computed styles from Playwright DOM
3. WebFetch CSS analysis
4. Screenshot color sampling (lowest accuracy — avoid)

### Font Matching Strategy
1. Exact match (if open-source: Inter, Geist, Source Sans, etc.)
2. Closest open-source match (Circular → Inter, Neue Haas → Helvetica Neue)
3. System font stack fallback

### SSR-Safe Animation Rules
- Above-fold: `initial={false}` — NEVER start invisible
- Below-fold: `whileInView` with `viewport={{ once: true, amount: 0.1 }}`
- Always: `<noscript>` CSS fallback in layout
- Always: respect `prefers-reduced-motion`
- Never: `initial={{ opacity: 0 }}` on any above-fold element

### Mobile-First Build Order
1. Mobile layout first (390px)
2. Add tablet breakpoint (768px → sm:, md:)
3. Add desktop breakpoint (1024px+ → lg:, xl:)
4. Test at all 3 viewports before declaring section complete

## Accuracy Targets

| Metric | Target | How Measured |
|--------|--------|-------------|
| Layout match | 90%+ | Section count and order matches scan |
| Color match | 95%+ | Delta E < 3 for all major colors |
| Typography match | 90%+ | Font family + size + weight correct |
| Responsive | 100% | No horizontal scroll, no overflow at 390px |
| Functional | 100% | All links work, all forms accept input |
| Accessibility | 100% | No critical WCAG 2.2 AA violations |
| Performance | 90+ | Lighthouse score |
