---
name: Premium App Builder
description: Premium component patterns, design tokens, animations, and quality rules for generating apps that look hand-crafted, not AI-generated
triggers:
  - /new-app
  - /clone-app
  - /build
  - /build-page
  - /auto-dev
  - /auto-build
---

# Premium App Builder Skill

This skill is the design bible for every generated app. It defines the exact tokens, patterns, and rules that produce Linear/Vercel/Stripe-quality output. Read every section before writing a single line of UI code.

---

## 1. Design Principles

Five non-negotiable laws. If an element violates any of them, change it before shipping.

### Law 1: Less is More
Whitespace is a feature, not waste. Every element must earn its place. If removing it does not hurt comprehension, remove it. Dense UIs signal amateur work. Sparse, deliberate layouts signal craft.

- Prefer one well-spaced hero image over five abstract icons
- Prefer one pull quote over four mediocre ones
- When in doubt, add 50% more padding than your instinct says

### Law 2: Typography is the #1 Visual Differentiator
Users cannot articulate why an app looks premium, but they feel it through type. Tight letter-spacing on headlines, relaxed leading on body, a clear heading ladder — these create trust before the user reads a single word.

- Only one `h1` per page. Ever.
- Maximum two font families (sans + mono)
- Never use `font-weight: 800` or `font-weight: 900` — these scream amateur
- Never `font-weight: 300` — poor readability on most screens
- Body text minimum `text-sm` (14px). Caption minimum `text-xs` (12px). Never go below.

### Law 3: Depth Through Shadows, Not Borders
Borders are sharp and flat. Layered shadows create the illusion of physical depth that premium products rely on. Use borders only for structure (form fields, dividers), not to make things "pop."

- Cards use layered `--shadow-md` or `--shadow-lg`, not `border-2`
- Product screenshots use `product-shadow` (5-layer depth)
- Hover states elevate with `shadow-lg` + `-translate-y-0.5`, not a border change

### Law 4: Brand Color Discipline
Apply the 60-30-10 rule without exception. If more than 10% of your UI pixels are the brand color, it looks like a toy.

- **60%:** Background and surface colors
- **30%:** Neutral foreground, borders, muted text
- **10%:** Brand/accent color — CTAs, active states, focus rings, badges only
- Maximum 3 distinct hues per page (neutrals + 1 brand + 1 status)
- Never use color for decoration; use it for communication

### Law 5: Animations Enhance Understanding
Every animation must justify its existence by communicating state change, direction, or hierarchy. Animations that exist only to look impressive slow users down and erode trust.

- Animate only: hover state, focus state, loading state, enter/exit, scroll reveal
- NEVER animate for decoration
- ALWAYS respect `prefers-reduced-motion`
- Duration: 150–200ms for micro-interactions, 400–600ms for scroll reveals
- Easing: `ease-out` for most; spring for bouncy toggles and badges only

---

## 2. Typography Scale

All type maps to exact Tailwind classes. Never deviate from these values.

| Level       | Tailwind Classes                                                      | Notes                          |
|-------------|-----------------------------------------------------------------------|--------------------------------|
| Display     | `text-6xl md:text-7xl font-bold tracking-[-0.04em] leading-[1.06]`  | Hero headlines only            |
| H1          | `text-4xl md:text-5xl font-bold tracking-[-0.03em] leading-tight`   | One per page                   |
| H2          | `text-3xl font-semibold tracking-[-0.02em] leading-tight`            | Section headings               |
| H3          | `text-xl font-semibold tracking-[-0.01em] leading-snug`              | Card headings, sub-sections    |
| H4          | `text-base font-semibold tracking-normal leading-snug`               | UI element headings            |
| Body Large  | `text-lg text-muted-foreground leading-relaxed`                      | Lead paragraphs, hero sublines |
| Body        | `text-base text-muted-foreground leading-relaxed`                    | Main content                   |
| Small       | `text-sm text-muted-foreground leading-normal`                       | Secondary content              |
| Caption     | `text-xs text-muted-foreground leading-normal tracking-[0.01em]`     | Labels, metadata               |
| Overline    | `text-xs font-semibold uppercase tracking-widest text-muted-foreground` | Section labels (ALL CAPS)   |
| Mono        | `font-mono text-sm leading-relaxed`                                  | Code, terminal output          |

### Fluid Hero Headline
For hero sections, use fluid type that scales smoothly between mobile and desktop:
```tsx
<h1 className="font-bold tracking-tight leading-tight text-balance"
  style={{ fontSize: "clamp(2.5rem, 5vw, 4.5rem)", letterSpacing: "-0.04em" }}>
  Your headline here
</h1>
```

### Font Loading (Next.js)
```tsx
// app/layout.tsx — load via next/font ONLY, never <link> tags
import { Inter, JetBrains_Mono } from 'next/font/google'

const sans = Inter({ subsets: ['latin'], variable: '--font-sans', display: 'swap', axes: ['opsz'] })
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono', display: 'swap' })
// Apply: <html className={`${sans.variable} ${mono.variable}`}>
// Enable in globals.css: body { font-optical-sizing: auto; -webkit-font-smoothing: antialiased; }
```

> For comprehensive font selection, pairing rules, variable font usage, fluid type patterns, dark mode adjustments, and company font research, see the dedicated typography skill:
> **`~/.claude/skills/typography/SKILL.md`**
>
> That skill covers: company font map (Stripe/Linear/Vercel/GitHub/Notion), 6 curated font stacks, next/font patterns, CSS clamp fluid scale, optical sizing, and a full anti-pattern list.

---

## 3. Spacing Scale

Every spacing value must be a multiple of 4px. Non-grid values signal carelessness.

### Layout Dimensions
| Context              | Mobile             | Desktop             |
|----------------------|--------------------|---------------------|
| Section padding      | `py-12 px-4`       | `md:py-20 md:px-8`  |
| Max content width    | `w-full`           | `max-w-7xl mx-auto` |
| Container horizontal | `px-4`             | `sm:px-6 lg:px-8`   |
| Card padding (sm)    | `p-5`              | `p-6`               |
| Card padding (lg)    | `p-6`              | `p-8`               |
| Dialog padding       | `p-5`              | `p-6`               |
| Section gap          | `gap-8`            | `lg:gap-16`         |

### Component Spacing
| Context              | Value               |
|----------------------|---------------------|
| Button sm            | `py-1.5 px-3`       |
| Button md            | `py-2 px-4`         |
| Button lg            | `py-2.5 px-5`       |
| Input field          | `py-2 px-3`         |
| Form field gap       | `space-y-4`         |
| List item gap        | `space-y-2`         |
| Card stack gap       | `space-y-3`         |
| Inline icon gap      | `gap-2`             |

---

## 4. Color System

### OKLCH Primitive Tokens
Define in `globals.css` under `:root`. These are never used in components directly — they feed the semantic layer.

```css
:root {
  /* Blue scale */
  --p-blue-50:  oklch(0.970 0.013 254.0);
  --p-blue-100: oklch(0.940 0.026 254.0);
  --p-blue-300: oklch(0.810 0.097 254.0);
  --p-blue-400: oklch(0.707 0.165 254.6);
  --p-blue-500: oklch(0.546 0.245 262.9);
  --p-blue-600: oklch(0.460 0.245 262.9);
  --p-blue-700: oklch(0.390 0.200 262.9);

  /* Warm gray scale (Geist/Vercel family) */
  --p-gray-0:    oklch(1.000 0.000   0.0);
  --p-gray-50:   oklch(0.985 0.000   0.0);
  --p-gray-100:  oklch(0.967 0.001 286.4);
  --p-gray-200:  oklch(0.925 0.003 286.3);
  --p-gray-400:  oklch(0.707 0.015 286.1);
  --p-gray-500:  oklch(0.552 0.016 285.9);
  --p-gray-700:  oklch(0.371 0.012 285.8);
  --p-gray-800:  oklch(0.274 0.006 286.0);
  --p-gray-900:  oklch(0.210 0.006 285.9);
  --p-gray-950:  oklch(0.141 0.005 285.8);

  /* Status */
  --p-red-500:    oklch(0.628 0.258  28.0);
  --p-green-500:  oklch(0.643 0.174 142.5);
  --p-yellow-500: oklch(0.795 0.184  87.0);
}
```

### Semantic Token Mapping (Light Mode)
```css
:root {
  /* Surfaces */
  --color-bg:             var(--p-gray-50);
  --color-bg-subtle:      var(--p-gray-100);
  --color-surface:        var(--p-gray-0);
  --color-surface-raised: var(--p-gray-0);

  /* Text */
  --color-fg:             var(--p-gray-950);
  --color-fg-muted:       var(--p-gray-500);
  --color-fg-subtle:      var(--p-gray-400);
  --color-fg-disabled:    var(--p-gray-300);
  --color-fg-on-accent:   var(--p-gray-0);

  /* Borders */
  --color-border:         var(--p-gray-200);
  --color-border-strong:  var(--p-gray-300);
  --color-border-focus:   var(--p-blue-500);

  /* Brand */
  --color-primary:        var(--p-blue-500);
  --color-primary-hover:  var(--p-blue-600);
  --color-primary-subtle: var(--p-blue-50);
  --color-primary-fg:     var(--p-gray-0);

  /* Status */
  --color-success:        var(--p-green-500);
  --color-warning:        var(--p-yellow-500);
  --color-danger:         var(--p-red-500);
  --color-ring:           var(--p-blue-500);
}
```

### Dark Mode Strategy
Add `suppressHydrationWarning` to `<html>`. Use `next-themes` `ThemeProvider`. Override only semantic tokens in `.dark` — primitives stay constant.

```css
.dark {
  --color-bg:             var(--p-gray-950);
  --color-bg-subtle:      var(--p-gray-900);
  --color-surface:        oklch(0.165 0.005 285.8);
  --color-surface-raised: oklch(0.192 0.005 285.8);

  --color-fg:             var(--p-gray-50);
  --color-fg-muted:       var(--p-gray-400);
  --color-fg-subtle:      var(--p-gray-500);
  --color-fg-disabled:    var(--p-gray-700);

  --color-border:         var(--p-gray-800);
  --color-border-strong:  var(--p-gray-700);

  --color-primary:        var(--p-blue-400);
  --color-primary-hover:  var(--p-blue-300);
  --color-primary-subtle: oklch(0.20 0.05 262.9);
}
```

### Brand Color Rules
- Use the semantic alias (`bg-primary`, `text-primary`) everywhere in JSX — never the raw primitive
- In dark mode, lighten brand color by one step for readability (blue-400 instead of blue-500)
- Never use brand color for text on colored backgrounds unless contrast ratio >= 4.5:1
- Status colors (success/warning/danger) are informational only — never decorative

---

## 5. Shadow System

Five levels. Use the right level for the right context. Never use `shadow-lg` alone for product images — use `product-shadow`.

```css
/* globals.css */
:root {
  --shadow-xs:  0 1px 2px 0 oklch(0 0 0 / 0.04);

  --shadow-sm:
    0 1px 2px 0   oklch(0 0 0 / 0.05),
    0 1px 3px 0   oklch(0 0 0 / 0.08);

  --shadow-md:
    0 1px 3px 0    oklch(0 0 0 / 0.06),
    0 4px 6px -1px oklch(0 0 0 / 0.08);

  --shadow-lg:
    0 1px 3px 0      oklch(0 0 0 / 0.04),
    0 10px 15px -3px  oklch(0 0 0 / 0.08),
    0 4px 6px -4px    oklch(0 0 0 / 0.04);

  --shadow-xl:
    0 1px 3px 0      oklch(0 0 0 / 0.04),
    0 20px 25px -5px  oklch(0 0 0 / 0.10),
    0 8px 10px -6px   oklch(0 0 0 / 0.04);

  /* Apple-style 5-layer depth shadow for product screenshots */
  --product-shadow:
    0 0 0 1px        oklch(0 0 0 / 0.04),
    0 2px 4px -1px   oklch(0 0 0 / 0.06),
    0 8px 16px -4px  oklch(0 0 0 / 0.10),
    0 24px 48px -8px oklch(0 0 0 / 0.14),
    0 48px 80px -16px oklch(0 0 0 / 0.10);
}

/* Usage via Tailwind arbitrary: shadow-[var(--shadow-md)] */
/* Or define as custom utilities in tailwind.config.ts */
```

| Level            | Use Case                                               |
|------------------|--------------------------------------------------------|
| `--shadow-xs`    | Subtle input fields, chip/badge containers             |
| `--shadow-sm`    | Inline cards, default card state                       |
| `--shadow-md`    | Hovered cards, dropdowns, popovers                     |
| `--shadow-lg`    | Modals, nav drawers, floating panels                   |
| `--shadow-xl`    | Toast notifications, command palette                   |
| `--product-shadow` | Browser mockups, screenshot frames, hero visuals    |

---

## 6. Visual Effects Library

Copy these CSS blocks into `globals.css` and apply as utility classes. Every effect has a specific use case — do not mix them.

### glass-card
For cards on dark or gradient backgrounds. Creates the frosted glass effect used on Linear, Vercel, and Raycast.
```css
.glass-card {
  background: oklch(1 0 0 / 0.04);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid oklch(1 0 0 / 0.10);
  box-shadow: var(--shadow-md);
}
/* Dark mode: slightly more opaque */
.dark .glass-card {
  background: oklch(1 0 0 / 0.06);
  border-color: oklch(1 0 0 / 0.08);
}
```

### gradient-text
For hero headlines. Maps to a dark-to-gray gradient in light mode; inverts in dark.
```css
.gradient-text {
  background: linear-gradient(135deg,
    oklch(0.141 0.005 285.8) 0%,
    oklch(0.450 0.014 285.9) 100%
  );
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  color: transparent;
}
.dark .gradient-text {
  background: linear-gradient(135deg,
    oklch(0.985 0 0) 0%,
    oklch(0.707 0.015 286.1) 100%
  );
  background-clip: text;
  -webkit-background-clip: text;
}
```

### hero-glow
Radial gradient behind hero content. Subtle brand accent at 12% opacity — any stronger looks garish.
```css
.hero-glow {
  position: relative;
}
.hero-glow::before {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(
    ellipse 80% 50% at 50% -10%,
    oklch(0.546 0.245 262.9 / 0.12),
    transparent 70%
  );
  pointer-events: none;
  z-index: 0;
}
.hero-glow > * { position: relative; z-index: 1; }
```

### bg-grid
Subtle 24px grid pattern. Use at 3–4% opacity maximum — beyond that it becomes a background instead of a texture.
```css
.bg-grid {
  background-image:
    linear-gradient(oklch(0.552 0.016 285.9 / 0.04) 1px, transparent 1px),
    linear-gradient(90deg, oklch(0.552 0.016 285.9 / 0.04) 1px, transparent 1px);
  background-size: 24px 24px;
}
.dark .bg-grid {
  background-image:
    linear-gradient(oklch(1 0 0 / 0.03) 1px, transparent 1px),
    linear-gradient(90deg, oklch(1 0 0 / 0.03) 1px, transparent 1px);
}
```

### noise texture
SVG turbulence overlay for depth on flat surfaces. Use at 1.5% opacity as a `::after` pseudo-element.
```css
.noise::after {
  content: '';
  position: absolute;
  inset: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  opacity: 0.015;
  pointer-events: none;
  border-radius: inherit;
}
```

### product-shadow
Apple-style multi-layer depth shadow for browser and app mockups. Applied as a wrapper class around `next/image` screenshot elements.
```css
.product-shadow {
  box-shadow: var(--product-shadow);
  border-radius: var(--p-radius-2xl);
  overflow: hidden;
}
```

### cta-gradient
Dark gradient background for CTA sections. Creates contrast from the page without using a harsh solid color.
```css
.cta-gradient {
  background: linear-gradient(
    135deg,
    oklch(0.12 0.006 285.8) 0%,
    oklch(0.08 0.004 285.8) 40%,
    oklch(0.10 0.005 285.8) 100%
  );
  position: relative;
  overflow: hidden;
}
```

### footer-gradient-divider
A single-pixel accent line that replaces the default `border-t` in footers. Creates visual separation with brand identity.
```css
.footer-gradient-divider {
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent 0%,
    oklch(0.546 0.245 262.9 / 0.6) 30%,
    oklch(0.546 0.245 262.9 / 0.8) 50%,
    oklch(0.546 0.245 262.9 / 0.6) 70%,
    transparent 100%
  );
}
```

---

## 7. Animation Patterns (SSR-Safe)

This is the most critical section. Framer Motion + Next.js SSR produces invisible content when `initial={{ opacity: 0 }}` is rendered into server HTML. Content stays invisible until JavaScript hydrates — which can be 3–8 seconds on slow connections.

### The Three Rules (Non-Negotiable)

**Rule 1: Above-fold content uses `initial={false}`**

```tsx
// CORRECT — visible from first paint, animates in on hydration
<motion.div initial={false} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
  <h1>Your hero headline</h1>
</motion.div>

// WRONG — invisible until JS hydrates (can be 3-8 seconds)
<motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
  <h1>Your hero headline</h1>
</motion.div>
```

**Rule 2: Below-fold content uses `whileInView` + `viewport={{ once: true }}`**

```tsx
// CORRECT — SSR-safe because we never set an initial invisible state
<motion.div
  initial={false}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, amount: 0.1 }}
  transition={{ duration: 0.6 }}
>
  <p>Feature card content</p>
</motion.div>
```

**Rule 3: Always add a noscript fallback in `app/layout.tsx`**

```tsx
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <noscript>
          <style>{`
            [style*="opacity: 0"], [style*="opacity:0"] {
              opacity: 1 !important;
              transform: none !important;
            }
          `}</style>
        </noscript>
      </head>
      <body>{children}</body>
    </html>
  )
}
```

### Standard Animation Variants (`src/lib/animations.ts`)
Every project ships this file. Import from here — never define inline.

```ts
import { Variants } from 'framer-motion'

export const fadeInUp: Variants = {
  hidden:  { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.5, ease: 'easeOut' } },
}

export const fadeInDown: Variants = {
  hidden:  { opacity: 0, y: -16 },
  visible: { opacity: 1, y: 0,  transition: { duration: 0.5, ease: 'easeOut' } },
}

export const fadeIn: Variants = {
  hidden:  { opacity: 0 },
  visible: { opacity: 1, transition: { duration: 0.4 } },
}

export const scaleIn: Variants = {
  hidden:  { opacity: 0, scale: 0.92 },
  visible: { opacity: 1, scale: 1,   transition: { duration: 0.4, ease: [0.25, 0.46, 0.45, 0.94] } },
}

export const staggerContainer: Variants = {
  hidden:  {},
  visible: { transition: { staggerChildren: 0.08 } },
}

export const slideInFromLeft: Variants = {
  hidden:  { opacity: 0, x: -24 },
  visible: { opacity: 1, x: 0,  transition: { duration: 0.5, ease: 'easeOut' } },
}
```

### Scroll Reveal — Standard Usage (below-fold sections)

```tsx
import { motion } from 'framer-motion'
import { staggerContainer, fadeInUp } from '@/lib/animations'

// Section wrapper — staggered children
<motion.div
  initial={false}
  whileInView="visible"
  viewport={{ once: true, amount: 0.1 }}
  variants={staggerContainer}
  className="grid grid-cols-1 md:grid-cols-3 gap-6"
>
  {items.map((item) => (
    <motion.div key={item.id} variants={fadeInUp}>
      <FeatureCard {...item} />
    </motion.div>
  ))}
</motion.div>
```

### Reduced Motion Support

```tsx
'use client'
import { useReducedMotion } from 'framer-motion'

export function AnimatedSection({ children }: { children: React.ReactNode }) {
  const prefersReducedMotion = useReducedMotion()

  return (
    <motion.div
      initial={false}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.1 }}
      transition={{ duration: prefersReducedMotion ? 0 : 0.6 }}
    >
      {children}
    </motion.div>
  )
}
```

### CSS-Only Animations (safest — no hydration risk)

```css
/* globals.css */

/* Blinking cursor (terminal mockups) */
@keyframes cursor-blink {
  0%, 100% { opacity: 1; }
  50%       { opacity: 0; }
}
.cursor-blink { animation: cursor-blink 1.1s step-end infinite; }

/* Pulsing badge dot */
@keyframes ping {
  75%, 100% { transform: scale(2); opacity: 0; }
}
.animate-ping { animation: ping 1.2s cubic-bezier(0, 0, 0.2, 1) infinite; }

/* Infinite marquee — row 1 */
@keyframes marquee {
  0%   { transform: translateX(0); }
  100% { transform: translateX(-50%); }
}
.animate-marquee { animation: marquee 28s linear infinite; }

/* Infinite marquee — row 2 (reversed) */
@keyframes marquee-reverse {
  0%   { transform: translateX(-50%); }
  100% { transform: translateX(0); }
}
.animate-marquee-reverse { animation: marquee-reverse 32s linear infinite; }

/* Skeleton shimmer */
@keyframes shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position:  200% 0; }
}
.skeleton-shimmer {
  background: linear-gradient(
    90deg,
    oklch(0.925 0.003 286.3) 25%,
    oklch(0.870 0.006 286.3) 50%,
    oklch(0.925 0.003 286.3) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.4s ease-in-out infinite;
}

/* Respect reduced motion — always included */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## 8. Component Patterns

Full copy-pasteable code for each pattern. Every pattern uses design tokens — no hardcoded values.

### Pattern 1: Premium Card
Glass-card with hover glow effect. Use for feature lists, testimonials, any elevated content.

```tsx
// components/shared/PremiumCard.tsx
import { cn } from '@/lib/utils'

interface PremiumCardProps extends React.HTMLAttributes<HTMLDivElement> {
  glow?: boolean
}

export function PremiumCard({ className, glow = true, children, ...props }: PremiumCardProps) {
  return (
    <div
      className={cn(
        'group relative overflow-hidden rounded-2xl p-6',
        'bg-card border border-border shadow-sm',
        'transition-all duration-200 ease-out',
        'hover:-translate-y-0.5 hover:shadow-lg hover:border-border-strong',
        className
      )}
      {...props}
    >
      {/* Hover glow — absolutely positioned, pointer-events none */}
      {glow && (
        <div
          className="absolute -top-12 -right-12 size-40 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none blur-3xl"
          style={{ background: 'oklch(0.546 0.245 262.9 / 20%)' }}
        />
      )}
      <div className="relative z-10">{children}</div>
    </div>
  )
}
```

### Pattern 2: CTA Button (Primary)
Pill shape, arrow animation, loading state. This is the primary action button — one per page section maximum.

```tsx
// components/shared/CTAButton.tsx
'use client'
import { ArrowRight, Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

interface CTAButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  loading?: boolean
  arrow?: boolean
}

export function CTAButton({
  className, loading, arrow = true, children, disabled, ...props
}: CTAButtonProps) {
  return (
    <button
      className={cn(
        'group inline-flex items-center justify-center gap-2',
        'px-7 py-3.5 min-h-[44px]',
        'bg-foreground text-background',
        'rounded-full text-sm font-medium',
        'hover:opacity-90 hover:shadow-lg hover:shadow-black/20',
        'active:scale-[0.98]',
        'transition-all duration-200',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
        'disabled:opacity-40 disabled:pointer-events-none',
        className
      )}
      disabled={disabled || loading}
      aria-busy={loading}
      {...props}
    >
      {loading
        ? <Loader2 size={15} className="animate-spin" />
        : children
      }
      {arrow && !loading && (
        <ArrowRight size={15} className="transition-transform duration-200 group-hover:translate-x-0.5" />
      )}
    </button>
  )
}
```

### Pattern 3: Ghost Button
Outline pill that inverts on hover. Use as the secondary action paired with CTAButton.

```tsx
// components/shared/GhostButton.tsx
import { cn } from '@/lib/utils'

export function GhostButton({
  className, children, ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={cn(
        'inline-flex items-center justify-center gap-2',
        'px-7 py-3.5 min-h-[44px]',
        'border border-border text-foreground',
        'rounded-full text-sm font-medium',
        'hover:bg-muted/70 hover:border-border-strong',
        'transition-colors duration-200',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
        'disabled:opacity-40 disabled:pointer-events-none',
        className
      )}
      {...props}
    >
      {children}
    </button>
  )
}
```

### Pattern 4: Sticky Navbar
Backdrop blur, scroll-aware border, mobile hamburger with AnimatePresence.

```tsx
// components/layouts/Navbar.tsx
'use client'
import { useState, useEffect } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Menu, X } from 'lucide-react'
import Link from 'next/link'
import { cn } from '@/lib/utils'

const NAV_LINKS = [
  { label: 'Features', href: '#features' },
  { label: 'Pricing',  href: '#pricing'  },
  { label: 'Docs',     href: '/docs'     },
]

export function Navbar() {
  const [scrolled, setScrolled] = useState(false)
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 8)
    window.addEventListener('scroll', handler, { passive: true })
    return () => window.removeEventListener('scroll', handler)
  }, [])

  return (
    <header
      className={cn(
        'sticky top-0 z-50 w-full',
        'bg-background/80 backdrop-blur-lg',
        'transition-shadow duration-200',
        scrolled && 'border-b border-border shadow-sm'
      )}
    >
      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="font-semibold text-base tracking-tight">
          YourBrand
        </Link>

        {/* Desktop links */}
        <div className="hidden md:flex items-center gap-1">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors rounded-md hover:bg-muted/60"
            >
              {link.label}
            </Link>
          ))}
        </div>

        {/* Desktop CTA */}
        <div className="hidden md:flex items-center gap-3">
          <Link href="/login" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
            Sign in
          </Link>
          <Link
            href="/signup"
            className="inline-flex items-center px-4 py-2 bg-primary text-primary-foreground rounded-full text-sm font-medium hover:opacity-90 transition-opacity"
          >
            Get started
          </Link>
        </div>

        {/* Mobile hamburger */}
        <button
          className="md:hidden p-2 rounded-md hover:bg-muted transition-colors"
          onClick={() => setOpen((v) => !v)}
          aria-label={open ? 'Close menu' : 'Open menu'}
        >
          {open ? <X size={20} /> : <Menu size={20} />}
        </button>
      </nav>

      {/* Mobile drawer */}
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.2 }}
            className="md:hidden border-t border-border bg-background overflow-hidden"
          >
            <div className="px-4 py-4 flex flex-col gap-1">
              {NAV_LINKS.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={() => setOpen(false)}
                  className="px-3 py-2.5 text-sm text-muted-foreground hover:text-foreground rounded-lg hover:bg-muted transition-colors"
                >
                  {link.label}
                </Link>
              ))}
              <div className="pt-3 flex flex-col gap-2">
                <Link href="/login" className="px-3 py-2.5 text-sm text-center border border-border rounded-full hover:bg-muted transition-colors">
                  Sign in
                </Link>
                <Link href="/signup" className="px-3 py-2.5 text-sm text-center bg-primary text-primary-foreground rounded-full hover:opacity-90 transition-opacity">
                  Get started
                </Link>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  )
}
```

### Pattern 5: Hero Section
Gradient text headline, badge with pulse dot, CTA pair, browser mockup placeholder.

```tsx
// components/sections/HeroSection.tsx
import { motion } from 'framer-motion'
import { ArrowRight } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'

export function HeroSection() {
  return (
    <section className="hero-glow bg-grid relative overflow-hidden py-20 md:py-32 px-4">
      <div className="max-w-7xl mx-auto flex flex-col items-center text-center gap-8">

        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-border bg-background/80 backdrop-blur-sm text-xs font-medium text-muted-foreground">
          <span className="relative flex size-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75" />
            <span className="relative inline-flex size-2 rounded-full bg-green-500" />
          </span>
          Now in beta — join 50,000+ teams
          <ArrowRight size={12} className="text-muted-foreground/60" />
        </div>

        {/* Headline */}
        <h1
          className="font-bold tracking-tight text-balance gradient-text"
          style={{ fontSize: 'clamp(2.5rem, 5vw, 4.5rem)', letterSpacing: '-0.04em', lineHeight: 1.06 }}
        >
          Ship faster.<br />Break fewer things.
        </h1>

        {/* Subline */}
        <p className="text-lg md:text-xl text-muted-foreground max-w-2xl leading-relaxed">
          The all-in-one platform that gives your team superpowers.
          Built for developers who care about quality.
        </p>

        {/* CTA pair */}
        <div className="flex flex-wrap items-center justify-center gap-4">
          <Link
            href="/signup"
            className="group inline-flex items-center gap-2 px-7 py-3.5 bg-foreground text-background rounded-full text-sm font-medium hover:opacity-90 hover:shadow-lg hover:shadow-black/20 transition-all duration-200 min-h-[44px]"
          >
            Get started for free
            <ArrowRight size={15} className="transition-transform group-hover:translate-x-0.5" />
          </Link>
          <Link
            href="/demo"
            className="inline-flex items-center gap-2 px-7 py-3.5 border border-border text-foreground rounded-full text-sm font-medium hover:bg-muted/70 transition-colors min-h-[44px]"
          >
            View demo
          </Link>
        </div>

        {/* Trust line */}
        <p className="text-xs text-muted-foreground/70">
          No credit card required. Free plan available.
        </p>

        {/* Product mockup */}
        <div className="w-full max-w-4xl mt-4">
          <div className="product-shadow rounded-2xl overflow-hidden border border-border">
            {/* Replace with your actual product screenshot */}
            <div className="h-96 bg-muted flex items-center justify-center text-muted-foreground text-sm">
              Product screenshot (use next/image with priority prop)
            </div>
          </div>
        </div>

      </div>
    </section>
  )
}
```

### Pattern 6: Feature Grid (Asymmetric)
One large card spanning 2 rows, four smaller cards. Stat badges, hover glows. More memorable than a uniform grid.

```tsx
// components/sections/FeaturesSection.tsx
import { motion } from 'framer-motion'
import { Zap, Shield, BarChart3, Globe, Code2 } from 'lucide-react'
import { staggerContainer, fadeInUp } from '@/lib/animations'

const features = [
  { icon: Zap,      label: 'Lightning fast', desc: '50ms median response time globally.',     stat: '50ms',  large: true },
  { icon: Shield,   label: 'Enterprise security', desc: 'SOC2 Type II certified.',             stat: null,   large: false },
  { icon: BarChart3,label: 'Real-time analytics', desc: 'Know what's happening instantly.',   stat: '99.9%', large: false },
  { icon: Globe,    label: 'Global edge',    desc: '250+ PoPs worldwide.',                    stat: '250+',  large: false },
  { icon: Code2,    label: 'API-first',      desc: 'Build anything with our REST & SDK.',     stat: null,   large: false },
]

export function FeaturesSection() {
  return (
    <section className="py-16 md:py-24 px-4">
      <div className="max-w-7xl mx-auto">

        {/* Section label */}
        <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-4">Features</p>
        <h2 className="text-3xl font-semibold tracking-tight text-balance mb-12 max-w-xl">
          Everything you need, nothing you don't.
        </h2>

        <motion.div
          initial={false}
          whileInView="visible"
          viewport={{ once: true, amount: 0.1 }}
          variants={staggerContainer}
          className="grid grid-cols-1 md:grid-cols-3 auto-rows-[200px] gap-5"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.label}
              variants={fadeInUp}
              className={feature.large ? 'md:row-span-2' : ''}
            >
              <div className="group relative h-full overflow-hidden rounded-2xl border border-border bg-card p-6 hover:-translate-y-0.5 hover:shadow-lg transition-all duration-200">
                {/* Hover glow */}
                <div
                  className="absolute -top-8 -right-8 size-32 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none blur-3xl"
                  style={{ background: 'oklch(0.546 0.245 262.9 / 15%)' }}
                />
                <div className="relative z-10 flex flex-col h-full">
                  <div className="size-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary mb-4 flex-shrink-0">
                    <feature.icon size={20} />
                  </div>
                  <h3 className="text-base font-semibold mb-1.5">{feature.label}</h3>
                  <p className="text-sm text-muted-foreground leading-relaxed flex-1">{feature.desc}</p>
                  {feature.stat && (
                    <span className="mt-4 inline-flex items-center self-start px-2.5 py-1 bg-primary/10 text-primary rounded-full text-xs font-semibold">
                      {feature.stat}
                    </span>
                  )}
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
```

### Pattern 7: Pricing Table
Three tiers, popular badge, full-width CTA at bottom of each card.

```tsx
// components/sections/PricingSection.tsx
import { Check } from 'lucide-react'
import { cn } from '@/lib/utils'

const plans = [
  {
    name: 'Starter', price: '$0', period: '/month', popular: false,
    description: 'For individuals and side projects.',
    features: ['5 projects', '10GB storage', 'Community support', 'Basic analytics'],
    cta: 'Get started free', ctaHref: '/signup',
  },
  {
    name: 'Pro', price: '$29', period: '/month', popular: true,
    description: 'For growing teams that need more.',
    features: ['Unlimited projects', '100GB storage', 'Priority support', 'Advanced analytics', 'Custom domains', 'Team collaboration'],
    cta: 'Start free trial', ctaHref: '/signup?plan=pro',
  },
  {
    name: 'Enterprise', price: 'Custom', period: '', popular: false,
    description: 'For large organizations with compliance needs.',
    features: ['Everything in Pro', 'SSO / SAML', 'SLA guarantee', 'Dedicated CSM', 'Custom contracts'],
    cta: 'Contact sales', ctaHref: '/contact',
  },
]

export function PricingSection() {
  return (
    <section id="pricing" className="py-16 md:py-24 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-12">
          <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-3">Pricing</p>
          <h2 className="text-3xl font-semibold tracking-tight">Simple, transparent pricing.</h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 items-start">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={cn(
                'relative rounded-2xl p-6 border bg-card',
                plan.popular
                  ? 'border-primary shadow-lg ring-1 ring-primary/30'
                  : 'border-border shadow-sm'
              )}
            >
              {plan.popular && (
                <div className="absolute -top-3.5 left-1/2 -translate-x-1/2">
                  <span className="inline-flex items-center px-3 py-1 rounded-full bg-primary text-primary-foreground text-xs font-semibold">
                    Most popular
                  </span>
                </div>
              )}

              <div className="mb-5">
                <h3 className="text-base font-semibold mb-1">{plan.name}</h3>
                <p className="text-sm text-muted-foreground">{plan.description}</p>
              </div>

              <div className="mb-6">
                <span className="text-4xl font-bold tracking-tight">{plan.price}</span>
                {plan.period && <span className="text-sm text-muted-foreground ml-1">{plan.period}</span>}
              </div>

              <ul className="space-y-2.5 mb-8">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-2.5 text-sm text-muted-foreground">
                    <Check size={15} className="text-green-500 flex-shrink-0" />
                    {feature}
                  </li>
                ))}
              </ul>

              <a
                href={plan.ctaHref}
                className={cn(
                  'block w-full text-center py-2.5 rounded-full text-sm font-medium transition-all duration-200',
                  plan.popular
                    ? 'bg-primary text-primary-foreground hover:opacity-90 shadow-sm'
                    : 'border border-border hover:bg-muted'
                )}
              >
                {plan.cta}
              </a>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

### Pattern 8: Footer
Gradient divider, newsletter form, 5-column grid, social icons.

```tsx
// components/sections/Footer.tsx
import Link from 'next/link'
import { Github, Twitter, Linkedin } from 'lucide-react'

const NAV = {
  Product:  ['Features', 'Pricing', 'Changelog', 'Roadmap'],
  Docs:     ['Getting started', 'API reference', 'Examples', 'CLI'],
  Company:  ['About', 'Blog', 'Careers', 'Press'],
  Legal:    ['Privacy', 'Terms', 'Security', 'Cookies'],
}

export function Footer() {
  return (
    <footer className="relative">
      {/* Gradient accent divider */}
      <div className="footer-gradient-divider" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="grid grid-cols-2 md:grid-cols-5 gap-8">

          {/* Brand column */}
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="font-semibold text-base">YourBrand</Link>
            <p className="mt-3 text-sm text-muted-foreground leading-relaxed">
              The platform that gives your team superpowers.
            </p>
            {/* Newsletter */}
            <form className="mt-5 flex gap-2">
              <input
                type="email"
                placeholder="Enter email"
                className="flex-1 min-w-0 px-3 py-2 text-sm bg-muted border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-ring"
              />
              <button
                type="submit"
                className="px-3 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:opacity-90 transition-opacity"
              >
                Subscribe
              </button>
            </form>
          </div>

          {/* Nav columns */}
          {Object.entries(NAV).map(([section, links]) => (
            <div key={section}>
              <h4 className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-4">{section}</h4>
              <ul className="space-y-2.5">
                {links.map((link) => (
                  <li key={link}>
                    <Link href="#" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
                      {link}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="mt-12 pt-6 border-t border-border flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-muted-foreground">
            &copy; {new Date().getFullYear()} YourBrand, Inc. All rights reserved.
          </p>
          <div className="flex items-center gap-4">
            {[
              { href: 'https://github.com', icon: Github,   label: 'GitHub'   },
              { href: 'https://twitter.com', icon: Twitter, label: 'Twitter'  },
              { href: 'https://linkedin.com', icon: Linkedin, label: 'LinkedIn' },
            ].map(({ href, icon: Icon, label }) => (
              <a key={label} href={href} target="_blank" rel="noopener noreferrer"
                className="text-muted-foreground hover:text-foreground transition-colors"
                aria-label={label}
              >
                <Icon size={16} />
              </a>
            ))}
          </div>
        </div>
      </div>
    </footer>
  )
}
```

### Pattern 9: Auth Form
Social OAuth button, "or continue with" divider, password show/hide, Zod + React Hook Form validation.

```tsx
// components/sections/AuthForm.tsx
'use client'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Eye, EyeOff, Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

const schema = z.object({
  email:    z.string().email('Enter a valid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
})
type FormValues = z.infer<typeof schema>

export function AuthForm({ mode = 'signin' }: { mode?: 'signin' | 'signup' }) {
  const [showPassword, setShowPassword] = useState(false)
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(schema),
  })

  async function onSubmit(data: FormValues) {
    // Replace with actual API call
    await new Promise((r) => setTimeout(r, 1200))
    console.log(data)
  }

  return (
    <div className="w-full max-w-md mx-auto">
      <div className="bg-card border border-border rounded-2xl p-8 shadow-md">
        <h1 className="text-2xl font-semibold tracking-tight mb-1">
          {mode === 'signin' ? 'Welcome back' : 'Create your account'}
        </h1>
        <p className="text-sm text-muted-foreground mb-6">
          {mode === 'signin' ? "Don't have an account? " : 'Already have an account? '}
          <a href={mode === 'signin' ? '/signup' : '/login'} className="text-primary hover:underline underline-offset-4">
            {mode === 'signin' ? 'Sign up' : 'Sign in'}
          </a>
        </p>

        {/* Social OAuth */}
        <button className="w-full flex items-center justify-center gap-3 py-2.5 border border-border rounded-lg text-sm font-medium hover:bg-muted transition-colors mb-5">
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
            <path fill="#4285F4" d="M23.745 12.27c0-.79-.07-1.54-.19-2.27h-11.3v4.51h6.47c-.29 1.48-1.14 2.73-2.4 3.58v3h3.86c2.26-2.09 3.56-5.17 3.56-8.82z"/>
            <path fill="#34A853" d="M12.255 24c3.24 0 5.95-1.08 7.93-2.91l-3.86-3c-1.08.72-2.45 1.16-4.07 1.16-3.13 0-5.78-2.11-6.73-4.96h-3.98v3.09C3.515 21.3 7.615 24 12.255 24z"/>
            <path fill="#FBBC05" d="M5.525 14.29c-.25-.72-.38-1.49-.38-2.29s.14-1.57.38-2.29V6.62h-3.98a11.86 11.86 0 000 10.76l3.98-3.09z"/>
            <path fill="#EA4335" d="M12.255 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C18.205 1.19 15.495 0 12.255 0c-4.64 0-8.74 2.7-10.71 6.62l3.98 3.09c.95-2.85 3.6-4.96 6.73-4.96z"/>
          </svg>
          Continue with Google
        </button>

        {/* Divider */}
        <div className="relative mb-5">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-border" />
          </div>
          <div className="relative flex justify-center">
            <span className="px-3 bg-card text-xs text-muted-foreground">or continue with email</span>
          </div>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} noValidate className="space-y-4">
          {/* Email */}
          <div>
            <label htmlFor="email" className="block text-sm font-medium mb-1.5">Email</label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              aria-describedby={errors.email ? 'email-error' : undefined}
              className={cn(
                'w-full px-3 py-2 text-sm rounded-lg border bg-background',
                'focus:outline-none focus:ring-2 focus:ring-ring',
                'transition-colors duration-150',
                errors.email ? 'border-destructive' : 'border-border'
              )}
              {...register('email')}
            />
            {errors.email && (
              <p id="email-error" role="alert" className="mt-1.5 text-xs text-destructive">{errors.email.message}</p>
            )}
          </div>

          {/* Password */}
          <div>
            <label htmlFor="password" className="block text-sm font-medium mb-1.5">Password</label>
            <div className="relative">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                autoComplete={mode === 'signin' ? 'current-password' : 'new-password'}
                aria-describedby={errors.password ? 'password-error' : undefined}
                className={cn(
                  'w-full px-3 py-2 pr-10 text-sm rounded-lg border bg-background',
                  'focus:outline-none focus:ring-2 focus:ring-ring',
                  'transition-colors duration-150',
                  errors.password ? 'border-destructive' : 'border-border'
                )}
                {...register('password')}
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {errors.password && (
              <p id="password-error" role="alert" className="mt-1.5 text-xs text-destructive">{errors.password.message}</p>
            )}
          </div>

          {/* Submit */}
          <button
            type="submit"
            disabled={isSubmitting}
            aria-busy={isSubmitting}
            className="w-full flex items-center justify-center gap-2 py-2.5 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-50 disabled:pointer-events-none min-h-[44px]"
          >
            {isSubmitting && <Loader2 size={15} className="animate-spin" />}
            {mode === 'signin' ? 'Sign in' : 'Create account'}
          </button>
        </form>
      </div>
    </div>
  )
}
```

### Pattern 10: Terminal Mockup
macOS chrome, syntax highlighting, blinking cursor, file tree. Renders server-side safely.

```tsx
// components/shared/TerminalMockup.tsx
export function TerminalMockup() {
  return (
    <div className="product-shadow rounded-xl overflow-hidden border border-border font-mono text-sm">
      {/* macOS chrome */}
      <div className="flex items-center gap-2 px-4 py-3 bg-muted border-b border-border">
        <div className="size-3 rounded-full bg-red-400" />
        <div className="size-3 rounded-full bg-yellow-400" />
        <div className="size-3 rounded-full bg-green-400" />
        <span className="ml-2 text-xs text-muted-foreground">~/your-project</span>
      </div>

      {/* Terminal body */}
      <div className="bg-gray-950 p-5 text-sm leading-relaxed">
        <div className="flex gap-2 mb-2">
          <span className="text-green-400">$</span>
          <span className="text-gray-200">npx create-your-app@latest my-app</span>
        </div>
        <div className="text-gray-500 mb-2">Creating a new app in /my-app...</div>
        <div className="flex gap-2 mb-2">
          <span className="text-blue-400">info</span>
          <span className="text-gray-300">Installing dependencies</span>
        </div>
        <div className="text-green-400 mb-2">+ 142 packages installed in 3.2s</div>
        <div className="flex gap-2">
          <span className="text-green-400">$</span>
          <span className="text-gray-200">cd my-app &amp;&amp; npm run dev</span>
          {/* Blinking cursor */}
          <span className="inline-block w-2 h-4 bg-gray-300 cursor-blink" aria-hidden="true" />
        </div>
      </div>
    </div>
  )
}
```

### Pattern 11: Integration Marquee
Dual-row infinite scroll, branded chips, fade edges. Respects `prefers-reduced-motion`.

```tsx
// components/shared/IntegrationMarquee.tsx
import { cn } from '@/lib/utils'

const row1 = ['Stripe', 'Vercel', 'GitHub', 'Figma', 'Slack', 'Linear', 'Notion', 'Jira']
const row2 = ['AWS', 'Supabase', 'Resend', 'Cloudflare', 'Datadog', 'Sentry', 'PostHog', 'PlanetScale']

function MarqueeRow({ items, reverse = false }: { items: string[]; reverse?: boolean }) {
  // Duplicate items to create seamless loop
  const doubled = [...items, ...items]
  return (
    <div className="flex overflow-hidden [mask-image:linear-gradient(to_right,transparent,black_10%,black_90%,transparent)]">
      <div className={cn('flex gap-3 py-2', reverse ? 'animate-marquee-reverse' : 'animate-marquee')}>
        {doubled.map((name, i) => (
          <div
            key={`${name}-${i}`}
            className="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2 rounded-full border border-border bg-card text-sm text-muted-foreground"
          >
            <div className="size-4 rounded-sm bg-muted" aria-hidden="true" />
            {name}
          </div>
        ))}
      </div>
    </div>
  )
}

export function IntegrationMarquee() {
  return (
    <section className="py-16 md:py-20 overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 mb-10 text-center">
        <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mb-3">Integrations</p>
        <h2 className="text-2xl font-semibold tracking-tight">
          Works with your whole stack
        </h2>
        <p className="mt-2 text-sm text-muted-foreground">100+ integrations available</p>
      </div>
      <div className="space-y-3">
        <MarqueeRow items={row1} />
        <MarqueeRow items={row2} reverse />
      </div>
    </section>
  )
}
```

### Pattern 12: Dark CTA Section
Gradient background, noise texture, avatar social proof, centered glow.

```tsx
// components/sections/CTASection.tsx
import Link from 'next/link'
import Image from 'next/image'
import { ArrowRight } from 'lucide-react'

const AVATARS = [
  '/avatars/1.jpg', '/avatars/2.jpg', '/avatars/3.jpg', '/avatars/4.jpg', '/avatars/5.jpg',
]

export function CTASection() {
  return (
    <section className="py-16 md:py-24 px-4">
      <div className="max-w-4xl mx-auto">
        <div className="cta-gradient noise relative rounded-3xl p-12 text-center overflow-hidden">
          {/* Central glow */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              background: 'radial-gradient(ellipse 60% 40% at 50% 0%, oklch(0.546 0.245 262.9 / 20%), transparent 70%)',
            }}
            aria-hidden="true"
          />

          <div className="relative z-10">
            {/* Avatar social proof */}
            <div className="flex items-center justify-center gap-1 mb-6">
              <div className="flex -space-x-2">
                {AVATARS.map((src, i) => (
                  <div key={i} className="size-8 rounded-full border-2 border-gray-900 overflow-hidden bg-muted">
                    {/* Replace with real user avatars */}
                    <div className="w-full h-full bg-gradient-to-br from-blue-400 to-purple-500" />
                  </div>
                ))}
              </div>
              <p className="ml-3 text-sm text-gray-400">
                Trusted by <span className="text-gray-200 font-medium">50,000+</span> developers
              </p>
            </div>

            <h2 className="text-3xl md:text-4xl font-bold text-white tracking-tight text-balance mb-4">
              Ready to ship faster?
            </h2>
            <p className="text-base text-gray-400 max-w-lg mx-auto mb-8 leading-relaxed">
              Join thousands of teams who use YourBrand to build, deploy, and scale their products.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4">
              <Link
                href="/signup"
                className="group inline-flex items-center gap-2 px-7 py-3.5 bg-white text-gray-950 rounded-full text-sm font-medium hover:opacity-90 hover:shadow-xl hover:shadow-black/30 transition-all duration-200 min-h-[44px]"
              >
                Get started for free
                <ArrowRight size={15} className="transition-transform group-hover:translate-x-0.5" />
              </Link>
              <Link
                href="/contact"
                className="inline-flex items-center gap-2 px-7 py-3.5 border border-white/20 text-white rounded-full text-sm font-medium hover:bg-white/10 transition-colors min-h-[44px]"
              >
                Talk to sales
              </Link>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
```

---

## 9. Page Templates

### Landing Page — Standard Section Order
1. **Navbar** — sticky, backdrop-blur, logo + links + CTA pair
2. **Hero** — badge + gradient headline + subline + CTA pair + product mockup
3. **Social proof strip** — logo marquee or "50K+ teams" with avatar stack
4. **Features** — asymmetric grid (1 large + 4 small), stat badges, hover glows
5. **How it works** — numbered steps or terminal mockup demo
6. **Testimonials** — 3 quote cards max, star ratings, author avatar
7. **Pricing** — 3 tiers, comparison table optional, popular badge
8. **CTA** — dark gradient card with glow + social proof
9. **Footer** — gradient accent divider + newsletter + 5-column grid + social icons

### Dashboard — Standard Layout Areas
1. **Sidebar** — collapsible, logo at top, nav items with active state, user menu at bottom
2. **Header** — breadcrumb trail, global search, notifications bell, user avatar
3. **Content area** — stat cards, data tables, charts, empty states
4. **Empty states** — illustration + descriptive heading + primary CTA

### Auth Pages — Element Checklist
1. Centered card (`max-w-md mx-auto`)
2. Brand logo + page heading (`h1`)
3. Social OAuth button(s) with provider logos
4. Divider "or continue with email"
5. Form fields with labels + inline validation
6. Submit button (full width, primary, loading state)
7. Footer link (already have account? / don't have?)

---

## 10. Quality Checklist

Run this before declaring any page complete. Every unchecked item is a bug.

### Color and Token Compliance
- [ ] Zero hardcoded hex values in JSX — all colors use design token classes or `var(--)`
- [ ] No `text-white`, `bg-black`, `text-gray-500` — use semantic token classes (`text-foreground`, `text-muted-foreground`)
- [ ] Dark mode tested — no colors look broken at `prefers-color-scheme: dark`
- [ ] Contrast ratio >= 4.5:1 for all body text (verify with browser DevTools)

### Typography
- [ ] Exactly one `<h1>` per page
- [ ] Heading ladder respected (h1 > h2 > h3 — no skipped levels)
- [ ] No more than 2 font families on the page
- [ ] No `font-weight: 800` or `font-weight: 900` anywhere
- [ ] Body text minimum 14px (text-sm)

### Accessibility (WCAG 2.1 AA)
- [ ] All interactive elements have visible `focus-visible:ring-2` state
- [ ] All touch targets >= 44x44px
- [ ] All images have `alt` attributes (decorative = `alt=""`)
- [ ] All form inputs have associated `<label>` elements
- [ ] All buttons have accessible names (text or `aria-label`)
- [ ] All links have valid `href` — never `href="#"` on live code
- [ ] Error messages linked to inputs via `aria-describedby`
- [ ] Semantic HTML: `<nav>`, `<main>`, `<section>`, `<footer>`, `<header>`

### Animation Safety
- [ ] No `initial={{ opacity: 0 }}` on above-fold content (use `initial={false}`)
- [ ] All `whileInView` animations use `viewport={{ once: true }}`
- [ ] `noscript` fallback in `app/layout.tsx`
- [ ] `prefers-reduced-motion` handled via `useReducedMotion()` or CSS media query

### Performance
- [ ] All images use `next/image` (never `<img>`)
- [ ] Hero image has `priority` prop on `next/image`
- [ ] Fonts loaded via `next/font` — no `<link>` font tags
- [ ] No `<img>` tags — every image is `next/image`
- [ ] Above-fold JS minimized (no large client components in hero)

### Responsive
- [ ] No horizontal scroll at 390px viewport width
- [ ] Mobile layout tested: single column, stacked sections
- [ ] Navigation collapses to hamburger below `md:` breakpoint
- [ ] Touch targets respect 44px minimum on mobile

### States
- [ ] Loading states for all async operations (skeleton, not spinner)
- [ ] Error states with message and recovery CTA
- [ ] Empty states with icon/illustration + description + CTA
- [ ] Disabled states styled with `opacity-40 pointer-events-none`
- [ ] Hover + focus states on every interactive element

---

## 11. Anti-Patterns (NEVER DO)

### Color
- NEVER use pure black (`#000000` or `bg-black`) — use `text-foreground` or `bg-background`
- NEVER use pure white (`#ffffff` or `text-white`) — use `text-foreground` or `bg-background`
- NEVER hardcode hex values in JSX or CSS — use design tokens
- NEVER use `text-gray-*`, `bg-gray-*` — use semantic tokens (`text-muted-foreground`, `bg-muted`)
- NEVER use more than 3 distinct hues on one page
- NEVER use rainbow color schemes — maximum 1 brand color + neutral scale

### Typography
- NEVER use `font-weight: 800` or `900` — they look heavy and amateurish
- NEVER use `font-weight: 300` (`font-light`) — poor readability on screens
- NEVER use `text-align: justify` — creates rivers of whitespace
- NEVER put more than 3 lines of centered text in a block
- NEVER use `letter-spacing: -0.1em` — maximum -0.04em
- NEVER use ALL CAPS for anything longer than 3 words

### Layout
- NEVER produce horizontal scroll at 390px (iPhone base viewport)
- NEVER center large blocks of body text (hero subline is OK, paragraphs are not)
- NEVER use `rounded-3xl` on small elements like badges and chips
- NEVER use `border-radius` inconsistently on the same page
- NEVER skip the `max-w-7xl` container — uncontained wide layouts look broken

### Components
- NEVER recreate `Button`, `Dialog`, `Toast`, `Select`, `Checkbox` — use shadcn/ui
- NEVER add `border-2` to cards to make them "pop" — use layered shadows instead
- NEVER use background patterns at > 5% opacity — they drown the content
- NEVER use spinners for content-area loading — use skeleton screens
- NEVER use `<img>` tags — always `next/image`
- NEVER import the full icon barrel (`import * from 'lucide-react'`) — import individually

### Animation
- NEVER set `initial={{ opacity: 0 }}` on above-fold content
- NEVER use `initial="hidden"` where `hidden = { opacity: 0 }` on above-fold content
- NEVER animate `width`, `height`, `top`, or `left` — use `transform` and `opacity` only
- NEVER animate more than 10 elements simultaneously on mobile
- NEVER use `type: "spring"` on page-level transitions — use duration-based easing
- NEVER skip `prefers-reduced-motion` handling
- NEVER use `<motion.div exit>` without an `<AnimatePresence>` parent

### Content
- NEVER use `href="#"` for links in production code — every link must go somewhere
- NEVER leave placeholder text ("Lorem ipsum", "Coming soon") in shipped templates
- NEVER use stock photo heroes — use product screenshots or abstract code/data visuals
- NEVER use clip-art style icon packs — use Lucide icons consistently
- NEVER put text directly on images without a sufficient background overlay (contrast < 4.5:1)
