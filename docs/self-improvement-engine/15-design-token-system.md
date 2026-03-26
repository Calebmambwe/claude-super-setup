# Design Token Pipeline: Complete Specification

## Overview

The design token system establishes a single source of truth for all visual design values (colors, typography, spacing, radius) that can be transformed into the correct format for any platform. A change in the source token file automatically propagates to CSS, Tailwind, iOS, and Android.

---

## 1. Architecture

### 1.1 The Problem Without Tokens

Without a token system, teams face:
- **Color drift**: `#6200EE` in one file, `#6100ec` in another (typo), `purple-600` in a third
- **Dark mode inconsistency**: Every component implements dark mode differently
- **Cross-platform divergence**: iOS purple is different from web purple
- **Refactoring impossibility**: Changing the primary color requires searching every file

### 1.2 The Solution: Three-Tier Token System

```
Reference Tokens (palette)
         ↓
Semantic Tokens (meaning)
         ↓
Component Tokens (specific overrides)
```

**Reference tokens**: Every available value. Never used directly in components.
```json
"color.palette.purple.40": "oklch(0.428 0.174 303.6)"
"color.palette.purple.90": "oklch(0.916 0.061 303.6)"
```

**Semantic tokens**: What a value means. Used in components.
```json
"color.primary": { "$value": "{color.palette.purple.40}" }
"color.on-primary": { "$value": "{color.palette.purple.90}" }
```

**Component tokens**: Only for components that need to deviate from semantic.
```json
"component.button.danger.background": { "$value": "{color.error}" }
```

### 1.3 Token Pipeline Flow

```
tokens/tokens.json (DTCG source)
         ↓
Style Dictionary v4 transforms
         ↓
     ┌───┴───┐
     ↓       ↓
CSS          Tailwind @theme
iOS Swift    Android XML
JSON (resolved)
```

---

## 2. W3C DTCG Format

### 2.1 File Structure

```
tokens/
├── tokens.json           # Main DTCG file (reference + semantic)
├── tokens.dark.json      # Dark mode overrides
├── tokens.brand.json     # Brand-specific overrides (for white-labeling)
└── outputs/              # Generated files (never edit these)
    ├── globals.css
    ├── tailwind.theme.ts
    ├── ios/
    │   └── ColorTokens.swift
    └── android/
        └── colors.xml
```

### 2.2 tokens.json Full Example

```json
{
  "$schema": "https://tr.designtokens.org/format/",

  "color": {
    "$description": "Color system",

    "palette": {
      "$description": "Reference palette — all available values",
      "purple": {
        "10": { "$value": "oklch(0.154 0.098 303.6)", "$type": "color" },
        "20": { "$value": "oklch(0.232 0.145 303.6)", "$type": "color" },
        "30": { "$value": "oklch(0.317 0.171 303.6)", "$type": "color" },
        "40": { "$value": "oklch(0.428 0.174 303.6)", "$type": "color" },
        "50": { "$value": "oklch(0.529 0.168 303.6)", "$type": "color" },
        "80": { "$value": "oklch(0.805 0.105 303.6)", "$type": "color" },
        "90": { "$value": "oklch(0.916 0.061 303.6)", "$type": "color" },
        "95": { "$value": "oklch(0.958 0.034 303.6)", "$type": "color" },
        "99": { "$value": "oklch(0.995 0.007 303.6)", "$type": "color" },
        "100": { "$value": "oklch(1 0 0)", "$type": "color" }
      },
      "neutral": {
        "0": { "$value": "oklch(0 0 0)", "$type": "color" },
        "10": { "$value": "oklch(0.145 0 0)", "$type": "color" },
        "20": { "$value": "oklch(0.237 0 0)", "$type": "color" },
        "90": { "$value": "oklch(0.922 0 0)", "$type": "color" },
        "95": { "$value": "oklch(0.961 0 0)", "$type": "color" },
        "97": { "$value": "oklch(0.975 0 0)", "$type": "color" },
        "99": { "$value": "oklch(0.995 0 0)", "$type": "color" },
        "100": { "$value": "oklch(1 0 0)", "$type": "color" }
      },
      "red": {
        "40": { "$value": "oklch(0.428 0.225 27.325)", "$type": "color" },
        "90": { "$value": "oklch(0.916 0.088 27.325)", "$type": "color" }
      }
    },

    "primary": {
      "$value": "{color.palette.purple.40}",
      "$type": "color",
      "$description": "Main brand color"
    },
    "on-primary": {
      "$value": "{color.palette.purple.100}",
      "$type": "color",
      "$description": "Text/icon on primary color"
    },
    "primary-container": {
      "$value": "{color.palette.purple.90}",
      "$type": "color"
    },
    "on-primary-container": {
      "$value": "{color.palette.purple.10}",
      "$type": "color"
    },

    "secondary": { "$value": "{color.palette.neutral.90}", "$type": "color" },
    "on-secondary": { "$value": "{color.palette.neutral.10}", "$type": "color" },

    "background": { "$value": "{color.palette.neutral.99}", "$type": "color" },
    "on-background": { "$value": "{color.palette.neutral.10}", "$type": "color" },
    "surface": { "$value": "{color.palette.neutral.99}", "$type": "color" },
    "on-surface": { "$value": "{color.palette.neutral.10}", "$type": "color" },
    "surface-variant": { "$value": "{color.palette.neutral.90}", "$type": "color" },
    "outline": { "$value": "{color.palette.neutral.20}", "$type": "color" },

    "error": { "$value": "{color.palette.red.40}", "$type": "color" },
    "on-error": { "$value": "{color.palette.purple.100}", "$type": "color" },
    "error-container": { "$value": "{color.palette.red.90}", "$type": "color" }
  },

  "typography": {
    "font-family": {
      "sans": { "$value": "'Inter Variable', ui-sans-serif, system-ui", "$type": "fontFamily" },
      "mono": { "$value": "'JetBrains Mono', ui-monospace", "$type": "fontFamily" }
    },
    "font-size": {
      "xs": { "$value": "0.75rem", "$type": "dimension" },
      "sm": { "$value": "0.875rem", "$type": "dimension" },
      "md": { "$value": "1rem", "$type": "dimension" },
      "lg": { "$value": "1.125rem", "$type": "dimension" },
      "xl": { "$value": "1.25rem", "$type": "dimension" },
      "2xl": { "$value": "1.5rem", "$type": "dimension" },
      "3xl": { "$value": "1.875rem", "$type": "dimension" },
      "4xl": { "$value": "2.25rem", "$type": "dimension" }
    },
    "font-weight": {
      "regular": { "$value": "400", "$type": "fontWeight" },
      "medium": { "$value": "500", "$type": "fontWeight" },
      "semibold": { "$value": "600", "$type": "fontWeight" },
      "bold": { "$value": "700", "$type": "fontWeight" }
    }
  },

  "spacing": {
    "0": { "$value": "0", "$type": "dimension" },
    "1": { "$value": "0.25rem", "$type": "dimension" },
    "2": { "$value": "0.5rem", "$type": "dimension" },
    "3": { "$value": "0.75rem", "$type": "dimension" },
    "4": { "$value": "1rem", "$type": "dimension" },
    "6": { "$value": "1.5rem", "$type": "dimension" },
    "8": { "$value": "2rem", "$type": "dimension" },
    "12": { "$value": "3rem", "$type": "dimension" },
    "16": { "$value": "4rem", "$type": "dimension" },
    "24": { "$value": "6rem", "$type": "dimension" }
  },

  "radius": {
    "none": { "$value": "0", "$type": "dimension" },
    "sm": { "$value": "0.25rem", "$type": "dimension" },
    "md": { "$value": "0.5rem", "$type": "dimension" },
    "lg": { "$value": "0.75rem", "$type": "dimension" },
    "xl": { "$value": "1rem", "$type": "dimension" },
    "full": { "$value": "9999px", "$type": "dimension" }
  }
}
```

---

## 3. Style Dictionary v4 Configuration

### 3.1 style-dictionary.config.js

```javascript
import StyleDictionary from 'style-dictionary';
import { register } from '@tokens-studio/sd-transforms';

// Register token studio transforms (handles DTCG format)
register(StyleDictionary);

export default {
  source: ['tokens/tokens.json'],

  platforms: {
    css: {
      transformGroup: 'tokens-studio',
      transforms: ['ts/color/css/hexrgba'],
      prefix: '',
      buildPath: 'tokens/outputs/',
      files: [{
        destination: 'globals.css',
        format: 'css/variables',
        options: {
          selector: ':root',
          outputReferences: false,
        },
        filter: (token) => token.attributes.category !== 'palette',
      }],
    },

    'css-dark': {
      source: ['tokens/tokens.json', 'tokens/tokens.dark.json'],
      transformGroup: 'tokens-studio',
      buildPath: 'tokens/outputs/',
      files: [{
        destination: 'globals.dark.css',
        format: 'css/variables',
        options: {
          selector: '.dark',
        },
        filter: (token) => token.attributes.category !== 'palette',
      }],
    },

    tailwind: {
      transformGroup: 'tokens-studio',
      buildPath: 'tokens/outputs/',
      files: [{
        destination: 'tailwind.theme.ts',
        format: 'javascript/module',
        options: {
          outputReferences: false,
        },
      }],
    },

    ios: {
      transformGroup: 'ios-swift',
      buildPath: 'tokens/outputs/ios/',
      files: [{
        destination: 'ColorTokens.swift',
        format: 'ios-swift/class.swift',
        className: 'ColorTokens',
        filter: (token) => token.attributes.category === 'color',
      }],
    },

    android: {
      transformGroup: 'android',
      buildPath: 'tokens/outputs/android/',
      files: [{
        destination: 'colors.xml',
        format: 'android/colors',
        filter: (token) => token.attributes.category === 'color',
      }],
    },
  },
};
```

---

## 4. Output Files

### 4.1 CSS Output (`tokens/outputs/globals.css`)

```css
/* Generated by Style Dictionary — DO NOT EDIT */
:root {
  --color-primary: oklch(0.428 0.174 303.6);
  --color-on-primary: oklch(1 0 0);
  --color-primary-container: oklch(0.916 0.061 303.6);
  --color-background: oklch(0.995 0 0);
  --color-on-background: oklch(0.145 0 0);
  --color-surface: oklch(0.995 0 0);
  --color-outline: oklch(0.237 0 0);
  --color-error: oklch(0.428 0.225 27.325);

  --typography-font-family-sans: 'Inter Variable', ui-sans-serif, system-ui;
  --typography-font-size-md: 1rem;
  --typography-font-weight-medium: 500;

  --spacing-4: 1rem;
  --spacing-8: 2rem;

  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
}
```

### 4.2 Tailwind v4 @theme Integration

```css
/* app/globals.css — imports generated tokens */
@import "tailwindcss";
@import "tokens/outputs/globals.css";

@theme {
  /* Map DTCG tokens to Tailwind utilities */
  --color-primary: var(--color-primary);
  --color-primary-foreground: var(--color-on-primary);
  --color-background: var(--color-background);
  --color-foreground: var(--color-on-background);
  --color-error: var(--color-error);
  --color-border: var(--color-outline);

  --font-sans: var(--typography-font-family-sans);
  --radius: var(--radius-md);
}
```

### 4.3 iOS Swift Output

```swift
// Generated by Style Dictionary — DO NOT EDIT
import UIKit

public class ColorTokens: NSObject {
  public static let primary = UIColor(
    red: 0.428, green: 0.174, blue: 0.303, alpha: 1.0
  )
  public static let onPrimary = UIColor.white
  public static let background = UIColor(
    red: 0.995, green: 0.995, blue: 0.995, alpha: 1.0
  )
  public static let error = UIColor(
    red: 0.428, green: 0.225, blue: 0.027, alpha: 1.0
  )
}
```

### 4.4 Android XML Output

```xml
<!-- Generated by Style Dictionary — DO NOT EDIT -->
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <color name="color_primary">#6C28CC</color>
  <color name="color_on_primary">#FFFFFF</color>
  <color name="color_background">#FEFEFE</color>
  <color name="color_error">#C3402B</color>
</resources>
```

---

## 5. Figma Variables + MCP Server Integration

### 5.1 Figma → Code Sync

```
Figma Variables (designer updates colors)
         ↓
Figma MCP server (design-token-manager agent reads)
         ↓
tokens/tokens.json (DTCG format, updated)
         ↓
git commit "feat: update design tokens from Figma"
         ↓
CI runs Style Dictionary
         ↓
All platform outputs updated automatically
```

### 5.2 design-token-manager Agent: Figma Sync Command

```typescript
// Agent command: /token-sync
async function syncFromFigma() {
  // 1. Read current Figma variables via MCP
  const figmaTokens = await mcp.figma.getVariables({ fileId: FIGMA_FILE_ID });

  // 2. Convert to DTCG format
  const dtcgTokens = convertFigmaToDTCG(figmaTokens);

  // 3. Compare with current tokens.json
  const diff = diffTokens(currentTokens, dtcgTokens);
  if (diff.length === 0) {
    console.log('Tokens are up to date');
    return;
  }

  // 4. Validate: check for breaking changes
  const breaking = detectBreakingChanges(diff);
  if (breaking.length > 0) {
    await notifyUser(`Breaking token changes detected: ${breaking.join(', ')}. Review required.`);
    return;
  }

  // 5. Update tokens.json
  await writeFile('tokens/tokens.json', JSON.stringify(dtcgTokens, null, 2));

  // 6. Run Style Dictionary
  await exec('pnpm tokens:build');

  // 7. Commit
  await git.commit('feat: update design tokens from Figma');
}
```

---

## 6. Verification: Contrast Ratio Checking

OKLCH enables programmatic contrast ratio calculation:

```typescript
import { parse as parseColor, oklch } from 'culori';
import { wcagContrast } from 'culori';

function checkContrastRatio(
  foreground: string,
  background: string,
  level: 'AA' | 'AAA' = 'AA'
): { pass: boolean; ratio: number; required: number } {
  const fg = parseColor(foreground);
  const bg = parseColor(background);
  const ratio = wcagContrast(fg, bg);
  const required = level === 'AA' ? 4.5 : 7.0;

  return { pass: ratio >= required, ratio, required };
}

// Run as part of CI
async function validateAllTokenContrasts() {
  const tokens = loadTokens();
  const pairs = [
    [tokens.color.primary, tokens['color.on-primary']],
    [tokens.color.background, tokens['color.on-background']],
    [tokens.color.error, tokens['color.on-error']],
  ];

  const failures = pairs
    .map(([bg, fg]) => checkContrastRatio(fg, bg))
    .filter(result => !result.pass);

  if (failures.length > 0) {
    throw new Error(`Contrast ratio failures: ${JSON.stringify(failures)}`);
  }
}
```

This runs in CI as part of the token build step, ensuring WCAG AA compliance is maintained as tokens evolve.

---

## 7. CI Integration

```yaml
# In .github/workflows/ci.yml
- name: Build design tokens
  run: pnpm tokens:build

- name: Check token contrast ratios
  run: pnpm tokens:verify-contrast

- name: Check for uncommitted token changes
  run: |
    if [[ -n $(git diff tokens/outputs/) ]]; then
      echo "Token outputs are out of sync. Run 'pnpm tokens:build' locally."
      exit 1
    fi
```

**package.json scripts**:
```json
{
  "scripts": {
    "tokens:build": "node tokens/style-dictionary.config.js",
    "tokens:verify-contrast": "ts-node tokens/verify-contrast.ts",
    "tokens:sync-figma": "claude-agent /token-sync"
  }
}
```
