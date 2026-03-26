# Quality Patterns for Professional AI-Generated Apps

This document codifies the patterns that separate apps that look hand-crafted from apps that look generated. Every section maps to a concrete implementation decision.

---

## 1. Design Quality Patterns

### 1.1 Typography Scales

The single biggest signal of a "cheap AI app" is poor typography hierarchy. Premium sites use a modular scale with consistent ratios.

**Recommended scales by use case:**
- Marketing / landing page: 1.618 (golden ratio) — dramatic, high-contrast
- Dashboard / SaaS app: 1.25 — subtle, information-dense
- Documentation / blog: 1.333 — readable, clear hierarchy

**Base size:** 16px (1rem). Never go below 14px for body copy.

**Type ramp (using 1.25 ratio from 16px base):**
```
xs:   12px / 0.75rem   — captions, labels
sm:   14px / 0.875rem  — secondary text, metadata
base: 16px / 1rem      — body copy
lg:   20px / 1.25rem   — lead text, card headings
xl:   24px / 1.5rem    — section headings
2xl:  30px / 1.875rem  — page sub-headings
3xl:  36px / 2.25rem   — page headings
4xl:  48px / 3rem      — hero headings
5xl:  60px / 3.75rem   — display / marketing
```

**Line heights:**
- Body copy: 1.6–1.75 (always more than headings)
- Headings: 1.1–1.2 (tight is premium)
- UI labels: 1.0–1.25

**Letter spacing:**
- Headings large (3xl+): -0.03em to -0.05em (tight = premium)
- Body: 0 to 0.01em
- ALL CAPS labels: 0.05em to 0.1em

**Font choices that read premium:**
- Geist Sans (Vercel's font — open source, optimized for interfaces)
- Inter (ubiquitous but excellent, use variable weights)
- Plus Jakarta Sans (good alternative to Inter)
- Cal Sans (display/headings only — used by Cal.com, Linear)

**Anti-pattern:** Using system-ui or a Google Font with only two weights. Always load variable fonts so you can use weight 300–900.

```tsx
// next.js layout.tsx — correct font loading pattern
import { GeistSans } from 'geist/font/sans'
import { GeistMono } from 'geist/font/mono'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable}`}>
      <body className="font-sans antialiased">{children}</body>
    </html>
  )
}
```

---

### 1.2 Color System Design — OKLCH + Semantic Tokens

**Why OKLCH over HSL/hex:**
OKLCH (perceptual lightness, chroma, hue) produces colors that look consistent across light and dark modes because lightness is perceptually uniform. HSL produces colors that appear to shift brightness when you try to create a dark mode palette.

**Browser support (2026):** Chrome 111+, Safari 16.4+, Firefox 128+ — fully supported.

**Three-tier token architecture:**

```css
/* Tier 1: Primitive / Reference tokens — raw values */
:root {
  --primitive-blue-50:  oklch(0.97 0.013 254);
  --primitive-blue-100: oklch(0.94 0.026 254);
  --primitive-blue-500: oklch(0.55 0.245 262.9);
  --primitive-blue-600: oklch(0.46 0.245 262.9);
  --primitive-blue-900: oklch(0.23 0.12  262.9);

  --primitive-gray-50:  oklch(0.985 0 0);
  --primitive-gray-100: oklch(0.96  0.003 286);
  --primitive-gray-900: oklch(0.141 0.005 286);
}

/* Tier 2: Semantic tokens — meaning, not value */
:root {
  --color-bg:           var(--primitive-gray-50);
  --color-bg-subtle:    var(--primitive-gray-100);
  --color-fg:           var(--primitive-gray-900);
  --color-fg-muted:     oklch(0.45 0.02 286);
  --color-border:       oklch(0.9 0.004 286);
  --color-border-strong:oklch(0.75 0.01 286);
  --color-primary:      var(--primitive-blue-500);
  --color-primary-hover:var(--primitive-blue-600);
  --color-primary-fg:   oklch(1 0 0);
}

.dark {
  --color-bg:           oklch(0.098 0.005 286);
  --color-bg-subtle:    oklch(0.141 0.005 286);
  --color-fg:           oklch(0.985 0 0);
  --color-fg-muted:     oklch(0.65 0.01 286);
  --color-border:       oklch(0.22 0.007 286);
  --color-border-strong:oklch(0.35 0.01 286);
  --color-primary:      var(--primitive-blue-400);
  --color-primary-hover:var(--primitive-blue-300);
  --color-primary-fg:   oklch(0.141 0.005 286);
}

/* Tier 3: Component tokens — referenced in components */
.btn-primary {
  background: var(--color-primary);
  color:      var(--color-primary-fg);
}
```

**shadcn/ui v4 registry theme (OKLCH):**
```json
{
  "cssVars": {
    "light": {
      "background":           "oklch(1 0 0)",
      "foreground":           "oklch(0.141 0.005 285.823)",
      "primary":              "oklch(0.546 0.245 262.881)",
      "primary-foreground":   "oklch(0.97 0.014 254.604)",
      "muted":                "oklch(0.967 0.001 286.375)",
      "muted-foreground":     "oklch(0.552 0.016 285.938)",
      "border":               "oklch(0.92 0.004 286.32)",
      "ring":                 "oklch(0.546 0.245 262.881)"
    },
    "dark": {
      "background":           "oklch(0.141 0.005 285.823)",
      "foreground":           "oklch(0.985 0 0)",
      "primary":              "oklch(0.707 0.165 254.624)",
      "primary-foreground":   "oklch(0.97 0.014 254.604)",
      "muted":                "oklch(0.21 0.006 285.885)",
      "muted-foreground":     "oklch(0.705 0.015 286.067)",
      "border":               "oklch(0.274 0.006 286.033)",
      "ring":                 "oklch(0.707 0.165 254.624)"
    }
  }
}
```

**Tailwind v4 @theme (CSS-first configuration):**
```css
@import "tailwindcss";

@theme {
  --color-primary-50:  oklch(0.97 0.013 254);
  --color-primary-500: oklch(0.55 0.245 262.9);
  --color-primary-600: oklch(0.46 0.245 262.9);

  --font-sans: "Geist", "Inter", system-ui, sans-serif;
  --font-mono: "Geist Mono", "JetBrains Mono", monospace;

  --radius-sm:  0.375rem;
  --radius-md:  0.5rem;
  --radius-lg:  0.75rem;
  --radius-xl:  1rem;
  --radius-2xl: 1.5rem;
}
```

---

### 1.3 Spacing System — 4px/8px Grid

**Base unit:** 4px. All spacing values are multiples of 4.

**The canonical scale (what Tailwind v4 + most design systems use):**
```
1  →  4px   (0.25rem)   — tight gaps, border offsets
2  →  8px   (0.5rem)    — icon padding, list item gaps
3  →  12px  (0.75rem)   — small internal padding
4  →  16px  (1rem)      — standard padding, baseline unit
5  →  20px  (1.25rem)   — slightly loose
6  →  24px  (1.5rem)    — card padding, section margins
8  →  32px  (2rem)      — section gaps
10 →  40px  (2.5rem)    — large section gaps
12 →  48px  (3rem)      — hero content spacing
16 →  64px  (4rem)      — page sections
20 →  80px  (5rem)      — large page sections
24 →  96px  (6rem)      — hero padding
```

**Anti-pattern:** Hardcoding pixel values like `mt-[17px]` or `p-[13px]`. Every value should be on the grid.

**Semantic spacing tokens (name the meaning):**
```css
@theme {
  --spacing-component-xs: 0.25rem;   /* 4px  — intra-component */
  --spacing-component-sm: 0.5rem;    /* 8px  — tight component */
  --spacing-component-md: 1rem;      /* 16px — standard component */
  --spacing-component-lg: 1.5rem;    /* 24px — loose component */
  --spacing-section-sm:   2rem;      /* 32px — section gap */
  --spacing-section-md:   4rem;      /* 64px — page section */
  --spacing-section-lg:   6rem;      /* 96px — hero section */
}
```

---

### 1.4 Shadow System — Layered Depth

Premium shadows use two layers: a tight "contact" shadow (anchors element to surface) and a loose "ambient" shadow (creates soft depth halo). Single-shadow UIs look flat.

**Shadow scale (5 elevation levels):**
```css
:root {
  /* Level 0: no elevation — flat surface */
  --shadow-0: none;

  /* Level 1: slightly raised — cards, inputs */
  --shadow-1:
    0 1px 2px 0 oklch(0 0 0 / 0.05),
    0 1px 3px 0 oklch(0 0 0 / 0.1);

  /* Level 2: raised — hover states, dropdowns */
  --shadow-2:
    0 1px 3px 0  oklch(0 0 0 / 0.07),
    0 4px 6px -1px oklch(0 0 0 / 0.1),
    0 2px 4px -2px oklch(0 0 0 / 0.06);

  /* Level 3: floating — modals, popovers */
  --shadow-3:
    0 1px 3px 0   oklch(0 0 0 / 0.05),
    0 10px 15px -3px oklch(0 0 0 / 0.1),
    0 4px 6px -4px   oklch(0 0 0 / 0.05);

  /* Level 4: overlays — dialogs, sheets */
  --shadow-4:
    0 1px 3px 0   oklch(0 0 0 / 0.05),
    0 25px 50px -12px oklch(0 0 0 / 0.25);

  /* Inset (pressed state) */
  --shadow-inset:
    inset 0 2px 4px 0 oklch(0 0 0 / 0.06);
}

/* Dark mode: shadows are less prominent (dark bg absorbs shadow) */
.dark {
  --shadow-1: 0 1px 2px 0 oklch(0 0 0 / 0.3);
  --shadow-2: 0 4px 6px -1px oklch(0 0 0 / 0.4), 0 2px 4px -2px oklch(0 0 0 / 0.3);
  --shadow-3: 0 10px 15px -3px oklch(0 0 0 / 0.5), 0 4px 6px -4px oklch(0 0 0 / 0.3);
  --shadow-4: 0 25px 50px -12px oklch(0 0 0 / 0.6);
}
```

**Tailwind v4 shadow mapping:**
```css
@theme {
  --shadow-sm: var(--shadow-1);
  --shadow:    var(--shadow-2);
  --shadow-md: var(--shadow-2);
  --shadow-lg: var(--shadow-3);
  --shadow-xl: var(--shadow-4);
}
```

---

### 1.5 Animation Patterns — Framer Motion for SSR

**Core rules:**
1. Use `motion` from `framer-motion` (not `m` unless you've loaded LazyMotion)
2. Wrap animated components in `<AnimatePresence>` when they mount/unmount
3. Prefer `layout` prop for size/position changes — avoids recalculating
4. Use `useReducedMotion()` hook and respect it
5. For SSR (Next.js App Router): mark animation components `"use client"`

**Reusable animation variants (define once, use everywhere):**
```tsx
// lib/animations.ts
export const fadeIn = {
  hidden:  { opacity: 0 },
  visible: { opacity: 1, transition: { duration: 0.3, ease: 'easeOut' } },
}

export const fadeInUp = {
  hidden:  { opacity: 0, y: 12 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.22, 1, 0.36, 1] } },
}

export const fadeInDown = {
  hidden:  { opacity: 0, y: -12 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] } },
}

export const scaleIn = {
  hidden:  { opacity: 0, scale: 0.96 },
  visible: { opacity: 1, scale: 1, transition: { duration: 0.3, ease: [0.22, 1, 0.36, 1] } },
}

export const staggerContainer = {
  hidden:  {},
  visible: { transition: { staggerChildren: 0.07, delayChildren: 0.1 } },
}
```

**Scroll-triggered animations:**
```tsx
"use client"
import { motion, useInView } from 'framer-motion'
import { useRef } from 'react'
import { fadeInUp } from '@/lib/animations'

export function AnimatedSection({ children }: { children: React.ReactNode }) {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  return (
    <motion.div
      ref={ref}
      variants={fadeInUp}
      initial="hidden"
      animate={isInView ? 'visible' : 'hidden'}
    >
      {children}
    </motion.div>
  )
}
```

**Reduced motion pattern:**
```tsx
import { useReducedMotion } from 'framer-motion'

export function AnimatedCard({ children }: { children: React.ReactNode }) {
  const shouldReduce = useReducedMotion()

  return (
    <motion.div
      whileHover={shouldReduce ? {} : { y: -2, scale: 1.01 }}
      transition={{ duration: 0.2 }}
    >
      {children}
    </motion.div>
  )
}
```

---

### 1.6 Glass Morphism, Gradients, Noise Textures

**Glassmorphism — correct implementation:**
```css
.glass {
  background:     oklch(1 0 0 / 0.08);
  backdrop-filter: blur(12px) saturate(180%);
  -webkit-backdrop-filter: blur(12px) saturate(180%);
  border:         1px solid oklch(1 0 0 / 0.12);
  border-radius:  var(--radius-lg);
}

/* Dark mode glass */
.dark .glass {
  background:     oklch(1 0 0 / 0.04);
  border:         1px solid oklch(1 0 0 / 0.06);
}
```

**Mesh gradient backgrounds (used by Linear, Vercel, Arc):**
```css
.gradient-mesh {
  background:
    radial-gradient(ellipse 80% 80% at 20%  20%, oklch(0.65 0.15 262 / 0.15) 0%, transparent 60%),
    radial-gradient(ellipse 80% 80% at 80%  80%, oklch(0.65 0.15 315 / 0.15) 0%, transparent 60%),
    radial-gradient(ellipse 60% 60% at 50%  50%, oklch(0.65 0.12 200 / 0.08) 0%, transparent 70%),
    var(--color-bg);
}
```

**Noise texture overlay (tactile, premium feel):**
```css
/* Generates SVG noise via data URI — no extra file needed */
.noise::after {
  content:  '';
  position: absolute;
  inset:    0;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='300' height='300'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='300' height='300' filter='url(%23noise)' opacity='0.04'/%3E%3C/svg%3E");
  pointer-events: none;
  border-radius: inherit;
  opacity: 0.6;
  mix-blend-mode: overlay;
}
```

**Tailwind utility classes for gradients:**
```tsx
// Hero gradient text — used by Vercel, Linear
<h1 className="bg-gradient-to-r from-foreground to-foreground/60 bg-clip-text text-transparent">
  Build faster
</h1>

// Gradient border card
<div className="relative rounded-xl p-px bg-gradient-to-b from-border to-transparent">
  <div className="rounded-xl bg-background p-6">
    Card content
  </div>
</div>
```

---

### 1.7 Component Polish — Hover States, Focus Rings, Transitions

**Every interactive element must have:**
1. A visible hover state (not just cursor change)
2. A visible focus ring (WCAG 2.2 AA: 2px, 3:1 contrast ratio)
3. A press/active state
4. A disabled state
5. Transition timing (150–200ms for micro-interactions)

**Focus ring pattern (matches Tailwind defaults):**
```css
/* Consistent focus ring — apply via Tailwind utility class */
.focus-ring {
  outline: none;
}
.focus-ring:focus-visible {
  outline:        2px solid var(--color-ring);
  outline-offset: 2px;
  border-radius:  var(--radius-sm);
}
```

**Button transition boilerplate:**
```tsx
<button className={cn(
  // Base
  "relative inline-flex items-center justify-center",
  "px-4 py-2 rounded-md text-sm font-medium",
  // Transition — all interactive states
  "transition-all duration-150 ease-out",
  // Default state
  "bg-primary text-primary-foreground",
  // Hover — subtle lift
  "hover:bg-primary/90 hover:-translate-y-px hover:shadow-md",
  // Active — press down
  "active:translate-y-0 active:shadow-none",
  // Focus
  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
  // Disabled
  "disabled:pointer-events-none disabled:opacity-50",
)}>
```

---

## 2. Frontend Architecture Patterns

### 2.1 Next.js App Router Best Practices (2026)

**RSC composition rule — minimize Client Components:**
```
Server Components: data fetching, layout, static content, auth checks
Client Components: interactivity, useState, useEffect, event handlers
```

**Granular Suspense boundaries — stream fast, stream smart:**
```tsx
// CORRECT: each async section gets its own boundary
export default function Dashboard() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <Suspense fallback={<MetricsSkeleton />}>
        <RevenueMetrics />          {/* streams independently */}
      </Suspense>
      <Suspense fallback={<TableSkeleton />}>
        <RecentOrders />            {/* streams independently */}
      </Suspense>
    </div>
  )
}

// WRONG: one boundary blocks everything
export default function Dashboard() {
  return (
    <Suspense fallback={<Spinner />}>
      <RevenueMetrics />
      <RecentOrders />
    </Suspense>
  )
}
```

**Image optimization (LCP impact):**
```tsx
import Image from 'next/image'

// Hero image — ALWAYS use priority
<Image
  src="/hero.webp"
  alt="Hero"
  width={1200}
  height={600}
  priority           // eliminates LCP lazy-load penalty
  quality={85}
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>

// Below-fold image — lazy load
<Image
  src="/feature.webp"
  alt="Feature"
  width={800}
  height={400}
  loading="lazy"     // default, explicit is fine
/>
```

**Font optimization:**
```tsx
// Variable font loads all weights in one file (~30kb vs 5×20kb)
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',      // shows system font until loaded
  preload: true,
})
```

**Metadata and SEO:**
```tsx
// app/layout.tsx — base metadata
export const metadata: Metadata = {
  metadataBase: new URL('https://yourapp.com'),
  title: { default: 'App Name', template: '%s | App Name' },
  description: 'One clear sentence about what this does.',
  openGraph: {
    type:      'website',
    siteName:  'App Name',
    images:    [{ url: '/og.png', width: 1200, height: 630 }],
  },
  twitter: { card: 'summary_large_image' },
  robots: { index: true, follow: true },
}

// app/[slug]/page.tsx — dynamic metadata
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await fetchPost(params.slug)
  return {
    title:       post.title,
    description: post.excerpt,
    openGraph: {
      title:  post.title,
      images: [{ url: post.ogImage ?? '/og.png' }],
    },
  }
}
```

---

### 2.2 shadcn/ui Advanced Patterns

**Custom registry item (your own design system on top of shadcn):**
```json
{
  "$schema": "https://ui.shadcn.com/schema/registry-item.json",
  "name": "my-design-system",
  "extends": "none",
  "type": "registry:base",
  "config": {
    "style":       "my-design-system",
    "iconLibrary": "lucide",
    "tailwind":    { "baseColor": "neutral" }
  },
  "dependencies": ["tailwind-merge", "clsx", "tw-animate-css", "lucide-react"],
  "cssVars": {
    "theme": {
      "font-sans":    "Geist, Inter, system-ui, sans-serif",
      "font-mono":    "Geist Mono, JetBrains Mono, monospace",
      "shadow-card":  "0 1px 3px 0 oklch(0 0 0 / 0.1), 0 1px 2px -1px oklch(0 0 0 / 0.06)"
    },
    "light": {
      "background": "oklch(1 0 0)",
      "foreground": "oklch(0.141 0.005 285.823)"
    },
    "dark": {
      "background": "oklch(0.141 0.005 285.823)",
      "foreground": "oklch(0.985 0 0)"
    }
  }
}
```

**Dark mode setup (next-themes):**
```tsx
// components/theme-provider.tsx
import { ThemeProvider as NextThemesProvider } from 'next-themes'

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  return (
    <NextThemesProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
    >
      {children}
    </NextThemesProvider>
  )
}

// app/layout.tsx
<html lang="en" suppressHydrationWarning>
  <body>
    <ThemeProvider>{children}</ThemeProvider>
  </body>
</html>
```

---

### 2.3 Tailwind v4 Key Features

**CSS-first config replaces tailwind.config.js:**
```css
@import "tailwindcss";

@theme {
  /* Colors automatically become utility classes: bg-brand-500, text-brand-500 */
  --color-brand-50:  oklch(0.97 0.013 254);
  --color-brand-500: oklch(0.55 0.245 262.9);
  --color-brand-600: oklch(0.46 0.245 262.9);

  /* Fonts become font-sans, font-mono */
  --font-sans: "Geist", "Inter", sans-serif;
  --font-mono: "Geist Mono", monospace;

  /* Radii become rounded-sm, rounded-lg */
  --radius-sm: 0.375rem;
  --radius-lg: 0.75rem;
}

/* Custom utilities — no plugin needed */
@utility text-balance {
  text-wrap: balance;
}

@utility animate-fade-in {
  animation: fade-in 0.3s ease-out both;
}

@keyframes fade-in {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
```

**Custom variant:**
```css
@variant hocus (&:hover, &:focus-visible);
/* Usage: hocus:bg-accent */
```

---

### 2.4 Performance Optimization

**Core Web Vitals targets:**
- LCP: ≤ 2.5s (largest contentful paint)
- INP: ≤ 200ms (interaction to next paint)
- CLS: ≤ 0.1 (cumulative layout shift)

**Critical optimizations:**
1. `priority` prop on hero images — eliminates LCP penalty
2. Variable fonts via `next/font` — one file, all weights, no layout shift
3. Granular Suspense — non-blocking render for slow data
4. `generateStaticParams` + ISR for data-driven pages
5. Route segment config: `export const dynamic = 'force-static'` where possible
6. `next/dynamic` for heavy client-side bundles (charts, editors)

---

## 3. Full-Stack Patterns

### 3.1 Authentication — Clerk

Clerk is the 2025/2026 recommendation for most generated apps. It handles OAuth, MFA, organization management, and has excellent Next.js App Router support.

**Middleware (protect routes):**
```typescript
// middleware.ts
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isProtectedRoute = createRouteMatcher([
  '/dashboard(.*)',
  '/settings(.*)',
  '/api/((?!webhooks).*)',  // protect API except webhooks
])

export default clerkMiddleware(async (auth, req) => {
  if (isProtectedRoute(req)) await auth.protect()
})

export const config = {
  matcher: [
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    '/(api|trpc)(.*)',
  ],
}
```

**Server Component auth check:**
```tsx
import { auth, currentUser } from '@clerk/nextjs/server'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const { isAuthenticated, userId } = await auth()
  if (!isAuthenticated) redirect('/sign-in')

  const user = await currentUser()
  return <div>Welcome, {user?.firstName}</div>
}
```

---

### 3.2 Database — Drizzle ORM + PostgreSQL

Drizzle is the recommended ORM: zero dependencies, type-safe, serverless-ready, ~7.4kb.

**Schema pattern:**
```typescript
// db/schema.ts
import { pgTable, serial, text, timestamp, integer, boolean } from 'drizzle-orm/pg-core'
import { defineRelations } from 'drizzle-orm'

export const users = pgTable('users', {
  id:        serial('id').primaryKey(),
  clerkId:   text('clerk_id').notNull().unique(),
  email:     text('email').notNull().unique(),
  name:      text('name'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
})

export const posts = pgTable('posts', {
  id:        serial('id').primaryKey(),
  title:     text('title').notNull(),
  content:   text('content').notNull(),
  published: boolean('published').notNull().default(false),
  authorId:  integer('author_id').notNull().references(() => users.id),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
})

export const relations = defineRelations({ users, posts }, (r) => ({
  users: { posts: r.many.posts() },
  posts: { author: r.one.users({ from: r.posts.authorId, to: r.users.id }) },
}))
```

**DB client (singleton pattern for serverless):**
```typescript
// db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'
import * as schema from './schema'
import { relations } from './schema'

const client = postgres(process.env.DATABASE_URL!, { prepare: false })
export const db = drizzle(client, { schema, relations })
```

---

### 3.3 API Pattern — Server Actions + tRPC

**When to use which:**
- **Server Actions:** mutations (form submissions, create/update/delete). Native Next.js, no extra setup.
- **tRPC:** complex queries with filters/pagination, real-time client refetching, shared type inference across monorepo.
- **REST API Routes:** webhooks (Stripe, Clerk), public APIs, third-party integrations.

**Server Action pattern (with Zod validation):**
```typescript
// app/actions/post.ts
'use server'
import { z } from 'zod'
import { auth } from '@clerk/nextjs/server'
import { db } from '@/db'
import { posts } from '@/db/schema'
import { revalidatePath } from 'next/cache'

const createPostSchema = z.object({
  title:   z.string().min(1).max(200),
  content: z.string().min(1),
})

export async function createPost(formData: FormData) {
  const { userId } = await auth()
  if (!userId) throw new Error('Unauthorized')

  const input = createPostSchema.parse({
    title:   formData.get('title'),
    content: formData.get('content'),
  })

  await db.insert(posts).values({ ...input, authorId: Number(userId) })
  revalidatePath('/dashboard/posts')
}
```

---

### 3.4 Email — Resend + React Email

```typescript
// emails/welcome.tsx
import { Html, Head, Body, Container, Text, Button, Hr } from '@react-email/components'

export function WelcomeEmail({ name, url }: { name: string; url: string }) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'Inter, system-ui, sans-serif', backgroundColor: '#f9fafb' }}>
        <Container style={{ maxWidth: '560px', margin: '40px auto', padding: '40px', backgroundColor: '#fff', borderRadius: '8px' }}>
          <Text style={{ fontSize: '24px', fontWeight: '600', color: '#111827' }}>
            Welcome, {name}
          </Text>
          <Text style={{ color: '#6b7280', lineHeight: '1.6' }}>
            Your account is ready. Click below to get started.
          </Text>
          <Button href={url} style={{ backgroundColor: '#2563eb', color: '#fff', padding: '12px 24px', borderRadius: '6px', textDecoration: 'none' }}>
            Get started
          </Button>
        </Container>
      </Body>
    </Html>
  )
}
```

```typescript
// app/api/send/route.ts
import { Resend } from 'resend'
import { WelcomeEmail } from '@/emails/welcome'

const resend = new Resend(process.env.RESEND_API_KEY)

export async function POST(req: Request) {
  const { email, name } = await req.json()

  const { data, error } = await resend.emails.send({
    from:    'App Name <noreply@yourapp.com>',
    to:      email,
    subject: 'Welcome to App Name',
    react:   WelcomeEmail({ name, url: 'https://yourapp.com/dashboard' }),
  })

  if (error) return Response.json({ error }, { status: 500 })
  return Response.json({ id: data?.id })
}
```

---

### 3.5 Payments — Stripe

**Checkout session (subscription):**
```typescript
// app/api/checkout/route.ts
import Stripe from 'stripe'
import { auth } from '@clerk/nextjs/server'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: Request) {
  const { userId } = await auth()
  if (!userId) return new Response('Unauthorized', { status: 401 })

  const { priceId } = await req.json()

  const session = await stripe.checkout.sessions.create({
    mode:        'subscription',
    line_items:  [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard?success=true`,
    cancel_url:  `${process.env.NEXT_PUBLIC_APP_URL}/pricing`,
    metadata:    { userId },
  })

  return Response.json({ url: session.url })
}
```

**Webhook handler (always verify signature):**
```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe'
import { db } from '@/db'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: Request) {
  const body      = await req.text()
  const signature = req.headers.get('stripe-signature')!

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch {
    return new Response('Invalid signature', { status: 400 })
  }

  switch (event.type) {
    case 'checkout.session.completed': {
      const session    = event.data.object as Stripe.Checkout.Session
      const userId     = session.metadata?.userId
      const subId      = session.subscription as string
      // Update DB: set user subscription status
      break
    }
    case 'customer.subscription.deleted': {
      // Handle cancellation
      break
    }
  }

  return new Response(null, { status: 200 })
}
```

---

## 4. Testing Patterns

### 4.1 E2E Testing — Playwright

**Test structure (Page Object Model):**
```typescript
// tests/pages/auth.page.ts
import { Page } from '@playwright/test'

export class AuthPage {
  constructor(private page: Page) {}

  async signIn(email: string, password: string) {
    await this.page.goto('/sign-in')
    await this.page.fill('[name="email"]', email)
    await this.page.fill('[name="password"]', password)
    await this.page.click('[type="submit"]')
    await this.page.waitForURL('/dashboard')
  }
}

// tests/auth.spec.ts
import { test, expect } from '@playwright/test'
import { AuthPage } from './pages/auth.page'

test('user can sign in and reach dashboard', async ({ page }) => {
  const auth = new AuthPage(page)
  await auth.signIn('test@example.com', 'password123')
  await expect(page).toHaveURL('/dashboard')
  await expect(page.getByRole('heading', { name: /dashboard/i })).toBeVisible()
})
```

**playwright.config.ts:**
```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir:              './tests/e2e',
  fullyParallel:        true,
  forbidOnly:           !!process.env.CI,
  retries:              process.env.CI ? 2 : 0,
  workers:              process.env.CI ? 1 : undefined,
  reporter:             'html',
  use: {
    baseURL:       'http://localhost:3000',
    trace:         'on-first-retry',
    screenshot:    'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile',   use: { ...devices['iPhone 14'] } },
  ],
  webServer: {
    command: 'pnpm dev',
    url:     'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

---

### 4.2 Accessibility Testing

**Automated a11y scan with axe-core:**
```typescript
// tests/accessibility.spec.ts
import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

const routes = ['/', '/about', '/pricing', '/dashboard']

for (const route of routes) {
  test(`${route} has no WCAG 2.2 AA violations`, async ({ page }) => {
    await page.goto(route)

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze()

    // Fingerprint violations (more stable than full snapshot)
    const fingerprints = results.violations.map(v => ({
      rule:    v.id,
      targets: v.nodes.map(n => n.target),
    }))

    expect(results.violations).toHaveLength(0)
  })
}
```

**WCAG 2.2 AA checklist (automated coverage):**
- Focus visible: 2px outline, 3:1 contrast ratio on indicator
- Focus not obscured: sticky headers must not cover focused elements
- Touch target size: minimum 24x24px (preferably 44x44px)
- Color contrast: 4.5:1 for normal text, 3:1 for large text
- Keyboard navigation: all interactive elements reachable via Tab
- Screen reader: all images have meaningful alt text, buttons have labels

---

### 4.3 Visual Regression Testing

```typescript
// tests/visual.spec.ts
import { test, expect } from '@playwright/test'

test('homepage visual snapshot', async ({ page }) => {
  await page.goto('/')
  await page.waitForLoadState('networkidle')

  // Mask dynamic content (timestamps, user-specific data)
  await expect(page).toHaveScreenshot('homepage.png', {
    mask:              [page.locator('[data-testid="timestamp"]')],
    maxDiffPixels:     100,   // allow small anti-aliasing diffs
    threshold:         0.2,   // 20% pixel threshold
    animations:        'disabled',
  })
})
```

---

## Confidence: High

Context7 docs used, all APIs verified against current library versions. Web search corroborated current best practices as of Q1 2026.

## Sources

- [Next.js App Router docs](/vercel/next.js) — Context7 library ID
- [shadcn/ui registry docs](/shadcn-ui/ui) — Context7 library ID
- [Clerk Next.js docs](/clerk/clerk-docs) — Context7 library ID
- [Drizzle ORM docs](/drizzle-team/drizzle-orm-docs) — Context7 library ID
- [Playwright docs](/microsoft/playwright) — Context7 library ID
- [Stripe docs](/websites/stripe) — Context7 library ID
- [Framer Motion](/grx7/framer-motion) — Context7 library ID
- [Tailwind CSS v4 announcement](https://tailwindcss.com/blog/tailwindcss-v4)
- [Tailwind v4 theme variables](https://tailwindcss.com/docs/theme)
- [Vercel Geist Font](https://vercel.com/font)
- [WCAG 2.2 W3C spec](https://www.w3.org/TR/WCAG22/)
- [tRPC + Next.js App Router](https://trpc.io/blog/trpc-actions)
- [Resend + Next.js](https://resend.com/docs/send-with-nextjs)
- [Elevation design patterns](https://designsystems.surf/articles/depth-with-purpose-how-elevation-adds-realism-and-hierarchy)
