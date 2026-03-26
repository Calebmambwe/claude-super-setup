---
name: mcp-install
description: Install an MCP server from the registry into Claude Code settings — looks up the server, prompts for required env vars, and merges the entry into mcpServers without overwriting existing servers
---
Install MCP server: $ARGUMENTS

You are the MCP Install agent. Your job is to look up the requested server in the local registry cache, collect any required configuration, and safely merge the server entry into the user's Claude Code settings.

---

## Step 1: Parse the Argument

Extract the server identifier from `$ARGUMENTS`. The argument may be:

- A full registry identifier: `@lobehub/mcp-filesystem`, `@modelcontextprotocol/github`, `@smithery/brave-search`
- A short name: `filesystem`, `github`, `brave-search`
- A number from recent `/mcp-search` results (e.g. `3`)

If no argument is provided, stop and print:

```
Usage: /mcp-install <server-name-or-number>

Run /mcp-search <query> first to find servers, then install by name or number.
```

---

## Step 2: Load the Registry Cache

Read `~/.claude/mcp-registry/cache.json`.

```bash
cat ~/.claude/mcp-registry/cache.json
```

If the file does not exist or is unreadable:

```
Registry cache not found. Run /mcp-search <query> first to populate the cache.
```

Parse the `servers` array. Each entry has this shape:

```json
{
  "identifier": "@lobehub/mcp-filesystem",
  "name": "Filesystem MCP",
  "description": "...",
  "registry": "lobehub",
  "transport": "stdio",
  "install_config": {
    "command": "npx",
    "args": ["-y", "@lobehub/mcp-filesystem"],
    "env": {
      "FILESYSTEM_ROOT": ""
    }
  }
}
```

---

## Step 3: Find the Server

Search the `servers` array for a match:

1. **By number**: if the argument is a digit, treat it as a 1-based index into the most recent search results (if available in context). Otherwise, fall back to name search.
2. **By exact identifier**: match `server.identifier === argument`
3. **By short name**: match if `server.identifier` ends with `/<argument>` or `server.name.toLowerCase()` contains the argument (case-insensitive)

If no match is found:

```
Server '<argument>' not found in the registry cache.

Try /mcp-search <query> to find servers, or check the spelling.
```

If multiple matches are found, display them and ask the user to be more specific:

```
Multiple servers matched '<argument>':

  1. @lobehub/filesystem        — Filesystem MCP (lobehub)
  2. @smithery/mcp-filesystem   — Filesystem via Smithery (smithery)

Re-run with the full identifier: /mcp-install @lobehub/filesystem
```

---

## Step 4: Check If Already Installed

Read the user's Claude Code settings:

```bash
cat ~/.claude/settings.json
```

Parse the `mcpServers` object. The key is typically a short name (the part after the last `/` in the identifier, stripped of `@` and scope).

Check if an entry matching the server name already exists. If yes:

```
MCP server '<name>' is already installed.

Current config:
  Command: <command> <args...>
  Env vars: <list>

To reinstall or update, remove it first with /mcp-remove <name>, then re-run this command.
```

Stop here — do not overwrite.

---

## Step 5: Display Server Details

Show the server details before proceeding:

```
## Installing: <Name>

  Registry:    <lobehub | modelcontextprotocol | smithery>
  Transport:   <stdio | http | sse>
  Description: <description>
  URL:         <registry_url if present>

  Install command: <command> <args...>
```

---

## Step 6: Collect Required Environment Variables

Inspect `install_config.env`. For each key whose value is empty (`""`) or a placeholder (e.g. `"<YOUR_API_KEY>"`), prompt the user:

```
This server requires configuration:

  GITHUB_TOKEN — Personal access token for GitHub API (required)
  > Enter value (or press Enter to skip and configure later):
```

Wait for the user to provide values. Accept empty input as "skip" — record the key with an empty string so the entry is still added but the user knows to configure it.

If `install_config.env` is empty or all values are pre-filled, skip this step.

---

## Step 7: Build the Settings Entry

Construct the `mcpServers` entry based on transport type:

**For stdio transport:**

```json
{
  "command": "<install_config.command>",
  "args": ["<install_config.args...>"],
  "env": {
    "KEY": "user-provided-or-empty-value"
  }
}
```

**For http / sse transport:**

```json
{
  "url": "<install_config.url>",
  "env": {
    "KEY": "user-provided-or-empty-value"
  }
}
```

Derive the entry key (the name used in `mcpServers`) from the identifier:

- Strip the `@scope/` prefix: `@lobehub/mcp-filesystem` → `mcp-filesystem`
- If the short name conflicts with an existing key, use the full scoped name without `@`: `lobehub-mcp-filesystem`

---

## Step 8: Merge Into settings.json

Read `~/.claude/settings.json` in full. Locate the `mcpServers` object. If it does not exist, create it as an empty object.

Add the new entry under the derived key. **Do not remove or modify any existing keys.** Write the file back.

```bash
# Read current settings
cat ~/.claude/settings.json

# After constructing the merged JSON, write it back
# Use jq to safely merge — never overwrite the whole file manually
jq '.mcpServers["<key>"] = <new-entry>' ~/.claude/settings.json > /tmp/settings-patch.json \
  && mv /tmp/settings-patch.json ~/.claude/settings.json
```

If `jq` is unavailable, read the JSON, surgically insert the new key, and write back — preserving all other content exactly.

---

## Step 9: Report Success

```
MCP server '<Name>' installed successfully.

  Key in mcpServers: <key>
  Transport:         <stdio | http>
  Command:           <command> <args...>

Restart Claude Code to activate the new server.

If you left any env vars blank, add them to ~/.claude/settings.json before restarting:
  "<KEY>": "your-value-here"
```

---

## Rules

- NEVER overwrite existing `mcpServers` entries — only add new keys
- NEVER write a partial JSON file — always validate the output is valid JSON before writing
- If `jq` is available, prefer it for JSON manipulation over manual string editing
- If `install_config` is absent from the cache entry, construct a best-effort entry using `npx -y <identifier>` and note it may need adjustment
- Always show the server details (Step 5) before making any changes
- If the user provides an env var value that looks like a secret, do not echo it back in the success message
