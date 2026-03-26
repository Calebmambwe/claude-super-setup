# Color Palette Generator Specification

## Purpose

Given a single brand color (hex), generate a complete design token palette in OKLCH color space with semantic mappings. This is used by every template and clone pipeline.

## Algorithm

### Input
One hex color (e.g., "#0081F2" for Manus blue, "#3ECF8E" for Supabase green)

### Step 1: Convert to OKLCH
```
#0081F2 → oklch(0.58 0.18 250)
         L=0.58, C=0.18, H=250 (blue)
```

### Step 2: Generate 11-shade scale
Vary lightness while maintaining hue and adjusting chroma:

```
primary-50:  oklch(0.97  0.02  H)   // near white, barely tinted
primary-100: oklch(0.93  0.04  H)
primary-200: oklch(0.87  0.08  H)
primary-300: oklch(0.78  0.12  H)
primary-400: oklch(0.68  0.16  H)
primary-500: oklch(L     C     H)   // ← base color
primary-600: oklch(L-8%  C-2%  H)
primary-700: oklch(L-16% C-4%  H)
primary-800: oklch(L-24% C-6%  H)
primary-900: oklch(L-32% C-8%  H)
primary-950: oklch(L-40% C-10% H)
```

### Step 3: Generate neutral scale
Gray scale with a hint of the brand hue:

```
gray-50:  oklch(0.985 0.005 H)
gray-100: oklch(0.96  0.005 H)
gray-200: oklch(0.90  0.005 H)
gray-300: oklch(0.83  0.005 H)
gray-400: oklch(0.70  0.005 H)
gray-500: oklch(0.55  0.005 H)
gray-600: oklch(0.45  0.005 H)
gray-700: oklch(0.37  0.005 H)
gray-800: oklch(0.27  0.005 H)
gray-900: oklch(0.18  0.005 H)
gray-950: oklch(0.10  0.005 H)
```

### Step 4: Generate semantic tokens

```css
/* Light theme */
--background:         gray-50
--foreground:         gray-900
--card:               white (oklch(1 0 0))
--card-foreground:    gray-900
--muted:              gray-100
--muted-foreground:   gray-500
--border:             gray-200
--input:              gray-200
--primary:            primary-500
--primary-foreground: white
--accent:             gray-100
--accent-foreground:  gray-900
--destructive:        oklch(0.577 0.245 27.325)
--ring:               primary-500

/* Dark theme */
--background:         gray-950
--foreground:         gray-50
--card:               gray-900
--card-foreground:    gray-50
--muted:              gray-800
--muted-foreground:   gray-400
--border:             gray-800
--input:              gray-800
--primary:            primary-400
--primary-foreground: gray-950
--accent:             gray-800
--accent-foreground:  gray-50
--destructive:        oklch(0.704 0.191 22.216)
--ring:               primary-400
```

### Step 5: Generate complementary colors

```
Success:  oklch(0.72 0.17 155)  // green
Warning:  oklch(0.80 0.15 85)   // amber
Error:    oklch(0.64 0.24 27)   // red
Info:     primary-500            // brand color
```

## Output Format

### CSS Custom Properties (globals.css)
```css
:root {
  --primary: oklch(0.58 0.18 250);
  --primary-foreground: oklch(1 0 0);
  --background: oklch(0.985 0.005 250);
  /* ... full palette ... */
}

.dark {
  --primary: oklch(0.68 0.16 250);
  --primary-foreground: oklch(0.10 0.005 250);
  --background: oklch(0.10 0.005 250);
  /* ... full palette ... */
}
```

### tokens.json (W3C DTCG format)
```json
{
  "color": {
    "primary": {
      "50":  { "$value": "oklch(0.97 0.02 250)", "$type": "color" },
      "500": { "$value": "oklch(0.58 0.18 250)", "$type": "color" },
      "900": { "$value": "oklch(0.26 0.10 250)", "$type": "color" }
    }
  }
}
```

## Implementation

Script: `scripts/generate-palette.sh`
```bash
#!/bin/bash
# Usage: ./generate-palette.sh "#0081F2" > globals-tokens.css
# Input: hex color
# Output: CSS custom properties for both light and dark themes
```

This script will be called by:
- `/new-app` — when user specifies a brand color
- `/clone-app` — with the extracted primary color
- Templates — during scaffold with user's brand color
