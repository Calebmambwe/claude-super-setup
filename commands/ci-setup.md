---
name: ci-setup
description: Set up a full CI/CD pipeline with linting, tests, and deployment for the current project
---
Set up a full CI/CD pipeline for this project: $ARGUMENTS

## Step 0: Create a Feature Branch

**MANDATORY — Do this BEFORE making any file changes.**

1. **Detect the default branch:**
   ```bash
   git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
   ```
   Fallback: `main`, then `master`.

2. **Create and switch to a new branch from the default branch:**
   ```bash
   git checkout -b ci/setup-pipeline <default-branch>
   ```

3. **Confirm you are on the new branch before proceeding.**

All file changes in Steps 1-6 are made on this branch. Nothing touches main/master directly.

---

## Step 1: Detect Project Stack

Read package.json, pyproject.toml, Cargo.toml, go.mod, or other manifest files to determine:
- Language/runtime (Node/TypeScript, Python, Rust, Go, etc.)
- Package manager (pnpm, npm, yarn, uv, pip, cargo, etc.)
- Test runner (vitest, jest, pytest, cargo test, go test, etc.)
- Linter (eslint, ruff, clippy, golangci-lint, etc.)
- Type checker (tsc, mypy, pyright, etc.)
- Build command if applicable
- Whether this is a monorepo (turbo, nx, workspaces)

## Step 2: Create CI Workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

Include these jobs based on detected stack:

### For all projects:
- **format** — run formatter check (e.g., `black --check .` for Python, `prettier --check .` for JS/TS) — fail CI if unformatted
- **lint** — run linter
- **typecheck** — run type checker (if applicable)
- **test** — run test suite with coverage
- **build** — verify build succeeds (if applicable)

### For TypeScript/Node projects:
- Use pnpm (with `pnpm/action-setup`)
- Cache pnpm store
- Node version from .nvmrc or package.json engines, default to LTS
- **format** — run `prettier --check .` (if prettier is in devDependencies) to enforce formatting
- Run: `pnpm format:check` (or `prettier --check .`), `pnpm lint`, `pnpm typecheck`, `pnpm test -- --coverage --coverage.thresholds.lines=80`, `pnpm build`

### For Python projects:
- Use uv for dependency management
- Cache uv venv
- Python version from pyproject.toml or .python-version, default to 3.12
- **format** — run `black --check .` to enforce formatting (fail CI if unformatted)
- Run: `black --check .`, `uv run ruff check .`, `uv run mypy .`, `uv run pytest --cov --cov-fail-under=80`
- Install black in the CI step: `uv pip install black` (or include in dev dependencies)

### For monorepos:
- Use turbo/nx caching
- Only run affected packages on PRs

### Validate workflows job (add to all projects):
```yaml
validate-workflows:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: rhysd/actionlint@v1.7.7
```

## Step 3: Create CD Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy
on:
  push:
    branches: [main, master]
  workflow_dispatch:
```

Include based on project type:

### For web apps (Next.js, Vite, etc.):
- Build step
- Deploy to Vercel/Netlify/Cloudflare Pages (detect from config or ask)
- Preview deployments on PRs

### For APIs/backends:
- Build Docker image (create Dockerfile if missing)
- Push to GitHub Container Registry (ghcr.io)
- Deploy step as placeholder with comment for user to configure target

### For libraries/packages:
- Publish to npm/PyPI on version tag push
- Create GitHub Release

## Step 4: Create Release Workflow

Create `.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*']
```

- Generate changelog from conventional commits
- Create GitHub Release with release notes
- Trigger deploy workflow

## Step 5: Add Supporting Files

Create or update these files if missing:

### `.github/dependabot.yml`
- Auto-update dependencies weekly
- Group minor/patch updates
- Limit open PRs to 5

### `.github/pull_request_template.md`
```markdown
## Summary
<!-- Brief description of changes -->

## Type
- [ ] Feature
- [ ] Bug fix
- [ ] Refactor
- [ ] Docs
- [ ] CI/CD

## Test plan
- [ ] Tests added/updated
- [ ] Tested locally

## Checklist
- [ ] Formatting passes (`black --check .` / `prettier --check .`)
- [ ] Linting passes
- [ ] Type checking passes
- [ ] Tests pass
- [ ] No secrets committed
```

### `.github/CODEOWNERS` (if team project)
- Set default reviewers

## Step 6: Add Status Badge

Add CI status badge to the top of README.md:
```markdown
![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)
```

## Step 7: Verify

- Check all workflow YAML is valid
- Run `actionlint .github/workflows/*.yml` if actionlint is installed (skip gracefully if not)
- Ensure no secrets are hardcoded (use `${{ secrets.* }}` references)
- List any secrets the user needs to add in GitHub repo settings

## Step 8: Commit, Push, and Open PR

1. **Stage all new/changed files:**
   ```bash
   git add .github/ README.md
   ```
   Only stage files created or modified by this command. Do NOT stage unrelated changes.

2. **Commit with a conventional commit message:**
   ```bash
   git commit -m "ci: set up CI/CD pipeline with lint, typecheck, test, build, and deploy workflows"
   ```

3. **Push the branch:**
   ```bash
   git push -u origin ci/setup-pipeline
   ```

4. **Create a Pull Request:**
   ```bash
   gh pr create \
     --title "ci: set up CI/CD pipeline" \
     --body "$(cat <<'EOF'
   ## Summary
   - CI workflow: lint, typecheck, test (with coverage), build
   - CD workflow: deploy on push to main
   - Release workflow: changelog + GitHub Release on version tags
   - Dependabot config for automated dependency updates
   - PR template for consistent reviews

   ## Test plan
   - [ ] CI workflow YAML is valid
   - [ ] No hardcoded secrets
   - [ ] All action versions are pinned

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

5. **Wait for CI checks** (if CI already exists or this is the first run):
   ```bash
   gh pr checks --watch
   ```

6. **If all checks pass, ask the user:**
   > "PR is open and CI checks have passed. Merge to main now?"
   - If yes: `gh pr merge --squash --delete-branch`
   - If no: leave PR open and share the URL

7. **Display summary:**
   ```
   CI/CD Pipeline Setup Complete!

   Branch: ci/setup-pipeline
   PR: {PR URL}
   Status: {merged | open for review}

   Files created:
     .github/workflows/ci.yml
     .github/workflows/deploy.yml
     .github/workflows/release.yml
     .github/dependabot.yml
     .github/pull_request_template.md

   Manual steps needed:
     - Add these secrets in GitHub repo settings: {list any needed secrets}
     - {any other manual steps}
   ```

## Rules
- ALWAYS create a feature branch (Step 0) before making any changes — NEVER commit directly to main/master
- ALWAYS open a PR and wait for CI before merging — no direct pushes to main
- ALWAYS ask the user before merging the PR — never auto-merge without confirmation
- NEVER hardcode secrets — always use GitHub Secrets references
- ALWAYS use specific action versions pinned by SHA or major version (e.g., `actions/checkout@v4`)
- ALWAYS set `concurrency` to cancel redundant runs
- ALWAYS cache dependencies for faster runs
- Use `--frozen-lockfile` / `--locked` to ensure reproducible installs
- Only stage files created or modified by this command — do not stage unrelated changes
- Coverage threshold (80%) is non-negotiable — global standard
- NEVER create a CI pipeline without a coverage enforcement step
