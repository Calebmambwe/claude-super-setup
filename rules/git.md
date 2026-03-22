# Git Workflow Rules (Always Loaded)

- Create feature branches from main: `feature/short-description`, `fix/issue-number`, `wip/experiment-name`.
- Conventional commits ONLY: `feat: add user signup`, `fix: handle null avatar`, `test: add auth service tests`.
- One logical change per commit. Don't mix refactoring with feature work in the same commit.
- NEVER push directly to main/master. Always use a feature branch + PR.
- NEVER use `--force` push unless explicitly told. Prefer `--force-with-lease` if rebasing.
- NEVER use `--no-verify` to skip pre-commit hooks. Fix the underlying issue instead.
- Run tests before committing. The pre-commit hook will verify this.
- Write descriptive commit messages: explain WHY, not just WHAT. Bad: "fix bug". Good: "fix: prevent duplicate signup when email has trailing whitespace".
