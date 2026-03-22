---
paths:
  - "**/tasks.json"
---
# Task Tracking Rules

- When `tasks.json` exists in the project, always check it before starting implementation work.
- After completing a task, update its status in `tasks.json` to "completed". Increment `attempts` only on failed attempts, not on success.
- After 3 failed attempts on a task, set status to "blocked" with a "blocked_reason" field. Skip to the next task.
- Never modify a task's acceptance criteria — they are the contract. If criteria are wrong, flag it to the user.
- If `tasks.json` is missing required fields (`id`, `status`, `acceptance`, `depends_on`, `priority`, `risk`), flag it as invalid and do not attempt to implement any tasks.
- `priority` values: P0 (critical path, execute first), P1 (important), P2 (nice-to-have, can defer)
- `risk` values: low (parallel OK), medium (parallel OK), high (sequential only, extra verification)
- Tasks with no `depends_on` overlap and risk != high are candidates for parallel execution in `/auto-build-all`.
- A task with `status: "pending"` and `attempts >= max_attempts` should be set to `"blocked"` immediately without attempting again.
- AGENTS.md rules are in a separate rule file (agents-md.md) — do not duplicate them here.
