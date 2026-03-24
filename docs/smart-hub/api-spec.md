# Smart Hub — API Specification

**Version:** 1.0.0
**Status:** Draft
**Created:** 2026-03-24

---

## Overview

This document defines the API contract for the Smart Hub desktop application. Smart Hub is a Tauri 2.0 app (Rust backend + React/TypeScript frontend). All data access happens via **Tauri IPC commands** invoked with `invoke()` from the frontend — there is no running HTTP server in the default build.

This spec uses REST-style conventions (HTTP method, URL path, query params, request/response bodies) for clarity and portability. The conventions serve two purposes:

1. **Frontend developers** can read this as a familiar interface contract regardless of the underlying transport.
2. **Future HTTP server compatibility** — if a local REST server is added (e.g. for the web dashboard panel or CLI tooling), these definitions map directly to Express/Axum route handlers with no contract changes.

**Design document:** `docs/smart-hub/design-doc.md`

### Tauri IPC Mapping

Each REST-style endpoint maps to a Tauri command as follows:

| REST Convention | Tauri Equivalent |
|---|---|
| `GET /api/pipeline/status` | `invoke('get_pipeline_status')` |
| `GET /api/pipeline/history` | `invoke('get_pipeline_history', { limit, offset })` |
| `GET /api/tasks` | `invoke('list_tasks', { status, priority, sortBy, projectDir })` |
| `GET /api/tasks/:id` | `invoke('get_task', { id, projectDir })` |
| `GET /api/metrics` | `invoke('get_metrics', { period, projectDir })` |
| `GET /api/agents` | `invoke('list_agents', { team, department })` |
| `GET /api/agents/:name` | `invoke('get_agent', { name })` |
| `POST /api/commands/:name/run` | `invoke('run_command', { name, args, projectDir })` |
| `GET /api/teams` | `invoke('list_teams')` |
| `GET /api/health` | `invoke('get_health')` |

### Error Envelope

All endpoints return errors in the following shape when a non-2xx equivalent status occurs. In Tauri, this surfaces as a rejected `invoke()` promise.

```typescript
type AppError =
  | { kind: 'io';       message: string }  // File system read failure
  | { kind: 'parse';    message: string }  // JSON/YAML parse error
  | { kind: 'notFound'; message: string }  // File or resource not found
  | { kind: 'shell';    message: string }; // Subprocess execution failure
```

---

## Endpoints

---

### GET /api/pipeline/status

Returns the current pipeline execution state. Combines data from `ghost-config.json` (current run) and `tasks.json` (task progress).

**Tauri command:** `invoke('get_pipeline_status', { projectDir?: string })`

#### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `project_dir` | `string` | `process.cwd()` | Absolute path to the project directory containing `tasks.json` |

#### Response Schema

```typescript
interface PipelineStatusResponse {
  status: 'idle' | 'running' | 'blocked' | 'complete';
  phase: string;                    // Current phase name, e.g. "implement", "verify", "idle"
  feature: string;                  // Feature description from ghost-config.json
  branch: string;                   // Current git branch name
  started: string;                  // ISO 8601 timestamp, empty string if idle
  progress: {
    completed: number;              // Number of completed tasks
    total: number;                  // Total task count
    percentage: number;             // 0–100, rounded to nearest integer
  };
  current_task: {
    id: number;
    title: string;
  } | null;                         // null when status is idle or complete
  pr_url: string | null;            // GitHub PR URL once created, otherwise null
}
```

#### Source Files

- `~/.claude/ghost-config.json` — status, feature, started_at, pr_url
- `tasks.json` in project directory — progress counts, current in-progress task

#### Example Response

```json
{
  "status": "running",
  "phase": "implement",
  "feature": "Enterprise Agent Platform Sprint 5: VS Code Agent Teams, Remote Control, Smart Hub API",
  "branch": "feat/ghost-sprint5-20260324-1623",
  "started": "2026-03-24T16:23:00Z",
  "progress": {
    "completed": 2,
    "total": 7,
    "percentage": 29
  },
  "current_task": {
    "id": 3,
    "title": "Smart Hub API spec"
  },
  "pr_url": null
}
```

---

### GET /api/pipeline/history

Returns a paginated list of recent pipeline run summaries, sourced from the append-only metrics log.

**Tauri command:** `invoke('get_pipeline_history', { limit?: number, offset?: number })`

#### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `limit` | `number` | `10` | Maximum number of runs to return |
| `offset` | `number` | `0` | Number of runs to skip (for pagination) |

#### Response Schema

```typescript
interface PipelineHistoryResponse {
  runs: PipelineRun[];
  total: number;         // Total number of pipeline run events in metrics.jsonl
  limit: number;
  offset: number;
}

interface PipelineRun {
  job_id: string;                               // e.g. "J-2026-000001"
  timestamp: string;                            // ISO 8601 — run completion time
  feature: string;
  project: string;
  outcome: 'merged' | 'blocked' | 'failed';
  total_minutes: number;
  agents_used: number;
  model_cost_usd: number;
  phases: {
    spec_minutes: number;
    plan_minutes: number;
    implement_minutes: number;
    verify_minutes: number;
    review_minutes: number;
  };
}
```

#### Source Files

- `~/.claude/metrics.jsonl` — filtered to `event: "job_complete"` entries, descending by timestamp

#### Example Response

```json
{
  "runs": [
    {
      "job_id": "J-2026-000012",
      "timestamp": "2026-03-24T22:01:00Z",
      "feature": "Enterprise Agent Platform Sprint 4 — personal assistant + Manus patterns",
      "project": "claude_super_setup",
      "outcome": "merged",
      "total_minutes": 47,
      "agents_used": 4,
      "model_cost_usd": 1.24,
      "phases": {
        "spec_minutes": 5,
        "plan_minutes": 8,
        "implement_minutes": 26,
        "verify_minutes": 5,
        "review_minutes": 3
      }
    },
    {
      "job_id": "J-2026-000011",
      "timestamp": "2026-03-23T18:44:00Z",
      "feature": "Enterprise Agent Platform Sprint 3 — enterprise dev process + Manus collaboration",
      "project": "claude_super_setup",
      "outcome": "merged",
      "total_minutes": 52,
      "agents_used": 5,
      "model_cost_usd": 1.61,
      "phases": {
        "spec_minutes": 6,
        "plan_minutes": 10,
        "implement_minutes": 28,
        "verify_minutes": 5,
        "review_minutes": 3
      }
    }
  ],
  "total": 12,
  "limit": 10,
  "offset": 0
}
```

---

### GET /api/tasks

Returns the task list for a project with optional filtering and sorting.

**Tauri command:** `invoke('list_tasks', { status?, priority?, sortBy?, projectDir? })`

#### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `status` | `'pending' \| 'completed' \| 'blocked' \| 'in_progress'` | (all) | Filter by task status |
| `priority` | `'P0' \| 'P1' \| 'P2'` | (all) | Filter by priority level |
| `sort_by` | `'id' \| 'priority' \| 'status'` | `'id'` | Sort order for returned tasks |
| `project_dir` | `string` | `process.cwd()` | Absolute path to the project directory |

#### Response Schema

```typescript
interface TaskListResponse {
  feature: string;         // Feature name from tasks.json
  project_dir: string;     // Resolved project directory used for this response
  tasks: Task[];
  summary: {
    total: number;
    completed: number;
    pending: number;
    in_progress: number;
    blocked: number;
  };
}

interface Task {
  id: number;
  title: string;
  description: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  priority: 'P0' | 'P1' | 'P2';
  risk: 'low' | 'medium' | 'high';
  depends_on: number[];
  acceptance_criteria: string[];
  files: string[];
  attempts: number;
  max_attempts: number;
}
```

#### Source Files

- `tasks.json` in `project_dir`

#### Example Response

```json
{
  "feature": "Enterprise Agent Platform Sprint 5: VS Code Agent Teams, Remote Control, Smart Hub API",
  "project_dir": "/Users/calebmambwe/claude_super_setup",
  "tasks": [
    {
      "id": 1,
      "title": "VS Code Agent Teams presets — review, feature, debug teams",
      "description": "Create agents/teams/ directory with team preset JSON configs for VS Code integration.",
      "status": "completed",
      "priority": "P0",
      "risk": "low",
      "depends_on": [],
      "acceptance_criteria": [
        "agents/teams/ directory created with review.json, feature.json, debug.json",
        "Each preset has: name, description, agents (with roles), workflow steps, model_tier"
      ],
      "files": [
        "agents/teams/review.json",
        "agents/teams/feature.json",
        "agents/teams/debug.json",
        "agents/teams/README.md"
      ],
      "attempts": 1,
      "max_attempts": 3
    },
    {
      "id": 3,
      "title": "Smart Hub API spec",
      "description": "Create docs/smart-hub/api-spec.md with OpenAPI-style endpoint definitions.",
      "status": "in_progress",
      "priority": "P1",
      "risk": "low",
      "depends_on": [],
      "acceptance_criteria": [
        "All 10 endpoints documented with request params, response schema, and example JSON",
        "TypeScript interface definitions match design-doc.md data structures"
      ],
      "files": ["docs/smart-hub/api-spec.md"],
      "attempts": 1,
      "max_attempts": 3
    }
  ],
  "summary": {
    "total": 7,
    "completed": 2,
    "pending": 4,
    "in_progress": 1,
    "blocked": 0
  }
}
```

---

### GET /api/tasks/:id

Returns the full detail for a single task, including all acceptance criteria and file references.

**Tauri command:** `invoke('get_task', { id: number, projectDir?: string })`

#### Path Parameters

| Parameter | Type | Description |
|---|---|---|
| `id` | `number` | Task ID (integer, matches `id` field in `tasks.json`) |

#### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `project_dir` | `string` | `process.cwd()` | Absolute path to the project directory |

#### Response Schema

```typescript
type TaskDetailResponse = Task; // Same Task interface as /api/tasks
```

Returns `AppError { kind: 'notFound' }` if no task with the given ID exists.

#### Source Files

- `tasks.json` in `project_dir`

#### Example Response

```json
{
  "id": 2,
  "title": "Remote Control documentation",
  "description": "Create docs/remote-control.md documenting the full remote control architecture: Telegram dispatch system, cron scheduling, parallel session management, ghost mode remote triggering, and notification channels.",
  "status": "pending",
  "priority": "P0",
  "risk": "low",
  "depends_on": [],
  "acceptance_criteria": [
    "Documents Telegram dispatch system (tiers, routing, safety)",
    "Documents cron scheduling via /telegram-cron",
    "Documents parallel session management (/telegram-parallel, screen sessions)",
    "Documents Ghost Mode remote triggering and notification flow",
    "Includes architecture diagram (mermaid) showing message flow",
    "References existing commands and config files with correct paths"
  ],
  "files": ["docs/remote-control.md"],
  "attempts": 0,
  "max_attempts": 3
}
```

---

### GET /api/metrics

Returns aggregated pipeline and activity metrics for the dashboard. Reads and aggregates `metrics.jsonl` events, optionally scoped to a time period and project.

**Tauri command:** `invoke('get_metrics', { period?: string, projectDir?: string })`

#### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `period` | `'day' \| 'week' \| 'month'` | `'week'` | Time window for aggregation |
| `project_dir` | `string` | (all projects) | If provided, scope metrics to this project only |

#### Response Schema

```typescript
interface MetricsResponse {
  period: 'day' | 'week' | 'month';
  period_start: string;          // ISO 8601 — start of the aggregation window
  period_end: string;            // ISO 8601 — end of the aggregation window (now)
  commits: number;               // Git commits in period (via git log --oneline)
  prs_created: number;           // PRs opened in period (via gh pr list)
  prs_merged: number;            // PRs merged in period
  tasks_completed: number;       // Tasks reaching 'completed' status in period
  agent_invocations: number;     // Total invoke() calls recorded in metrics events
  tokens_used: number;           // Estimated token count (derived from model_cost_usd)
  cost_usd: number;              // Summed model_cost_usd from metrics events
  trends: {
    commits_delta: number;       // Change vs previous equivalent period (positive = up)
    tasks_delta: number;         // Change vs previous equivalent period (positive = up)
    cost_delta_usd: number;      // Change vs previous equivalent period
  };
}
```

#### Source Files

- `~/.claude/metrics.jsonl` — aggregated by timestamp window; filtered by project if `project_dir` provided

#### Example Response

```json
{
  "period": "week",
  "period_start": "2026-03-17T00:00:00Z",
  "period_end": "2026-03-24T23:59:59Z",
  "commits": 23,
  "prs_created": 5,
  "prs_merged": 4,
  "tasks_completed": 31,
  "agent_invocations": 148,
  "tokens_used": 892400,
  "cost_usd": 9.87,
  "trends": {
    "commits_delta": 7,
    "tasks_delta": 6,
    "cost_delta_usd": 2.14
  }
}
```

---

### GET /api/agents

Returns the full agent catalog with optional filtering by team or department.

**Tauri command:** `invoke('list_agents', { team?: string, department?: string })`

#### Query Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `team` | `string` | (all) | Filter to agents that are members of this team (e.g. `"review"`, `"frontend"`) |
| `department` | `string` | (all) | Filter by department (e.g. `"engineering"`, `"testing"`) |

#### Response Schema

```typescript
interface AgentListResponse {
  version: string;
  model_tiers: Record<string, ModelTier>;
  teams: Record<string, Team>;
  agents: AgentEntry[];
  total: number;
}

interface ModelTier {
  model: string;      // e.g. "claude-sonnet-4-6"
  use_for: string;
}

interface Team {
  description: string;
  agents: string[];   // Agent name references (kebab-case)
}

interface AgentEntry {
  name: string;
  file: string;
  source: 'core' | 'community' | 'project';
  source_repo?: string;
  department: 'engineering' | 'testing' | 'design' | 'product' | 'marketing' | 'studio-operations' | 'project-management' | 'bonus';
  description: string;
  model_tier: 'haiku' | 'sonnet' | 'opus' | 'custom';
  capabilities: string[];
  tools?: string[];
  teams?: string[];
}
```

#### Source Files

- `agents/catalog.json` in the claude-super-setup directory (`~/.claude-super-setup/agents/catalog.json`)

#### Example Response

```json
{
  "version": "1.0.0",
  "model_tiers": {
    "haiku": {
      "model": "claude-haiku-3-5",
      "use_for": "Fast, lightweight tasks: content generation, simple queries, high-volume repetitive work"
    },
    "sonnet": {
      "model": "claude-sonnet-4-6",
      "use_for": "General engineering and analysis tasks: coding, debugging, research, standard reviews"
    },
    "opus": {
      "model": "claude-opus-4",
      "use_for": "Complex reasoning tasks: architecture decisions, security audits, legal review, ML design"
    }
  },
  "teams": {
    "review": {
      "description": "Code quality, security, and documentation review pipeline",
      "agents": ["code-reviewer", "security-auditor", "doc-verifier", "tdd-test-writer"]
    },
    "frontend": {
      "description": "Frontend and UI development team",
      "agents": ["frontend-dev", "frontend-developer", "ui-designer", "ux-researcher", "visual-tester"]
    }
  },
  "agents": [
    {
      "name": "code-reviewer",
      "file": "agents/core/engineering/code-reviewer.md",
      "source": "core",
      "department": "engineering",
      "description": "Reviews code for quality, correctness, and adherence to project standards",
      "model_tier": "sonnet",
      "capabilities": ["code-review", "static-analysis", "feedback"],
      "tools": ["Read", "Glob", "Grep"],
      "teams": ["review", "fullstack"]
    },
    {
      "name": "security-auditor",
      "file": "agents/core/engineering/security-auditor.md",
      "source": "core",
      "department": "engineering",
      "description": "Audits code and config for security vulnerabilities and policy violations",
      "model_tier": "opus",
      "capabilities": ["security-audit", "threat-modeling", "owasp"],
      "tools": ["Read", "Glob", "Grep", "Bash"],
      "teams": ["review", "backend", "fullstack"]
    }
  ],
  "total": 2
}
```

---

### GET /api/agents/:name

Returns full detail for a single named agent, including its parsed frontmatter and the raw markdown body.

**Tauri command:** `invoke('get_agent', { name: string })`

#### Path Parameters

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Agent kebab-case name (e.g. `"code-reviewer"`, `"security-auditor"`) |

#### Response Schema

```typescript
interface AgentDetailResponse extends AgentEntry {
  frontmatter: AgentFrontmatter;
  body: string;              // Raw markdown content after the frontmatter block
  file_path: string;         // Resolved absolute path to the .md file
}

interface AgentFrontmatter {
  name: string;
  department?: string;
  description: string;
  model?: 'haiku' | 'sonnet' | 'opus' | 'custom';
  tools?: string;            // Comma-separated string as written in YAML
  memory?: 'user' | 'project';
  skills?: string[];
  permissionMode?: string;
  invoked_by?: string[];
  escalation?: string;
  color?: string;
  maxTurns?: number;
}
```

Returns `AppError { kind: 'notFound' }` if no agent with the given name exists in the catalog.

#### Source Files

- `agents/catalog.json` — to resolve the agent's `.file` path
- The resolved `.md` file for frontmatter and body content

#### Example Response

```json
{
  "name": "code-reviewer",
  "file": "agents/core/engineering/code-reviewer.md",
  "file_path": "/Users/calebmambwe/.claude-super-setup/agents/core/engineering/code-reviewer.md",
  "source": "core",
  "department": "engineering",
  "description": "Reviews code for quality, correctness, and adherence to project standards",
  "model_tier": "sonnet",
  "capabilities": ["code-review", "static-analysis", "feedback"],
  "tools": ["Read", "Glob", "Grep"],
  "teams": ["review", "fullstack"],
  "frontmatter": {
    "name": "code-reviewer",
    "department": "engineering",
    "description": "Reviews code for quality, correctness, and adherence to project standards",
    "model": "sonnet",
    "tools": "Read, Glob, Grep",
    "memory": "project",
    "invoked_by": ["check", "auto-ship"],
    "escalation": "security-auditor",
    "maxTurns": 10
  },
  "body": "# Code Reviewer\n\nYou are a senior code reviewer...\n"
}
```

---

### POST /api/commands/:name/run

Triggers a named Claude Code command by spawning a `claude -p /<name>` subprocess in the specified project directory. Returns immediately with an execution ID; the subprocess runs asynchronously and emits a `command-output` Tauri event as lines arrive.

**Tauri command:** `invoke('run_command', { name: string, args?: string, projectDir?: string })`

> **Security:** This command is local-only. The Tauri app enforces this via OS-level process isolation — no remote callers can reach the `invoke()` bridge. Commands run as the current macOS user with their existing shell permissions. No privilege escalation occurs.

#### Path Parameters

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Command name without the leading slash (e.g. `"check"`, `"auto-dev"`, `"ship"`) |

#### Request Body

```typescript
interface RunCommandRequest {
  args?: string;          // Arguments appended after the command name, e.g. "my-feature-name"
  project_dir?: string;   // Absolute path to run the command in; defaults to process.cwd()
}
```

> **Input Validation (required):**
> - `name` MUST be checked against a static command allowlist before execution.
> - `args` MUST match `^[a-zA-Z0-9 _./-]{0,200}$` — reject anything else. Pass to `Command::arg()` as a discrete element, never interpolated into a shell string.
> - `project_dir` MUST be canonicalized via `fs::canonicalize()` and checked against a set of permitted root directories before use as `cwd`.

#### Response Schema

```typescript
interface RunCommandResponse {
  execution_id: string;   // UUID v4 — used to correlate subsequent Tauri events
  status: 'started';
  command: string;        // Full command string that was executed, e.g. "/auto-dev my-feature"
  project_dir: string;    // Resolved project directory used
  started_at: string;     // ISO 8601
}
```

#### Live Output Events

After the command starts, the Rust backend emits Tauri events on channel `command-output`:

```typescript
interface CommandOutputEvent {
  execution_id: string;
  line: string;           // A single line of stdout or stderr output
  stream: 'stdout' | 'stderr';
  finished: boolean;      // true on the final event when process exits
  exit_code?: number;     // Present only when finished: true
}
```

Frontend usage:
```typescript
listen<CommandOutputEvent>('command-output', (event) => {
  if (event.payload.execution_id === myExecutionId) {
    appendOutputLine(event.payload.line);
  }
});
```

#### Source Files

- Spawns `claude` CLI subprocess via `tokio::process::Command`
- Working directory set to `project_dir`

#### Example Request Body

```json
{
  "args": "add telegram notification for pipeline completion",
  "project_dir": "/Users/calebmambwe/claude_super_setup"
}
```

#### Example Response

```json
{
  "execution_id": "a3f2c1d0-7b4e-4a1f-9c8d-2e5f6b7a0c3d",
  "status": "started",
  "command": "/auto-dev add telegram notification for pipeline completion",
  "project_dir": "/Users/calebmambwe/claude_super_setup",
  "started_at": "2026-03-24T16:45:00Z"
}
```

---

### GET /api/teams

Returns all team presets, each describing agent composition, model tiers, and workflow steps.

**Tauri command:** `invoke('list_teams')`

#### Query Parameters

None.

#### Response Schema

```typescript
interface TeamListResponse {
  teams: TeamPreset[];
  total: number;
}

interface TeamPreset {
  name: string;                   // kebab-case identifier, e.g. "review", "feature", "debug"
  description: string;
  agents: TeamAgentRef[];
  workflow_steps: string[];       // Ordered list of workflow step labels
  model_tier: 'haiku' | 'sonnet' | 'opus'; // Default tier for the team
  file_path: string;              // Absolute path to the source .json file
}

interface TeamAgentRef {
  name: string;        // Agent kebab-case name — must match an entry in catalog.json
  role: string;        // Human-readable role within this team context
}
```

#### Source Files

- All `*.json` files under `agents/teams/` in the claude-super-setup directory

#### Example Response

```json
{
  "teams": [
    {
      "name": "review",
      "description": "Code quality, security, and documentation review pipeline",
      "agents": [
        { "name": "code-reviewer",   "role": "Primary code quality reviewer" },
        { "name": "security-auditor","role": "Security vulnerability scanner" },
        { "name": "doc-verifier",    "role": "Documentation accuracy checker" },
        { "name": "tdd-test-writer", "role": "Test coverage verifier" }
      ],
      "workflow_steps": ["read-diff", "review-code", "audit-security", "verify-docs", "write-summary"],
      "model_tier": "sonnet",
      "file_path": "/Users/calebmambwe/.claude-super-setup/agents/teams/review.json"
    },
    {
      "name": "feature",
      "description": "Full-stack feature development team",
      "agents": [
        { "name": "architect",       "role": "System design and architecture" },
        { "name": "backend-dev",     "role": "API and data layer implementation" },
        { "name": "frontend-dev",    "role": "UI and component implementation" },
        { "name": "tdd-test-writer", "role": "Test suite authoring" }
      ],
      "workflow_steps": ["spec", "architect", "implement-backend", "implement-frontend", "write-tests", "review"],
      "model_tier": "sonnet",
      "file_path": "/Users/calebmambwe/.claude-super-setup/agents/teams/feature.json"
    },
    {
      "name": "debug",
      "description": "Environment diagnosis and test failure recovery team",
      "agents": [
        { "name": "env-doctor",         "role": "Environment and config diagnosis" },
        { "name": "test-writer-fixer",  "role": "Failing test repair" },
        { "name": "researcher",         "role": "Root cause research" }
      ],
      "workflow_steps": ["diagnose", "reproduce", "research", "fix", "verify"],
      "model_tier": "sonnet",
      "file_path": "/Users/calebmambwe/.claude-super-setup/agents/teams/debug.json"
    }
  ],
  "total": 3
}
```

---

### GET /api/health

Returns a system health snapshot: Claude Code availability, MCP server connection status, ghost mode state, and sandbox container status.

**Tauri command:** `invoke('get_health')`

#### Query Parameters

None.

#### Response Schema

```typescript
interface HealthResponse {
  claude_code: boolean;           // true if `claude --version` exits 0
  mcp_servers: McpServerStatus[];
  ghost_mode: 'idle' | 'running' | 'blocked';
  sandbox: 'running' | 'stopped' | 'unavailable';
  checked_at: string;             // ISO 8601 — timestamp of this health check
}

interface McpServerStatus {
  name: string;                           // MCP server name, e.g. "context7", "sandbox"
  status: 'connected' | 'disconnected';
  last_seen?: string;                     // ISO 8601 — last successful ping, if available
}
```

#### Source Files

- `claude --version` subprocess — for `claude_code`
- `~/.claude/ghost-config.json` — for `ghost_mode` (reads `status` field)
- `docker ps` or equivalent — for `sandbox` container state
- `~/.mcp.json` — to enumerate expected MCP servers; ping each to determine connected status

#### Example Response

```json
{
  "claude_code": true,
  "mcp_servers": [
    {
      "name": "context7",
      "status": "connected",
      "last_seen": "2026-03-24T16:44:58Z"
    },
    {
      "name": "sandbox",
      "status": "connected",
      "last_seen": "2026-03-24T16:44:57Z"
    },
    {
      "name": "learning",
      "status": "connected",
      "last_seen": "2026-03-24T16:44:58Z"
    },
    {
      "name": "memory",
      "status": "disconnected"
    }
  ],
  "ghost_mode": "idle",
  "sandbox": "running",
  "checked_at": "2026-03-24T16:45:00Z"
}
```

---

## Data Type Reference

All TypeScript interfaces used across endpoints are consolidated here for import clarity.

```typescript
// types/api.ts — canonical type definitions for Smart Hub API responses

export type PipelineStatus = 'idle' | 'running' | 'blocked' | 'complete';
export type TaskStatus     = 'pending' | 'in_progress' | 'completed' | 'failed';
export type Priority       = 'P0' | 'P1' | 'P2';
export type Risk           = 'low' | 'medium' | 'high';
export type ModelTierName  = 'haiku' | 'sonnet' | 'opus' | 'custom';
export type AgentDepartment =
  | 'engineering' | 'testing' | 'design' | 'product'
  | 'marketing'   | 'studio-operations' | 'project-management' | 'bonus';
export type MetricsPeriod  = 'day' | 'week' | 'month';
export type AppErrorKind   = 'io' | 'parse' | 'notFound' | 'shell';

export interface AppError {
  kind: AppErrorKind;
  message: string;
}
```

---

## Changelog

| Version | Date | Notes |
|---|---|---|
| 1.0.0 | 2026-03-24 | Initial spec — 10 endpoints covering pipeline, tasks, metrics, agents, teams, health, and command execution |
