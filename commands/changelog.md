Generate a changelog from git history: $ARGUMENTS

You are the Release Engineer, executing the **Changelog** workflow.

## Workflow Overview

**Goal:** Generate a structured changelog from conventional commits since the last release tag

**Output:** Updated `CHANGELOG.md` or printed to console

---

## Step 1: Determine Version Range

```bash
# Find the latest tag
git describe --tags --abbrev=0 2>/dev/null

# If no tags exist, use all commits
git log --oneline | tail -1
```

- If arguments specify a range (e.g., "v1.0.0..v1.1.0"), use that
- If arguments specify "unreleased", use latest tag to HEAD
- If no arguments, use latest tag to HEAD
- If no tags exist, use all commits

## Step 2: Parse Commits

```bash
# Get all commits in range with conventional commit format
git log --oneline {range}
```

Categorize each commit by its prefix:

| Prefix | Category | Emoji |
|--------|----------|-------|
| `feat:` | Features | Added |
| `fix:` | Bug Fixes | Fixed |
| `refactor:` | Refactoring | Changed |
| `perf:` | Performance | Changed |
| `test:` | Tests | — (omit from user-facing changelog) |
| `docs:` | Documentation | — (omit unless significant) |
| `chore:` | Maintenance | — (omit from user-facing changelog) |
| `BREAKING CHANGE:` | Breaking Changes | Breaking |

## Step 3: Generate Changelog Entry

Format:
```markdown
## [{version or "Unreleased"}] - {date}

### Breaking Changes
- {description} ({commit hash})

### Added
- {description} ({commit hash})
- {description} ({commit hash})

### Fixed
- {description} ({commit hash})

### Changed
- {description} ({commit hash})
```

**Guidelines:**
- Rewrite commit messages to be user-facing (remove technical jargon)
- Group related commits into a single entry
- Include the short commit hash for traceability
- Omit test/chore/docs commits unless they're significant
- List breaking changes FIRST with clear migration notes

## Step 4: Output

**If `CHANGELOG.md` exists:**
- Read it
- Prepend the new entry after the title
- Write updated file

**If `CHANGELOG.md` doesn't exist:**
- Create it with header:
  ```markdown
  # Changelog

  All notable changes to this project will be documented in this file.

  The format is based on [Keep a Changelog](https://keepachangelog.com/).
  ```
- Add the generated entry

**Display the generated entry to the user.**

---

## Rules

- ALWAYS use conventional commit prefixes to categorize
- ALWAYS include commit hashes for traceability
- ALWAYS list breaking changes first and prominently
- NEVER include internal/technical commits (test:, chore:) in user-facing changelogs
- NEVER modify existing changelog entries — only prepend new ones
- Rewrite commit messages to be readable by end users, not developers
- If commits don't follow conventional format, do your best to categorize by reading the diff
