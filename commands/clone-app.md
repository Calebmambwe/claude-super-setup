---
name: clone-app
description: Clone a website into a new project — scrape URL, identify stack, scaffold a replica using our templates
---

Clone a website into a new project: $ARGUMENTS

## Process

### Step 1: Parse URL

Extract the URL from $ARGUMENTS. If no URL provided:
> "Paste a website URL to clone. I'll analyze it and scaffold a matching project."
> Example: `/clone-app https://linear.app`

### Step 2: Analyze the Website

Use WebFetch to scrape the target URL:
```
WebFetch(url, "Analyze this website completely:
1. What type of site is it? (landing page, SaaS dashboard, blog, e-commerce, etc.)
2. What's the visual design language? (minimal, bold, corporate, playful)
3. List every section/component visible (hero, navbar, features grid, pricing, footer, etc.)
4. What colors are used? List the primary, secondary, accent, background colors.
5. What fonts are used?
6. What interactions are visible? (animations, hover effects, modals)
7. Is it responsive? What layout patterns?
8. Any specific UI library signatures? (Tailwind classes, Material UI, shadcn patterns)")
```

### Step 3: Match to Template

Based on the analysis, select the best matching template:
- Landing page / marketing site → `web-shadcn-v4`
- SaaS with auth/billing → `saas-complete`
- AI/chat app → `ai-rag-complete`
- Blog / content site → `web-astro`
- E-commerce → `saas-complete` (adapted)
- Mobile-first → `mobile-gluestack`

### Step 4: Generate Design Tokens

From the color analysis, generate custom design tokens:
- Extract primary, secondary, accent colors
- Convert to OKLCH format
- Generate a custom globals.css @theme block
- Map fonts to the template's font system

### Step 5: Scaffold the Project

1. Run `/new-app <template>` with the selected template
2. Override the default design tokens with extracted colors
3. Generate component stubs matching the analyzed sections:
   - Hero section → src/components/sections/hero.tsx
   - Features grid → src/components/sections/features.tsx
   - Pricing → src/components/sections/pricing.tsx
   - etc.
4. Each component stub includes:
   - Layout structure matching the original
   - Correct spacing and sizing
   - Placeholder content matching the original's content type

### Step 6: Report

Show:
- Source URL analyzed
- Template selected and why
- Sections identified and components created
- Custom design tokens applied
- Next steps: "Run `pnpm dev` to preview. Customize content in each component."

## Rules
- NEVER copy copyrighted content verbatim — generate structural replicas with placeholder content
- Always use our design token system for colors/spacing
- Match layout and structure, not pixel-perfect screenshots
- Use shadcn/ui components wherever possible
- Include accessibility from the start (skip-nav, ARIA, contrast)
- If the site is too complex (>20 distinct sections), focus on the top 10
