# Typography Research — Company Fonts & Best Practices
*Researched: March 2026*

## Company Font Findings

### Stripe
- **Font**: Sohne (variable), licensed from Klim Type Foundry
- **Category**: Geometric grotesque
- **UI stack**: `"Sohne", system-ui, sans-serif` / `"Ideal Sans", system-ui, sans-serif`
- **Notes**: Premium paid font. Sohne-var is a variable font used across all Stripe surfaces.
- **Google Alternative**: Inter or Plus Jakarta Sans — both share the neutral, confident geometry

### Linear
- **Font**: Inter
- **Category**: Neo-grotesque
- **Notes**: The canonical example of Inter for a premium SaaS product. Uses Inter at multiple weights with precise tracking.
- **Google Alternative**: N/A — Inter is already the free option

### Vercel
- **Font**: Geist Sans + Geist Mono (custom, now open source)
- **Category**: Geometric grotesque
- **Notes**: Created in collaboration with Basement Studio. Available free on Google Fonts (`Geist` and `Geist Mono`). Designed specifically for web/developer interfaces.
- **Google Alternative**: Geist is now ON Google Fonts. Also available via `npm install geist`.

### GitHub
- **Font**: Mona Sans (variable) + Hubot Sans (variable)
- **Category**: Variable humanist grotesque
- **Notes**: Both are open source under OFL from GitHub. Wide axis range makes headings pop. Monaspace superfamily for code.
- **Mono**: SFMono-Regular, Consolas, Liberation Mono, Menlo, Courier (system stack)
- **Google Alternative**: Mona Sans is open source — use directly from GitHub releases.

### Notion
- **Font**: Inter (primary UI + marketing website)
- **Category**: Neo-grotesque
- **Notes**: Default content font options in app are Sans (Inter), Serif (Lyon Text), and Mono (Iawriter Mono).
- **Google Alternative**: N/A — Inter is already free

### Figma
- **Font**: Inter (interface and website)
- **Category**: Neo-grotesque
- **Notes**: Inter was designed by Rasmus Andersson who worked at Figma. Its ubiquity in design tools is no accident — it was designed for these exact contexts. Full feature settings: `'cv02', 'cv03', 'cv04', 'cv11'` for cleaner digits.
- **Google Alternative**: N/A — Inter is already free

### Apple
- **Font**: SF Pro (system only; not licensed for web embedding)
- **Category**: Humanist grotesque with optical sizes
- **CSS**: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif`
- **Notes**: Apple's SF Pro family has 9 weights, optical sizes (Text vs Display), and a Rounded variant. Not available for web embedding via @font-face — system font only.
- **Google Alternative**: DM Sans (closest proportions), Nunito Sans (closest feel)

### Airbnb
- **Font**: Cereal (proprietary, designed with Dalton Maag)
- **Category**: Geometric rounded sans-serif
- **Notes**: Custom font designed for the Airbnb brand. Friendly, rounded geometry signaling hospitality and approachability. Weights: Light, Book, Medium, Bold, Extra Bold, Black.
- **Google Alternative**: Nunito (most similar rounded geometry), Poppins, Outfit

---

## Google Fonts Alternatives Mapping

| Proprietary Font | Company         | Best Google Alternative | Runner-up           |
|------------------|-----------------|-------------------------|---------------------|
| Sohne            | Stripe          | Plus Jakarta Sans       | Inter               |
| SF Pro           | Apple           | DM Sans                 | Nunito Sans         |
| Circular         | Various         | Nunito Sans             | Outfit              |
| Graphik          | Various         | Manrope                 | DM Sans             |
| Cereal           | Airbnb          | Nunito                  | Outfit              |
| GT Walsheim      | Various         | Plus Jakarta Sans       | Poppins             |
| Neue Montreal    | Various         | Plus Jakarta Sans       | Manrope             |
| Söhne Mono       | Stripe (code)   | JetBrains Mono          | Geist Mono          |

### Top Free Fonts for SaaS (2025–2026 consensus)
1. **Inter** — de facto standard for SaaS UI; used by Linear, Figma, Notion, Vercel (previously)
2. **Geist** — rising standard for dev-focused products; Vercel's creation
3. **Plus Jakarta Sans** — distinctive alternative when Inter feels too generic
4. **DM Sans** — premium feel, excellent with DM Serif Display pairing
5. **Manrope** — enterprise/corporate feel, excellent readability
6. **Outfit** — geometric with personality; great for consumer/B2C
7. **Nunito Sans** — friendly, rounded; great for health/wellness/consumer

---

## Variable Fonts — Key Findings

### How variable fonts work
A single font file contains a design space across one or more axes:
- `wght` — weight (100–900)
- `wdth` — width (condensed to expanded)
- `opsz` — optical size (tuned proportions per size)
- `slnt` — slant (roman to italic)
- `ital` — italic substitution

Loading a variable font = 1 HTTP request instead of 6–8. Performance win is typically 30–60% smaller total font payload.

### font-optical-sizing: auto
- Setting: `font-optical-sizing: auto` tells the browser to use the font's `opsz` axis automatically, mapped to the element's `font-size`.
- This means: a 72px headline gets different glyph proportions than a 14px caption — automatically.
- Only works if the font has an `opsz` axis (Inter, Geist, DM Sans, Roboto Flex, Source Sans 3).
- Default browser behavior on supported fonts: auto.
- To override manually: `font-variation-settings: 'opsz' 32` (set explicit optical size).

### Font feature settings — Inter
```css
font-feature-settings:
  'cv02' 1,  /* Open 4 */
  'cv03' 1,  /* Open 6 */
  'cv04' 1,  /* Open 9 */
  'cv11' 1,  /* Single-storey a (cleaner in UI) */
  'ss01' 1,  /* Disambiguation: I/l/1 distinction */
  'calt' 1,  /* Contextual alternates */
  'liga' 1;  /* Standard ligatures */
```

---

## Fluid Typography — Key Findings

### CSS clamp() syntax
```css
font-size: clamp(MIN, PREFERRED, MAX);
```

The PREFERRED value should combine vw + rem so it scales with viewport but respects user font size preferences:
```css
font-size: clamp(1.5rem, 1rem + 2.5vw, 3rem);
```

### WCAG compliance
WCAG SC 1.4.4 requires text to be resizable to 200% without loss of content. With fluid typography, if MAX/MIN <= 2.5, the text passes at all standard viewport sizes.

### Pre-built fluid scale (320px → 1440px)
- Display:    `clamp(2.5rem, 1.714rem + 3.571vw, 4.5rem)` — 40px → 72px
- H1:         `clamp(1.875rem, 1.393rem + 2.143vw, 3rem)` — 30px → 48px
- H2:         `clamp(1.5rem, 1.339rem + 0.714vw, 1.875rem)` — 24px → 30px
- Body:       `clamp(0.9375rem, 0.911rem + 0.119vw, 1rem)` — 15px → 16px

---

## next/font — Key Findings

### What it does
- Downloads fonts at BUILD TIME and self-hosts them — no runtime Google Fonts requests from browser
- Generates precise fallback fonts using `size-adjust` CSS property = zero layout shift (no FOUT)
- Automatically subsets to requested character sets
- `display: 'swap'` prevents invisible text during load

### Critical pattern
```tsx
// CORRECT: CSS variable pattern — font applies globally via Tailwind
const sans = Inter({ variable: '--font-sans', subsets: ['latin'], display: 'swap' })
<html className={sans.variable}>

// WRONG: className pattern — applies Inter directly to html element, bypasses Tailwind font-family
const sans = Inter({ subsets: ['latin'], display: 'swap' })
<html className={sans.className}>
```

### Performance best practice
- Only load character subsets you need
- Request the `axes` array only for variable axes you'll actually use
- Two fonts maximum per project

---

## Sources
- Stripe font: https://copyprogramming.com/howto/stripe-custom-typography-font
- Vercel Geist: https://vercel.com/font + https://github.com/vercel/geist-font
- GitHub fonts: https://github.com/github/mona-sans
- Airbnb Cereal: https://www.itsnicethat.com/news/airbnb-cereal-typeface-font-dalton-maag-graphic-design-150518
- Variable fonts: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Fonts/Variable_fonts
- font-optical-sizing: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/font-optical-sizing
- Fluid typography: https://www.smashingmagazine.com/2022/01/modern-fluid-typography-css-clamp/
- next/font: https://nextjs.org/docs/app/getting-started/fonts
- SaaS font guide: https://harrisonbroadbent.com/blog/saas-fonts/
- Google Fonts alternatives: https://frontendresource.com/most-used-fonts-alternative-google-fonts/
