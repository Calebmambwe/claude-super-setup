# Design Token System

W3C DTCG-compliant design tokens for consistent UI across all projects.

## Format

Tokens are authored in [W3C Design Token Community Group (DTCG)](https://design-tokens.github.io/community-group/format/) format. Each token is an object with at minimum a `$value` and `$type`:

```json
{
  "color": {
    "primary": {
      "$value": "oklch(0.208 0.042 265.755)",
      "$type": "color",
      "$description": "Primary brand — CTAs, links, active states"
    }
  }
}
```

Supported `$type` values: `color`, `dimension`, `fontFamily`.

## Three-Tier Architecture

```
Reference tokens    Semantic tokens       Component tokens
(raw values)   →   (role-based aliases) → (component-scoped)

oklch(...)          color-primary          btn-bg
0.5rem              spacing-md             card-padding
```

- **Reference tokens** live in `tokens.json` — raw values only, no meaning attached.
- **Semantic tokens** (future) alias reference tokens to roles: `color-primary`, `spacing-section`, etc. These are what components consume.
- **Component tokens** (future) scope semantic tokens to a specific component: `btn-bg`, `card-radius`.

The current `tokens.json` covers the reference and semantic layers. Component tokens are defined inline per project as CSS custom property overrides.

## How to Build

No npm required — the build script uses Python 3 (stdlib only).

```bash
bash tokens/build-tokens.sh
```

This generates two files in `tokens/outputs/`:

| File | Purpose |
|---|---|
| `tokens.css` | `:root {}` block — import in any CSS project |
| `tailwind-theme.css` | Tailwind v4 `@theme {}` block — import in your main CSS |

The script also runs an approximate WCAG AA contrast check on key foreground/background pairs and prints a summary table.

## How to Use in Projects

### Any CSS project

```css
/* main.css */
@import "../tokens/outputs/tokens.css";

.btn-primary {
  background: var(--color-primary);
  color: var(--color-primary-foreground);
  border-radius: var(--radius-md);
  padding: var(--spacing-sm) var(--spacing-md);
}
```

### Tailwind v4 project

```css
/* app.css */
@import "tailwindcss";
@import "../tokens/outputs/tailwind-theme.css";
```

Tailwind v4 automatically maps `--color-*`, `--spacing-*`, and `--radius-*` custom properties to its utility classes.

### React / component libraries

Reference tokens via the CSS custom property names. Never hardcode hex values or arbitrary pixel values — always pull from `var(--color-*)`, `var(--spacing-*)`, etc.

## Token Reference

### Colors

| Token | Value | Role |
|---|---|---|
| `--color-primary` | oklch(0.208 0.042 265.755) | CTAs, links, active states |
| `--color-primary-foreground` | oklch(0.984 0.003 247.858) | Text on primary bg |
| `--color-background` | oklch(1 0 0) | Page background |
| `--color-foreground` | oklch(0.145 0.042 265.755) | Default text |
| `--color-muted` | oklch(0.968 0.007 247.896) | Subtle backgrounds |
| `--color-muted-foreground` | oklch(0.554 0.046 257.417) | Secondary text |
| `--color-destructive` | oklch(0.577 0.245 27.325) | Errors, danger actions |
| `--color-border` | oklch(0.921 0.013 255.508) | Dividers, input borders |
| `--color-success` | oklch(0.627 0.194 149.214) | Confirmations |
| `--color-warning` | oklch(0.769 0.188 70.08) | Warnings |
| `--color-info` | oklch(0.623 0.214 259.815) | Informational |

### Spacing

| Token | Value |
|---|---|
| `--spacing-xs` | 0.25rem (4px) |
| `--spacing-sm` | 0.5rem (8px) |
| `--spacing-md` | 1rem (16px) |
| `--spacing-lg` | 1.5rem (24px) |
| `--spacing-xl` | 2rem (32px) |
| `--spacing-2xl` | 3rem (48px) |
| `--spacing-section` | 6rem (96px) |

### Border Radius

| Token | Value |
|---|---|
| `--radius-sm` | 0.25rem |
| `--radius-md` | 0.375rem |
| `--radius-lg` | 0.5rem |
| `--radius-xl` | 0.75rem |
| `--radius-full` | 9999px |

### Typography

| Token | Value |
|---|---|
| `--font-sans` | Inter Variable, system-ui, sans-serif |
| `--font-heading` | Space Grotesk, system-ui, sans-serif |
| `--font-mono` | JetBrains Mono, monospace |

## Adding New Tokens

1. Add the token to `tokens.json` following DTCG format.
2. Run `bash tokens/build-tokens.sh` to regenerate outputs.
3. Commit both `tokens.json` and the updated `outputs/` files.

Do not add raw hex values — use `oklch()` for colors to stay in a perceptually uniform color space.
