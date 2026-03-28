---
name: design-system
description: Production design system — tokens, animations, accessibility, 25+ component patterns. The design system is LAW.
---

## Golden Rule (from Lovable — non-negotiable)

The design system is law. NEVER write custom styles in components. NEVER use direct color classes like `text-white` or `bg-black`. Every visual property traces back to a token. If a token doesn't exist for what you need, add it here first, then use it.

---

## Color Palettes (pick one per project, NEVER mix palettes)

Choose a palette based on the project's personality. Each is derived from a world-class reference.

### Palette: Vercel (minimal, developer-focused — vercel.com)
Best for: dev tools, dashboards, technical products
```
--background:       #000000        --background-light: #FFFFFF
--foreground:       #EDEDED        --foreground-light: #171717
--surface:          #111111        --surface-light:    #FAFAFA
--surface-elevated: #1A1A1A        --surface-el-light: #F5F5F5
--primary:          #FFFFFF        --primary-light:    #000000
--muted:            #888888        --muted-light:      #666666
--border:           #333333        --border-light:     #EAEAEA
--accent:           #0070F3        --accent both modes
--error:            #EE0000        --success: #0070F3
```

### Palette: Linear (focused, calm authority — linear.app)
Best for: SaaS, productivity tools, project management
```
--background:       #0A0A0F        --background-light: #FFFFFF
--foreground:       #F1F1F4        --foreground-light: #1B1B1F
--surface:          #16161D        --surface-light:    #F7F7F8
--surface-elevated: #1F1F28        --surface-el-light: #EFEFEF
--primary:          #5E6AD2        --primary (indigo, both modes)
--primary-hover:    #7B85E0
--muted:            #787882        --muted-light:      #8B8B94
--border:           #26262E        --border-light:     #E8E8EC
--accent:           #8B5CF6        --accent: violet highlight
--error:            #E5484D        --success: #30A46C
```

### Palette: Stripe (trustworthy, premium fintech — stripe.com)
Best for: fintech, payments, enterprise SaaS, B2B
```
--background:       #0A2540        --background-light: #FFFFFF
--foreground:       #F6F9FC        --foreground-light: #425466
--surface:          #143556        --surface-light:    #F6F9FC
--surface-elevated: #1D4469        --surface-el-light: #EDF2F7
--primary:          #635BFF        --primary (both modes)
--primary-hover:    #7A73FF
--muted:            #8898AA        --muted-light:      #8898AA
--border:           #1E4976        --border-light:     #E3E8EE
--accent:           #00D4FF        --cyan accent
--error:            #DF1B41        --success: #2DD4BF
--gradient:         linear-gradient(135deg, #635BFF, #00D4FF, #7C3AED)
```

### Palette: Supabase (developer-friendly, growth — supabase.com)
Best for: developer platforms, open source, databases
```
--background:       #1C1C1C        --background-light: #FCFCFC
--foreground:       #EDEDED        --foreground-light: #11181C
--surface:          #2A2A2A        --surface-light:    #F8F9FA
--surface-elevated: #333333        --surface-el-light: #F1F3F5
--primary:          #3ECF8E        --primary (emerald, both)
--primary-hover:    #34B27B
--muted:            #7E7E7E        --muted-light:      #687076
--border:           #3A3A3A        --border-light:     #DFE3E6
--accent:           #6EE7B7        --accent: light emerald
--error:            #F75F5F        --success: #3ECF8E
```

### Palette: Apple (premium, minimal — apple.com)
Best for: consumer products, premium brands, hardware
```
--background:       #000000        --background-light: #FBFBFD
--foreground:       #F5F5F7        --foreground-light: #1D1D1F
--surface:          #161617        --surface-light:    #F5F5F7
--surface-elevated: #1D1D1F        --surface-el-light: #E8E8ED
--primary:          #0071E3        --primary (blue, both)
--primary-hover:    #0077ED
--muted:            #86868B        --muted-light:      #6E6E73
--border:           #424245        --border-light:     #D2D2D7
--accent:           #BF5AF2        --accent: purple
--error:            #FF453A        --success: #30D158
--gradient:         linear-gradient(90deg, #2997FF, #BF5AF2, #FF375F)
```

### Palette: Warm (food, lifestyle, creative — custom)
Best for: food apps, social platforms, creative tools, lifestyle brands
```
--background:       #1A1412        --background-light: #FFFBF5
--foreground:       #F5EDE4        --foreground-light: #2D1F14
--surface:          #261E18        --surface-light:    #FFF7ED
--surface-elevated: #332820        --surface-el-light: #FFF1E0
--primary:          #F97316        --primary (orange, both)
--primary-hover:    #EA580C
--muted:            #9C8B7D        --muted-light:      #78716C
--border:           #3D3028        --border-light:     #E7DDD0
--accent:           #F43F5E        --accent: rose
--error:            #EF4444        --success: #22C55E
--gradient:         linear-gradient(135deg, #F97316, #F43F5E, #EC4899)
```

### How to Apply a Palette
In `globals.css`, define tokens under `:root` (light) and `.dark` (dark):
```css
:root {
  --background: 255 251 245;   /* light mode values */
  --foreground: 45 31 20;
  /* ... all tokens from chosen palette */
}
.dark {
  --background: 26 20 18;     /* dark mode values */
  --foreground: 245 237 228;
}
```

### Dark/Light Mode
Use `next-themes` for mode switching. Prevent FOUC with `suppressHydrationWarning` on `<html>`. Define tokens as CSS variables in `globals.css` under `:root` (light) and `.dark` (dark). NEVER use conditional class logic in components — let the theme provider handle it.

---

## Typography

### Font Stacks (pick one pair per project)

| Use Case | Heading Font | Body Font | Mono Font | Reference |
|----------|-------------|-----------|-----------|-----------|
| Developer tools | **Geist Sans** | Geist Sans | Geist Mono | Vercel |
| SaaS / productivity | **Inter Display** (600-800) | Inter (400-500) | JetBrains Mono | Linear |
| Premium / fintech | **Sohne** or **Plus Jakarta Sans** (600-800) | Inter (400-500) | IBM Plex Mono | Stripe |
| Consumer / lifestyle | **Cabinet Grotesk** or **Satoshi** (700-900) | Plus Jakarta Sans (400-500) | Fira Code | Apple vibes |
| Editorial / content | **Playfair Display** (700) | Source Serif Pro (400) | Fira Code | NYT/Medium |

### Default Stack (when in doubt)
- Headings: **Inter** (variable, weight 600-800) — the most versatile, used by Linear, GitHub, Figma
- Body: **Inter** (variable, weight 400-500)
- Mono: **Geist Mono** or **JetBrains Mono**
- Display (hero): **Plus Jakarta Sans** (weight 800) or **Inter Display** (weight 800)

### Type Scale
- 12 / 14 / 16 / 18 / 20 / 24 / 30 / 36 / 48 / 60 / 72 / 96
- Line heights: tight (1.05) for display/hero, snug (1.2) for headings, normal (1.5) for body, relaxed (1.7) for long-form
- Letter spacing: `-0.02em` for display, `-0.015em` for headings, `0` for body, `0.05em` for overlines/labels
- Fluid type for hero headlines: `clamp(2.5rem, 5vw + 1rem, 5rem)`
- Overline labels: `text-[11px] font-semibold uppercase tracking-[0.08em]` (like Linear's section labels)

### Typography Rules
- Load via `next/font` with `display: 'swap'` — NEVER use `<link>` tags or CDN fonts
- ALWAYS use font-weight from the variable font — never load multiple static weights
- Hero text should be 48-96px with tight line-height and negative letter-spacing
- Body text minimum 16px, never smaller than 14px for readability
- Use `text-balance` on headings for better line wrapping

---

## Icon System

### Approved Libraries (priority order)
1. **Lucide React** (`lucide-react`) — default, ships with shadcn/ui. 1,500+ icons.
2. **Phosphor Icons** (`@phosphor-icons/react`) — 9,000+ icons, 6 weights (Thin/Light/Regular/Bold/Fill/Duotone). Use for expressive, distinctive UIs.
3. **Tabler Icons** (`@tabler/icons-react`) — 5,600+ icons. Best for dashboard/SaaS technical icons Lucide lacks.
4. **Heroicons** (`@heroicons/react`) — 316 pixel-perfect icons from the Tailwind team. 4 variants (Outline/Solid/Mini/Micro).

### Icon Rules
- Sizes: 16px (inline text), 20px (buttons, nav), 24px (section icons), 32px (feature cards)
- Stroke width: 1.5 (consistent across all uses)
- Color: inherit from parent text color — NEVER hardcode icon colors
- Import individually: `import { ArrowRight } from 'lucide-react'` — NEVER import the barrel
- For Phosphor: configure `optimizePackageImports: ['@phosphor-icons/react']` in `next.config.js`
- NEVER use AI-generated, custom SVG, or emoji-style icons — only use approved libraries above

---

## Approved UI Libraries

### Component Libraries (beyond shadcn/ui)
| Library | npm | Use For |
|---------|-----|---------|
| **Ark UI** | `@ark-ui/react` | Date pickers, comboboxes, color pickers — headless primitives Radix lacks |
| **Tremor** | `@tremor/react` | Dashboard charts, KPI cards, analytics data tables |
| **HeroUI** | `@heroui/react` | Alternative styled components with React Aria a11y |

### Premium Copy-Paste Collections (no npm — copy source)
| Library | URL | Use For |
|---------|-----|---------|
| **Aceternity UI** | https://ui.aceternity.com | Animated hero sections, glowing cards, beam effects, spotlight |
| **Magic UI** | https://magicui.design | Shimmer, marquee, typing, particle effects. CLI: `npx magicui-cli add` |
| **shadcnblocks** | https://www.shadcnblocks.com | 1,400+ pre-built page blocks for shadcn stack |
| **Origin UI** | https://originui.com | Advanced shadcn extensions (timelines, richer dialogs) |
| **Cult UI** | https://cult-ui.com | Motion-heavy components with Framer Motion |

### Animation Libraries
| Library | npm | Size | Use For |
|---------|-----|------|---------|
| **Motion** (Framer) | `motion` | 85KB | Page transitions, gestures, scroll — already in stack |
| **GSAP** | `gsap` | 78KB | Scroll-driven sequences, SVG morph, cinematic timelines. **100% free** (2025+) |
| **AutoAnimate** | `@formkit/auto-animate` | 2KB | Zero-config smooth transitions for list/table add/remove/reorder |
| **tailwindcss-motion** | `tailwindcss-motion` | 5KB | CSS-only utility animations (`motion-preset-bounce`, etc.) |

### Color & Theme Tools (no install — web tools)
- **tints.dev** — Generate 11-shade Tailwind palette from one hex color
- **uicolors.app** — Alternative palette generator with live preview

### When to Use What
- **Default UI**: shadcn/ui (always)
- **Missing primitive**: Ark UI (date picker, combobox, color picker)
- **Dashboard/charts**: Tremor
- **Landing page wow**: Aceternity UI + GSAP scroll sequences
- **Subtle polish**: Magic UI shimmer + AutoAnimate lists
- **Page sections**: shadcnblocks reference library

---

## Spacing Scale

Use Tailwind's default scale. Consistent patterns:
- Inline gaps: gap-1.5 (6px) for tight, gap-2 (8px) default, gap-4 (16px) for groups
- Cards: p-6 internal padding
- Sections: py-16 md:py-24
- Container: max-w-7xl mx-auto px-4 sm:px-6 lg:px-8
- Between sections: space-y-0 (sections manage own py)
- Page vertical rhythm: consistent py-16 md:py-24 on all sections

---

## Border Radius
- Buttons: rounded-lg
- Cards: rounded-xl
- Inputs: rounded-md
- Modals/Drawers: rounded-2xl
- Badges: rounded-full
- Avatars: rounded-full
- Tooltips: rounded-md

---

## Shadows
- Cards: shadow-lg shadow-black/10
- Cards hover: shadow-xl shadow-primary/5
- Elevated (dropdowns, modals): shadow-xl shadow-black/20
- Buttons hover: shadow-md shadow-primary/10
- Subtle (inputs): shadow-sm

---

## Z-Index Scale
- 10: Sticky navbar
- 20: Dropdown menus, popovers
- 30: Modal/dialog overlay (backdrop)
- 40: Modal/dialog content
- 50: Toast notifications
- 60: Tooltips

---

## Animation Tokens

### Duration Scale
- 100ms: Micro-interactions (opacity, color changes)
- 200ms: Transitions (hover states, focus rings)
- 300ms: UI elements (dropdowns, accordions, modals)
- 500ms: Page/section transitions (scroll reveals)
- 1000ms: Skeleton shimmer cycle

### Easing Curves
- Default: `ease-out` — most UI transitions
- Spring: `[0.25, 0.46, 0.45, 0.94]` — bouncy elements (Framer Motion)
- Smooth: `[0.4, 0, 0.2, 1]` — Material-style smooth

### Reduced Motion
ALWAYS wrap animations with `prefers-reduced-motion`:
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```
In Framer Motion: use `useReducedMotion()` hook to disable animations.

---

## Micro-Interactions

- **Button press**: `scale: 0.97` on active, duration 100ms
- **Button hover**: `scale: 1.02` + shadow increase, duration 200ms
- **Card hover**: `translateY: -2px` + shadow increase, duration 200ms
- **Link hover**: color transition + optional underline slide, duration 200ms
- **Focus ring**: `ring-2 ring-primary/50 ring-offset-2 ring-offset-background`, transition 150ms
- **Form field focus**: border color change to primary, duration 150ms
- **Toggle/switch**: spring animation with Framer Motion, duration 300ms
- **Toast enter**: slide up + fade in, duration 300ms
- **Toast exit**: slide right + fade out, duration 200ms
- **Checkbox**: scale bounce on check, duration 200ms

---

## Framer Motion Patterns

### Scroll Reveal (most common)
```tsx
const fadeInUp = { hidden: { opacity: 0, y: 20 }, visible: { opacity: 1, y: 0, transition: { duration: 0.5 } } };
// Usage: <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeInUp}>
```

### Stagger Children (for grids/lists)
```tsx
const staggerContainer = { hidden: {}, visible: { transition: { staggerChildren: 0.1 } } };
// Usage: <motion.div variants={staggerContainer} initial="hidden" whileInView="visible">
```

### Exit Animations
```tsx
// Wrap with <AnimatePresence> for exit animations on route changes and modal dismiss
<AnimatePresence mode="wait"><motion.div key={key} exit={{ opacity: 0, y: -10 }} /></AnimatePresence>
```

### Layout Animations
```tsx
// Use layoutId for shared element transitions between states
<motion.div layoutId="active-tab" className="bg-primary rounded-full" />
```

### Reusable animation variants file: `src/lib/animations.ts`
Every project should have this file with: fadeInUp, fadeInDown, fadeInLeft, fadeInRight, scaleIn, staggerContainer, slideInFromBottom.

---

## Responsive Breakpoints

Use Tailwind's defaults: sm (640px), md (768px), lg (1024px), xl (1280px), 2xl (1536px).

- Mobile-first: write base styles for mobile, enhance upward
- Container queries: use `@container` for components that need to adapt to their container, not the viewport
- Fluid typography: use `clamp()` for hero headings that scale smoothly
- Touch targets: minimum 44x44px on mobile (WCAG 2.5.8)
- Navigation: hamburger menu below md, horizontal nav at md+

---

## Accessibility (WCAG 2.1 AA — Non-Negotiable)

- **Contrast**: 4.5:1 for normal text, 3:1 for large text (18px+ or 14px+ bold)
- **Focus visible**: every interactive element must show `focus-visible:ring-2 ring-primary/50`
- **Touch targets**: minimum 44x44px on mobile
- **Semantic HTML**: `<nav>`, `<main>`, `<section>`, `<article>`, `<footer>`, `<header>`
- **Alt text**: descriptive for informational images, `alt=""` for decorative
- **ARIA**: use only when semantic HTML is insufficient. Prefer native elements.
- **Keyboard**: all interactions navigable via Tab, Enter, Escape, Arrow keys
- **Reduced motion**: respect `prefers-reduced-motion` (see Animation Tokens)
- **Screen readers**: test with content hidden via `sr-only` class where visual-only info exists

---

## Skeleton Screens (mandatory for async content)

- Match the layout dimensions of loaded content precisely
- Use pulsing animation: `animate-pulse` with `bg-muted/50 rounded`
- Duration: show skeleton immediately, content replaces when ready
- NEVER use spinners for content areas — spinners are only for button loading states
- Skeleton components: `<Skeleton className="h-4 w-[200px]" />` from shadcn/ui

---

## Loading States

- **Page level**: `loading.tsx` in Next.js App Router — shows full page skeleton
- **Component level**: `Suspense` boundary with skeleton fallback
- **Button loading**: disable + spinner icon replacing text, NEVER change button size
- **Inline loading**: small spinner next to the action that triggered it
- **Data tables**: row-level skeleton matching column widths

---

## Error States

- **Inline form errors**: red text below field, `aria-describedby` linking error to input, border-error on the field
- **Page-level errors**: `error.tsx` with illustration, clear message, and retry CTA
- **Toast errors**: brief message + optional action button, auto-dismiss after 5s
- **Empty states**: illustration or icon + descriptive text + primary CTA to fix the emptiness
- **404 page**: `not-found.tsx` with personality, search suggestion, and home link

---

## Glassmorphism Recipe
```
backdrop-blur-xl bg-white/5 border border-white/10 shadow-xl shadow-black/10
```
Add noise texture for depth: `bg-[url('/noise.svg')] bg-repeat opacity-[0.02]`

---

## Gradient Patterns

- **Hero background**: `bg-gradient-to-br from-primary/20 via-background to-accent/10`
- **Radial glow**: `bg-[radial-gradient(ellipse_at_top_right,_var(--primary)_0%,_transparent_50%)] opacity-10`
- **CTA section**: `bg-gradient-to-br from-primary to-primary/80`
- **Text gradient**: `bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent`
- NEVER use more than 2 gradient layers on a single section

---

## Component Patterns

### Navbar
- Sticky `top-0 z-10`, transparent with `bg-background/80 backdrop-blur-lg`
- Border bottom: `border-b border-border`
- Logo left, nav center, CTA right
- Mobile: hamburger icon → slide-out menu with `AnimatePresence`
- Height: `h-16` consistent

### Hero Section
- `min-h-[80vh]` with gradient background
- Headline: `font-heading text-5xl md:text-6xl font-bold` with fluid `clamp()`
- Subheadline: `text-xl text-muted-foreground max-w-2xl leading-relaxed`
- CTA group: Two buttons (primary filled, secondary outline) with `gap-4`
- Social proof strip below CTAs (checkmarks, stats, trust badges)
- Scroll-reveal animation on content

### Cards
- `bg-card rounded-xl border border-border p-6`
- Hover: `hover:-translate-y-0.5 hover:shadow-xl hover:shadow-primary/5 transition-all duration-200`
- Icon container: `size-12 rounded-xl bg-primary/10 flex items-center justify-center text-primary`
- Title: `font-heading text-lg font-bold`
- Description: `text-sm text-muted-foreground leading-relaxed`

### Buttons (use shadcn/ui Button — NEVER create custom)
- Primary: `bg-primary text-primary-foreground hover:bg-primary/90`
- Secondary/Outline: `border-border hover:bg-muted`
- Ghost: `hover:bg-muted`
- ALWAYS include: `focus-visible:ring-2`, `transition-all duration-200`
- Loading state: spinner icon + disabled, same dimensions

### Dialog/Modal
- Overlay: `bg-black/50 backdrop-blur-sm z-30`
- Content: `bg-card rounded-2xl shadow-xl z-40 p-6`
- Entry: fade + scale from 0.95, duration 200ms
- Exit: fade + scale to 0.95, duration 150ms
- Close on Escape and overlay click
- Use shadcn/ui `Dialog` — NEVER create custom modals

### Toast/Notification
- Position: `fixed bottom-4 right-4 z-50`
- Entry: slide up from bottom + fade
- Auto-dismiss: 5s default, persistent for errors
- Use shadcn/ui `Sonner` or `Toast`

### Form Fields
- Label above input, `text-sm font-medium mb-1.5`
- Input: `rounded-md border-border bg-background focus:border-primary focus:ring-1 focus:ring-primary/50`
- Error: `border-error` + red message below with `aria-describedby`
- Helper text: `text-xs text-muted-foreground mt-1`
- Required indicator: `*` after label in `text-error`

### Tabs
- Use shadcn/ui `Tabs` — underline style or pill style
- Active indicator: animated with `layoutId` (Framer Motion)
- Content: fade transition between panels

### Accordion
- Use shadcn/ui `Accordion`
- Chevron rotation animation on open/close
- Content: height animation with `overflow-hidden`

### Avatar
- Sizes: `size-8` (small), `size-10` (default), `size-12` (large)
- Fallback: initials on `bg-primary/20 text-primary font-bold`
- Always `rounded-full`

### Tooltip
- `z-60` above everything
- `bg-card border border-border rounded-md px-3 py-1.5 text-xs shadow-lg`
- Delay: 500ms before showing
- Use shadcn/ui `Tooltip`

### Table
- Header: `bg-muted/50 text-muted-foreground text-xs uppercase tracking-wider`
- Rows: `border-b border-border hover:bg-muted/30`
- Responsive: horizontal scroll on mobile with `overflow-x-auto`

### Pagination
- Use shadcn/ui `Pagination`
- Show: Previous, 1 2 3 ... N, Next
- Active page: `bg-primary text-primary-foreground`

### Badge
- Use shadcn/ui `Badge`
- Variants: default (muted bg), primary, secondary, destructive, outline
- `rounded-full px-2.5 py-0.5 text-xs font-medium`

### Footer
- Multi-column grid: `grid-cols-2 md:grid-cols-5`
- Logo + description in first column
- Link columns with `text-sm text-muted-foreground hover:text-foreground`
- Separator before copyright bar
- Social icons in copyright row
- `border-t border-border` at top

### Pricing Cards
- 3-column grid, center card highlighted with `ring-2 ring-primary`
- "Most Popular" badge: positioned `absolute -top-3` center
- Price: `font-heading text-4xl font-bold`
- Feature list with check icons in `text-success`
- CTA button full width at bottom

### Testimonials
- Star ratings in `text-secondary` (amber)
- Quote: `text-sm text-foreground leading-relaxed`
- Avatar + name + role below quote
- Card layout with same card tokens

---

## GSAP Scroll Patterns

### ScrollTrigger (landing pages, marketing sections)
```tsx
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
gsap.registerPlugin(ScrollTrigger);

// Pin + scrub animation
gsap.to('.hero-text', {
  scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true },
  y: -100, opacity: 0,
});
```
Use GSAP for: scroll-pinned sequences, SVG morphing, text splitting (SplitText), cinematic timelines.
Use Motion (Framer) for: React state-driven UI, gestures, layout animations, simple scroll reveals.

### AutoAnimate (lists and tables — zero config)
```tsx
import { useAutoAnimate } from '@formkit/auto-animate/react';
const [parent] = useAutoAnimate();
// Usage: <ul ref={parent}>{items.map(...)}</ul>
```
Add to ANY list, table, or dynamic content. Instant smooth add/remove/reorder with zero config.

### tailwindcss-motion (CSS-only micro-animations)
```html
<div class="motion-preset-fade-in motion-duration-500">Fades in</div>
<button class="motion-preset-bounce hover:motion-preset-pulse">Bouncy</button>
```
Use for: hover states, entrance animations, skeleton loaders — anywhere JS animation is overkill.

---

## Project Setup Checklist (new projects)

When scaffolding a new project, ensure these are installed:
```bash
# Icons (always)
pnpm add lucide-react @phosphor-icons/react @tabler/icons-react

# Animation (always)
pnpm add @formkit/auto-animate tailwindcss-motion

# Animation (landing pages / marketing)
pnpm add gsap

# Components (when needed)
pnpm add @ark-ui/react        # complex interactive primitives
pnpm add @tremor/react         # dashboards only
```

In `next.config.js`:
```js
experimental: {
  optimizePackageImports: ['@phosphor-icons/react', '@tabler/icons-react', 'lucide-react'],
}
```

---

## Anti-Patterns (NEVER DO)

- NEVER use AI-generated, custom SVG, or emoji-style icons — only use approved icon libraries
- NEVER use pure black (#000) — use Slate 900 or the background token
- NEVER mix border-radius styles on the same page
- NEVER use more than 3 font weights
- NEVER put text directly on images without overlay
- NEVER use default browser blue links
- NEVER skip hover/focus states on interactive elements
- NEVER hardcode hex values outside of design tokens
- NEVER use `text-white` or `bg-black` — use token classes
- NEVER create custom button/modal/toast components — use shadcn/ui
- NEVER use spinners for content loading — use skeleton screens
- NEVER skip `prefers-reduced-motion` handling
- NEVER use `<img>` tags — use `next/image` for optimization
- NEVER import entire icon libraries — import individually
- NEVER use GSAP for simple hover/focus animations — use Motion or tailwindcss-motion
- NEVER skip `optimizePackageImports` when using Phosphor or Tabler icons
