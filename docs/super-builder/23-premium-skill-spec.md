# Premium App Generation Skill

## Purpose

A comprehensive skill that ensures every generated app looks like it was built by a top-tier design team. This skill is loaded for every /new-app, /clone-app, and /build command.

## Skill File: skills/premium-builder/SKILL.md

### Design Principles (always apply)
1. Less is more — whitespace is a feature, not a waste
2. Typography hierarchy is the #1 visual differentiator
3. Depth through shadows, not borders (except subtle ones)
4. Color comes from the brand, not from rainbow variety
5. Animations enhance understanding, they don't show off
6. Every element serves a purpose — remove anything decorative-only

### Typography Rules
- Display headlines: font-semibold, tracking-tight, text-balance
- Body: text-muted-foreground, leading-relaxed
- Overline labels: text-xs, uppercase, tracking-widest, font-semibold
- Maximum 2 font families (sans + mono)
- Never use font-light or font-thin (poor readability on screens)

### Color Rules
- Maximum 1 brand color + neutral scale
- Brand color only for: CTAs, active states, focus rings, badges
- Everything else: neutral scale (foreground, muted-foreground, border)
- Dark mode: lighten brand color by 10% for readability
- Never use more than 3 distinct hues per page

### Layout Rules
- Max content width: 1280px (max-w-7xl)
- Section padding: py-12 md:py-20 px-6
- Asymmetric layouts > uniform grids
- One hero mockup/visual > five abstract icons
- Cards: rounded-2xl, not rounded-md

### Component Rules
- Buttons: rounded-full for CTAs, rounded-lg for form actions
- Cards: glass-card effect (backdrop-blur + translucent bg)
- Inputs: rounded-lg, border-border, focus:ring-2 focus:ring-ring
- Tables: overflow-x-auto, rounded container, hover:bg-muted/30
- Badges: rounded-full, px-4 py-1.5, small text

### Visual Effect Rules
- Hero: radial glow behind headline, subtle grid pattern
- Cards: hover glow (blur-3xl, opacity transition)
- Shadows: layered (product-shadow for screenshots)
- Dividers: gradient accent lines (not solid)
- Loading: skeleton shimmer, not spinners (except inline)

### Anti-Patterns (NEVER)
- Rainbow color schemes
- Clip-art style icons or illustrations
- Stock photo heroes
- Excessive border radius (rounded-3xl on small elements)
- Drop shadows without diffuse shadows (shadow-lg alone)
- Centered text for more than 3 lines
- Justified text
- ALL CAPS for body text (only for overline labels)
- Underlined links (except in body text)
- Background patterns at > 5% opacity

### Page Templates

Every app type has a standard page structure:

#### Landing Page
1. Navbar (sticky, blur, logo + links + CTAs)
2. Hero (badge + headline + subline + CTAs + mockup)
3. Social proof (logos marquee or avatar stack + stat)
4. Features (asymmetric grid, 1 large + 4 small)
5. How it works (steps or terminal demo)
6. Testimonials (quote cards, 3 max)
7. Pricing (3 tiers, comparison table)
8. CTA (dark card with glow)
9. Footer (accent divider + newsletter + 6 columns)

#### Dashboard
1. Sidebar (collapsible, logo, nav items, user menu)
2. Header (breadcrumb, search, notifications)
3. Content area (cards, tables, charts)
4. Empty states (illustration + CTA)

#### Auth Pages
1. Centered card (max-w-md)
2. Logo + heading
3. Social OAuth button(s)
4. Divider "or continue with email"
5. Form fields with validation
6. Submit button (full width, primary)
7. Footer link (already have account? / don't have?)

## Quality Checklist (run before declaring any page complete)

- [ ] No hardcoded hex colors (all from tokens)
- [ ] No arbitrary spacing (all from scale)
- [ ] Typography hierarchy correct (only 1 h1 per page)
- [ ] All images have alt text
- [ ] All buttons have accessible names
- [ ] All form inputs have labels
- [ ] All links have valid href (not "#")
- [ ] Touch targets >= 44px
- [ ] No horizontal scroll at 390px
- [ ] No invisible content (check initial={false})
- [ ] Hover states on all interactive elements
- [ ] Focus rings on all focusable elements
- [ ] Loading states for async operations
- [ ] Error states for form validation
- [ ] Empty states when no data
