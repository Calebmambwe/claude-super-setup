---
name: mcp-list
description: List all installed MCP servers from Claude Code settings — shows name, transport, registry source, and configuration status in a readable table
---
List installed MCP servers.

You are the MCP List agent. Your job is to read the user's installed MCP servers from Claude Code settings, cross-reference them with the registry cache to determine their source, and display a clear summary table.

---

## Step 1: Read Installed Servers

Read `~/.claude/settings.json`:

```bash
cat ~/.claude/settings.json
```

If the file does not exist or cannot be read, stop:

```
Could not read ~/.claude/settings.json. Is Claude Code installed?
```

Extract the `mcpServers` object. If it is absent or empty:

```
No MCP servers are currently installed.

Run /mcp-search <query> to find servers, then /mcp-install <name> to add one.
```

Collect each installed server. For each key in `mcpServers`, note:
- **key** — the name used in settings (e.g. `mcp-filesystem`)
- **command** — `entry.command` (for stdio)
- **args** — `entry.args` (for stdio)
- **url** — `entry.url` (for http/sse)
- **env** — `entry.env` (keys only, not values)
- **transport** — infer from entry: if `url` is present → `http`; if `command` is present → `stdio`; otherwise `unknown`

---

## Step 2: Load the Registry Cache

Read `~/.claude/mcp-registry/cache.json`:

```bash
cat ~/.claude/mcp-registry/cache.json
```

If the cache does not exist, continue without it — mark all sources as `custom` and note the cache is absent.

Parse the `servers` array. Build a lookup map: `identifier → registry`.

---

## Step 3: Determine Source for Each Installed Server

For each installed server key, try to find a matching registry entry:

1. Look for a cache entry whose `identifier` ends with `/<key>` (e.g. key `mcp-filesystem` matches `@lobehub/mcp-filesystem`)
2. Look for a cache entry whose `name` matches the key (case-insensitive)
3. Check the `command` or `url` field for registry-specific patterns:
   - Contains `@lobehub/` → `lobehub`
   - Contains `@modelcontextprotocol/` → `official`
   - Contains `@smithery/` → `smithery`
   - Local path (starts with `/` or `~/` or `.`) → `local`

If no match is found in the cache and no pattern matches: `custom`

Map registry values to display labels:
- `lobehub` → `lobehub`
- `modelcontextprotocol` → `official`
- `smithery` → `smithery`
- local path → `local`
- no match → `custom`

---

## Step 4: Check Configuration Status

For each installed server, determine its configuration status:

- **configured** — all env vars are non-empty strings (or there are no env vars)
- **incomplete** — one or more env var values are empty (`""`) or placeholder-like (`<...>`, `YOUR_*`, `REPLACE_*`)
- **unknown** — the `env` field is absent (assume configured)

---

## Step 5: Display the Table

Print a Markdown table of all installed servers:

```
## Installed MCP Servers

Found <N> server(s) installed in ~/.claude/settings.json

| Server | Transport | Source | Status |
|--------|-----------|--------|--------|
| mcp-filesystem | stdio | lobehub | configured |
| github | stdio | official | incomplete (GITHUB_TOKEN missing) |
| brave-search | http | smithery | configured |
| my-local-tool | stdio | local | configured |

```

Column definitions:
- **Server** — the key from `mcpServers`
- **Transport** — `stdio`, `http`, `sse`, or `unknown`
- **Source** — `lobehub`, `official`, `smithery`, `local`, or `custom`
- **Status** — `configured` or `incomplete (<var> missing)` listing incomplete var names

After the table, print summary counts:

```
Summary: <N> installed · <configured> configured · <incomplete> need configuration

```

---

## Step 6: Show Incomplete Servers Detail

If any servers have `incomplete` status, add a section below the table:

```
### Servers needing configuration

Edit ~/.claude/settings.json and fill in the missing values:

**github**
  GITHUB_TOKEN = ""   ← add your personal access token here

Restart Claude Code after making changes.
```

---

## Step 7: Offer Next Actions

Always close with:

```
### Manage servers

  /mcp-search <query>     — find new servers to install
  /mcp-install <name>     — install a server from the registry
  /mcp-remove <name>      — remove an installed server
```

If the registry cache is absent or stale (older than 24 hours), also show:

```
  Note: Registry cache is absent or stale. Run /mcp-search to refresh it.
```

---

## Rules

- NEVER display env var values — show only the key names and whether they are set
- ALWAYS read settings.json before the cache — installed list is the source of truth
- If the cache is missing, still show all installed servers with source marked as `custom`
- Infer transport from the entry structure, not from the cache
- Sort the table: `incomplete` servers first, then `configured`, both groups alphabetically by key
- Show absolute path expansions for local servers (e.g. `~/tools/my-server` → resolved path)
