# Testing Standards

## Rules
- Every new feature must have tests written alongside implementation
- Unit tests for business logic (mock dependencies)
- Integration tests for API endpoints (full request/response cycle)
- Contract tests: response matches OpenAPI spec exactly
- Target 80%+ coverage for new code

## Examples
```typescript
// Unit test — mock the repository, test the service
describe('UserService.create', () => {
  it('hashes password before storing', async () => {
    const repo = mockUserRepo();
    const service = new UserService(repo);
    await service.create({ email: 'a@b.com', password: 'secret' });
    expect(repo.save).toHaveBeenCalledWith(
      expect.objectContaining({ passwordHash: expect.any(String) })
    );
  });
});
```

## Contract Testing
- Use `openapi-typescript` + `fetch` wrapper to type-check API responses against the spec
- For Python: `schemathesis` to fuzz-test endpoints against the OpenAPI spec
- Contract tests run in CI alongside unit and integration tests
- Any response that doesn't match the OpenAPI spec is a test failure

## Anti-Patterns
- Writing tests after all code is complete — write them alongside
- Testing implementation details instead of behavior
- Skipping integration tests — unit tests alone miss wiring bugs
- No coverage threshold — set 80% minimum and enforce in CI
- No contract tests — responses must match the OpenAPI spec exactly
