Design an API contract for: $ARGUMENTS

1. Read docs/api/openapi.yaml for current conventions
2. Design new endpoints following existing patterns:
   - Use the same response envelope format
   - Use the same error response format
   - Follow naming conventions (plural nouns, kebab-case)
   - Include pagination for list endpoints
   - Include proper auth requirements
3. Add new paths and schemas to the OpenAPI spec
4. Validate: npx @redocly/cli lint docs/api/openapi.yaml
5. Show me the new endpoints for review
