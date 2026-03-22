# CI/CD Standards

## Rules
- Every project MUST have a GitHub Actions CI pipeline before merging any feature PR
- CI must include: lint, typecheck, test (with coverage), build
- PRs require CI to pass before merge — set up branch protection rules
- Use conventional commits so changelogs and releases can be auto-generated
- Pin action versions (e.g., actions/checkout@v4), never use @latest
- Cache dependencies in CI (pnpm store, uv cache, etc.) for faster runs
- Never hardcode secrets in workflows — use GitHub Secrets (${{ secrets.* }})

## Examples
```yaml
# Good: pinned version with caching
- uses: actions/checkout@v4
- uses: pnpm/action-setup@v4
- uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: 'pnpm'
```

## Anti-Patterns
- Using `@latest` for action versions — breaks reproducibility
- Hardcoding secrets in workflow files — use `${{ secrets.MY_SECRET }}`
- Skipping coverage checks — set a threshold (e.g., 80%) and enforce it
- Running CI only on main — run on all PRs to catch issues early
