Implement the API endpoint: $ARGUMENTS

1. Read docs/api/openapi.yaml -- find the endpoint spec
2. Create Pydantic/Zod schemas matching the spec exactly
3. Create repository method (data access layer)
4. Create service method (business logic)
5. Create route handler (HTTP concerns only)
6. Write tests:
   - Unit test for the service (mock repository)
   - Integration test for the route (full request/response)
   - Verify response matches OpenAPI schema
   - Edge cases: invalid input, unauthorized, not found, conflict
7. Run tests and fix failures
8. Follow the backend-architecture skill for all patterns
