# Premium Component Library Specification

## Purpose

Default shadcn/ui components look basic. This spec defines how to elevate every component to Linear/Vercel/Stripe quality. These patterns are used by all templates and the /clone-app pipeline.

## Component Enhancement Patterns

### 1. Cards

**Default shadcn:** Flat border, no depth
**Premium:** Glass effect, layered shadow, hover glow, gradient border on hover

```tsx
// Premium card pattern
<div className="group glass-card rounded-2xl p-6 hover:shadow-xl hover:-translate-y-0.5 transition-all duration-200 relative overflow-hidden">
  {/* Hover glow */}
  <div className="absolute -top-12 -right-12 size-36 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none blur-3xl"
    style={{ background: "oklch(0.58 0.18 250 / 25%)" }} />
  {/* Content */}
</div>
```

### 2. Buttons

**Default shadcn:** Flat, basic hover
**Premium:** Pill shape, shadow on hover, arrow animation, loading state

```tsx
// Primary CTA pattern
<button className="group inline-flex items-center gap-2 px-7 py-3.5 bg-foreground text-background rounded-full text-sm font-medium hover:opacity-90 hover:shadow-lg hover:shadow-black/20 transition-all duration-200 min-h-[44px]">
  Get started
  <ArrowRight size={15} className="transition-transform group-hover:translate-x-0.5" />
</button>

// Ghost button pattern
<button className="inline-flex items-center gap-2 px-7 py-3.5 border border-border text-foreground rounded-full text-sm font-medium hover:bg-muted/70 transition-colors min-h-[44px]">
  Learn more
</button>
```

### 3. Navbars

**Default:** Basic links
**Premium:** Sticky + backdrop blur, scroll-aware, mobile hamburger with animation

```tsx
<header className="sticky top-0 z-50 bg-background/90 backdrop-blur-lg border-b border-border">
  <nav className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
    {/* Logo, links, CTAs */}
  </nav>
</header>
```

### 4. Hero Sections

**Default:** Text + button
**Premium:** Gradient text, animated badge, radial glow, product mockup, trust indicators

Key elements:
- Badge with pulsing dot ("Now in beta — join 50K+ teams")
- Headline with `gradient-text` class
- Subline in muted-foreground
- Two CTA buttons (primary pill + ghost pill)
- Trust line ("No credit card required")
- Full browser mockup showing the actual product

### 5. Feature Sections

**Default:** Uniform 3-column grid with icons
**Premium:** Asymmetric layout, one large card spanning 2 rows, stat badges, hover glows

### 6. Pricing Tables

**Default:** 3 equal cards
**Premium:** Popular tier has accent border + "Most popular" badge, toggle monthly/annual, comparison table below

### 7. Footers

**Default:** Link list
**Premium:** Gradient accent divider, newsletter form, 6-column grid, social icons with hover, legal links

### 8. Auth Forms

**Default:** Basic form fields
**Premium:** Social OAuth button, divider "or continue with email", show/hide password, validation with aria-describedby, loading spinner on submit

### 9. Terminal/Code Mockups

**Premium pattern:**
- macOS traffic lights (red/yellow/green)
- URL bar or tab bar
- Syntax highlighting (purple keywords, blue functions, green strings)
- Blinking cursor (CSS animation)
- Line numbers
- File tree sidebar
- Apple-style reflection shadow below

### 10. Integration Displays

**Premium pattern:**
- Infinite marquee (2 rows, opposite directions)
- Branded chips with logo square + name
- Edge fade overlays
- "100+ integrations" stat badge
- respects prefers-reduced-motion

## Visual Effects Library

### Gradients
- Hero glow: `radial-gradient(ellipse 80% 50% at 50% -10%, oklch(accent / 12%), transparent 70%)`
- CTA background: `linear-gradient(135deg, oklch(0.12) 0%, oklch(0.08) 40%, oklch(0.10) 100%)`
- Text gradient: `linear-gradient(135deg, #1a1a1a 0%, #555 100%)`
- Border gradient: `linear-gradient(var(--border-angle), accent, transparent)`

### Shadows
- Card: `glass-card` class (backdrop-blur + translucent bg + subtle border)
- Product: `product-shadow` class (5-layer depth shadow)
- Hover: `hover:shadow-xl hover:-translate-y-0.5 transition-all duration-200`

### Textures
- Grid: `bg-grid` class (24px grid lines at 3% opacity)
- Noise: `noise` class (SVG turbulence at 1.5% opacity)

### Animations
- Badge pulse: CSS `ping` keyframe on status dot
- Cursor blink: CSS `blink` keyframe (1.1s step-end)
- Marquee: CSS `marquee` / `marquee-reverse` keyframes
- Hover glow: `opacity-0 group-hover:opacity-100 transition-opacity duration-500 blur-3xl`
- Button arrow: `group-hover:translate-x-0.5 transition-transform`

## Typography Scale

```
Display:  text-7xl (72px) font-semibold tracking-tight leading-[1.06]
H1:       text-5xl (48px) font-semibold tracking-tight leading-tight
H2:       text-4xl (36px) font-semibold tracking-tight leading-tight
H3:       text-xl  (20px) font-semibold
H4:       text-lg  (18px) font-semibold
Body:     text-base (16px) text-muted-foreground leading-relaxed
Small:    text-sm  (14px) text-muted-foreground
Caption:  text-xs  (12px) text-muted-foreground
Overline: text-xs  (12px) font-semibold uppercase tracking-widest text-muted-foreground
```

## Spacing Scale

```
Section padding: py-12 md:py-20 (mobile-first)
Max width:       max-w-7xl mx-auto px-6
Card padding:    p-6 (small), p-8 (large)
Section gap:     gap-12 lg:gap-16
Card gap:        gap-4 (tight), gap-5 (normal)
Stack gap:       space-y-3 (tight), space-y-4 (normal), space-y-6 (loose)
```

## Responsive Breakpoints

```
Mobile:  default (< 640px) — 1 column, stacked layout
Tablet:  sm: (640px+)      — 2 columns
Desktop: md: (768px+)      — side navigation, 3 columns
Wide:    lg: (1024px+)     — full layout
Max:     max-w-7xl         — content cap at 1280px
```
