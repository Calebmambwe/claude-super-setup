# Standard CI/CD Template

## Overview

Every project scaffolded from our templates gets a fully configured CI/CD pipeline from day one. This document defines the standard GitHub Actions workflow, coverage thresholds, mutation testing integration, accessibility audit, Dependabot configuration, and recommended branch protection rules.

---

## 1. GitHub Actions: ci.yml

### 1.1 TypeScript/Next.js Projects

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    name: Test, Lint, Build
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 9

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Type check
        run: pnpm typecheck

      - name: Lint
        run: pnpm lint

      - name: Test + Coverage
        run: pnpm test:coverage
        env:
          CI: true

      - name: Check coverage thresholds
        run: |
          LINES=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          BRANCHES=$(cat coverage/coverage-summary.json | jq '.total.branches.pct')
          FUNCTIONS=$(cat coverage/coverage-summary.json | jq '.total.functions.pct')
          echo "Coverage: lines=$LINES% branches=$BRANCHES% functions=$FUNCTIONS%"
          if (( $(echo "$LINES < 70" | bc -l) )); then
            echo "ERROR: Line coverage $LINES% is below 70% threshold"
            exit 1
          fi

      - name: Build
        run: pnpm build
        env:
          NODE_ENV: production

      - name: Accessibility audit
        run: pnpm audit:a11y
        continue-on-error: false

      - name: Upload coverage report
        uses: codecov/codecov-action@v4
        if: always()
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/lcov.info
          fail_ci_if_error: false

  mutation:
    name: Mutation Testing
    runs-on: ubuntu-latest
    timeout-minutes: 30
    if: github.event_name == 'pull_request'
    needs: ci  # Only run after CI passes

    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run mutation tests
        run: pnpm test:mutation
        continue-on-error: true  # Warn but don't block (Phase 1 — change to false in Phase 2)

      - name: Report mutation score
        run: |
          if [ -f reports/mutation/mutation.json ]; then
            SCORE=$(cat reports/mutation/mutation.json | jq '.metrics.mutationScore')
            echo "Mutation score: $SCORE%"
            if (( $(echo "$SCORE < 50" | bc -l) )); then
              echo "WARNING: Mutation score $SCORE% is below 50% — please improve test quality"
            fi
          fi
```

### 1.2 Python/FastAPI Projects

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    timeout-minutes: 15

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'

      - name: Install dependencies
        run: pip install -r requirements.txt -r requirements-dev.txt

      - name: Type check (mypy)
        run: mypy src/

      - name: Lint (ruff)
        run: ruff check src/

      - name: Test + Coverage
        run: pytest --cov=src --cov-report=xml --cov-fail-under=80
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/testdb

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.xml
```

---

## 2. Coverage Thresholds

### 2.1 Vitest Coverage Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'json-summary', 'html'],
      reportsDirectory: 'coverage',
      thresholds: {
        lines: 70,
        branches: 60,
        functions: 70,
        statements: 70,
      },
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.d.ts',
        '**/*.config.*',
        'src/app/layout.tsx',  // Usually not testable
        'src/middleware.ts',   // Usually integration test territory
      ],
    },
  },
});
```

### 2.2 Threshold Rationale

- **Lines: 70%**: The minimum acceptable coverage. Below this, too many code paths are untested.
- **Branches: 60%**: Branch coverage is harder to achieve (every if/else, ternary). 60% is realistic.
- **Functions: 70%**: Matches line coverage. Each function should have at least one test calling it.

**What 70% means in practice**:
- It's not a target — it's a floor. Aim for 80%+.
- It prevents the worst cases (entire features with zero tests)
- It allows for some pragmatism (UI layout components are hard to test, skip them)

### 2.3 pytest Coverage Configuration

```ini
# pytest.ini or pyproject.toml [tool.pytest.ini_options]
[tool.pytest.ini_options]
addopts = "--cov=src --cov-report=term-missing --cov-fail-under=80"
testpaths = ["tests"]

[tool.coverage.run]
source = ["src"]
omit = ["src/migrations/*", "src/*/alembic/*"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
]
```

---

## 3. Mutation Testing Gate

### 3.1 Stryker Configuration

```javascript
// stryker.config.mjs
export default {
  packageManager: 'pnpm',
  reporters: ['html', 'clear-text', 'progress', 'json'],
  testRunner: 'vitest',
  vitest: {
    configFile: 'vitest.config.ts',
  },
  coverageAnalysis: 'perTest',
  mutate: [
    'src/**/*.ts',
    'src/**/*.tsx',
    '!src/**/*.test.ts',
    '!src/**/*.test.tsx',
    '!src/**/*.spec.ts',
    '!src/test/**/*',
    '!src/app/layout.tsx',
  ],
  thresholds: {
    high: 80,  // Above this: green
    low: 60,   // Below this: yellow warning
    break: 50, // Below this: CI fails
  },
  htmlReporter: {
    baseDir: 'reports/mutation',
  },
  jsonReporter: {
    fileName: 'reports/mutation/mutation.json',
  },
  timeoutMS: 60000,
  concurrency: 4,
};
```

### 3.2 Phase Approach

**Phase 1** (start): Run mutation tests, report results, warn if < 50% but don't fail CI.
**Phase 2** (after 4 weeks): Fail CI if score drops below 50%.
**Phase 3** (target state): Require > 80% score for new code.

The phase approach avoids culture shock and gives the team time to improve test quality gradually.

---

## 4. Accessibility Audit CI Step

### 4.1 Playwright + Axe Integration

```typescript
// tests/e2e/accessibility.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const PAGES_TO_AUDIT = [
  { name: 'Home', path: '/' },
  { name: 'Login', path: '/login' },
  { name: 'Dashboard', path: '/dashboard' },
  { name: 'Settings', path: '/settings' },
];

for (const page of PAGES_TO_AUDIT) {
  test(`${page.name} has no WCAG AA violations`, async ({ page: playwrightPage }) => {
    await playwrightPage.goto(page.path);

    const accessibilityScanResults = await new AxeBuilder({ page: playwrightPage })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });
}
```

### 4.2 Package.json Script

```json
{
  "scripts": {
    "audit:a11y": "playwright test tests/e2e/accessibility.spec.ts",
    "audit:a11y:report": "playwright test tests/e2e/accessibility.spec.ts --reporter=html"
  }
}
```

---

## 5. Dependabot Configuration

### 5.1 `.github/dependabot.yml`

```yaml
version: 2
updates:
  # npm/pnpm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
    open-pull-requests-limit: 10
    groups:
      # Group related updates together
      development-dependencies:
        patterns:
          - "@types/*"
          - "eslint*"
          - "prettier*"
          - "vitest*"
          - "playwright*"
        update-types:
          - "minor"
          - "patch"
      production-dependencies:
        patterns:
          - "next"
          - "react"
          - "react-dom"
        update-types:
          - "patch"
    labels:
      - "dependencies"
    reviewers:
      - "calebmambwe"
    commit-message:
      prefix: "chore"
      include: "scope"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns:
          - "*"
    labels:
      - "dependencies"
      - "github-actions"
```

### 5.2 Auto-Merge for Safe Updates

```yaml
# .github/workflows/dependabot-automerge.yml
name: Auto-merge Dependabot PRs

on:
  pull_request:

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - name: Get Dependabot metadata
        id: metadata
        uses: dependabot/fetch-metadata@v2

      - name: Auto-merge patch updates
        if: |
          steps.metadata.outputs.update-type == 'version-update:semver-patch' &&
          steps.metadata.outputs.dependency-type == 'direct:development'
        run: gh pr merge --auto --merge "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ github.token }}
```

This auto-merges patch-level updates to development dependencies (like `@types/*`, ESLint plugins) after CI passes. All other updates require manual review.

---

## 6. Branch Protection Rules

### 6.1 Recommended Settings (document in CONTRIBUTING.md)

For the `main` branch:

| Setting | Value |
|---------|-------|
| Require a pull request before merging | Yes |
| Required approving reviews | 1 |
| Dismiss stale pull request approvals when new commits are pushed | Yes |
| Require status checks to pass before merging | Yes |
| Required status checks | `ci / Test, Lint, Build` |
| Require branches to be up to date before merging | Yes |
| Do not allow bypassing the above settings | Yes |
| Allow force pushes | No |
| Allow deletions | No |

### 6.2 Set Via GitHub CLI

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field required_status_checks='{"strict":true,"contexts":["ci / Test, Lint, Build"]}' \
  --field enforce_admins=true \
  --field restrictions=null
```

---

## 7. Complete package.json Scripts Reference

```json
{
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit",
    "lint": "eslint . --max-warnings 0",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:mutation": "stryker run",
    "test:e2e": "playwright test",
    "audit:a11y": "playwright test tests/e2e/accessibility.spec.ts",
    "tokens:build": "node tokens/style-dictionary.config.js",
    "tokens:verify": "ts-node tokens/verify-contrast.ts",
    "ci": "pnpm typecheck && pnpm lint && pnpm test:coverage && pnpm build"
  }
}
```

The `ci` script runs all checks in sequence — useful for local verification before pushing.
