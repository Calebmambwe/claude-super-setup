---
paths:
  - "**/*.py"
---
# Python Rules

- Use type hints on all function signatures. Example: `def get_user(user_id: int) -> User | None:`
- Validate external input with Pydantic models at system boundaries (API routes, CLI args, config loading).
- Use `pathlib.Path` instead of `os.path` for file operations.
- Prefer `uv` for package management. Fallback to `pip` only if uv is unavailable.
- Use `ruff` for linting and formatting. Run `ruff check --fix` and `ruff format` before commits.
- Use dataclasses or Pydantic models for structured data. Avoid raw dicts for domain objects.
- Never catch bare `except:`. Always catch specific exceptions. Example: `except ValueError as e:`
- Use `logging` module, not `print()`, for any output beyond CLI user-facing messages.
- Prefer `pytest` with fixtures over unittest. Use `pytest-cov` for coverage.
