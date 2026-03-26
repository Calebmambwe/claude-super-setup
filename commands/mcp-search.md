---
name: mcp-search
description: Search MCP servers across LobeHub, Official MCP Registry, and Smithery using the local cache — shows name, registry, transport, stars, and install status
---
Search for MCP servers matching: $ARGUMENTS

You are the MCP Search agent. Find MCP servers relevant to the user's query using the local registry cache, then display a formatted table with install status.

---

## Step 1: Parse the Query

Extract the search term from $ARGUMENTS. Treat the entire argument string as the query.

Examples:
- `/mcp-search github` → query = "github"
- `/mcp-search "web search"` → query = "web search"
- `/mcp-search` → no query; show top 20 most popular servers by stars

---

## Step 2: Check and Refresh the Cache

Check whether the cache file exists and is fresh:

```bash
# Check cache existence and age
stat ~/.claude/mcp-registry/cache.json 2>/dev/null || echo "MISSING"
```

Determine cache staleness:
- If the file does not exist → cache is **missing**
- If the file exists, read its `cached_at` field and compare to the current time
  - If `cached_at` is more than 24 hours ago → cache is **stale**
  - Otherwise → cache is **fresh**

If the cache is **missing or stale**, refresh it by running:

```bash
# Refresh the registry cache (uses uv for dependency management)
uv run --with httpx /Users/calebmambwe/claude_super_setup/scripts/mcp-registry-fetch.py
```

If the script is not available via `uv`, fall back to:

```bash
python3 /Users/calebmambwe/claude_super_setup/scripts/mcp-registry-fetch.py
```

Wait for the script to complete before proceeding. If it fails, continue with whatever cache exists (stale data is better than no data). Note the failure in the output.

---

## Step 3: Load the Cache

Read `~/.claude/mcp-registry/cache.json`. The file has this structure:

```json
{
  "cached_at": "<ISO timestamp>",
  "servers": [
    {
      "identifier": "@lobehub/github",
      "name": "GitHub",
      "registry": "lobehub",
      "transport": "stdio",
      "description": "Interact with GitHub repositories",
      "tags": ["github", "git", "version-control"],
      "categories": ["developer-tools"],
      "stars": 1200,
      "install_config": { "command": "npx", "args": ["-y", "@lobehub/mcp-github"] }
    }
  ]
}
```

Key fields per server entry:
- `identifier` — unique ID (e.g. `@lobehub/github`)
- `name` — human-readable display name
- `registry` — source registry: `lobehub`, `modelcontextprotocol`, or `smithery`
- `transport` — connection type: `stdio`, `http`, or `sse`
- `description` — what the server does
- `tags` — keyword list
- `categories` — category list
- `stars` — popularity count (may be `null`)

---

## Step 4: Check Installed Servers

Read the user's Claude settings to determine which MCP servers are already installed. Try these paths in order (stop at the first one that exists and contains `mcpServers`):

```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json 2>/dev/null
cat ~/.config/claude/claude_desktop_config.json 2>/dev/null
cat ~/.claude/settings.json 2>/dev/null
```

Extract the keys from the `mcpServers` object — these are the installed server names. Example:

```json
{
  "mcpServers": {
    "github": { ... },
    "filesystem": { ... }
  }
}
```

Installed names here: `github`, `filesystem`.

Build an **installed set** by collecting all keys from `mcpServers`. If none of the config files can be read, the installed set is empty — note this in the output.

---

## Step 5: Score and Filter Results

**If a query was provided**, score each server entry against the query (case-insensitive substring match):

| Field matched | Points |
|---------------|--------|
| `name` | +10 |
| `tags` (any tag) | +5 |
| `categories` (any category) | +3 |
| `description` | +1 |

Scoring rules:
- A server scores 0 if it matches none of the fields — exclude it from results
- A server that matches multiple fields accumulates points from each match
- Sort results by `(score DESC, stars DESC)` — highest score first, then most stars as a tiebreaker
- `null` stars count as 0 for sorting purposes

**If no query was provided**, skip scoring. Return all servers sorted by `stars DESC` and take the top 20.

---

## Step 6: Determine Install Status

For each result, determine its status:
- **installed** — the server's `name` (case-insensitive) is in the installed set, OR the last segment of the `identifier` (e.g. `github` from `@lobehub/github`) is in the installed set
- **available** — not installed

---

## Step 7: Display Results

Display results as a Markdown table. Cap the table at **20 rows**. If more matches exist, show a count of additional results beneath the table.

```
## MCP Server Search: "<query>"

Cache: <N> servers · fetched <relative time ago> · from lobehub, modelcontextprotocol, smithery
Found <M> match(es)

| # | Name | Registry | Transport | Stars | Status |
|---|------|----------|-----------|-------|--------|
| 1 | GitHub | lobehub | stdio | 1200 | installed |
| 2 | GitLab | modelcontextprotocol | stdio | 430 | available |
| 3 | Gitea | smithery | http | — | available |
```

Column definitions:
- **#** — rank (1-based)
- **Name** — display name from `name` field
- **Registry** — `lobehub`, `modelcontextprotocol`, or `smithery`
- **Transport** — `stdio`, `http`, or `sse`
- **Stars** — numeric value, or `—` if null
- **Status** — `installed` or `available`

After the table, if results were capped, print:

```
Showing top 20 of <total> matches. Refine your query to narrow results.
```

---

## Step 8: Show Install Instructions

After the results table, always print:

```
### Install an MCP server

  /mcp-install <name>

Example: /mcp-install github
```

If no query was provided (top-20 mode), also print:

```
### Search for a specific server

  /mcp-search <query>

Example: /mcp-search web search
```

---

## Step 9: Handle Zero Results

If a query was provided but zero servers scored above 0:

```
No MCP servers found for "<query>".

Try a broader term — e.g. /mcp-search git instead of /mcp-search github-enterprise.

Browse registries directly:
  LobeHub:                https://lobehub.com/mcp
  Official MCP Registry:  https://registry.modelcontextprotocol.io
  Smithery:               https://smithery.ai
```

---

## Rules

- ALWAYS check cache freshness before searching — never search a cache older than 24 hours without first attempting a refresh
- ALWAYS check the installed set before displaying results — status accuracy matters
- NEVER show more than 20 rows in the table — cap and note the overflow
- NEVER skip the install instruction footer — it tells the user what to do next
- Truncate descriptions in any prose output to 80 characters, but do NOT show descriptions in the table (keep the table scannable)
- If the cache refresh script fails, continue with stale data and note: `Warning: cache refresh failed — showing potentially stale results (<cached_at>)`
- If no Claude config file is found, show all results as `available` and note: `Note: could not read Claude config — install status unknown`
- `null` stars display as `—` in the table, not `0` or `null`
- Registry labels in the table must use the shorthand: `lobehub`, `modelcontextprotocol`, `smithery` — never the full URL
