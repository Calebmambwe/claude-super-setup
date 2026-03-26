---
name: agent-search
description: Search local catalog and LobeHub marketplace for agents — shows name, department, model tier, description, and source
---
Search for agents matching: $ARGUMENTS

You are the Agent Search agent. Find agents relevant to the user's query by combining local catalog discovery with remote LobeHub marketplace results, then display unified results.

---

## Step 1: Parse the Query

Extract the search term from $ARGUMENTS. If no argument is provided, display all local agents grouped by department and skip the remote search.

Examples:
- `/agent-search coding` → query = "coding"
- `/agent-search "data analysis"` → query = "data analysis"
- `/agent-search` → list all local agents grouped by department, no remote search

---

## Step 2: Search Local Catalog

Read `agents/catalog.json` and extract all entries from the `"agents"` array.

For each agent entry, collect:
- `name` — agent identifier
- `department` — department grouping (e.g. "engineering", "design", "mobile")
- `model_tier` — one of `haiku`, `sonnet`, `opus`, `custom`
- `description` — what the agent does
- `capabilities` — list of capability tags
- `source` — `core`, `community`, or `imported`

**Filter local results:** If a query was provided, include only agents whose `name`, `description`, `capabilities`, or `tags` contain the query string (case-insensitive substring match). If no query, include all.

**If no query provided:** Skip to the "No-Query Display" section below.

---

## Step 3: Search LobeHub Marketplace (only when query is provided)

Search for remote agents matching the query using WebSearch:

**Primary method — WebSearch:**
```
Search query: site:lobehub.com/discover/agent "<QUERY>"
```

Also try:
```
Search query: lobehub agent "<QUERY>" site:lobehub.com
```

For each remote result, collect:
- `name` — agent name as shown on LobeHub
- `description` — what the agent does (first sentence or subtitle)
- `link` — the full LobeHub URL (e.g. `https://lobehub.com/discover/agent/<id>`)
- `lobehub_id` — the slug from the URL path

**Deduplicate:** If a remote agent's name or lobehub_id matches a local agent's `lobehub_id` field (if present), mark it as `installed: true` and show it once as local. Do not show it again as a remote result.

If WebSearch yields no results, note this in the output and do not treat it as an error — local results still display.

---

## Step 4: Merge and Display Results (query provided)

Combine local and remote results into a single deduplicated list.

Sort order: local agents first (alphabetically by name), then remote agents (alphabetically by name).

Display the merged results as a Markdown table:

```
## Agent Search Results: "<query>"

Found {local_count} local · {remote_count} remote · {total_unique} unique

### Local Agents

| Agent | Department | Tier | Description | Source |
|-------|------------|------|-------------|--------|
| architect | engineering | opus | Plans architecture for multi-file changes | core |
| backend-dev | engineering | sonnet | Implements backend services following Route/Service/Repository architecture | core |

### LobeHub Agents

| Agent | Description | Link |
|-------|-------------|------|
| [sql-expert](https://lobehub.com/discover/agent/sql-expert) | Expert in SQL query design and database optimisation | https://lobehub.com/discover/agent/sql-expert |
```

Column definitions:
- **Agent** — name (hyperlinked to LobeHub URL for remote agents)
- **Department** — department field from catalog (local agents only)
- **Tier** — model_tier from catalog (`haiku` / `sonnet` / `opus` / `custom`) (local agents only)
- **Description** — truncated to 80 characters
- **Source** — `core`, `community`, `imported`, or `lobehub`
- **Link** — full LobeHub URL (remote agents only)

---

## No-Query Display (when $ARGUMENTS is empty)

When no query is provided, display all local agents grouped by department. Do not run a remote search.

```
## Local Agents — All Departments

### engineering (N agents)

| Agent | Tier | Description | Source |
|-------|------|-------------|--------|
| architect | opus | Plans architecture for multi-file changes | core |
| backend-dev | sonnet | Implements backend services ... | core |

### design (N agents)
...

---
To search for more agents (including LobeHub marketplace):
  /agent-search <query>

Browse LobeHub: https://lobehub.com/discover/agent
```

Group agents alphabetically within each department. Sort departments alphabetically.

---

## Step 5: Offer Next Actions

After all results, print:

```
### Import a LobeHub agent

To import a remote agent into your local catalog:
  /agent-import <lobehub-url-or-id>

Example:
  /agent-import https://lobehub.com/discover/agent/sql-expert
  /agent-import sql-expert

### Can't find what you need?

Browse the full LobeHub agent marketplace: https://lobehub.com/discover/agent
```

If zero results were found (both local and remote), suggest broadening the query:

```
No agents found for "<query>".

Try a broader term — e.g., /agent-search coding instead of /agent-search python-debugger.
Or browse: https://lobehub.com/discover/agent
```

---

## Rules

- ALWAYS read `agents/catalog.json` before making any remote calls — local results are instant
- NEVER skip local discovery even if a query is provided
- NEVER show duplicate entries — if a remote agent matches a local agent, show it once as local
- ALWAYS truncate descriptions to 80 characters in the table to keep output readable
- NEVER run a WebSearch when no query is provided — only list local agents
- If WebSearch fails or returns no results, show local results only and note the remote search was inconclusive
- Do NOT surface agents with `source: "imported"` differently from other local agents — they are fully local
