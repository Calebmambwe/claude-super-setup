# Milestone Prompts Template

> **Portable prompt template.** Use after creating a design document to generate per-milestone implementation prompts for independent LLM sessions.
> **Claude Code command:** `/milestone-prompts`

---

## Critical Principles

Each generated prompt will be executed in an **independent LLM agent thread with no shared context**. This means:
- The agent running Milestone 3 has **zero knowledge** of Milestones 1-2
- Each prompt must be **fully self-contained** — all context must be embedded
- Scope must be **surgically precise** — the agent must not drift into other milestones
- The design document is the **single source of truth**

---

## Structure of Each Generated Prompt

### Section 1: Task Summary

```
Your task is to implement [MILESTONE NAME] for the [PROJECT NAME] project.

What you must do:
- [Specific deliverable 1]
- [Specific deliverable 2]

What is IN SCOPE:
- [Feature/component 1]
- [Specific file/module to create]

What is OUT OF SCOPE (do NOT implement):
- [Future milestone feature]
- [Anything from other milestones]

Definition of Done:
[Exact DoD checklist from the design document]
```

### Section 2: Project Background

```
Project: [name]
Description: [one-line description]
Stack: [frontend], [backend], [database]

Architecture:
[Paste system overview Mermaid diagram]

Key Components:
[List 3-7 components with one-line descriptions]

Repository Structure:
[Paste folder structure from conventions section]

Coding Conventions:
- Files: [naming convention]
- Error handling: [pattern]
- Response format: [envelope format]
```

### Section 3: Current Task Context

```
This is Milestone [N] of [total].

What has been completed (assume done, do not re-implement):
- Milestone 1: [name] — [one-line summary]
- Milestone 2: [name] — [one-line summary]

What this milestone enables (OUT OF SCOPE):
- Milestone [N+1]: [name] — [one-line summary]

Dependencies from previous milestones you can assume exist:
- [Database table X exists with columns Y, Z]
- [Auth middleware is in place at path/to/file]
```

### Section 4: Design Document Reference

```
The following design document describes all milestones.
You MUST read it before writing any code.
Implement ONLY the portions relevant to Milestone [N].

Design document path: docs/[project]/design-doc.md

Relevant sections for this milestone:
- Section 3.X: [Entity name]
- Section 4.X: [Endpoint group]
- Section 5: Conventions (follow all)
```

### Section 5: Pre-Implementation Exploration

```
CRITICAL: Complete ALL steps BEFORE writing any code.
Writing code before exploration is a failure condition.

Step 1: Read the design document
Step 2: Explore repository structure
Step 3: Inspect existing code relevant to this milestone
Step 4: Search for existing patterns (routes, services, validation, tests)
Step 5: Verify prerequisites from previous milestones exist
```

### Section 6: Implementation Instructions

```
Architecture Constraints:
- Follow Route → Service → Repository → Database pattern
- All API responses use: { success, data, error, meta }
- Validation at system boundaries using [Zod/Pydantic]

What to Build (Ordered):
1. [First thing] — File: [path] — Purpose: [what it does]
2. [Second thing] — File: [path] — Purpose: [what it does]

Testing Requirements:
- Write tests alongside implementation, not after
- Unit tests for business logic
- Integration tests for API endpoints
- Target: 80%+ coverage for new code

Git Workflow:
- Branch: feature/milestone-[N]-[short-name]
- Conventional commits: feat:, fix:, test:
```

### Section 7: Final Reminders (REQUIRED in every prompt)

```
1. Read the design document before coding.
2. Explore the existing codebase before coding.
3. Implement ONLY Milestone [N]. Do not implement other milestones.
4. Assume other milestones are handled in separate sessions.
5. Do not introduce speculative or forward-looking changes.
6. Verify the Definition of Done before finishing.
```

---

## Milestone Map Output

Also generate `docs/[project]/prompts/README.md`:

```markdown
# Milestone Implementation Plan

Execution Order:
Milestone 1: [name]
    └── Milestone 2: [name] (depends on 1)
        └── Milestone 3: [name] (depends on 2)

| # | Name | Depends On | Prompt File |
|---|------|-----------|-------------|
| 1 | [name] | None | milestone-1-[name].md |
| 2 | [name] | M1 | milestone-2-[name].md |

Parallel Opportunities:
- [Milestone X] and [Milestone Y] can run simultaneously after [Milestone Z]
```
