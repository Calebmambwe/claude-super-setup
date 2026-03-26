# Accessibility Framework

## Overview

WCAG 2.2 AA compliance should be built into every scaffolded project from day one, not retrofitted after launch. Retrofitting accessibility is 10-100x more expensive than building it in from the start. This framework defines the requirements, tools, and patterns to make WCAG 2.2 AA the baseline for all web templates.

---

## 1. WCAG 2.2 AA: Target Standard

### Why WCAG 2.2 AA

- **Legal requirement**: ADA (US), AODA (Canada), EUAA (EU Directive 2025), EN 301 549 (Europe) all reference WCAG 2.2 AA
- **User impact**: ~15% of people globally have a disability. Inaccessible apps exclude them.
- **Business case**: Accessible apps are often better for everyone (keyboard navigation, clear labels, sufficient contrast)

### WCAG 2.2 AA Requirements Summary

**Perceivable**
- All images have alt text (or empty alt for decorative)
- Color is never the sole means of conveying information
- Text contrast ratio ≥ 4.5:1 (normal text) or 3:1 (large text, >18pt or >14pt bold)
- Audio/video have captions and transcripts

**Operable**
- All functionality available via keyboard
- No keyboard trap (user can navigate away from any element)
- Focus is visible (`:focus-visible` styles)
- Skip navigation link at top of page
- No timing requirements (or user can adjust/extend)
- No content that flashes more than 3 times per second

**Understandable**
- Language of page is set (`<html lang="en">`)
- Error messages identify the field and describe what's needed
- Labels are associated with inputs (explicit or implicit)
- Form validation doesn't surprise the user

**Robust**
- HTML is valid and parseable
- ARIA roles and properties are used correctly
- Status messages are announced to screen readers

---

## 2. ESLint: Static Analysis with jsx-a11y

### Installation

```bash
pnpm add -D eslint-plugin-jsx-a11y
```

### ESLint Configuration

```js
// .eslintrc.cjs
module.exports = {
  extends: [
    'next/core-web-vitals',
    'plugin:jsx-a11y/recommended',
  ],
  plugins: ['jsx-a11y'],
  rules: {
    // Upgrade recommended to errors (not warnings)
    'jsx-a11y/alt-text': 'error',
    'jsx-a11y/aria-props': 'error',
    'jsx-a11y/aria-proptypes': 'error',
    'jsx-a11y/aria-unsupported-elements': 'error',
    'jsx-a11y/click-events-have-key-events': 'error',
    'jsx-a11y/interactive-supports-focus': 'error',
    'jsx-a11y/label-has-associated-control': 'error',
    'jsx-a11y/no-noninteractive-element-interactions': 'warn',
    'jsx-a11y/role-has-required-aria-props': 'error',

    // Additional rules for WCAG 2.2
    'jsx-a11y/anchor-has-content': 'error',
    'jsx-a11y/button-has-type': 'error',
    'jsx-a11y/heading-has-content': 'error',
  },
};
```

### What jsx-a11y Catches

| Rule | What it prevents |
|------|-----------------|
| `alt-text` | Images without alt text |
| `click-events-have-key-events` | `onClick` without `onKeyDown` |
| `label-has-associated-control` | Inputs without labels |
| `aria-props` | Invalid ARIA attribute names |
| `interactive-supports-focus` | Interactive elements that can't receive focus |
| `anchor-has-content` | Empty `<a>` links |
| `button-has-type` | Buttons without `type` attribute |

---

## 3. Axe-Core: Runtime Testing

### Why Runtime Testing Is Needed

jsx-a11y is static — it can only see the JSX structure. Some accessibility issues only manifest at runtime:
- Contrast ratios (depend on computed styles, not source)
- ARIA states (depend on JavaScript state)
- Focus management (depends on interaction flow)
- Dynamic content announcements

axe-core tests the rendered DOM.

### Installation

```bash
pnpm add -D @axe-core/react axe-core jest-axe vitest-axe
```

### Integration with Vitest

```typescript
// src/test/setup.ts
import { expect } from 'vitest';
import { toHaveNoViolations } from 'vitest-axe';

expect.extend(toHaveNoViolations);
```

### Usage in Tests

```typescript
// src/components/Button.test.tsx
import { render } from '@testing-library/react';
import { axe } from 'vitest-axe';
import { Button } from './Button';

describe('Button accessibility', () => {
  it('has no accessibility violations', async () => {
    const { container } = render(
      <Button variant="primary">Submit Form</Button>
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('disabled state is accessible', async () => {
    const { container } = render(
      <Button variant="primary" disabled>
        Submit Form
      </Button>
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
```

### Test Utility for Easy A11y Testing

```typescript
// src/test/a11y.ts
import { render, RenderOptions } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'vitest-axe';
import { expect } from 'vitest';

expect.extend(toHaveNoViolations);

/**
 * Renders a component and asserts it has no accessibility violations.
 * Use this for every component's primary test.
 */
export async function renderAccessible(
  ui: React.ReactElement,
  options?: RenderOptions
) {
  const result = render(ui, options);
  const violations = await axe(result.container);
  expect(violations).toHaveNoViolations();
  return result;
}
```

---

## 4. Focus Management Patterns

### 4.1 Visible Focus

Every interactive element must have a visible focus indicator.

```css
/* Never do this: */
*:focus { outline: none; }

/* Do this instead: */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
  border-radius: var(--radius-sm);
}

/* For elements where outline looks bad (e.g., buttons with complex shapes) */
.btn:focus-visible {
  box-shadow: 0 0 0 3px var(--color-background), 0 0 0 5px var(--color-primary);
  outline: none;
}
```

### 4.2 Modal Focus Trap

When a modal opens, keyboard focus should be trapped within it.

```typescript
// Using Radix UI Dialog (handles this automatically):
import * as Dialog from '@radix-ui/react-dialog';

function Modal({ open, onClose, children }) {
  return (
    <Dialog.Root open={open} onOpenChange={onClose}>
      <Dialog.Overlay className="fixed inset-0 bg-black/50" />
      <Dialog.Content className="...">
        {/* Focus is automatically trapped here by Radix */}
        {children}
        <Dialog.Close>Close</Dialog.Close>
      </Dialog.Content>
    </Dialog.Root>
  );
}
```

**Important**: Radix UI Dialog handles focus trapping, initial focus, and return focus on close. Use Radix primitives instead of building these behaviors manually.

### 4.3 Focus Restoration

When a modal or drawer closes, focus should return to the element that opened it.

```typescript
// Radix handles this automatically. For custom implementations:
function useRestoredFocus(isOpen: boolean) {
  const triggerRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      triggerRef.current = document.activeElement as HTMLElement;
    } else if (triggerRef.current) {
      triggerRef.current.focus();
      triggerRef.current = null;
    }
  }, [isOpen]);
}
```

### 4.4 Dynamic Content Focus

When new content appears (success message, error, dynamic result), move focus to it:

```typescript
function SearchResults({ results, isLoading }) {
  const resultsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (results.length > 0 && resultsRef.current) {
      resultsRef.current.focus();
    }
  }, [results.length]);

  return (
    <div
      ref={resultsRef}
      tabIndex={-1}  // Makes non-interactive element focusable programmatically
      aria-live="polite"
      aria-label={`${results.length} search results`}
    >
      {results.map(result => <ResultCard key={result.id} {...result} />)}
    </div>
  );
}
```

---

## 5. Skip Navigation

### 5.1 What It Is

A "skip to main content" link at the very top of the page that allows keyboard users to bypass repeated navigation and jump directly to the main content.

### 5.2 Implementation

```typescript
// src/components/layout/SkipNav.tsx
export function SkipNav() {
  return (
    <a
      href="#main-content"
      className="
        sr-only focus:not-sr-only
        absolute top-0 left-0 z-50
        bg-primary text-primary-foreground
        px-4 py-2 rounded-br-lg
        focus:outline-none focus:ring-2 focus:ring-ring
      "
    >
      Skip to main content
    </a>
  );
}

// In layout.tsx:
export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <SkipNav />
        <Header />
        <main id="main-content">  {/* ← matches href="#main-content" */}
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
```

The `sr-only` class hides it visually but keeps it in the DOM. `focus:not-sr-only` makes it visible when focused (keyboard Tab from the top of the page).

---

## 6. ARIA Attribute Requirements

### 6.1 Essential ARIA Patterns

**Loading states**:
```tsx
<Button aria-busy={isLoading} disabled={isLoading}>
  {isLoading ? 'Saving...' : 'Save'}
</Button>
```

**Error states**:
```tsx
<div>
  <Input
    id="email"
    aria-invalid={!!errors.email}
    aria-describedby={errors.email ? 'email-error' : undefined}
  />
  {errors.email && (
    <p id="email-error" role="alert" className="text-destructive">
      {errors.email.message}
    </p>
  )}
</div>
```

**Live regions** (for dynamic updates):
```tsx
<div aria-live="polite" aria-atomic="true">
  {statusMessage}
</div>
```

**Icon-only buttons**:
```tsx
<button aria-label="Close dialog" onClick={onClose}>
  <XIcon aria-hidden="true" />  {/* Icon is decorative when button has aria-label */}
</button>
```

### 6.2 Landmark Roles

Every page should have proper landmark roles for screen reader navigation:

```tsx
<header role="banner">         {/* Or use <header> element */}
<nav aria-label="Main">        {/* Use aria-label to distinguish multiple navs */}
<main id="main-content">       {/* One per page */}
<aside aria-label="Filters">   {/* Supplementary content */}
<footer role="contentinfo">    {/* Or use <footer> element */}
```

---

## 7. Color Contrast Guidelines

### 7.1 WCAG AA Requirements

| Text Type | Minimum Ratio |
|-----------|---------------|
| Normal text (< 18pt or < 14pt bold) | 4.5:1 |
| Large text (≥ 18pt or ≥ 14pt bold) | 3:1 |
| UI components and graphical objects | 3:1 |
| Decorative elements | No requirement |
| Inactive UI components | No requirement |

### 7.2 OKLCH Advantage for Contrast

OKLCH is a perceptually uniform color space. This means:
- You can predict how changing the L (lightness) value will affect contrast
- Generate accessible color pairs mathematically
- Dark mode colors can be validated the same way as light mode

```typescript
// Generate an accessible text color for any background
function getAccessibleTextColor(bgColor: string): string {
  const bg = parseColor(bgColor);
  const white = parseColor('oklch(1 0 0)');
  const black = parseColor('oklch(0 0 0)');

  const whiteContrast = wcagContrast(white, bg);
  const blackContrast = wcagContrast(black, bg);

  // Return whichever has better contrast
  return whiteContrast > blackContrast
    ? 'oklch(1 0 0)'  // white
    : 'oklch(0 0 0)'; // black
}
```

### 7.3 In Practice

Never communicate information using color alone:
```tsx
// Wrong: error is only communicated by color
<Input className={hasError ? 'border-red-500' : 'border-gray-300'} />

// Correct: error communicated by color + icon + text
<div>
  <Input
    className={cn(hasError && 'border-destructive')}
    aria-invalid={hasError}
    aria-describedby={hasError ? 'field-error' : undefined}
  />
  {hasError && (
    <p id="field-error" className="flex items-center gap-1 text-destructive">
      <AlertCircleIcon aria-hidden="true" className="h-4 w-4" />
      {errorMessage}
    </p>
  )}
</div>
```

---

## 8. Template Integration Checklist

Every new template must pass this checklist before being considered complete:

### Static (ESLint jsx-a11y)
- [ ] Zero jsx-a11y errors in ESLint
- [ ] `eslint-plugin-jsx-a11y` in devDependencies
- [ ] jsx-a11y/recommended + custom rules in ESLint config

### Runtime (axe-core)
- [ ] vitest-axe installed and configured in test setup
- [ ] Every component has at least one accessibility test
- [ ] Zero axe violations in all test scenarios

### Manual Verification
- [ ] Skip navigation link present (`SkipNav.tsx`)
- [ ] `<html lang="en">` in root layout
- [ ] All interactive elements have keyboard access
- [ ] All interactive elements have visible focus indicator
- [ ] Focus order is logical (follows visual layout)
- [ ] Screen reader announcements work for dynamic content

### Design Token Compliance
- [ ] All color values come from tokens (no hardcoded hex)
- [ ] Token contrast ratios verified ≥ 4.5:1 (normal text)
- [ ] Dark mode maintains all contrast requirements

### CI Gate
- [ ] `pnpm audit:a11y` runs in CI
- [ ] CI fails if any axe violations found
