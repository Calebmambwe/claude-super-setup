# Design System Bible
## The Definitive Guide for Generating Premium-Looking UIs

This document is the reference that gets loaded into every AI-generated app. It contains the exact values, exact patterns, and exact decisions that produce apps that look like they were built by a senior designer — not an LLM.

If a generated app uses every rule in this document, it will not look "AI-generated."

---

## 0. The Five Laws

Before any design decision, internalize these:

1. **Restraint over abundance.** One primary color. Two font weights for 90% of text. Less is always more premium than more.
2. **Hierarchy creates trust.** Every screen has exactly one visual focus point. If everything is bold, nothing is.
3. **Consistency signals craft.** Use your tokens. Never hardcode a hex value or a pixel value that is not on the grid.
4. **Motion earns attention.** Animate only state changes. Never animate for decoration. Always respect `prefers-reduced-motion`.
5. **Details are the product.** Focus rings, disabled states, empty states, loading states, error states — these are not afterthoughts. They are what separates "good" from "premium."

---

## 1. The Token Stack

All design values live in CSS custom properties. Three tiers, always.

### Tier 1 — Primitive (raw values, never used directly in components)

```css
:root {
  /* === PRIMITIVES: Color === */
  /* Blue */
  --p-blue-50:  oklch(0.970 0.013 254.0);
  --p-blue-100: oklch(0.940 0.026 254.0);
  --p-blue-200: oklch(0.890 0.053 254.0);
  --p-blue-300: oklch(0.810 0.097 254.0);
  --p-blue-400: oklch(0.707 0.165 254.6);
  --p-blue-500: oklch(0.546 0.245 262.9);
  --p-blue-600: oklch(0.460 0.245 262.9);
  --p-blue-700: oklch(0.390 0.200 262.9);
  --p-blue-800: oklch(0.310 0.150 262.9);
  --p-blue-900: oklch(0.230 0.100 262.9);
  --p-blue-950: oklch(0.150 0.060 262.9);

  /* Gray (warm neutral — matches Geist/Vercel) */
  --p-gray-0:   oklch(1.000 0.000   0.0);
  --p-gray-50:  oklch(0.985 0.000   0.0);
  --p-gray-100: oklch(0.967 0.001 286.4);
  --p-gray-200: oklch(0.925 0.003 286.3);
  --p-gray-300: oklch(0.870 0.006 286.3);
  --p-gray-400: oklch(0.707 0.015 286.1);
  --p-gray-500: oklch(0.552 0.016 285.9);
  --p-gray-600: oklch(0.450 0.014 285.9);
  --p-gray-700: oklch(0.371 0.012 285.8);
  --p-gray-800: oklch(0.274 0.006 286.0);
  --p-gray-900: oklch(0.210 0.006 285.9);
  --p-gray-950: oklch(0.141 0.005 285.8);
  --p-gray-1000:oklch(0.000 0.000   0.0);

  /* Red */
  --p-red-500:  oklch(0.628 0.258  28.0);
  --p-red-600:  oklch(0.556 0.230  28.0);

  /* Green */
  --p-green-500:oklch(0.643 0.174 142.5);
  --p-green-600:oklch(0.560 0.150 142.5);

  /* Yellow */
  --p-yellow-500:oklch(0.795 0.184  87.0);
  --p-yellow-600:oklch(0.704 0.163  87.0);

  /* === PRIMITIVES: Spacing (4px base grid) === */
  --p-space-1:  0.25rem;   /* 4px  */
  --p-space-2:  0.5rem;    /* 8px  */
  --p-space-3:  0.75rem;   /* 12px */
  --p-space-4:  1rem;      /* 16px */
  --p-space-5:  1.25rem;   /* 20px */
  --p-space-6:  1.5rem;    /* 24px */
  --p-space-8:  2rem;      /* 32px */
  --p-space-10: 2.5rem;    /* 40px */
  --p-space-12: 3rem;      /* 48px */
  --p-space-16: 4rem;      /* 64px */
  --p-space-20: 5rem;      /* 80px */
  --p-space-24: 6rem;      /* 96px */

  /* === PRIMITIVES: Radius === */
  --p-radius-none: 0;
  --p-radius-sm:   0.25rem;   /* 4px  */
  --p-radius-md:   0.375rem;  /* 6px  */
  --p-radius-lg:   0.5rem;    /* 8px  */
  --p-radius-xl:   0.75rem;   /* 12px */
  --p-radius-2xl:  1rem;      /* 16px */
  --p-radius-3xl:  1.5rem;    /* 24px */
  --p-radius-full: 9999px;

  /* === PRIMITIVES: Typography === */
  --p-text-xs:   0.75rem;   /* 12px */
  --p-text-sm:   0.875rem;  /* 14px */
  --p-text-base: 1rem;      /* 16px */
  --p-text-lg:   1.125rem;  /* 18px */
  --p-text-xl:   1.25rem;   /* 20px */
  --p-text-2xl:  1.5rem;    /* 24px */
  --p-text-3xl:  1.875rem;  /* 30px */
  --p-text-4xl:  2.25rem;   /* 36px */
  --p-text-5xl:  3rem;      /* 48px */
  --p-text-6xl:  3.75rem;   /* 60px */
  --p-text-7xl:  4.5rem;    /* 72px */
}
```

### Tier 2 — Semantic (meaning-bearing, used in components)

```css
:root {
  /* === SEMANTIC: Color — Light mode === */

  /* Surface */
  --color-bg:            var(--p-gray-50);
  --color-bg-subtle:     var(--p-gray-100);
  --color-bg-muted:      var(--p-gray-200);
  --color-surface:       var(--p-gray-0);
  --color-surface-raised:var(--p-gray-0);
  --color-overlay:       var(--p-gray-0);

  /* Text */
  --color-fg:            var(--p-gray-950);
  --color-fg-muted:      var(--p-gray-500);
  --color-fg-subtle:     var(--p-gray-400);
  --color-fg-disabled:   var(--p-gray-300);
  --color-fg-on-accent:  var(--p-gray-0);

  /* Border */
  --color-border:        var(--p-gray-200);
  --color-border-strong: var(--p-gray-300);
  --color-border-focus:  var(--p-blue-500);

  /* Brand/Primary */
  --color-primary:       var(--p-blue-500);
  --color-primary-hover: var(--p-blue-600);
  --color-primary-active:var(--p-blue-700);
  --color-primary-subtle:var(--p-blue-50);
  --color-primary-fg:    var(--p-gray-0);

  /* Status */
  --color-success:       var(--p-green-500);
  --color-success-subtle:oklch(0.97 0.05 142.5);
  --color-warning:       var(--p-yellow-500);
  --color-warning-subtle:oklch(0.98 0.05 87.0);
  --color-danger:        var(--p-red-500);
  --color-danger-subtle: oklch(0.98 0.05 28.0);
  --color-info:          var(--p-blue-500);
  --color-info-subtle:   var(--p-blue-50);

  /* Ring (focus indicator) */
  --color-ring: var(--p-blue-500);

  /* === SEMANTIC: Shadow — Light mode === */
  --shadow-xs:
    0 1px 2px 0 oklch(0 0 0 / 0.04);
  --shadow-sm:
    0 1px 2px 0 oklch(0 0 0 / 0.05),
    0 1px 3px 0 oklch(0 0 0 / 0.08);
  --shadow-md:
    0 1px 3px 0   oklch(0 0 0 / 0.06),
    0 4px 6px -1px oklch(0 0 0 / 0.08);
  --shadow-lg:
    0 1px 3px 0    oklch(0 0 0 / 0.04),
    0 10px 15px -3px oklch(0 0 0 / 0.08),
    0 4px 6px -4px   oklch(0 0 0 / 0.04);
  --shadow-xl:
    0 1px 3px 0    oklch(0 0 0 / 0.04),
    0 20px 25px -5px oklch(0 0 0 / 0.10),
    0 8px 10px -6px  oklch(0 0 0 / 0.04);
  --shadow-2xl:
    0 25px 50px -12px oklch(0 0 0 / 0.20);
  --shadow-inset:
    inset 0 2px 4px 0 oklch(0 0 0 / 0.05);

  /* === SEMANTIC: Typography === */
  --font-sans:    "Geist", "Inter", -apple-system, system-ui, sans-serif;
  --font-mono:    "Geist Mono", "JetBrains Mono", "Fira Code", monospace;
  --font-display: "Cal Sans", "Geist", sans-serif;

  --leading-tight:  1.15;
  --leading-snug:   1.375;
  --leading-normal: 1.5;
  --leading-relaxed:1.625;
  --leading-loose:  1.75;

  --tracking-tighter: -0.05em;
  --tracking-tight:   -0.03em;
  --tracking-normal:   0em;
  --tracking-wide:     0.025em;
  --tracking-wider:    0.05em;
  --tracking-widest:   0.1em;

  /* === SEMANTIC: Radius — choose ONE radius personality per app === */
  --radius-component: var(--p-radius-lg);   /* buttons, inputs */
  --radius-card:      var(--p-radius-xl);   /* cards, panels */
  --radius-dialog:    var(--p-radius-2xl);  /* modals, sheets */
  --radius-badge:     var(--p-radius-full); /* pills, tags */
  --radius-image:     var(--p-radius-xl);   /* thumbnails */
}

/* === SEMANTIC: Dark mode override === */
.dark {
  --color-bg:            var(--p-gray-950);
  --color-bg-subtle:     var(--p-gray-900);
  --color-bg-muted:      var(--p-gray-800);
  --color-surface:       oklch(0.165 0.005 285.8);
  --color-surface-raised:oklch(0.192 0.005 285.8);
  --color-overlay:       oklch(0.210 0.006 285.9);

  --color-fg:            var(--p-gray-50);
  --color-fg-muted:      var(--p-gray-400);
  --color-fg-subtle:     var(--p-gray-500);
  --color-fg-disabled:   var(--p-gray-700);
  --color-fg-on-accent:  var(--p-gray-0);

  --color-border:        var(--p-gray-800);
  --color-border-strong: var(--p-gray-700);

  --color-primary:       var(--p-blue-400);
  --color-primary-hover: var(--p-blue-300);
  --color-primary-active:var(--p-blue-200);
  --color-primary-subtle:oklch(0.20 0.05 262.9);

  /* Dark mode shadows are heavier (surface is dark) */
  --shadow-sm:
    0 1px 2px 0 oklch(0 0 0 / 0.25),
    0 1px 3px 0 oklch(0 0 0 / 0.35);
  --shadow-md:
    0 1px 3px 0   oklch(0 0 0 / 0.30),
    0 4px 6px -1px oklch(0 0 0 / 0.40);
  --shadow-lg:
    0 10px 15px -3px oklch(0 0 0 / 0.45),
    0 4px 6px -4px   oklch(0 0 0 / 0.30);
}
```

---

## 2. Typography Rules

### The Heading Ladder

Every generated page uses this exact ladder. Never skip levels.

| Level        | Size    | Weight | Tracking      | Line height | Use case                    |
|-------------|---------|--------|---------------|-------------|------------------------------|
| Display     | 60–72px | 700    | -0.04em       | 1.1         | Hero headlines, landing pages |
| H1          | 36–48px | 700    | -0.03em       | 1.1         | Page title                   |
| H2          | 24–30px | 600    | -0.02em       | 1.2         | Section heading              |
| H3          | 20px    | 600    | -0.01em       | 1.25        | Card heading, sub-section    |
| H4          | 16px    | 600    | 0             | 1.3         | UI element heading           |
| Body large  | 18px    | 400    | 0             | 1.65        | Lead paragraph               |
| Body        | 16px    | 400    | 0             | 1.6         | Main content                 |
| Body small  | 14px    | 400    | 0             | 1.5         | Secondary content            |
| Caption     | 12px    | 400    | 0.01em        | 1.4         | Labels, metadata             |
| Overline    | 11–12px | 500    | 0.08em        | 1.0         | Section labels (UPPERCASE)   |

### Tailwind v4 Typography Utilities

```css
@utility heading-display {
  font-size:   var(--p-text-6xl);
  font-weight: 700;
  line-height: var(--leading-tight);
  letter-spacing: -0.04em;
  text-wrap:   balance;
}
@utility heading-1 {
  font-size:   var(--p-text-4xl);
  font-weight: 700;
  line-height: var(--leading-tight);
  letter-spacing: -0.03em;
  text-wrap:   balance;
}
@utility heading-2 {
  font-size:   var(--p-text-3xl);
  font-weight: 600;
  line-height: 1.2;
  letter-spacing: -0.02em;
}
@utility heading-3 {
  font-size:   var(--p-text-xl);
  font-weight: 600;
  line-height: 1.25;
  letter-spacing: -0.01em;
}
@utility body-lg {
  font-size:   var(--p-text-lg);
  line-height: var(--leading-relaxed);
}
@utility body {
  font-size:   var(--p-text-base);
  line-height: var(--leading-normal);
}
@utility label-sm {
  font-size:      var(--p-text-xs);
  font-weight:    500;
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
}
```

### Typography Anti-patterns — NEVER DO

- `font-size: 13px` — too small for body, use 14px minimum
- `font-weight: 800` or `font-weight: 900` for body — screams amateur
- `letter-spacing: -0.1em` — too tight, use -0.04em max
- More than 2 different font families on one page
- More than 4 font sizes in one UI section
- `text-align: justify` — creates rivers of whitespace
- `line-height: 1.0` on body text — unreadable

---

## 3. Color Rules

### The 60-30-10 Rule

- **60%:** Background and surface colors (bg, surface, bg-subtle)
- **30%:** Neutral foreground, borders, muted text
- **10%:** Accent/brand color (primary, links, CTAs)

If more than 10% of your UI pixels are the brand color, it looks like a toy.

### Semantic Usage — Always

```
BACKGROUND:     bg-background / var(--color-bg)
CARDS/PANELS:   bg-card / var(--color-surface)
BODY TEXT:      text-foreground / var(--color-fg)
SECONDARY TEXT: text-muted-foreground / var(--color-fg-muted)
BORDERS:        border-border / var(--color-border)
PRIMARY CTA:    bg-primary / var(--color-primary)
LINKS:          text-primary / var(--color-primary)
DANGER:         text-destructive / var(--color-danger)
SUCCESS:        text-green-600 dark:text-green-400
```

### Color Anti-patterns

- Using raw hex values anywhere in JSX/CSS — use tokens only
- More than one primary brand color
- Light-mode-only colors (no `.dark` override)
- Using opacity for text contrast — use dedicated muted tokens
- Pure black (`#000000`) — use `var(--p-gray-950)` or `oklch(0.141 0.005 285.8)`
- Pure white (`#ffffff`) — use `var(--p-gray-0)` or `oklch(1 0 0)`

---

## 4. Spacing Rules

### The Non-Negotiables

1. Every spacing value must be a multiple of 4px
2. Padding inside components uses `space-4` (16px) as the standard
3. Gap between list items: `space-2` (8px) to `space-3` (12px)
4. Gap between sections: `space-16` (64px) minimum on desktop
5. Max content width: 1280px for apps, 768px for content/text

### Component-Level Spacing

```
Input padding:       py-2 px-3   (8px / 12px)
Button padding sm:   py-1.5 px-3 (6px / 12px)
Button padding md:   py-2 px-4   (8px / 16px)
Button padding lg:   py-2.5 px-5 (10px / 20px)
Card padding:        p-6         (24px)
Card padding lg:     p-8         (32px)
Dialog padding:      p-6         (24px)
Section padding:     py-16 px-4  (64px / 16px)
Section padding lg:  py-24 px-8  (96px / 32px)
List item gap:       space-y-2   (8px)
Form field gap:      space-y-4   (16px)
```

---

## 5. Component Patterns

### The Button Component (canonical)

Every generated button must follow this pattern:

```tsx
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  // Base styles applied to all variants
  [
    'relative inline-flex items-center justify-center gap-2',
    'whitespace-nowrap rounded-[var(--radius-component)]',
    'text-sm font-medium',
    'transition-all duration-150 ease-out',
    'select-none',
    // Focus ring — WCAG 2.2 AA compliant
    'focus-visible:outline-none focus-visible:ring-2',
    'focus-visible:ring-ring focus-visible:ring-offset-2',
    'focus-visible:ring-offset-background',
    // Disabled
    'disabled:pointer-events-none disabled:opacity-40',
    // Loading state
    '[&[aria-busy=true]]:cursor-wait',
  ],
  {
    variants: {
      variant: {
        default: [
          'bg-primary text-primary-foreground',
          'hover:bg-primary/90 hover:-translate-y-px hover:shadow-md',
          'active:translate-y-0 active:shadow-none',
          'shadow-sm',
        ],
        secondary: [
          'bg-secondary text-secondary-foreground border border-border',
          'hover:bg-secondary/80 hover:-translate-y-px hover:shadow-sm',
          'active:translate-y-0',
        ],
        ghost: [
          'text-foreground',
          'hover:bg-accent hover:text-accent-foreground',
          'active:bg-accent/80',
        ],
        destructive: [
          'bg-destructive text-destructive-foreground',
          'hover:bg-destructive/90 hover:shadow-sm',
        ],
        outline: [
          'border border-border bg-background text-foreground',
          'hover:bg-accent hover:border-border-strong',
        ],
        link: [
          'text-primary underline-offset-4',
          'hover:underline',
          'p-0 h-auto',
        ],
      },
      size: {
        sm:      'h-8  px-3 text-xs',
        default: 'h-9  px-4 text-sm',
        lg:      'h-10 px-6 text-sm',
        xl:      'h-11 px-8 text-base',
        icon:    'h-9  w-9 p-0',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
)

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  loading?: boolean
}

export function Button({ className, variant, size, loading, children, ...props }: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      aria-busy={loading}
      disabled={props.disabled || loading}
      {...props}
    >
      {loading && <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />}
      {children}
    </button>
  )
}
```

### The Card Component (canonical)

```tsx
import { cn } from '@/lib/utils'

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  hover?: boolean
}

export function Card({ className, hover = false, ...props }: CardProps) {
  return (
    <div
      className={cn(
        // Structure
        'rounded-[var(--radius-card)] border border-border',
        'bg-card text-card-foreground',
        // Shadow
        'shadow-sm',
        // Hover upgrade — use only when cards are clickable
        hover && [
          'transition-all duration-200 ease-out cursor-pointer',
          'hover:-translate-y-0.5 hover:shadow-md hover:border-border-strong',
        ],
        className,
      )}
      {...props}
    />
  )
}

export function CardHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('flex flex-col space-y-1.5 p-6', className)} {...props} />
}

export function CardTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      className={cn('text-lg font-semibold leading-tight tracking-tight', className)}
      {...props}
    />
  )
}

export function CardDescription({ className, ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return (
    <p className={cn('text-sm text-muted-foreground leading-relaxed', className)} {...props} />
  )
}

export function CardContent({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('p-6 pt-0', className)} {...props} />
}
```

### Input Component (canonical)

```tsx
import { cn } from '@/lib/utils'

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: boolean
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, error, type, ...props }, ref) => {
    return (
      <input
        type={type}
        ref={ref}
        className={cn(
          // Layout
          'flex h-9 w-full px-3 py-1',
          // Typography
          'text-sm bg-transparent',
          // Border + radius
          'rounded-[var(--radius-component)] border',
          'border-border',
          // Placeholder
          'placeholder:text-muted-foreground',
          // Focus ring
          'focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring',
          // File input reset
          'file:border-0 file:bg-transparent file:text-sm file:font-medium',
          // Disabled
          'disabled:cursor-not-allowed disabled:opacity-50',
          // Error
          error && 'border-destructive focus-visible:ring-destructive',
          className,
        )}
        {...props}
      />
    )
  }
)
Input.displayName = 'Input'
```

---

## 6. Layout Patterns

### Page Layout (full-stack app)

```tsx
// Standard authenticated app layout
export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <div className="pl-[var(--sidebar-width,240px)]">
        <Header />
        <main className="p-6 max-w-[1280px]">
          {children}
        </main>
      </div>
    </div>
  )
}

// Marketing / landing page layout
export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <nav className="sticky top-0 z-50 border-b border-border bg-background/80 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-14 flex items-center justify-between">
          {/* nav content */}
        </div>
      </nav>
      {children}
    </div>
  )
}
```

### Section Layout (marketing pages)

```tsx
// Standard section container — use this for every section
export function Section({
  children,
  className,
  size = 'default',
}: {
  children: React.ReactNode
  className?: string
  size?: 'sm' | 'default' | 'lg'
}) {
  const padding = {
    sm:      'py-12 md:py-16',
    default: 'py-16 md:py-24',
    lg:      'py-24 md:py-32',
  }

  return (
    <section className={cn(padding[size], className)}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {children}
      </div>
    </section>
  )
}
```

### Grid Patterns

```tsx
// Feature grid — 3 columns on desktop
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">

// Two column (content + sidebar)
<div className="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-8">

// Dashboard grid — auto-fill cards
<div className="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-4">

// Hero — centered, constrained
<div className="max-w-3xl mx-auto text-center">
```

---

## 7. Motion System

### Timing Functions (cubic-bezier presets)

```css
:root {
  /* Snappy — UI micro-interactions (hover, focus) */
  --ease-snap:     cubic-bezier(0.2, 0, 0, 1);

  /* Spring — entry animations, layout shifts */
  --ease-spring:   cubic-bezier(0.22, 1, 0.36, 1);

  /* Smooth — overlays, modals */
  --ease-smooth:   cubic-bezier(0.4, 0, 0.2, 1);

  /* Exit — element leaving the screen */
  --ease-out:      cubic-bezier(0, 0, 0.2, 1);
}
```

### Duration Scale

```
50ms  — color/opacity micro-interactions (checkboxes, toggles)
100ms — button hover states, icon transitions
150ms — focus rings, border color changes
200ms — card hovers, dropdown appear
300ms — page element enter animations
400ms — modal/dialog appear
500ms — page transitions
```

### Animation Variants Library

```tsx
// lib/motion.ts — import from here in all components
export const spring = { type: 'spring', damping: 30, stiffness: 400 }
export const springFast = { type: 'spring', damping: 40, stiffness: 500 }

export const fadeIn = {
  initial:  { opacity: 0 },
  animate:  { opacity: 1, transition: { duration: 0.25, ease: 'easeOut' } },
  exit:     { opacity: 0, transition: { duration: 0.15, ease: 'easeIn' } },
}

export const fadeUp = {
  initial:  { opacity: 0, y: 16 },
  animate:  { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.22, 1, 0.36, 1] } },
  exit:     { opacity: 0, y: 8,  transition: { duration: 0.2, ease: 'easeIn' } },
}

export const scaleIn = {
  initial:  { opacity: 0, scale: 0.95 },
  animate:  { opacity: 1, scale: 1, transition: { duration: 0.2, ease: [0.22, 1, 0.36, 1] } },
  exit:     { opacity: 0, scale: 0.95, transition: { duration: 0.15, ease: 'easeIn' } },
}

export const slideInFromRight = {
  initial:  { opacity: 0, x: 24 },
  animate:  { opacity: 1, x: 0, transition: { duration: 0.3, ease: [0.22, 1, 0.36, 1] } },
  exit:     { opacity: 0, x: 24, transition: { duration: 0.2, ease: 'easeIn' } },
}

export const stagger = {
  animate: { transition: { staggerChildren: 0.06 } },
}
```

### The Motion Rule

Every animation must be wrapped in a reduced-motion check:
```tsx
"use client"
import { motion, useReducedMotion } from 'framer-motion'
import { fadeUp } from '@/lib/motion'

export function AnimatedCard({ children }: { children: React.ReactNode }) {
  const reduce = useReducedMotion()
  return (
    <motion.div
      variants={reduce ? {} : fadeUp}
      initial="initial"
      animate="animate"
    >
      {children}
    </motion.div>
  )
}
```

---

## 8. Elevation and Depth

### Elevation Map

```
Level 0: Page background        — no shadow, bg-background
Level 1: Cards, panels          — shadow-sm, bg-card, border
Level 2: Raised cards (hover)   — shadow-md
Level 3: Sticky bars, popovers  — shadow-lg, backdrop blur
Level 4: Dropdowns, tooltips    — shadow-xl, z-50
Level 5: Modals, dialogs        — shadow-2xl, z-[100], backdrop overlay
Level 6: Toasts, notifications  — shadow-2xl, z-[200], corner of screen
```

### Glass Nav (Level 3 sticky bar pattern)

```tsx
<nav className={cn(
  'sticky top-0 z-50 w-full',
  // Glass effect
  'bg-background/75 backdrop-blur-md backdrop-saturate-150',
  // Border creates depth boundary
  'border-b border-border/60',
  // Smooth transition when scrolling
  'transition-all duration-200',
)}>
```

---

## 9. Empty States, Loading States, Error States

These are where most AI-generated apps fail. Every data surface needs all three.

### Loading State (Skeleton)

```tsx
// components/ui/skeleton.tsx
export function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn('animate-pulse rounded-md bg-muted', className)}
      {...props}
    />
  )
}

// Usage in a card skeleton
export function CardSkeleton() {
  return (
    <div className="rounded-[var(--radius-card)] border border-border p-6 space-y-4">
      <Skeleton className="h-5 w-1/2" />
      <Skeleton className="h-4 w-full" />
      <Skeleton className="h-4 w-3/4" />
      <Skeleton className="h-9 w-28 mt-2" />
    </div>
  )
}
```

### Empty State

```tsx
export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
}: {
  icon?: React.ComponentType<{ className?: string }>
  title: string
  description?: string
  action?: React.ReactNode
}) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
      {Icon && (
        <div className="mb-4 rounded-full bg-muted p-3">
          <Icon className="h-6 w-6 text-muted-foreground" />
        </div>
      )}
      <h3 className="text-base font-semibold text-foreground">{title}</h3>
      {description && (
        <p className="mt-1 text-sm text-muted-foreground max-w-xs">{description}</p>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}
```

### Error State

```tsx
export function ErrorState({
  message = 'Something went wrong',
  onRetry,
}: {
  message?: string
  onRetry?: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
      <div className="mb-4 rounded-full bg-destructive/10 p-3">
        <AlertCircle className="h-6 w-6 text-destructive" />
      </div>
      <h3 className="text-base font-semibold text-foreground">Error</h3>
      <p className="mt-1 text-sm text-muted-foreground max-w-xs">{message}</p>
      {onRetry && (
        <Button variant="outline" size="sm" onClick={onRetry} className="mt-4">
          Try again
        </Button>
      )}
    </div>
  )
}
```

---

## 10. Accessibility Checklist (WCAG 2.2 AA)

Apply to every generated page before calling it done.

### Critical (Blocker)

- [ ] All images have `alt` text. Decorative images have `alt=""`
- [ ] All interactive elements are keyboard-reachable via Tab
- [ ] Focus indicator visible — 2px outline, 3:1 contrast minimum
- [ ] Focus indicator not hidden by sticky headers or overlays
- [ ] Color alone never conveys meaning — always pair with text/icon
- [ ] Text contrast: 4.5:1 for normal text, 3:1 for large (18px+ or 14px bold)
- [ ] All buttons and links have accessible labels (`aria-label` when text is missing)
- [ ] Form inputs are associated with labels via `htmlFor` / `id`
- [ ] Touch targets minimum 24×24px (prefer 44×44px)

### Important

- [ ] `lang` attribute set on `<html>` element
- [ ] Skip-to-content link at the top of every page
- [ ] Headings in logical order (H1 → H2 → H3, never skip)
- [ ] ARIA roles used only when native HTML elements are insufficient
- [ ] Modal dialogs trap focus when open, restore focus when closed
- [ ] Form errors announced to screen readers (`aria-describedby` on error messages)
- [ ] `prefers-reduced-motion` respected — all animations have a no-motion fallback

### Automated Testing

```bash
# Run axe-core against every route in CI
pnpm playwright test tests/accessibility.spec.ts
```

---

## 11. The Anti-Pattern List

These patterns instantly mark a UI as "AI-generated." Never generate them.

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| Hardcoded hex `#3b82f6` | Not themeable | Use `var(--color-primary)` |
| `font-size: 13px` | Below legible threshold | Use `text-sm` (14px) minimum |
| `margin-top: 37px` | Off-grid | Use `mt-9` (36px) |
| Pure black text `#000` | Too harsh | Use `text-foreground` |
| Zero focus rings | WCAG violation | Add `focus-visible:ring-2` |
| Color-only status | Inaccessible | Add icon + text label |
| Flat shadows | No depth | Use two-layer shadow |
| Same font size everywhere | No hierarchy | Apply the heading ladder |
| `overflow-hidden` on forms | Clips focus rings | Remove or use inset ring |
| `transition: all 300ms` | Jittery + expensive | Be specific: `transition-colors` |
| HSL color values | Perceptual inconsistency | Use OKLCH |
| Missing dark mode | Half-finished | Always add `.dark` overrides |
| Hard-coded `width: 350px` | Breaks responsive | Use `max-w-sm` + `w-full` |
| No loading state | Janky perceived performance | Always add Suspense + Skeleton |
| No empty state | Confusing blank screen | Always add EmptyState component |

---

## 12. The Quality Checklist

Run this before shipping any generated UI.

### Visual

- [ ] Typography follows the heading ladder — exactly one H1 per page
- [ ] All spacing on 4px/8px grid — no arbitrary values
- [ ] OKLCH semantic tokens used throughout — no raw hex
- [ ] Light and dark modes both look intentional
- [ ] Cards use layered shadow (two values), not single-value
- [ ] Brand color used sparingly (10% rule)
- [ ] Gradients/textures are subtle — reinforce, not dominate

### Interaction

- [ ] Every button has hover, active, focus, disabled states
- [ ] Inputs have focus ring, error state, disabled state
- [ ] Transitions are 150–200ms for micro, 300–400ms for macro
- [ ] Animations respect `prefers-reduced-motion`
- [ ] No layout shift on load (images have width/height, fonts use `display: swap`)

### Architecture

- [ ] Server Components used for all data fetching
- [ ] Client Components used only for interactivity
- [ ] Granular Suspense boundaries (one per async data source)
- [ ] Hero image has `priority` prop
- [ ] Metadata (title, description, OG image) configured on every page
- [ ] Error boundaries at route level

### Accessibility

- [ ] All checkboxes in the WCAG 2.2 AA section above pass
- [ ] Axe-core automated scan returns zero violations

---

## Sources

- [Tailwind CSS v4 docs](https://tailwindcss.com/docs/theme) — @theme, OKLCH colors
- [shadcn/ui registry](https://ui.shadcn.com/docs/registry) — theme structure, CSS vars
- [Vercel Geist font](https://vercel.com/font) — typography system
- [Vercel Geist design system (Figma)](https://www.figma.com/community/file/1330020847221146106/geist-design-system-vercel)
- [WCAG 2.2 W3C spec](https://www.w3.org/TR/WCAG22/)
- [WCAG 2.2 AA checklist](https://www.levelaccess.com/blog/wcag-2-2-aa-summary-and-checklist-for-website-owners/)
- [Elevation design patterns](https://designsystems.surf/articles/depth-with-purpose-how-elevation-adds-realism-and-hierarchy)
- [Framer Motion docs](/grx7/framer-motion) — Context7
- [Next.js App Router docs](/vercel/next.js) — Context7
- [shadcn/ui docs](/shadcn-ui/ui) — Context7
