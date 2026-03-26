---
name: Premium Typography
description: Font selection, pairing, hierarchy, variable fonts, fluid type, and next/font optimization for generating polished web UIs
triggers:
  - /new-app
  - /clone-app
  - /build
  - /build-page
  - /auto-dev
---

# Premium Typography System

> Typography is the #1 visual differentiator. Users cannot articulate why an app looks premium, but they feel it through type. This skill is the definitive reference — read it before writing a single font-related line of code.

---

## 1. Company Font Map

What every top company actually uses, with Google Fonts alternatives.

| Company   | Font Used         | Category              | Available          | Google Font Alternative      | Why It Works                                      |
|-----------|-------------------|-----------------------|--------------------|------------------------------|---------------------------------------------------|
| Stripe    | Sohne (variable)  | Geometric grotesque   | Paid (Klim Type)   | Inter, Plus Jakarta Sans     | Confident, neutral, excellent at all weights      |
| Linear    | Inter             | Neo-grotesque         | Free (Google Fonts)| Inter (it IS the alternative)| Designed for screens, exceptional small-size perf |
| Vercel    | Geist Sans        | Geometric grotesque   | Free (Google Fonts)| Geist (now on Google Fonts)  | Created for dev tools; clean, precise             |
| GitHub    | Mona Sans         | Variable humanist     | Free (OFL)         | Mona Sans (open source)      | Wide axis range, strong in headings               |
| Notion    | Inter             | Neo-grotesque         | Free (Google Fonts)| Inter (it IS the alternative)| Neutral, workhorse for dense information UI       |
| Figma     | Inter             | Neo-grotesque         | Free (Google Fonts)| Inter (it IS the alternative)| Creator of Inter was a Figma designer             |
| Apple     | SF Pro (system)   | Humanist grotesque    | System only (-apple-system) | DM Sans, Nunito Sans  | Optical sizes tuned for every scale               |
| Airbnb    | Cereal            | Geometric rounded     | Proprietary        | Nunito, Poppins, Outfit      | Friendly, rounded — signals approachability       |

### Key Insight
Inter dominates modern SaaS (Linear, Notion, Figma all use it). Geist is the rising alternative for developer-focused products. Sohne is the aspirational paid option for premium brands.

---

## 2. Recommended Font Stacks

Six curated stacks for different product personalities. Copy the entire stack.

### Stack 1: Clean SaaS (default recommendation)
**Primary: Inter + JetBrains Mono**
- Use for: productivity tools, dashboards, dev tools, B2B SaaS
- Why: Inter is purpose-built for UI at all sizes; JetBrains Mono is the gold standard for code

```tsx
// app/layout.tsx
import { Inter, JetBrains_Mono } from 'next/font/google'

const sans = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  // Enable variable font features
  axes: ['opsz'],
})

const mono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
  weight: ['400', '500', '700'],
})
```

**CSS custom properties:**
```css
:root {
  --font-sans: 'Inter Variable', 'Inter', system-ui, -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace;
}
```

### Stack 2: Developer Tools / Technical Products
**Primary: Geist + Geist Mono**
- Use for: CLIs, documentation, developer dashboards, API tools
- Why: Vercel designed Geist specifically for developer interfaces; precise geometry, excellent DX

```tsx
import { Geist, Geist_Mono } from 'next/font/google'

const geist = Geist({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
})

const geistMono = Geist_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})
```

### Stack 3: Editorial / Content Platform
**Primary: Plus Jakarta Sans + Lora**
- Use for: blogs, content platforms, media sites, newsletters
- Why: Plus Jakarta Sans is distinctive without being distracting; Lora provides authoritative serif contrast

```tsx
import { Plus_Jakarta_Sans, Lora } from 'next/font/google'

const sans = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  axes: ['wght'],
})

const serif = Lora({
  subsets: ['latin'],
  variable: '--font-serif',
  display: 'swap',
  weight: ['400', '500', '600', '700'],
})
```

**Usage rule:** Serif for article body / pull quotes only. Sans for UI chrome, nav, CTAs.

### Stack 4: Luxury / Premium Consumer
**Primary: DM Sans + DM Serif Display**
- Use for: fintech, luxury e-commerce, premium lifestyle apps
- Why: DM Serif Display has elegant authority; DM Sans keeps it grounded and legible

```tsx
import { DM_Sans, DM_Serif_Display } from 'next/font/google'

const sans = DM_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  axes: ['opsz'],
})

const display = DM_Serif_Display({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
  weight: ['400'],
  style: ['normal', 'italic'],
})
```

**Usage rule:** Display font for hero headlines and section titles only. Never for UI.

### Stack 5: Playful / Consumer App
**Primary: Outfit + Space Mono**
- Use for: consumer apps, gaming, social, younger demographics
- Why: Outfit is clean with personality; Space Mono adds retro-tech character

```tsx
import { Outfit, Space_Mono } from 'next/font/google'

const sans = Outfit({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  weight: ['300', '400', '500', '600', '700'],
})
```

### Stack 6: Corporate / Enterprise
**Primary: Manrope + IBM Plex Mono**
- Use for: enterprise SaaS, B2B, fintech, healthcare, legal
- Why: Manrope reads as trustworthy and modern; IBM Plex Mono is authoritative for technical content

```tsx
import { Manrope, IBM_Plex_Mono } from 'next/font/google'

const sans = Manrope({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  axes: ['wght'],
})

const mono = IBM_Plex_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
  weight: ['400', '500', '600'],
})
```

---

## 3. Font Pairing Rules

### Rule 1: Contrast is the foundation
Pair fonts with clear contrast: a geometric sans with a humanist serif, or a high-contrast display with a neutral body font. Pairing two similar-looking typefaces creates visual noise.

### Rule 2: Maximum two font families per project
- One sans-serif for UI + body
- One optional serif/display for headlines OR one monospace for code
- NEVER three families. Two is already pushing it.

### Rule 3: Geometric + Humanist works; Geometric + Geometric clashes
- Good: Geist (geometric) + Lora (humanist serif)
- Good: Inter (neo-grotesque) + DM Serif Display (transitional serif)
- Bad: Outfit (geometric) + Poppins (geometric) — too similar, no contrast

### Rule 4: Weight contrast creates hierarchy without changing fonts
Use weight contrast before reaching for a second typeface:
- Regular (400) → body
- Medium (500) → labels, UI text
- Semibold (600) → headings, CTAs
- Bold (700) → hero headlines, emphasis

### Rule 5: Optical sizes do the heavy lifting
With variable fonts (Inter, Geist, DM Sans), the same font family handles everything from 11px captions to 72px display headlines — just vary weight and tracking. This is cleaner than font-switching.

### Proven Pairings (copy-safe)
| Display/Heading       | Body/UI           | Use Case              |
|-----------------------|-------------------|-----------------------|
| Playfair Display 700  | Inter 400/500     | Fintech, premium SaaS |
| DM Serif Display 400  | DM Sans 400/500   | Luxury, editorial     |
| Cal Sans 700          | Geist 400/500     | Dev tools (Vercel-style) |
| Fraunces 700 italic   | Manrope 400       | Editorial, blogs      |
| Space Grotesk 700     | Inter 400         | Startup marketing     |

---

## 4. Typography Hierarchy

The complete type scale with exact values for CSS and Tailwind.

### Scale Table

| Role        | Size (rem) | Size (px) | Weight | Letter-spacing | Line-height | Tailwind                                              |
|-------------|-----------|-----------|--------|----------------|-------------|-------------------------------------------------------|
| Display     | 4.5rem    | 72px      | 700    | -0.04em        | 1.06        | `text-7xl font-bold tracking-[-0.04em] leading-[1.06]` |
| H1          | 3rem      | 48px      | 700    | -0.03em        | 1.1         | `text-5xl font-bold tracking-[-0.03em] leading-tight`  |
| H2          | 1.875rem  | 30px      | 600    | -0.02em        | 1.2         | `text-3xl font-semibold tracking-[-0.02em]`            |
| H3          | 1.25rem   | 20px      | 600    | -0.01em        | 1.25        | `text-xl font-semibold tracking-[-0.01em] leading-snug`|
| H4          | 1rem      | 16px      | 600    | 0              | 1.3         | `text-base font-semibold leading-snug`                 |
| Body Large  | 1.125rem  | 18px      | 400    | 0              | 1.65        | `text-lg leading-[1.65]`                               |
| Body        | 1rem      | 16px      | 400    | 0              | 1.6         | `text-base leading-relaxed`                            |
| Body Small  | 0.875rem  | 14px      | 400    | 0              | 1.5         | `text-sm leading-[1.5]`                                |
| Caption     | 0.75rem   | 12px      | 400    | +0.01em        | 1.4         | `text-xs leading-[1.4]`                                |
| Overline    | 0.6875rem | 11px      | 500    | +0.08em        | 1.0         | `text-[11px] font-medium uppercase tracking-widest`    |
| Mono        | 0.875rem  | 14px      | 400    | 0              | 1.7         | `font-mono text-sm leading-[1.7]`                      |

### CSS Custom Utilities (Tailwind v4)

```css
@utility heading-display {
  font-size:      clamp(2.5rem, 5vw, 4.5rem);
  font-weight:    700;
  line-height:    1.06;
  letter-spacing: -0.04em;
  text-wrap:      balance;
  font-optical-sizing: auto;
}

@utility heading-1 {
  font-size:      clamp(1.875rem, 3.5vw, 3rem);
  font-weight:    700;
  line-height:    1.1;
  letter-spacing: -0.03em;
  text-wrap:      balance;
  font-optical-sizing: auto;
}

@utility heading-2 {
  font-size:      clamp(1.5rem, 2.5vw, 1.875rem);
  font-weight:    600;
  line-height:    1.2;
  letter-spacing: -0.02em;
  text-wrap:      balance;
}

@utility heading-3 {
  font-size:      1.25rem;
  font-weight:    600;
  line-height:    1.25;
  letter-spacing: -0.01em;
}

@utility body-lg {
  font-size:   1.125rem;
  font-weight: 400;
  line-height: 1.65;
}

@utility body {
  font-size:   1rem;
  font-weight: 400;
  line-height: 1.6;
}

@utility caption {
  font-size:      0.75rem;
  font-weight:    400;
  line-height:    1.4;
  letter-spacing: 0.01em;
}

@utility overline {
  font-size:      0.6875rem;
  font-weight:    500;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  line-height:    1.0;
}
```

### React Component Examples

```tsx
// Hero headline — fluid, balanced, tight tracking
<h1
  className="font-bold tracking-tight text-balance"
  style={{ fontSize: 'clamp(2.5rem, 5vw, 4.5rem)', letterSpacing: '-0.04em', lineHeight: 1.06 }}
>
  Build in a weekend. Scale to millions.
</h1>

// Section heading H2
<h2 className="text-3xl font-semibold tracking-[-0.02em] leading-tight text-balance">
  Everything you need
</h2>

// Overline label above a section title
<p className="text-[11px] font-medium uppercase tracking-[0.08em] text-muted-foreground">
  Features
</p>

// Body copy
<p className="text-base leading-relaxed text-muted-foreground max-w-prose">
  Your body copy goes here. Max-w-prose (65ch) keeps lines readable.
</p>

// Caption / metadata
<span className="text-xs text-muted-foreground leading-[1.4]">Updated 3 days ago</span>

// Mono — code or terminal
<code className="font-mono text-sm leading-[1.7] bg-muted/50 px-1.5 py-0.5 rounded">
  npm install next
</code>
```

---

## 5. Variable Font Usage

### What variable fonts give you
A single font file with a continuous axis for weight (wght), width (wdth), optical size (opsz), slant (slnt), and italics (ital). Loading one file instead of 6–8 static weight files = massive performance win.

### Supported variable axes (Inter example)
```css
/* Inter Variable supports: wght (100–900), opsz (14–32) */
font-variation-settings: 'wght' 450, 'opsz' 32;
```

### next/font setup for variable fonts

```tsx
// BEST: Load variable font with axes
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  // Request the optical size axis for Inter Variable
  axes: ['opsz'],
})

// globals.css — enable features
body {
  font-family: var(--font-sans), system-ui, sans-serif;
  font-feature-settings: 'cv02', 'cv03', 'cv04', 'cv11'; /* Inter: open digits, cleaner g */
  font-optical-sizing: auto;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

### Font feature settings (Inter)
```css
/* Enable all Inter's optical improvements */
font-feature-settings:
  'cv02' 1,   /* Open 4 */
  'cv03' 1,   /* Open 6 */
  'cv04' 1,   /* Open 9 */
  'cv11' 1,   /* Single-storey a */
  'ss01' 1,   /* Disambiguation (I l 1) for UI/code */
  'calt' 1,   /* Contextual alternates */
  'liga' 1;   /* Standard ligatures */
```

### Font subsetting
Always subset Google Fonts to only the character sets you need:
```tsx
// Don't load cyrillic if your app is English-only
const inter = Inter({
  subsets: ['latin'],  // NOT ['latin', 'latin-ext', 'cyrillic'] unless needed
  variable: '--font-sans',
  display: 'swap',
})
```

### Performance budget
| Scenario                              | File size target  |
|---------------------------------------|-------------------|
| Single variable font (latin subset)   | < 100KB           |
| Two variable fonts (sans + mono)      | < 180KB           |
| Three fonts (display + body + mono)   | < 220KB           |

---

## 6. Fluid Typography

### The clamp() formula
```css
font-size: clamp(MIN, PREFERRED, MAX);
/* PREFERRED = viewport-relative + rem anchor */
font-size: clamp(1rem, 0.5rem + 2.5vw, 1.5rem);
```

### How to calculate a clamp value
1. Pick a minimum size (e.g., 1rem at 320px viewport)
2. Pick a maximum size (e.g., 1.5rem at 1440px viewport)
3. Calculate: `PREFERRED = ((MAX - MIN) / (1440 - 320)) * 100vw + (MIN - 320 * ((MAX - MIN) / (1440 - 320)))`

Or use a generator: https://clampgenerator.com/

### Pre-calculated fluid scale (320px → 1440px)

```css
:root {
  /* Display: 40px → 72px */
  --text-display: clamp(2.5rem, 1.714rem + 3.571vw, 4.5rem);

  /* H1: 30px → 48px */
  --text-h1: clamp(1.875rem, 1.393rem + 2.143vw, 3rem);

  /* H2: 24px → 30px */
  --text-h2: clamp(1.5rem, 1.339rem + 0.714vw, 1.875rem);

  /* H3: 18px → 20px */
  --text-h3: clamp(1.125rem, 1.071rem + 0.238vw, 1.25rem);

  /* Body: 15px → 16px */
  --text-body: clamp(0.9375rem, 0.911rem + 0.119vw, 1rem);

  /* Body small: 13px → 14px */
  --text-sm: clamp(0.8125rem, 0.786rem + 0.119vw, 0.875rem);
}
```

### Applying fluid type in Tailwind (class approach)
```tsx
// Use inline style for hero/display — clamp doesn't map to Tailwind classes cleanly
<h1
  className="font-bold tracking-tight leading-[1.06]"
  style={{ fontSize: 'clamp(2.5rem, 5vw, 4.5rem)' }}
>

// Or define custom CSS utilities in globals.css:
// @utility heading-display { font-size: clamp(2.5rem, 5vw, 4.5rem); ... }
// Then: <h1 className="heading-display">
```

### WCAG compliance check for fluid type
If MAX / MIN <= 2.5, the text always passes WCAG SC 1.4.4 (text resize 200%). Verify:
- Display: 72 / 40 = 1.8 ✓
- H1: 48 / 30 = 1.6 ✓
- Body: 16 / 14 = 1.14 ✓

---

## 7. Optical Sizing

### What it does
Optical sizing automatically adjusts a font's stroke contrast, spacing, and glyph proportions for the size at which text is displayed. A headline at 72px needs different proportions than body text at 14px — optical sizing handles this automatically when the font supports the `opsz` axis.

### How to enable it
```css
/* Enable globally — browsers use font-size to set opsz automatically */
* {
  font-optical-sizing: auto;
}

/* Or just on the body */
body {
  font-optical-sizing: auto;
}
```

### Manual control (when you need precision)
```css
/* Force a specific optical size regardless of font-size */
.hero-headline {
  font-variation-settings: 'opsz' 72; /* optimized for 72px rendering */
}

.body-text {
  font-variation-settings: 'opsz' 16; /* optimized for 16px rendering */
}

.caption {
  font-variation-settings: 'opsz' 11; /* tuned for small text */
}
```

### Which Google Fonts support opsz
- Inter Variable (opsz 14–32)
- DM Sans (opsz via variable)
- Geist (opsz supported)
- Roboto Flex (opsz 8–144)
- Source Sans 3 (opsz 8–60)

### When to use `font-optical-sizing: none`
Only when you have custom `font-variation-settings` for `opsz` and want manual control. If you set manual `'opsz'` values, the browser ignores `font-optical-sizing: auto` anyway.

---

## 8. next/font Setup Patterns

### Pattern 1: Single variable font (recommended for most apps)
```tsx
// app/layout.tsx
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
  axes: ['opsz'],
  // Preload only regular and semibold to reduce initial load
  // (variable font streams the rest on demand)
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <body className="antialiased font-sans">
        {children}
      </body>
    </html>
  )
}
```

### Pattern 2: Sans + Mono (SaaS / dev tool standard)
```tsx
import { Geist, Geist_Mono } from 'next/font/google'

const geistSans = Geist({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
})

const geistMono = Geist_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable}`}
      suppressHydrationWarning
    >
      <body className="antialiased font-sans">
        {children}
      </body>
    </html>
  )
}
```

### Pattern 3: Sans + Display (editorial / marketing)
```tsx
import { Inter, Playfair_Display } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
})

const playfair = Playfair_Display({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
  weight: ['400', '700'],
  style: ['normal', 'italic'],
})

// globals.css
// h1, h2, .heading-display { font-family: var(--font-display); }
// body, p, button, input { font-family: var(--font-sans); }
```

### Pattern 4: Local / self-hosted font
```tsx
import localFont from 'next/font/local'

// Place font files in /public/fonts/ or /src/fonts/
const customFont = localFont({
  src: [
    { path: '../../public/fonts/CustomFont-Regular.woff2',    weight: '400', style: 'normal' },
    { path: '../../public/fonts/CustomFont-Medium.woff2',     weight: '500', style: 'normal' },
    { path: '../../public/fonts/CustomFont-SemiBold.woff2',   weight: '600', style: 'normal' },
    { path: '../../public/fonts/CustomFont-Bold.woff2',       weight: '700', style: 'normal' },
  ],
  variable: '--font-sans',
  display: 'swap',
})

// For variable local font (single file)
const customVarFont = localFont({
  src: '../../public/fonts/CustomFont-Variable.woff2',
  variable: '--font-sans',
  display: 'swap',
})
```

### Tailwind CSS v4 — connecting CSS variables
```css
/* globals.css */
@import "tailwindcss";

@theme {
  --font-sans: var(--font-sans), system-ui, -apple-system, sans-serif;
  --font-mono: var(--font-mono), 'Cascadia Code', monospace;
  --font-display: var(--font-display), var(--font-sans);
}

body {
  font-family:          theme(fontFamily.sans);
  font-optical-sizing:  auto;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  font-feature-settings: 'cv02', 'cv03', 'cv04', 'cv11'; /* Inter optical improvements */
}
```

### Tailwind CSS v3 — tailwind.config.ts
```ts
import { fontFamily } from 'tailwindcss/defaultTheme'

const config = {
  theme: {
    extend: {
      fontFamily: {
        sans:    ['var(--font-sans)', ...fontFamily.sans],
        mono:    ['var(--font-mono)', ...fontFamily.mono],
        display: ['var(--font-display)', 'var(--font-sans)', ...fontFamily.sans],
      },
    },
  },
}
```

---

## 9. Dark Mode Typography Adjustments

Text that looks correct in light mode often feels too light or too heavy in dark mode. These adjustments are non-negotiable for polished dark interfaces.

### Core principles
1. **Reduce font weight in dark mode** — bold text on dark backgrounds appears heavier optically. Drop one weight step (700 → 600 for headings, 500 → 400 for labels).
2. **Slightly increase letter-spacing** — tight tracking looks cramped on dark backgrounds. Add +0.005em.
3. **Reduce color temperature** — pure white (#fff) on pure dark (#0a0a0a) is harsh. Use slightly warm whites: `oklch(95% 0.01 240)` or Slate 100 (`#f1f5f9`).
4. **font-smooth differs** — `-webkit-font-smoothing: antialiased` renders thinner on macOS. Keep it on dark; remove or use `auto` on light for heavier appearance.

### CSS implementation
```css
:root {
  /* Light mode — standard */
  --font-heading-weight: 700;
  --font-heading-tracking: -0.03em;
  -webkit-font-smoothing: auto;
  -moz-osx-font-smoothing: auto;
}

.dark {
  /* Dark mode — visually calibrated */
  --font-heading-weight: 600;           /* one weight lighter */
  --font-heading-tracking: -0.025em;    /* slightly less tight */
  -webkit-font-smoothing: antialiased;  /* thinner strokes on dark */
  -moz-osx-font-smoothing: grayscale;
}
```

### Component example with dark mode
```tsx
<h1
  className="
    font-bold dark:font-semibold
    tracking-[-0.03em] dark:tracking-[-0.025em]
    text-foreground
  "
  style={{ fontSize: 'clamp(2.5rem, 5vw, 4.5rem)', lineHeight: 1.06 }}
>
  {title}
</h1>
```

### Color adjustments for dark text
```css
.dark {
  --color-fg:       oklch(96% 0.005 250);   /* slightly blue-tinted white, not pure */
  --color-fg-muted: oklch(65% 0.005 250);   /* softer muted text */
}
```

---

## 10. Anti-Patterns

These are the specific things that make typography look amateur. Read them once a week.

### Font selection
- **NEVER use system-ui as the only font** — it renders differently on every OS. Always have a named fallback.
- **NEVER use more than 2 font families** on a single page. Three is chaos.
- **NEVER use Google Fonts `<link>` tags** — always next/font. Link tags cause FOUT and don't benefit from Next.js optimization.
- **NEVER use Roboto** for UI design in 2025 — it's Android's system font and signals generic design.
- **NEVER pair two geometric sans-serifs** — e.g., Poppins + Outfit. No contrast, no hierarchy.

### Weight mistakes
- **NEVER use `font-weight: 800` or `900`** for anything except decorative display use. They scream amateur at small sizes.
- **NEVER use `font-weight: 300`** (`font-light`) — poor legibility on most screens, especially on Windows ClearType.
- **NEVER use more than 3–4 weights** from the same family on one page.

### Size and spacing
- **NEVER use `font-size` below 12px** — `text-xs` is the minimum. Below that, use icons instead.
- **NEVER set `line-height: 1` on multi-line text** — fatal for readability.
- **NEVER use `letter-spacing` tighter than -0.04em** — becomes illegible.
- **NEVER use `letter-spacing` wider than 0.1em** on body text — reserved for overlines only.
- **NEVER use `text-align: justify`** — creates rivers of whitespace that break reading flow.

### Hierarchy failures
- **NEVER have two H1s on a page** — one H1 per page, full stop.
- **NEVER skip heading levels** (H1 → H3, skipping H2) — breaks screen readers.
- **NEVER make all text the same size** — the eye needs a clear hierarchy ladder.
- **NEVER center large blocks of body text** — hero sublines are OK (max 2–3 lines), paragraphs never.
- **NEVER use ALL CAPS on body text** — reserved for overlines and badges only.

### Dark mode failures
- **NEVER use pure white `#ffffff` on very dark backgrounds** — too much contrast causes eye strain.
- **NEVER forget to reduce font weight** for headings in dark mode — they optically appear heavier.
- **NEVER use identical letter-spacing in light and dark mode** — dark mode needs a touch more looseness.

### Performance
- **NEVER load font weights you don't use** — each weight is a separate file request.
- **NEVER load character subsets for scripts you don't use** (cyrillic, greek, etc.).
- **NEVER import fonts without `display: 'swap'`** — invisible text during load = bad UX.

---

## Quick Reference Cheat Sheet

```
FONT CHOICE BY PRODUCT TYPE:
  SaaS / B2B        → Inter + JetBrains Mono
  Dev tools         → Geist + Geist Mono
  Editorial         → Plus Jakarta Sans + Lora
  Fintech / Premium → DM Sans + DM Serif Display
  Consumer / Social → Outfit
  Enterprise        → Manrope + IBM Plex Mono

HEADING TRACKING (letter-spacing):
  Display (72px)    → -0.04em
  H1 (48px)         → -0.03em
  H2 (30px)         → -0.02em
  H3 (20px)         → -0.01em
  H4 (16px)         → 0
  Body              → 0
  Overline          → +0.08em

LINE HEIGHT:
  Display / H1      → 1.06–1.1   (tight)
  H2 / H3           → 1.2–1.3    (snug)
  Body Large        → 1.65       (relaxed)
  Body              → 1.6        (relaxed)
  Code / Mono       → 1.7        (extra relaxed)

FLUID TYPE (copy these):
  Display:  clamp(2.5rem, 5vw, 4.5rem)
  H1:       clamp(1.875rem, 3.5vw, 3rem)
  H2:       clamp(1.5rem, 2.5vw, 1.875rem)

ANTI-PATTERNS (never):
  font-weight 800/900/300
  font-size below 12px
  letter-spacing below -0.04em
  more than 2 font families
  <link> tags for fonts
  Roboto for UI design
  two geometric sans pairs
  centered paragraphs
```

---

## See Also

- [design-system/SKILL.md](../design-system/SKILL.md) — color tokens, component patterns, full design system
- [premium-builder/SKILL.md](../premium-builder/SKILL.md) — full premium app building pipeline
- Vercel Geist font: https://vercel.com/font
- Inter variable font: https://rsms.me/inter/
- Fluid type calculator: https://clampgenerator.com/
- Font pairs: https://www.fontpair.co/
- Variable fonts explorer: https://fonts.google.com/variablefonts
