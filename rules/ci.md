---
paths:
  - ".github/**"
  - "**/ci/**"
  - "**/.github/**"
---
# CI/YAML Rules (Loaded for Workflow and Config Files)

- Pin ALL GitHub Action versions to a specific tag. Example: `actions/checkout@v4`. NEVER use `@latest` or `@main`.
- Cache dependencies in CI. Example: `cache: 'pnpm'` in `actions/setup-node@v4`.
- NEVER hardcode secrets in workflow files. Use `${{ secrets.MY_SECRET }}`.
- Add `concurrency` to prevent duplicate runs: `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`.
- Run CI on all pull requests, not just pushes to main.
- Use `timeout-minutes` on jobs to prevent hung workflows. Default: 15 minutes.
- Validate workflow files locally with `actionlint` before committing.
- For Docker Compose files: pin image versions, never use `latest` tag.
