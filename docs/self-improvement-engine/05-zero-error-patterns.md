# Zero-Error Delivery Patterns

## Overview

"Zero errors" is aspirational but directional. The goal is systematically reducing error rates in shipped code by applying advanced testing strategies that go beyond standard unit/integration tests. This document covers mutation testing, property-based testing, contract testing, and formal verification patterns applicable to our stack.

---

## Why Standard Testing Is Not Enough

Standard unit tests have a fundamental problem: they test what you thought to test, not all the ways the code can fail.

**The gap**:
```typescript
// You write this function
function divide(a: number, b: number): number {
  return a / b;
}

// You write this test
test('divide', () => {
  expect(divide(10, 2)).toBe(5);  // Passes
});

// But you didn't test:
// divide(10, 0)  → Infinity (not an error, but probably wrong)
// divide(NaN, 2) → NaN
// divide(1e308, 0.5) → Infinity (overflow)
// divide(-0, 1) → -0 (not equal to 0 in all contexts)
```

Standard tests verify the happy path. Advanced testing strategies verify the boundaries.

---

## Mutation Testing

### The Concept

Mutation testing works by intentionally introducing bugs into your code (mutations), then running your test suite. If your tests don't catch the mutation, they're inadequate.

**Example mutation**:
```typescript
// Original code
if (x > 0) { return "positive"; }

// Mutation 1: change operator
if (x >= 0) { return "positive"; }  // Should be caught

// Mutation 2: negate condition
if (!(x > 0)) { return "positive"; }  // Should be caught

// Mutation 3: change return value
if (x > 0) { return "negative"; }  // Should be caught
```

If your tests don't catch these mutations, your tests have gaps.

### Mutation Score

**Definition**: `mutation_score = killed_mutants / total_mutants`

- **Target**: > 80% mutation score
- **Current industry average**: ~60% for well-tested projects
- **What < 50% means**: Your tests are decorative. They don't validate behavior.

### Stryker (JavaScript/TypeScript)

```bash
npx stryker run
```

**Configuration** (`stryker.config.mjs`):
```js
export default {
  packageManager: 'pnpm',
  reporters: ['html', 'clear-text', 'progress'],
  testRunner: 'vitest',
  coverageAnalysis: 'perTest',
  mutate: ['src/**/*.ts', '!src/**/*.test.ts', '!src/**/*.spec.ts'],
  thresholds: {
    high: 80,
    low: 60,
    break: 50  // CI fails if score drops below 50
  }
};
```

**Key operators Stryker tests**:
- Arithmetic operators (`+` → `-`, `*` → `/`)
- Equality operators (`===` → `!==`, `>` → `>=`)
- Boolean literals (`true` → `false`)
- String literals (empty string replacement)
- Block removal (remove entire function body)

### mutmut (Python)

```bash
mutmut run
mutmut results
mutmut html  # generates HTML report
```

**Integration with pytest**:
```bash
mutmut run --paths-to-mutate src/ --runner "pytest tests/"
```

**Configuration** (`setup.cfg`):
```ini
[mutmut]
paths_to_mutate = src/
backup = False
runner = pytest
tests_dir = tests/
dict_synonyms = Struct, AttrDict
```

### CI Integration

```yaml
# .github/workflows/mutation.yml
- name: Run mutation tests
  run: npx stryker run
  env:
    STRYKER_DASHBOARD_API_KEY: ${{ secrets.STRYKER_DASHBOARD_API_KEY }}
- name: Fail if mutation score too low
  run: |
    score=$(cat reports/mutation/mutation.json | jq '.metrics.mutationScore')
    if (( $(echo "$score < 50" | bc -l) )); then
      echo "Mutation score $score is below threshold of 50"
      exit 1
    fi
```

---

## Property-Based Testing

### The Concept

Instead of writing specific examples, you describe the *properties* that should always hold, then the framework generates hundreds of random inputs to find counterexamples.

```typescript
// Traditional test: specific examples
test('sort is idempotent', () => {
  expect(sort([3,1,2])).toEqual([1,2,3]);  // Tests one case
});

// Property-based test: universal property
property('sort is idempotent', fc.array(fc.integer()), (arr) => {
  const sorted = sort(arr);
  expect(sort(sorted)).toEqual(sorted);  // Tests thousands of cases
});
```

### fast-check (JavaScript/TypeScript)

```typescript
import fc from 'fast-check';

// Test that JSON serialization is reversible
test('JSON roundtrip', () => {
  fc.assert(
    fc.property(
      fc.jsonObject(),  // Generates arbitrary JSON objects
      (obj) => {
        const serialized = JSON.stringify(obj);
        const deserialized = JSON.parse(serialized);
        expect(deserialized).toEqual(obj);
      }
    ),
    { numRuns: 1000 }
  );
});

// Test that user ID is always a valid UUID after creation
test('user creation always produces valid UUID', () => {
  fc.assert(
    fc.property(
      fc.record({
        email: fc.emailAddress(),
        name: fc.string({ minLength: 1, maxLength: 100 }),
      }),
      (userInput) => {
        const user = createUser(userInput);
        expect(user.id).toMatch(UUID_REGEX);
      }
    )
  );
});
```

### Hypothesis (Python)

```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers()))
def test_sort_is_stable(lst):
    """Sort should produce same result when run twice"""
    assert sorted(sorted(lst)) == sorted(lst)

@given(st.emails(), st.text(min_size=8))
def test_user_creation(email, password):
    """User creation should always produce valid user or raise specific errors"""
    try:
        user = create_user(email=email, password=password)
        assert user.id is not None
        assert user.email == email.lower()
    except ValidationError:
        pass  # Expected for invalid inputs
    except Exception as e:
        raise AssertionError(f"Unexpected exception: {e}")
```

### Key Properties to Test

For typical web applications:
- **Roundtrip properties**: Serialize → Deserialize → equals original
- **Idempotency**: Applying an operation twice gives same result as once
- **Monotonicity**: Adding more items never reduces a count
- **Boundary invariants**: IDs always valid format, timestamps always in valid range
- **Inverse operations**: Create → Delete → not found

---

## Contract Testing (Pact)

### The Concept

Contract testing verifies that a consumer and provider agree on an API contract, without requiring both services to be running simultaneously.

**Problem it solves**: Integration tests require both services running. In CI, this is slow and fragile. Contract tests verify the *agreement* without the *integration*.

### How Pact Works

1. **Consumer writes tests** that define what they expect from the provider
2. **Pact generates a contract** from those expectations
3. **Provider verifies the contract** against their actual implementation
4. **Pact Broker** stores contracts and verification results

### Consumer Test (Next.js API client)

```typescript
import { Pact } from '@pact-foundation/pact';
import { getUserById } from '../api/users';

const provider = new Pact({
  consumer: 'web-frontend',
  provider: 'user-service',
  port: 8080,
});

describe('User API contract', () => {
  beforeAll(() => provider.setup());
  afterAll(() => provider.finalize());

  it('returns user by ID', async () => {
    await provider.addInteraction({
      state: 'user with ID 1 exists',
      uponReceiving: 'a request for user 1',
      withRequest: {
        method: 'GET',
        path: '/users/1',
        headers: { Authorization: 'Bearer token' },
      },
      willRespondWith: {
        status: 200,
        body: {
          id: 1,
          email: 'test@example.com',
          name: 'Test User',
        },
      },
    });

    const user = await getUserById(1);
    expect(user.email).toBe('test@example.com');
  });
});
```

### Provider Verification (Express API)

```typescript
import { Verifier } from '@pact-foundation/pact';

describe('Provider verification', () => {
  it('validates consumer contracts', () => {
    return new Verifier({
      provider: 'user-service',
      providerBaseUrl: 'http://localhost:3001',
      pactBrokerUrl: process.env.PACT_BROKER_URL,
      publishVerificationResult: true,
    }).verifyProvider();
  });
});
```

---

## Formal Verification: Bounded State Machines

### The Concept

For critical business logic (payment flows, authentication state, permissions), formal verification using state machines can prove that certain invalid states are unreachable.

### XState for UI State Machines

```typescript
import { createMachine, assign } from 'xstate';

// Payment flow state machine — formally verified states
const paymentMachine = createMachine({
  id: 'payment',
  initial: 'idle',
  states: {
    idle: {
      on: { INITIATE: 'processing' }
    },
    processing: {
      on: {
        SUCCESS: 'complete',
        FAILURE: 'failed',
        TIMEOUT: 'failed'
      }
    },
    complete: {
      type: 'final'  // Terminal state — no further transitions
    },
    failed: {
      on: { RETRY: 'processing' }  // Can retry
    }
  }
});
```

**Property to verify**: From `complete` state, there is no path to `processing`. Once payment is complete, it cannot be re-charged.

### Temporal Logic Assertions

For critical flows, use `xstate/model` to write assertions about reachable states:

```typescript
// Verify that complete → processing is impossible
const model = createModel(paymentMachine);
const paths = model.getShortestPaths();
const reachableFromComplete = paths
  .filter(p => p.state.value === 'complete')
  .flatMap(p => p.steps);

expect(reachableFromComplete.some(s => s.state.value === 'processing'))
  .toBe(false);
```

---

## Recommended Testing Stack

### For TypeScript/Next.js Projects

| Layer | Tool | Purpose | Threshold |
|-------|------|---------|-----------|
| Unit | Vitest | Fast unit tests | 70% line coverage |
| Integration | Vitest + supertest | API route tests | Critical paths |
| Component | Testing Library | UI component tests | Core components |
| Property | fast-check | Boundary/invariant testing | All pure functions |
| Mutation | Stryker | Test quality validation | > 80% mutation score |
| Contract | Pact | API contract verification | All public APIs |
| E2E | Playwright | Full user journey tests | Critical user flows |
| Accessibility | axe-core | WCAG compliance | Zero violations |

### For Python/FastAPI Projects

| Layer | Tool | Purpose | Threshold |
|-------|------|---------|-----------|
| Unit | pytest | Unit tests | 80% line coverage |
| Integration | pytest + httpx | API tests | Critical paths |
| Property | Hypothesis | Boundary testing | All pure functions |
| Mutation | mutmut | Test quality | > 80% mutation score |
| Contract | Pact | API contracts | All public APIs |
| Type checking | mypy | Static types | No Any |

---

## CI/CD Integration Strategy

### Gate Ordering (Fail Fast)

```
lint → typecheck → unit tests → integration tests → mutation tests → E2E
```

Each gate is a prerequisite for the next. Mutation tests run after unit tests because they require existing tests to exist and pass.

### Coverage Gate Configuration

```yaml
# .github/workflows/ci.yml
- name: Check coverage thresholds
  run: npx vitest run --coverage
- name: Validate coverage
  run: |
    npx nyc check-coverage \
      --lines 70 \
      --functions 70 \
      --branches 60 \
      --statements 70
```

### Mutation Test Gate (Non-Blocking Initially)

Run mutation tests on PRs but only fail if score drops below 50% (critical threshold). The 80% target is aspirational and enforced via team convention, not CI blocking. Blocking CI on mutation tests for the first time is a culture shock — phase it in.

```yaml
- name: Mutation testing (warn only)
  run: npx stryker run --reporters progress
  continue-on-error: true  # Phase 1: warn only
  # Remove continue-on-error in Phase 2
```
