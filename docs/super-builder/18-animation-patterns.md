# SSR-Safe Animation Patterns

## The Problem

Framer Motion + Next.js SSR = invisible content. When SSR renders `initial={{ opacity: 0 }}` into HTML, content is invisible until JS hydrates (3-8s over slow connections/ngrok). This is the #1 cause of "blank page" reports.

## The Three Rules

### Rule 1: Above-fold content uses `initial={false}`
```tsx
// CORRECT — content visible immediately
<motion.div initial={false} animate={{ opacity: 1, y: 0 }}>
  <h1>Visible from first paint</h1>
</motion.div>

// WRONG — content invisible until JS hydrates
<motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
  <h1>Invisible for 3-8 seconds</h1>
</motion.div>
```

### Rule 2: Below-fold content uses `whileInView` + `viewport={{ once: true }}`
```tsx
// CORRECT — content visible in SSR, animates when scrolled to
<motion.div
  initial={false}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, amount: 0.1 }}
>
  <p>Below the fold content</p>
</motion.div>
```

### Rule 3: Always include noscript fallback
```tsx
// In layout.tsx
<noscript>
  <style>{`
    [style*="opacity: 0"], [style*="opacity:0"] {
      opacity: 1 !important;
      transform: none !important;
    }
  `}</style>
</noscript>
```

## Safe Animation Patterns

### Entrance Animation (above-fold)
```tsx
<motion.div initial={false} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
  {children}
</motion.div>
```

### Scroll Reveal (below-fold)
```tsx
<motion.div
  initial={false}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, amount: 0.1 }}
  transition={{ duration: 0.6 }}
>
  {children}
</motion.div>
```

### Stagger Children
```tsx
const container = { visible: { transition: { staggerChildren: 0.08 } } };
const item = { visible: { opacity: 1, y: 0, transition: { duration: 0.5 } } };

<motion.div initial={false} animate="visible" variants={container}>
  {items.map(i => (
    <motion.div key={i} variants={item}>{i}</motion.div>
  ))}
</motion.div>
```

### Hover Effects (CSS preferred)
```tsx
// Use Tailwind, not Framer Motion
<div className="hover:-translate-y-0.5 hover:shadow-xl transition-all duration-200">
  {children}
</div>
```

### CSS-Only Animations (safest)
```css
/* Blinking cursor */
@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}
.cursor-blink { animation: blink 1.1s step-end infinite; }

/* Marquee scroll */
@keyframes marquee {
  0% { transform: translateX(0); }
  100% { transform: translateX(-50%); }
}

/* Pulsing dot */
@keyframes ping {
  75%, 100% { transform: scale(2); opacity: 0; }
}

/* Spinner */
.animate-spin { animation: spin 1s linear infinite; }
```

### Reduced Motion Respect
```tsx
const prefersReducedMotion = useReducedMotion();

<motion.div
  initial={false}
  whileInView={{ opacity: 1, y: 0 }}
  transition={{ duration: prefersReducedMotion ? 0 : 0.6 }}
>
```

## Anti-Patterns (NEVER DO)

```tsx
// NEVER: opacity 0 on above-fold
initial={{ opacity: 0 }}

// NEVER: hidden variant on above-fold
initial="hidden"  // where hidden = { opacity: 0 }

// NEVER: exit animation without AnimatePresence
<motion.div exit={{ opacity: 0 }} />  // won't work without AnimatePresence parent

// NEVER: layout animation on large containers (causes jank)
<motion.div layout>  // only for small elements like tabs, badges

// NEVER: spring animation on page transitions (too slow)
transition={{ type: "spring" }}  // use duration-based for page elements
```

## Validation Hook

The `ssr-safety-check.sh` hook catches violations:
1. Scans .tsx files for `initial={{ opacity: 0` or `initial="hidden"`
2. Checks if the component is above-fold (imported in page.tsx directly)
3. Verifies noscript fallback exists in layout.tsx
4. Warns on `whileInView` without `viewport={{ once: true }}`
