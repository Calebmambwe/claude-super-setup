---
name: build-page
description: Build a frontend page section by section using the design system and shadcn/ui components
---
Build the frontend page: $ARGUMENTS

1. Read the design-system skill for visual constraints
2. **Pre-flight: shadcn registry check** (skip if no `components.json`):
   - Run `scripts/shadcn-skills-cache.sh .` to get/refresh cached registry context
   - Run `pnpm dlx shadcn@latest diff 2>/dev/null` to detect registry drift
   - If drift is found, note which components are customized before building
3. Check reference-designs/ for any visual references
4. Build section by section (not the entire page at once):
   - Navbar
   - Hero/header
   - Main content sections
   - Footer
5. Use shadcn/ui components as the base (only use components confirmed installed by registry check)
6. Apply design tokens from the skill (colors, fonts, spacing)
7. Include hover/focus states on all interactive elements
8. Ensure responsive design (mobile-first: 375px, 768px, 1024px, 1440px)
9. Run lint and typecheck after implementation
