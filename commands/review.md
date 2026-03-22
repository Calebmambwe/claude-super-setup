Review all changes on the current branch:

1. Check backend changes:
   - Routes contain ONLY HTTP concerns?
   - Services have no HTTP imports?
   - All responses match OpenAPI spec?
   - Tests cover happy path + edge cases?
   - Input validation present?
   - No raw SQL / string interpolation?

2. Check frontend changes:
   - Colors from design tokens only?
   - Consistent border-radius and spacing?
   - Hover/focus states on all interactive elements?
   - Responsive design works?
   - No hardcoded values?

3. General:
   - No secrets/env values in code?
   - Descriptive variable names?
   - Conventional commit messages?

Report findings with severity (critical/warning/info).
