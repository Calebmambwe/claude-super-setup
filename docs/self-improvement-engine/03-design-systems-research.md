# Modern Design Systems Research

## Overview

Design systems have matured significantly. The current generation (2024-2025) is characterized by three shifts: CSS-native token management (replacing JS-in-CSS), OKLCH color science (replacing hex/hsl), and AI-assisted component generation (Figma MCP, Google Stitch). This document captures the state of the art and its implications for our stack templates.

---

## Material Design 3 (Material You)

### Token Architecture

Material 3 introduced a three-tier token system that has become the industry reference model:

**Reference Tokens** (the palette — never used directly in components)
```
md-ref-palette-primary10: #21005D
md-ref-palette-primary20: #381E72
...
md-ref-palette-primary100: #FFFFFF
```

**Semantic Tokens** (role-based — what components use)
```
md-sys-color-primary: {md-ref-palette-primary40}
md-sys-color-on-primary: {md-ref-palette-primary100}
md-sys-color-primary-container: {md-ref-palette-primary90}
```

**Component Tokens** (component-specific overrides — rarely used)
```
md-comp-filled-button-container-color: {md-sys-color-primary}
```

**Key insight**: This three-tier architecture separates the "what color is available" (palette) from "what does this color mean" (role) from "what does this button use" (component). It enables theming without redesigning — change the palette, semantic tokens automatically update.

### Adaptive Layouts

Material 3's adaptive layout system uses five canonical breakpoints:

| Breakpoint | Range | Layout | Navigation Pattern |
|------------|-------|---------|-------------------|
| Compact | 0-599px | Single column | Bottom navigation bar |
| Medium | 600-839px | Two columns | Navigation rail |
| Expanded | 840-1199px | Three columns | Navigation drawer |
| Large | 1200-1599px | Four columns | Navigation drawer |
| Extra-large | 1600px+ | Five columns | Navigation drawer |

The adaptive layout system is particularly important for mobile-first development — it provides a principled approach to responsive design.

### Material Expressive (2025)

Material Expressive is the 2025 evolution of Material You, adding:
- Spring physics animations for all transitions
- Morphic shapes (components that flow between states with organic animation)
- Emotional color palettes (beyond functional color assignment)
- Variable fonts for dynamic expressiveness

**For our templates**: Material 3 tokens are the reference, but we should use the Tailwind/shadcn abstraction layer rather than Material directly in web templates. Flutter templates should use full Material 3.

---

## shadcn/ui: The New Standard for React Component Libraries

### Why shadcn/ui Won

shadcn/ui is not a component library — it's a component distribution system. You own the code. This distinction is fundamental:

- Traditional library: `npm install @company/ui` → components live in `node_modules`, you can't modify them
- shadcn/ui: `npx shadcn add button` → button source code copied into your repo, fully modifiable

This model aligns with the "explicit over implicit" principle and avoids the "fighting the library" problem.

### OKLCH Color Tokens

shadcn/ui v2 (late 2024) migrated to OKLCH color space. This is a significant improvement:

**Why OKLCH over HSL:**
- Perceptually uniform: changing L (lightness) by 10 units looks like the same change everywhere in the color space. HSL is not perceptually uniform.
- Better dark mode: OKLCH dark mode variants have consistent perceived contrast
- Mathematical color relationships: complementary colors, analogous palettes are calculable
- Accessibility: contrast ratios are more predictable (WCAG calculations work better)

**Token format:**
```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --border: oklch(0.922 0 0);
  --radius: 0.625rem;
}
```

### Registry System

The shadcn/ui registry system (2024) enables:
- Custom component registries (distribute your design system like shadcn distributes theirs)
- Component versioning and updates
- Dependency resolution (component A depends on component B)
- CLI-driven installation: `npx shadcn add your-registry/your-component`

**For our system**: We can build a custom registry for our design system. When a new project is scaffolded, it can pull from our registry.

### Three-Layer Architecture

shadcn/ui components are built on a three-layer stack:

1. **Radix UI Primitives** (bottom): Unstyled, accessible, behavior-correct headless components
2. **Tailwind CSS** (middle): Utility-class styling applied to Radix primitives
3. **shadcn/ui** (top): Opinionated component implementations with sensible defaults

This layering means: if you don't like shadcn's Button styling, modify it. If you don't like the animation, go to the Radix layer. The behaviors (focus trap, ARIA, keyboard nav) are always correct because they're in Radix.

---

## Tailwind CSS v4: CSS-First Configuration

### The @theme Directive

Tailwind v4 moved configuration from `tailwind.config.js` (JavaScript) to `globals.css` (CSS). This is architecturally significant:

```css
/* globals.css — Tailwind v4 */
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.205 0 0);
  --color-primary-foreground: oklch(0.985 0 0);
  --font-sans: "Inter Variable", sans-serif;
  --radius-lg: 0.625rem;
  --spacing-4: 1rem;
}
```

**Generated utilities**: Tailwind v4 automatically generates `text-primary`, `bg-primary`, `border-primary` etc. from the `--color-primary` token.

**Benefits**:
- Design tokens live in CSS, not JavaScript
- CSS custom properties are inspectable in browser DevTools
- Token values are available in CSS `calc()` expressions
- No build step needed to see token values

### Performance Improvements

Tailwind v4 uses a Rust-based engine (Oxide) for CSS generation:
- ~5x faster builds compared to v3
- Incremental compilation
- Zero-config content detection (no `content: [...]` array needed)

---

## Radix UI vs Ark UI: Headless Component Comparison

### Radix UI
- **Maturity**: High (3+ years in production)
- **Coverage**: 28 primitives (dialog, dropdown, tooltip, etc.)
- **React only**: No Vue/Svelte support
- **Framework**: shadcn/ui, Mantine, Radix Themes build on Radix

### Ark UI
- **Maturity**: Newer (2023+), growing
- **Coverage**: 50+ primitives
- **Multi-framework**: React, Vue, Solid, Svelte
- **Framework**: Chakra UI v3 builds on Ark

**Recommendation**: Use Radix for React-only projects (shadcn/ui ecosystem). Use Ark for multi-framework projects. Both provide excellent accessibility out of the box.

---

## NativeWind v4 + Gluestack UI v3: React Native Design Systems

### NativeWind v4

NativeWind brings Tailwind to React Native. v4 is a complete rewrite:
- Uses Tailwind v4 under the hood (CSS-first config)
- Proper TypeScript types for all utilities
- `className` prop on all React Native core components
- SSR support via Expo Router

```tsx
// NativeWind v4 usage
<View className="flex-1 bg-background p-4">
  <Text className="text-primary text-lg font-semibold">
    Hello World
  </Text>
</View>
```

### Gluestack UI v3

Gluestack UI v3 is a React Native component library built on:
- NativeWind v4 for styling
- Radix UI primitives for web (via universal components)
- Universal components: same API on iOS, Android, and Web

**The key differentiator**: Gluestack v3 components are truly universal — they render correctly on both React Native and web without any code changes. This enables a monorepo approach where one component library serves all platforms.

**Token configuration:**
```ts
// gluestack-ui.config.ts
const config = createConfig({
  aliases: {
    bg: 'backgroundColor',
    p: 'padding',
  },
  tokens: {
    colors: {
      primary: '#6200EE',
      'primary-foreground': '#FFFFFF',
    },
  },
});
```

---

## W3C Design Token Community Group (DTCG) Standard

The DTCG established a standard JSON format for design tokens. This is becoming the universal interchange format between design tools (Figma) and code.

### Token Format

```json
{
  "color": {
    "primary": {
      "$value": "oklch(0.205 0 0)",
      "$type": "color",
      "$description": "Primary brand color"
    }
  },
  "spacing": {
    "4": {
      "$value": "1rem",
      "$type": "dimension"
    }
  }
}
```

### Key Conventions
- All token keys starting with `$` are metadata (`$value`, `$type`, `$description`)
- Token groups are nested JSON objects
- References use `{group.token}` syntax: `"$value": "{color.primary}"`

**For our system**: Style Dictionary v4 reads DTCG format and outputs CSS custom properties, Tailwind config, iOS Swift color assets, and Android XML resources. This enables a single source of truth for all platform targets.

---

## Figma Dev Mode + MCP Server Integration

### Figma Dev Mode

Figma Dev Mode (2024) bridges the gap between design and implementation:
- Developers can inspect components with auto-generated code snippets
- CSS, React, iOS, Android code generation from components
- Design token export in W3C DTCG format
- Link to Storybook stories from Figma components

### Figma MCP Server

The Figma MCP server (released 2025) exposes Figma data to AI agents:
- Read design tokens from Figma variables
- Read component structures and variants
- Generate code from Figma frames
- Two-way sync: update Figma tokens from code

**For our system**: A `design-token-manager` agent can use the Figma MCP server to:
1. Read token changes from Figma
2. Update the DTCG token JSON
3. Run Style Dictionary to generate platform outputs
4. Commit the changes with a conventional commit

---

## Google Stitch: DESIGN.md Pattern

Google Stitch (2025) introduced the `DESIGN.md` pattern:

### What is DESIGN.md?

A `DESIGN.md` file at the project root documents:
- Visual design language (color palette, typography, spacing)
- Component inventory with descriptions
- Design token references
- Layout patterns and grid system
- Accessibility requirements

### Why It Matters for AI Agents

When an AI agent is asked to build UI, it typically has no design context. It invents arbitrary colors, sizing, and layouts. `DESIGN.md` gives the agent:
- Which design system is in use (Material 3, shadcn, custom)
- Which token names to use (not what values to hardcode)
- What the design intent is for each component

**For our templates**: Every scaffolded project should include a `DESIGN.md` that documents its design system configuration. This is a new file to add to all templates.

---

## Summary: Design System Implications for Templates

| Concern | Current State | Target State |
|---------|--------------|--------------|
| Color tokens | Hex values hardcoded | OKLCH via CSS custom properties |
| Token format | Various | W3C DTCG JSON |
| Token pipeline | Manual | Style Dictionary v4 |
| Web components | MUI / basic | shadcn/ui + Radix |
| Native components | Basic StyleSheet | NativeWind v4 + Gluestack v3 |
| Tailwind config | v3 JS config | v4 CSS-first @theme |
| Design documentation | None | DESIGN.md in every project |
| Figma integration | None | MCP server sync |
| Accessibility | Inconsistent | WCAG 2.2 AA via Radix primitives |
