---
name: accessibility
description: WCAG 2.2 AA accessibility patterns, ARIA, focus management, color contrast
version: 1.0.0
tags: [accessibility, wcag, a11y, aria]
status: active
---

## Golden Rule

Prefer semantic HTML over ARIA. A `<button>` with text content is always better than `<div role="button" aria-label="...">`. ARIA supplements HTML; it does not replace it. When in doubt, use the native element.

---

## WCAG 2.2 AA Requirements Summary

WCAG 2.2 is organized around four principles: **Perceivable, Operable, Understandable, Robust**.

The criteria most commonly violated in web apps:

| Criterion | Level | Requirement |
|-----------|-------|-------------|
| 1.1.1 Non-text Content | A | Images need alt text (or `alt=""` for decorative) |
| 1.3.1 Info and Relationships | A | Structure conveyed through semantic HTML or ARIA |
| 1.3.5 Identify Input Purpose | AA | Form fields have `autocomplete` where applicable |
| 1.4.3 Contrast (Minimum) | AA | 4.5:1 for normal text, 3:1 for large text |
| 1.4.4 Resize Text | AA | Text resizes to 200% without loss of content |
| 1.4.10 Reflow | AA | Content reflows at 320px wide without horizontal scroll |
| 1.4.11 Non-text Contrast | AA | UI components/icons have 3:1 contrast against adjacent color |
| 1.4.13 Content on Hover/Focus | AA | Tooltips/popovers are dismissible, hoverable, persistent |
| 2.1.1 Keyboard | A | All functionality available by keyboard |
| 2.1.2 No Keyboard Trap | A | Focus can always be moved away via keyboard |
| 2.4.1 Bypass Blocks | A | Skip navigation link before repetitive content |
| 2.4.3 Focus Order | A | Focus order matches visual reading order |
| 2.4.7 Focus Visible | AA | Keyboard focus indicator is visible |
| 2.4.11 Focus Appearance (2.2) | AA | Focus indicator meets minimum size and contrast |
| 2.5.3 Label in Name | A | Visible label text is part of the accessible name |
| 3.1.1 Language of Page | A | `<html lang="...">` is present and correct |
| 3.3.1 Error Identification | A | Form errors are identified and described in text |
| 3.3.2 Labels or Instructions | A | Form inputs have associated labels |
| 4.1.2 Name, Role, Value | A | UI components expose name, role, and state to AT |
| 4.1.3 Status Messages | AA | Status messages are programmatically determinable |

New in WCAG 2.2 (beyond 2.1):
- **2.4.11 Focus Appearance**: Focus indicator must have 2px minimum perimeter and 3:1 contrast
- **2.5.7 Dragging Movements**: Drag actions have a single-pointer alternative
- **2.5.8 Target Size (Minimum)**: Touch targets are at least 24x24px
- **3.2.6 Consistent Help**: Help mechanisms appear in consistent location
- **3.3.7 Redundant Entry**: Previously entered info is auto-populated or selectable
- **3.3.8 Accessible Authentication**: No cognitive function test required for auth (no CAPTCHA without alternative)

---

## Required ARIA Attributes by Component

### Buttons

```tsx
// Icon-only button — must have aria-label
<button aria-label="Close dialog" type="button">
  <XIcon aria-hidden="true" size={20} />
</button>

// Toggle button — use aria-pressed
<button
  type="button"
  aria-pressed={isActive}
  onClick={() => setIsActive(p => !p)}
>
  Bold
</button>

// Button with loading state
<button type="submit" aria-disabled={isLoading} disabled={isLoading}>
  {isLoading ? <Spinner aria-hidden="true" /> : null}
  {isLoading ? 'Saving...' : 'Save'}
</button>
```

### Dialogs / Modals

```tsx
// Always: role="dialog", aria-modal="true", aria-labelledby
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="dialog-title"
  aria-describedby="dialog-desc"  // optional but recommended
>
  <h2 id="dialog-title">Confirm Delete</h2>
  <p id="dialog-desc">This action cannot be undone.</p>
  <button onClick={onConfirm}>Delete</button>
  <button onClick={onClose}>Cancel</button>
</div>
```

Focus behavior:
1. On open: move focus to the first focusable element inside the dialog (or the dialog itself with `tabIndex={-1}`)
2. While open: trap focus within the dialog (use `focus-trap-react`)
3. On close: return focus to the trigger element that opened the dialog

### Menus and Dropdowns

```tsx
// Trigger button
<button
  type="button"
  aria-haspopup="menu"
  aria-expanded={isOpen}
  aria-controls="user-menu"
  id="user-menu-trigger"
>
  Account
</button>

// Menu
<ul
  role="menu"
  id="user-menu"
  aria-labelledby="user-menu-trigger"
>
  <li role="none">
    <a role="menuitem" href="/profile">Profile</a>
  </li>
  <li role="none">
    <button role="menuitem" onClick={handleLogout}>Log out</button>
  </li>
</ul>
```

Keyboard behavior:
- `Enter`/`Space`: activate trigger, open menu
- `Arrow Down`/`Up`: move between menu items
- `Escape`: close menu, return focus to trigger
- `Home`/`End`: jump to first/last item

### Forms

```tsx
// Every input needs an associated label — use htmlFor + id
<div>
  <label htmlFor="email">
    Email address
    <span aria-hidden="true"> *</span>  {/* visual asterisk */}
  </label>
  <input
    id="email"
    type="email"
    name="email"
    required
    aria-required="true"
    aria-describedby="email-error"  // connect to error
    autoComplete="email"
    aria-invalid={hasError ? 'true' : undefined}
  />
  {hasError && (
    <p id="email-error" role="alert">
      Please enter a valid email address.
    </p>
  )}
</div>
```

Form group (radio/checkbox):
```tsx
<fieldset>
  <legend>Notification preferences</legend>
  <label>
    <input type="radio" name="notif" value="email" />
    Email
  </label>
  <label>
    <input type="radio" name="notif" value="sms" />
    SMS
  </label>
</fieldset>
```

### Tabs

```tsx
// Tab list
<div role="tablist" aria-label="Account settings">
  <button
    role="tab"
    id="tab-profile"
    aria-controls="panel-profile"
    aria-selected={activeTab === 'profile'}
    tabIndex={activeTab === 'profile' ? 0 : -1}
  >
    Profile
  </button>
  <button
    role="tab"
    id="tab-security"
    aria-controls="panel-security"
    aria-selected={activeTab === 'security'}
    tabIndex={activeTab === 'security' ? 0 : -1}
  >
    Security
  </button>
</div>

// Tab panels
<div
  role="tabpanel"
  id="panel-profile"
  aria-labelledby="tab-profile"
  hidden={activeTab !== 'profile'}
>
  {/* profile content */}
</div>
```

Keyboard: `Arrow Left`/`Right` moves between tabs (roving tabindex — see Focus Management section).

### Live Regions / Toasts

```tsx
// Polite — for non-urgent updates (success messages)
<div aria-live="polite" aria-atomic="true" className="sr-only">
  {statusMessage}
</div>

// Assertive — for errors and urgent alerts only
<div role="alert" aria-live="assertive" aria-atomic="true">
  {errorMessage}
</div>

// Toast container — always in the DOM, update content dynamically
export function ToastRegion() {
  return (
    <div
      aria-live="polite"
      aria-atomic="false"
      aria-relevant="additions text"
      className="fixed bottom-4 right-4 z-50"
    >
      {toasts.map(t => <Toast key={t.id} {...t} />)}
    </div>
  );
}
```

### Navigation

```tsx
// Primary nav — use <nav> with aria-label when multiple navs exist
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/" aria-current={isHome ? 'page' : undefined}>Home</a></li>
    <li><a href="/about" aria-current={isAbout ? 'page' : undefined}>About</a></li>
  </ul>
</nav>

// Breadcrumb
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Home</a></li>
    <li><a href="/products">Products</a></li>
    <li><span aria-current="page">Widget Pro</span></li>
  </ol>
</nav>
```

---

## Focus Management Patterns

### Skip Navigation

The skip nav link must be the very first focusable element in the DOM. It is `sr-only` by default and becomes visible on focus:

```tsx
// components/SkipNav.tsx
export function SkipNav({ targetId = 'main-content' }: { targetId?: string }) {
  return (
    <a
      href={`#${targetId}`}
      className={[
        'sr-only',
        'focus:not-sr-only',
        'focus:fixed focus:top-4 focus:left-4 focus:z-[9999]',
        'focus:px-4 focus:py-2',
        'focus:bg-background focus:text-foreground',
        'focus:rounded focus:shadow-lg',
        'focus:outline-none focus:ring-2 focus:ring-primary',
      ].join(' ')}
    >
      Skip to main content
    </a>
  );
}

// In layout.tsx
<body>
  <SkipNav />
  <Header />
  <main id="main-content" tabIndex={-1}>
    {children}
  </main>
</body>
```

`tabIndex={-1}` on `<main>` allows programmatic focus without adding it to the tab order.

### Focus Trap

Use `focus-trap-react` for any overlay (modal, drawer, popover with form content):

```tsx
// pnpm add focus-trap-react
import FocusTrap from 'focus-trap-react';

function Modal({ isOpen, onClose, initialFocusRef, children }) {
  return isOpen ? (
    <FocusTrap
      focusTrapOptions={{
        initialFocus: initialFocusRef?.current ?? undefined,
        returnFocusOnDeactivate: true,
        escapeDeactivates: true,
        onDeactivate: onClose,
      }}
    >
      <div role="dialog" aria-modal="true" aria-labelledby="modal-title">
        {children}
      </div>
    </FocusTrap>
  ) : null;
}
```

### Roving Tabindex (for composite widgets)

Used for tab lists, toolbars, radio groups, and menus — only one item in the group is in the tab order at a time:

```tsx
function TabList({ tabs, activeTab, onSelect }) {
  const refs = useRef<(HTMLButtonElement | null)[]>([]);

  function handleKeyDown(e: React.KeyboardEvent, index: number) {
    let next = index;
    if (e.key === 'ArrowRight') next = (index + 1) % tabs.length;
    if (e.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
    if (e.key === 'Home') next = 0;
    if (e.key === 'End') next = tabs.length - 1;
    if (next !== index) {
      e.preventDefault();
      onSelect(tabs[next].id);
      refs.current[next]?.focus();
    }
  }

  return (
    <div role="tablist">
      {tabs.map((tab, i) => (
        <button
          key={tab.id}
          ref={el => { refs.current[i] = el; }}
          role="tab"
          tabIndex={activeTab === tab.id ? 0 : -1}
          aria-selected={activeTab === tab.id}
          aria-controls={`panel-${tab.id}`}
          onKeyDown={e => handleKeyDown(e, i)}
          onClick={() => onSelect(tab.id)}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
```

### Focus Restoration

When closing a modal or removing a component that had focus, restore focus to the element that triggered it:

```tsx
function useDisclosure() {
  const [isOpen, setIsOpen] = useState(false);
  const triggerRef = useRef<HTMLElement | null>(null);

  function open(e: React.MouseEvent<HTMLElement>) {
    triggerRef.current = e.currentTarget;
    setIsOpen(true);
  }

  function close() {
    setIsOpen(false);
    // Restore focus after the DOM update
    setTimeout(() => triggerRef.current?.focus(), 0);
  }

  return { isOpen, open, close };
}
```

---

## Color Contrast Requirements

| Text Type | Minimum Ratio | WCAG Criterion |
|-----------|---------------|----------------|
| Normal text (< 18pt / < 14pt bold) | 4.5:1 | 1.4.3 AA |
| Large text (>= 18pt / >= 14pt bold) | 3:1 | 1.4.3 AA |
| UI components (borders, icons) | 3:1 | 1.4.11 AA |
| Focus indicators | 3:1 against adjacent color | 2.4.11 AA (2.2) |
| Disabled elements | Exempt | — |

**18pt = 24px. 14pt bold = ~18.67px bold.**

Checking contrast:
- Browser: Chrome DevTools > Accessibility > Color Contrast
- Online tool: https://webaim.org/resources/contrastchecker/
- Design: Figma plugins "Contrast" or "A11y - Color Contrast Checker"

Common pitfalls:
- Tailwind `text-gray-400` on white background = ~3.1:1 (fails for normal text)
- Tailwind `text-gray-500` on white background = ~4.6:1 (passes AA)
- Placeholder text is often too light — style it with sufficient contrast
- Disabled states are exempt but should still be visually distinct

---

## Common Violations and Fixes

### 1. Images Without Alt Text

```tsx
// Bad
<img src="/profile.jpg" />
<Image src="/hero.png" width={800} height={400} />

// Good — meaningful image
<img src="/profile.jpg" alt="Sarah Chen, CTO at Acme Corp" />
<Image src="/hero.png" alt="Dashboard showing monthly revenue chart" width={800} height={400} />

// Good — decorative (background, spacer, icon with adjacent text)
<img src="/wave-divider.svg" alt="" role="presentation" />
<Image src="/icon.png" alt="" aria-hidden={true} width={24} height={24} />
```

### 2. Missing Form Labels

```tsx
// Bad — placeholder is NOT a label
<input type="text" placeholder="First name" />

// Good
<label htmlFor="first-name">First name</label>
<input id="first-name" type="text" placeholder="John" />

// Good — visually hidden label (when design prohibits visible label)
<label htmlFor="search" className="sr-only">Search</label>
<input id="search" type="search" placeholder="Search..." />
```

### 3. Keyboard-Inaccessible Click Handlers

```tsx
// Bad
<div onClick={handleEdit} className="cursor-pointer">Edit</div>

// Good — use semantic elements
<button type="button" onClick={handleEdit}>Edit</button>
<a href="/edit/123">Edit</a>

// If you must use div (avoid this), add full keyboard support
<div
  role="button"
  tabIndex={0}
  onClick={handleEdit}
  onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') handleEdit(); }}
>
  Edit
</div>
```

### 4. Missing Focus Visible Styles

```css
/* Bad — globally removes focus rings */
* { outline: none; }
:focus { outline: none; }

/* Good — custom focus-visible ring */
:focus { outline: none; }
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
  border-radius: 4px;
}

/* Tailwind equivalent in component */
/* className="focus:outline-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary" */
```

### 5. No Skip Navigation

```tsx
// In app/layout.tsx — add before <Header />
import { SkipNav } from '@/components/SkipNav';

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <SkipNav />
        <Header />
        <main id="main-content" tabIndex={-1}>
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
```

### 6. Dialog Without Focus Trap

```tsx
// Bad — focus leaks outside modal
function BadModal({ onClose }) {
  return (
    <div className="modal">
      <button onClick={onClose}>Close</button>
    </div>
  );
}

// Good — focus is trapped
import FocusTrap from 'focus-trap-react';

function GoodModal({ onClose }) {
  return (
    <FocusTrap focusTrapOptions={{ onDeactivate: onClose }}>
      <div role="dialog" aria-modal="true" aria-labelledby="title">
        <h2 id="title">Modal Title</h2>
        <button onClick={onClose}>Close</button>
      </div>
    </FocusTrap>
  );
}
```

### 7. Dynamic Content Without Live Regions

```tsx
// Bad — screen readers don't announce the change
function SearchResults({ count }) {
  return <p>{count} results found</p>;
}

// Good — polite announcement
function SearchResults({ count }) {
  return (
    <>
      <p>{count} results found</p>
      <div aria-live="polite" className="sr-only">
        {count} results found
      </div>
    </>
  );
}

// Good — role="status" is shorthand for aria-live="polite" + aria-atomic="true"
function SaveStatus({ saved }) {
  return (
    <p role="status">
      {saved ? 'Changes saved' : ''}
    </p>
  );
}
```

### 8. Icon Buttons Without Labels

```tsx
// Bad — no accessible name
<button onClick={toggleMenu}>
  <MenuIcon />
</button>

// Good — aria-label
<button onClick={toggleMenu} aria-label="Open navigation menu" type="button">
  <MenuIcon aria-hidden="true" size={20} />
</button>

// Good — visually hidden text (preferred when localization matters)
<button onClick={toggleMenu} type="button">
  <MenuIcon aria-hidden="true" size={20} />
  <span className="sr-only">Open navigation menu</span>
</button>
```

---

## Testing Checklist

Run this checklist before shipping any UI feature:

### Automated
- [ ] `eslint-plugin-jsx-a11y` passes with zero errors
- [ ] axe-core finds zero critical/serious violations on all routes
- [ ] Color contrast verified for all text/background combinations

### Keyboard Navigation
- [ ] Tab through entire page — every interactive element is reachable
- [ ] Focus order is logical (matches visual reading order)
- [ ] Focus indicator is clearly visible on every interactive element
- [ ] Escape closes modals, drawers, and dropdowns
- [ ] Arrow keys navigate within composite widgets (menus, tabs, radio groups)
- [ ] Skip nav link appears on first Tab keypress and works correctly

### Screen Reader (VoiceOver on macOS: Cmd+F5, or NVDA on Windows)
- [ ] Page title is read on load
- [ ] All images convey their meaning through alt text
- [ ] All form fields announce their label
- [ ] Error messages are read when they appear
- [ ] Dynamic content updates (toasts, search results) are announced
- [ ] Modal announces its title when opened
- [ ] Current page in nav is announced (aria-current="page")

### Manual Visual Checks
- [ ] No content is obscured at 200% zoom
- [ ] Page content reflows at 320px viewport width
- [ ] Focus ring is visible at high contrast mode (Windows)
- [ ] Touch targets are minimum 44x44px (iOS) or 48x48dp (Android) for mobile

### HTML Structure
- [ ] `<html lang="...">` is set correctly
- [ ] Heading hierarchy is logical (one `<h1>`, then `<h2>`, etc.)
- [ ] Landmarks are used (`<main>`, `<nav>`, `<header>`, `<footer>`, `<aside>`)
- [ ] Lists use `<ul>`/`<ol>` — not styled `<div>`s
- [ ] Tables have `<th>` with `scope` attribute
- [ ] Forms use `<fieldset>`/`<legend>` for grouped controls

---

## Recommended Libraries

| Purpose | Library | Install |
|---------|---------|---------|
| Focus trap | focus-trap-react | `pnpm add focus-trap-react` |
| Accessible components | @radix-ui/react-* | `pnpm add @radix-ui/react-dialog` |
| Accessible components | @headlessui/react | `pnpm add @headlessui/react` |
| Static analysis | eslint-plugin-jsx-a11y | `pnpm add -D eslint-plugin-jsx-a11y` |
| Runtime testing | @axe-core/playwright | `pnpm add -D @axe-core/playwright` |
| Color contrast | @radix-ui/colors | `pnpm add @radix-ui/colors` |
| Screen reader utils | aria-query | `pnpm add aria-query` |

Prefer Radix UI primitives — they are fully accessible (keyboard, ARIA, focus management) out of the box. Wrapping Radix with your design system tokens is the recommended pattern over building accessible components from scratch.
