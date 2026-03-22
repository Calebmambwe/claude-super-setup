---
name: design-system
description: Project visual identity, color palette, typography, component patterns
---

## Color Palette (Template -- customize per project)
- Primary: #6366f1 (Indigo)
- Secondary: #f59e0b (Amber)
- Background: #0f172a (Slate 900)
- Surface: #1e293b (Slate 800)
- Text: #f8fafc (Slate 50)
- Muted: #94a3b8 (Slate 400)
- Accent: #22d3ee (Cyan)
- Error: #ef4444
- Success: #22c55e

## Typography (Template -- customize per project)
- Headings: Space Grotesk, font-weight 700
- Body: DM Sans, font-weight 400/500
- Mono: JetBrains Mono
- Scale: 14/16/18/20/24/30/36/48/60

## Spacing Scale
Use Tailwind's default scale. Consistent padding:
- Cards: p-6
- Sections: py-16 md:py-24
- Container: max-w-7xl mx-auto px-4 sm:px-6 lg:px-8

## Border Radius
- Buttons: rounded-lg
- Cards: rounded-xl
- Inputs: rounded-md
- Modals: rounded-2xl

## Shadows
- Cards: shadow-lg shadow-black/10
- Elevated: shadow-xl shadow-black/20
- Buttons on hover: shadow-md

## Component Patterns

### Navbar
- Sticky, transparent on scroll, blur backdrop
- Logo left, nav center, CTA right
- Mobile: hamburger with slide-out

### Hero Section
- Full viewport height or min-h-[80vh]
- Background: gradient or SVG pattern
- Headline: text-5xl md:text-6xl font-bold
- Subheadline: text-xl text-muted max-w-2xl
- CTA: Two buttons (primary filled, secondary outline)

### Cards
- Surface color background
- Subtle border (border border-white/10)
- Hover: slight scale transform + shadow increase
- Consistent p-6 padding

### Buttons
- Primary: bg-primary text-white hover:bg-primary-dark
- Secondary: border border-primary text-primary hover:bg-primary/10
- Always include focus-visible ring
- Transition: transition-all duration-200

### Footer
- Multi-column layout
- Company info left, links center, newsletter right
- Copyright bar at bottom with border-t

## Anti-Patterns (NEVER DO)
- Never use pure black (#000) -- use slate-900 or similar
- Never mix border-radius styles on the same page
- Never use more than 3 font weights
- Never put text directly on images without overlay
- Never use default browser blue links
- Never skip hover/focus states on interactive elements
- Never hardcode hex values outside of design tokens
