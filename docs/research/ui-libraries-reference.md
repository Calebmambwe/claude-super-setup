# UI Libraries Reference (2026-03-26)

Approved professional libraries for all Twendai projects. Updated from research brief.

## Always Install (every project)

| Package | npm | Purpose | Size |
|---------|-----|---------|------|
| Lucide React | `lucide-react` | Default icons (ships with shadcn) | tree-shaken |
| Phosphor Icons | `@phosphor-icons/react` | 9,000+ icons, 6 weights | tree-shaken |
| Tabler Icons | `@tabler/icons-react` | 5,600+ dashboard/technical icons | tree-shaken |
| AutoAnimate | `@formkit/auto-animate` | Zero-config list/table transitions | 2KB |
| tailwindcss-motion | `tailwindcss-motion` | CSS-only animation utilities | 5KB |

## Install When Needed

| Package | npm | When | Size |
|---------|-----|------|------|
| GSAP | `gsap` | Landing pages, scroll sequences, SVG morph | 78KB |
| Ark UI | `@ark-ui/react` | Date pickers, comboboxes, color pickers | modular |
| Tremor | `@tremor/react` | Dashboard charts, KPI cards, analytics | ~120KB |
| HeroUI | `@heroui/react` | Alternative to shadcn for greenfield projects | modular |

## Copy-Paste Collections (no npm)

| Library | URL | Best For |
|---------|-----|----------|
| Aceternity UI | https://ui.aceternity.com | Hero sections, glowing cards, beams, spotlights |
| Magic UI | https://magicui.design | Shimmer, marquee, typing, particles |
| shadcnblocks | https://www.shadcnblocks.com | 1,400+ page blocks for shadcn |
| Origin UI | https://originui.com | Advanced shadcn extensions |
| Cult UI | https://cult-ui.com | Motion-heavy Framer Motion components |

## Color Tools (web, no install)

- **tints.dev** — https://www.tints.dev — Generate Tailwind palette from one color
- **uicolors.app** — https://uicolors.app — Alternative palette generator

## Icon Libraries (approved only)

| Library | Icons | Weights | npm |
|---------|-------|---------|-----|
| Lucide | 1,500+ | 1 | `lucide-react` |
| Phosphor | 9,000+ | 6 (Thin/Light/Regular/Bold/Fill/Duotone) | `@phosphor-icons/react` |
| Tabler | 5,600+ | 1 (stroke) | `@tabler/icons-react` |
| Heroicons | 316 | 4 (Outline/Solid/Mini/Micro) | `@heroicons/react` |
| Radix Icons | 333 | 1 | `@radix-ui/react-icons` |

**NEVER use AI-generated, custom SVG, or emoji-style icons.**

## next.config.js Required Config

```js
experimental: {
  optimizePackageImports: [
    '@phosphor-icons/react',
    '@tabler/icons-react',
    'lucide-react',
  ],
}
```

## Sources

- Builder.io: "15 Best React UI Libraries for 2026"
- LogRocket: "Headless UI alternatives" + "Best React animation libraries"
- GSAP: Now 100% free after Webflow acquisition (2025)
- npm weekly downloads verified 2026-03-26
