---
name: test-plan
description: Generate a comprehensive test plan using the test-writer-fixer agent
---
Create a test plan for: $ARGUMENTS

Use the test-writer-fixer agent to:

1. **Analyze the feature** -- read the spec, code, or description
2. **Generate test categories:**
   - Unit tests: pure business logic, utility functions
   - Integration tests: API endpoints, database operations
   - Contract tests: response shapes match OpenAPI spec
   - Edge case tests: boundary conditions, error paths
   - Performance tests: response time, throughput (if applicable)
   - Accessibility tests: WCAG compliance (if UI)

3. **For each test, specify:**
   - Test name (descriptive, Given/When/Then)
   - Input data
   - Expected output
   - Setup/teardown requirements
   - Priority (P0=critical, P1=important, P2=nice-to-have)

4. **Output:** A test plan document that can be directly used by /generate-tests
