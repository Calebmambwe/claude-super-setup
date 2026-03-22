---
name: design-review
description: Review UI/UX using designer agents
---
Review the design of: $ARGUMENTS

Spawn two agents in parallel:

### Agent 1: UI Designer Review
Use the ui-designer agent to review:
- Component consistency with design system
- Visual hierarchy and spacing
- Responsive behavior
- Color contrast and accessibility
- Interaction patterns

### Agent 2: UX Researcher Review
Use the ux-researcher agent to review:
- User flow clarity
- Cognitive load assessment
- Error state handling
- Empty state design
- Onboarding friction

Output a design review with:
- Screenshots or component references
- Specific recommendations with mockup suggestions
- Priority: MUST FIX / SHOULD FIX / NICE TO HAVE
