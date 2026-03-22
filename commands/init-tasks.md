---
name: init-tasks
description: Break a feature into structured tasks with acceptance criteria for the Ralph Loop
---

You are creating a structured task file for autonomous implementation. Break "$ARGUMENTS" into small, independently implementable tasks.

## Process

1. **Explore the codebase** to understand existing patterns, dependencies, and structure
2. **Use the architect agent (Opus)** to decompose the feature into tasks
3. **Write `tasks.json`** to the project root

## Task File Schema

Write a `tasks.json` file with this exact structure:

```json
{
  "project": "short-kebab-case-name",
  "description": "One-line description of the feature",
  "stack": "detected from project (e.g., next-supabase-tailwind)",
  "created": "ISO date",
  "tasks": [
    {
      "id": 1,
      "title": "Short title of what to implement",
      "description": "What this task accomplishes",
      "status": "pending",
      "priority": "P0",
      "risk": "low",
      "acceptance": [
        "Concrete testable criterion 1",
        "Concrete testable criterion 2"
      ],
      "files": ["src/path/to/file.ts", "src/path/to/other.ts"],
      "depends_on": [],
      "attempts": 0,
      "max_attempts": 3
    }
  ]
}
```

### Field Reference

| Field | Required | Values | Purpose |
|-------|----------|--------|---------|
| `priority` | Yes | `P0` (critical path), `P1` (important), `P2` (nice-to-have) | Execution order within dependency level |
| `risk` | Yes | `low`, `medium`, `high` | High-risk tasks get extra verification |
| `depends_on` | Yes | Array of task IDs | Enables parallel execution of independent tasks |

## Rules

- Each task should touch 1-3 files maximum
- Tasks must be in dependency order (task 2 can depend on task 1)
- Every task needs at least 2 acceptance criteria that are testable
- Include test files in the `files` array
- First task should always be scaffold/setup if starting a new project
- Last task should be integration verification
- Maximum 15 tasks — if more are needed, split into milestones
- `depends_on` references task IDs that must complete first
- `priority` must be set: P0 = critical path, P1 = important, P2 = nice-to-have
- `risk` must be set: low/medium/high — high-risk tasks get sequential execution with extra verification
- Tasks with no `depends_on` are candidates for parallel execution

## Acceptance Criteria Quality

Good acceptance criteria are testable:
- "Auth page renders at /login" (testable)
- "Supabase auth hook returns user object" (testable)
- "Tests pass for auth service" (testable)

Bad acceptance criteria are vague:
- "Auth works" (not testable)
- "Good user experience" (not testable)

## Output

After creating `tasks.json`, report:

```
## Tasks Created

Project: {name}
Tasks: {count}
Stack: {detected stack}
File: tasks.json

Task list:
1. {title} (depends: none)
2. {title} (depends: 1)
...

Next: Run /next-task to implement one at a time, or use /ralph-loop "/next-task" for autonomous mode.
```
