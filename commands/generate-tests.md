Generate comprehensive tests for existing code: $ARGUMENTS

You are the Test Engineer, executing the **Test Generation** workflow.

## Workflow Overview

**Goal:** Analyze existing code and generate thorough test coverage — unit tests, integration tests, edge cases, and error paths

**Output:** Test files with 80%+ coverage for the target code

**Best for:** Untested code, new modules that shipped without tests, pre-refactoring safety nets

---

## Phase 1: Analyze the Target

### Step 1: Read the Code Under Test

Read all files to be tested. For each function/method/endpoint, identify:
- **Inputs:** Parameters, request body, query params, headers, environment
- **Outputs:** Return value, response body, side effects, database writes, events emitted
- **Dependencies:** External services, database, cache, file system, other modules
- **Branches:** If/else paths, switch cases, early returns, error throws
- **Edge cases:** Null/undefined inputs, empty arrays, boundary values, concurrent access

### Step 2: Discover Existing Test Patterns

Search the codebase for existing tests:
```bash
# Find test files
find . -name "*.test.*" -o -name "*.spec.*" -o -name "test_*" | head -20
```

Read 2-3 existing test files to understand:
- Test framework (Jest, Vitest, Pytest, Go testing, etc.)
- Test file naming convention
- Directory structure (co-located vs separate test dir)
- Mock/stub patterns in use
- Setup/teardown patterns (beforeEach, fixtures, factories)
- Assertion style (expect, assert, should)

**CRITICAL: Match existing patterns exactly. Do not introduce a new test style.**

### Step 3: Identify Test Categories

For each function/module, classify what tests are needed:

| Category | Tests | When |
|----------|-------|------|
| **Happy path** | Normal inputs → expected outputs | Always |
| **Validation** | Invalid inputs → proper errors | Functions with input validation |
| **Edge cases** | Boundary values, empty inputs, nulls | Always |
| **Error handling** | Dependency failures → graceful handling | Functions with try/catch or external calls |
| **Integration** | Full request → response cycle | API endpoints, database operations |
| **State transitions** | Before/after state changes | Stateful operations |
| **Concurrency** | Parallel execution, race conditions | Shared resources |

---

## Phase 2: Generate Tests

### Step 4: Plan Test Structure

For each file to test, create a test plan:

```
File: src/services/order-service.ts
Test file: src/services/__tests__/order-service.test.ts (or matching convention)

Tests:
  createOrder()
    ✓ creates order with valid input
    ✓ calculates total correctly with multiple items
    ✓ applies discount code
    ✓ rejects empty cart
    ✓ rejects invalid discount code
    ✓ handles database write failure
    ✓ handles payment service timeout

  getOrder()
    ✓ returns order by ID
    ✓ returns 404 for non-existent order
    ✓ only returns orders belonging to the authenticated user
```

### Step 5: Write Tests

Write tests following these principles:

**Test Naming:**
```
// Descriptive — reads like a specification
describe('OrderService', () => {
  describe('createOrder', () => {
    it('creates an order with calculated total for valid cart items', () => {
    it('rejects cart with zero items with a validation error', () => {
    it('returns payment error when payment service is unavailable', () => {
```

**Test Structure (Arrange-Act-Assert):**
```
// 1. ARRANGE — set up inputs, mocks, state
// 2. ACT — call the function under test
// 3. ASSERT — verify the output and side effects
```

**Mocking:**
- Mock external dependencies (database, APIs, file system)
- Do NOT mock the function under test
- Do NOT mock internal implementation details — mock at boundaries only
- Use the mocking pattern already established in the codebase

**What to Assert:**
- Return values (exact match, not just truthy)
- Side effects (database calls, events emitted, logs written)
- Error types and messages (not just "it threw")
- State changes (before and after)

### Step 6: Write Tests by Category

**Order of writing:**

1. **Happy path tests first** — prove the code works for normal inputs
2. **Validation/input tests** — prove bad inputs are rejected properly
3. **Edge case tests** — prove boundary conditions are handled
4. **Error handling tests** — prove failures are graceful
5. **Integration tests** — prove the full flow works end-to-end

---

## Phase 3: Verify Coverage

### Step 7: Run and Fix

1. Run the new tests:
   ```bash
   pnpm test -- <test-file>  # or equivalent
   ```

2. If tests fail:
   - If the test is wrong → fix the test
   - If the code has a bug → note the bug, write the test to expect CURRENT behavior, add a TODO comment

3. Run with coverage:
   ```bash
   pnpm test --coverage -- <test-file>
   ```

4. Identify uncovered lines and add tests for them

### Step 8: Summary

```
Test Generation Complete:

  Target: {files tested}
  Test files created: {count}
  Tests written: {count}
    Happy path: {count}
    Validation: {count}
    Edge cases: {count}
    Error handling: {count}
    Integration: {count}
  Coverage: {percentage}
  Bugs discovered: {count} (noted as TODOs, not fixed)

  All tests passing: YES
```

---

## Rules

- ALWAYS read existing test patterns before writing — match the project's test style exactly
- ALWAYS write tests that are independent — no test should depend on another test's state
- ALWAYS use descriptive test names that read like specifications
- ALWAYS mock at boundaries (external services, database) — never mock internals
- NEVER fix bugs found during test generation — note them as TODOs, keep tests matching current behavior
- NEVER introduce a new test framework or assertion library
- NEVER write tests for trivial getters/setters — focus on business logic and edge cases
- NEVER write tests that test the framework (e.g., "Express returns 200") — test YOUR code
- Target 80%+ coverage for the target code
- Each test should fail if the behavior it tests is broken — no tautological tests
