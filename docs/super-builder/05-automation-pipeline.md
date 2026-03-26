# 05 — Autonomous Development Pipeline

## What This Document Covers

A complete blueprint for a self-healing, quality-enforced, fully observable autonomous development pipeline. This document synthesizes patterns from Manus, Devin, OpenHands, Bolt, and Claude Code's own Ralph Loop into a unified execution model.

---

## 1. Pipeline Architecture Overview

```
UserPrompt
    │
    ▼
[Phase 0: Research Gate]
    │  researcher agent: Context7 → Research Brief
    ▼
[Phase 1: Decomposition]
    │  task graph: topological sort + parallel groups
    ▼
[Phase 2: Per-Task Loop — The Ralph Loop]
    │  plan → implement → verify → fix → verify → ...
    │  max_iterations = 5, circuit breaker on repeat errors
    ▼
[Phase 3: Quality Gates]
    │  TypeScript / lint / format / tests / visual regression
    ▼
[Phase 4: Ship Gate]
    │  security audit + code review + accessibility
    ▼
[Phase 5: Deploy Gate]
    │  smoke tests + monitoring + rollback sentinel
    ▼
Done / PR created
```

Each phase is observable: hook events feed a SQLite store, a dashboard reflects live state, and Telegram receives phase-boundary notifications.

---

## 2. Self-Healing Patterns

### 2.1 The Ralph Loop (Claude Code Native)

The Ralph Loop is the innermost recovery mechanism. It is implemented via the `Stop` hook interceptor:

```
for each task:
    while iterations < MAX_ITERATIONS:
        implement(task)
        result = verify(task)          # run tests / typecheck / lint
        if result.passing:
            break
        else:
            feed(error_context)        # inject stderr into next turn
            iterations += 1
    if iterations == MAX_ITERATIONS:
        escalate(task)                 # surface to human, do not proceed
```

Key insight from Boris Cherny (Claude Code creator): always give Claude a way to verify its own work. Without verification, the loop runs forever or stops too early. With verification, it knows when it is done.

The Stop hook is what makes this mechanical rather than heuristic — it intercepts the agent's natural exit, re-feeds the original prompt alongside any new error context, and forces another pass.

### 2.2 Manus Sandbox Pattern

Manus runs every action in an isolated sandbox and checkpoints state after every major action. The recovery flow:

1. Serialize agent state to JSON after each completed action
2. On tool failure: inject the stack trace into context (do not hide it)
3. The model observes the failed action + error and implicitly updates its beliefs
4. Retry with modified approach, not the same command
5. If same error appears twice: break the retry loop, surface to operator

The critical anti-pattern Manus avoids: infinite retry loops on the same command. Circuit breakers must compare error fingerprints, not just error presence.

### 2.3 Devin Backtracking Pattern

Devin's approach is plan-first, backtrack-explicitly:

1. Before any execution: produce a structured plan with numbered steps
2. Each step has a defined success criterion
3. On failure at step N: backtrack to the last known-good checkpoint (step N-1)
4. Re-plan steps N onward with the new information
5. Dynamic re-planning = updating the plan, not abandoning it

Devin 2.0 achieves 83% more tasks per compute unit through this approach. The key: re-planning is cheap. Re-executing is expensive.

### 2.4 OpenHands Event-Sourced Recovery

OpenHands uses an event-sourced state model with deterministic replay:

1. Every agent action is an immutable event appended to an event log
2. State at any point = replay of all events from the beginning
3. On failure: the replay stops at the failed event
4. Recovery = append a compensating event, replay forward
5. This enables exact reproduction of failures in testing

The practical benefit: a failed run is never lost. You can inspect the full event sequence, find the divergence point, and re-run from there.

### 2.5 Bolt WebContainer Error Capture

Bolt's model: the entire environment (filesystem, node server, package manager, terminal) lives inside WebContainers. Error capture is total:

1. Intercept stdout/stderr from every process running inside the container
2. Parse error patterns: TypeScript errors, runtime exceptions, build failures
3. Feed structured error payloads directly to the model, not raw terminal output
4. Auto-fix works best for: syntax errors, missing imports, type mismatches
5. Auto-fix fails for: architectural mismatches, missing environment variables, network issues

Lesson: auto-fix is reliable only for shallow errors. Deep architectural errors require human escalation. The pipeline must distinguish between the two.

---

## 3. Task Decomposition Strategy

### 3.1 Taxonomy of Task Sizes

| Size | Files | Duration | Execution Mode |
|------|-------|----------|----------------|
| Tiny | 1–2 | < 5 min | Direct — no planning |
| Small | 3–5 | 5–15 min | Architect once, build sequentially |
| Medium | 6–15 | 15–60 min | Sequential tasks, Ralph Loop per task |
| Large | 16+ | 60+ min | Parallel task groups, max 3 concurrent |

### 3.2 Task Graph Construction

Every medium or large feature produces a `tasks.json` before execution begins:

```json
{
  "version": "1.0",
  "feature": "user-authentication",
  "tasks": [
    {
      "id": "T001",
      "title": "Define User schema",
      "files": ["src/models/user.ts", "src/db/migrations/001_users.sql"],
      "priority": "critical",
      "risk": "low",
      "depends_on": [],
      "success_criteria": ["pnpm typecheck passes", "migration runs without error"]
    },
    {
      "id": "T002",
      "title": "Build auth service",
      "files": ["src/services/auth.ts", "src/services/auth.test.ts"],
      "priority": "high",
      "risk": "medium",
      "depends_on": ["T001"],
      "success_criteria": ["all tests pass", "no TypeScript errors"]
    },
    {
      "id": "T003",
      "title": "Build auth API routes",
      "files": ["src/routes/auth.ts", "src/routes/auth.test.ts"],
      "priority": "high",
      "risk": "medium",
      "depends_on": ["T002"],
      "success_criteria": ["all tests pass", "OpenAPI spec validates"]
    }
  ]
}
```

### 3.3 Parallel Execution Rules

Tasks in the same "parallel group" have no `depends_on` overlap:

```
Group A (parallel):  T001, T004, T007   ← no shared dependencies
Group B (sequential): T002 depends on T001, T005 depends on T004
Group C (parallel):  T003, T006          ← both depend on Group B but not each other
```

Hard limit: max 3 concurrent agents. Above that, context fragmentation degrades quality faster than parallelism saves time.

### 3.4 Dependency Cycle Detection

Before execution starts:

```python
def detect_cycles(tasks):
    # Kahn's algorithm on the depends_on graph
    in_degree = {t.id: 0 for t in tasks}
    for t in tasks:
        for dep in t.depends_on:
            in_degree[t.id] += 1
    queue = [t.id for t in tasks if in_degree[t.id] == 0]
    visited = 0
    while queue:
        node = queue.pop(0)
        visited += 1
        for t in tasks:
            if node in t.depends_on:
                in_degree[t.id] -= 1
                if in_degree[t.id] == 0:
                    queue.append(t.id)
    if visited != len(tasks):
        raise CyclicDependencyError("Task graph contains a cycle")
```

---

## 4. Pipeline Orchestration

### 4.1 Phase State Machine

```
PENDING → RUNNING → VERIFYING → PASSED → SHIPPED
                 ↘          ↗
               FAILED → RETRYING → ESCALATED
```

Transitions are driven by hook events. The observability server receives events via POST and broadcasts to all connected dashboards via WebSocket.

### 4.2 Progress Tracking

Every phase boundary fires a Telegram notification. Format:

```
[super-builder] Phase complete: BUILD
  Tasks: 12/12 passed
  Time: 4m 32s
  Quality: TypeScript OK | Lint OK | Tests 94/94
  Next: SECURITY AUDIT
```

Failures are reported immediately with:
- Task ID and title
- Error type (typecheck / lint / test / visual)
- File path and line number if available
- Retry count

### 4.3 Rollback Strategy

Three levels of rollback:

**Level 1 — Task rollback:** git stash the files from the failed task, re-run from pre-task state.

**Level 2 — Feature rollback:** `git reset --hard <pre-feature-commit>`, delete the feature branch, re-open all tasks in `tasks.json`.

**Level 3 — PR rollback:** revert the merged PR commit, re-open the PR with a new branch, emit a `ROLLBACK` event to the observability server.

Rollback is never automatic for Level 2 or Level 3. The agent surfaces the situation and waits for human approval before destructive operations.

### 4.4 Context Budgeting

Context exhaustion is the silent killer of autonomous pipelines. Rules:

1. At 65% context usage: run `/compact` before starting the next task
2. At 80%: force compact, regardless of task state
3. Compact metadata to preserve: task description, success criteria, file paths modified, errors encountered in this session, architecture decisions made

After compact: re-read `tasks.json` and resume from the last `PASSED` task.

---

## 5. Visual Verification

### 5.1 Playwright Screenshot Comparison

Every UI task has a visual verification step after the build:

```typescript
// playwright.config.ts
export default {
  use: {
    viewport: { width: 1440, height: 900 },
    screenshot: 'only-on-failure',
  },
  expect: {
    toHaveScreenshot: {
      maxDiffPixels: 50,           // tolerance for font rendering differences
      threshold: 0.2,              // per-pixel color difference threshold
      animations: 'disabled',     // deterministic captures
    },
  },
};
```

Baseline images are committed to the repo at `.playwright/baseline/`. On every build, Playwright compares to baseline and produces:
- `[name].png` — baseline
- `[name]-actual.png` — current
- `[name]-diff.png` — visual diff overlay

Any diff above the configured threshold fails the visual gate.

### 5.2 Responsive Verification Viewports

Standard breakpoints to test on every UI task:

| Breakpoint | Viewport | Priority |
|-----------|---------|----------|
| Mobile S | 375 × 812 | Required |
| Mobile L | 430 × 932 | Required |
| Tablet | 768 × 1024 | Required |
| Desktop | 1440 × 900 | Required |
| Wide | 1920 × 1080 | Optional |

### 5.3 Accessibility Validation

Run `axe-core` on every rendered page as part of the visual gate:

```typescript
import { checkA11y } from 'axe-playwright';

test('accessibility audit', async ({ page }) => {
  await page.goto('/');
  await checkA11y(page, undefined, {
    detailedReport: true,
    detailedReportOptions: { html: true },
    runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa'],
  });
});
```

Critical violations block the pipeline. Moderate violations are reported but do not block.

### 5.4 Animation Testing

Animations must be tested in reduced-motion mode as well:

```typescript
await page.emulateMedia({ reducedMotion: 'reduce' });
await expect(page).toHaveScreenshot('homepage-reduced-motion.png');
```

Animated components must also have a `prefers-reduced-motion` CSS override. This is enforced at the pre-write hook level (design system compliance check).

### 5.5 DOM Snapshot Testing

For component libraries: use Storybook's interaction testing + snapshot comparison.

```typescript
// component.stories.ts
export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await expect(canvas.getByRole('button')).toBeVisible();
    await userEvent.click(canvas.getByRole('button'));
    await expect(canvas.getByText('Clicked')).toBeInViewport();
  },
};
```

DOM snapshots catch structural regressions that pixel comparisons miss (e.g., a button losing its `aria-label` without any visual change).

---

## 6. Observability Architecture

### 6.1 Event Bus

Hook events flow from Claude Code → observability server → WebSocket → dashboard:

```
Claude Code hooks
     │  HTTP POST /events
     ▼
SQLite event store
     │  WebSocket broadcast
     ▼
Dashboard (realtime)    Telegram (phase boundaries)    Log file
```

Event schema:
```json
{
  "source_app": "super-builder",
  "session_id": "string",
  "hook_event_type": "PreToolUse | PostToolUse | Stop | TaskCompleted | ...",
  "payload": {},
  "timestamp": 1699000000000
}
```

### 6.2 What to Observe at Each Phase

| Phase | Events to track | Alert condition |
|-------|----------------|-----------------|
| Decomposition | TaskCreate × N | N > 20 — warn, may need splitting |
| Build | PostToolUseFailure | 3 failures on same file |
| Verify | Stop (blocked) | verify step failed after 5 retries |
| Quality | PostToolUse on Bash | lint/test commands with non-zero exit |
| Ship | TaskCompleted | all tasks complete — trigger PR creation |

---

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Ralph Loop Plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop)
- [Ralph Wiggum Technique](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)
- [Manus Context Engineering](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [Manus Self-Debug Tuning](https://medium.com/@connect.hashblock/how-i-tuned-manus-agents-to-self-debug-and-retry-api-failures-autonomously-0c385893aae9)
- [OpenHands Software Agent SDK](https://openhands.dev/blog/introducing-the-openhands-software-agent-sdk)
- [Bolt.new GitHub](https://github.com/stackblitz/bolt.new)
- [Playwright Visual Comparisons](https://playwright.dev/docs/test-snapshots)
- [AI Agents in CI/CD Pipelines](https://www.mabl.com/blog/ai-agents-cicd-pipelines-continuous-quality)
- [Autonomous Quality Gates](https://www.augmentcode.com/guides/autonomous-quality-gates-ai-powered-code-review)
- [Claude Code Hooks Multi-Agent Observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- Context7 library ID: `/disler/claude-code-hooks-mastery`
- Context7 library ID: `/mizunashi-mana/claude-code-hook-sdk`
- Context7 library ID: `/disler/claude-code-hooks-multi-agent-observability`
