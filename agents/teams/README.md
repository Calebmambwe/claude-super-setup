# Agent Team Presets

Team presets are predefined agent compositions for common development workflows. Each preset wires together a set of agents from `catalog.json`, assigns them roles, and defines a dependency-aware workflow — ready to invoke from VS Code with a single keybinding or slash command.

---

## What Are Team Presets?

A team preset answers: "Which agents do I need for this class of work, in what order, running in parallel where safe?"

- **review** — Code quality, security, and acceptance-criteria verification before any PR merge
- **feature** — Full-stack feature development: architect plans, backend and frontend implement in parallel, TDD validates
- **debug** — Environment diagnosis, root-cause research, and test fixing for failures and regressions

Presets are VS Code-specific configuration files. They reference agents by name (which must exist in `catalog.json`) and layer on top of the logical team definitions already declared under `catalog.json > teams`.

---

## JSON Schema

Every preset file conforms to `../../schemas/team-preset.schema.json`. The top-level fields are:

```json
{
  "$schema": "../../schemas/team-preset.schema.json",
  "name": "string — unique ID, matches filename",
  "description": "string — what this team does and when to use it",
  "model_tier": "haiku | sonnet | opus | custom — default for all agents",
  "agents": [...],
  "workflow": [...],
  "triggers": { "manual": "...", "automatic": "..." },
  "vscode_integration": { "task_label": "...", "keybinding": "...", "status_bar": true }
}
```

### agents array

Each agent entry declares its role within this team:

```json
{
  "name": "code-reviewer",           // must match catalog.json
  "role": "lead",                    // lead | specialist | implementer | quality | gatekeeper | diagnostician | fixer | investigator
  "description": "...",             // what it does in this team's context
  "model_tier_override": "sonnet",  // optional — overrides team-level model_tier for this agent only
  "tools": ["Read", "Grep", "Bash"] // tools this agent is permitted to use
}
```

### workflow array

Steps are numbered from 1. Execution is sequential by default; add `parallel_with` to run two steps concurrently, or `depends_on` to express a multi-step dependency:

```json
{ "step": 1, "agent": "architect",    "action": "Analyze requirements and create implementation plan" },
{ "step": 3, "agent": "backend-dev",  "action": "Implement backend changes", "depends_on": [1] },
{ "step": 4, "agent": "frontend-dev", "action": "Implement frontend changes", "parallel_with": 3, "depends_on": [1] },
{ "step": 5, "agent": "tdd-test-writer", "action": "Verify all tests pass",  "depends_on": [3, 4] }
```

- `parallel_with: N` — this step may start at the same time as step N
- `depends_on: [N, M]` — this step waits for steps N and M to complete

---

## Using Presets in VS Code

### Keybindings

| Team    | Keybinding      | VS Code Task Label        |
|---------|-----------------|---------------------------|
| review  | `Cmd+Shift+R`   | Claude: Review Team       |
| feature | `Cmd+Shift+F`   | Claude: Feature Team      |
| debug   | `Cmd+Shift+D`   | Claude: Debug Team        |

Keybindings are declared in `vscode_integration.keybinding` and should be registered in `.vscode/keybindings.json` for the project, or in the user's global keybindings.

### Status Bar

Presets with `"status_bar": true` will surface a clickable button in the VS Code status bar when the team is active.

### Slash Commands (Manual Trigger)

Each preset also declares manual slash commands:

```
/review        → triggers the review team
/check         → alias for /review
/code-review   → alias for /review

/build         → triggers the feature team
/team-build    → alias for /build

/debug         → triggers the debug team
```

---

## Creating a Custom Preset

1. Copy an existing preset as a starting point:
   ```bash
   cp agents/teams/feature.json agents/teams/my-team.json
   ```

2. Update the top-level `name` (must match the filename without `.json`) and `description`.

3. Edit the `agents` array. Each agent name must appear in `catalog.json`. If you need a new agent, add it to `catalog.json` first.

4. Update the `workflow` array to reflect your desired execution order and parallelism.

5. Set `triggers.manual` to the slash commands that should invoke your team.

6. Set `vscode_integration.task_label` and `vscode_integration.keybinding` to a shortcut not already in use by the three built-in presets.

7. Validate the file conforms to the schema:
   ```bash
   npx ajv validate -s schemas/team-preset.schema.json -d agents/teams/my-team.json
   ```

---

## Relationship to catalog.json Teams

`catalog.json > teams` contains **logical team definitions** — a list of agent names grouped by purpose (review, backend, frontend, etc.). These are the canonical registry entries.

Team presets in this directory are **VS Code-specific execution configs** that build on those logical teams by adding:

- Ordered, dependency-aware workflow steps
- Per-agent model tier overrides
- Per-agent tool restrictions
- Keybindings, status bar, and task label metadata

A preset may use a subset of the agents listed in the corresponding `catalog.json` team, and may assign them different roles depending on the workflow being modeled.

---

## Available Presets

| File          | Team     | Description                                                                  |
|---------------|----------|------------------------------------------------------------------------------|
| `review.json` | review   | Code quality, security audit, and acceptance criteria verification           |
| `feature.json`| feature  | Architecture planning, parallel backend/frontend implementation, TDD gating  |
| `debug.json`  | debug    | Environment diagnosis, error research, and test regression fixing            |
