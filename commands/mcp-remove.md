---
name: mcp-remove
description: Remove an installed MCP server from Claude Code settings by name — safely deletes only the target entry and leaves all other mcpServers intact
---
Remove MCP server: $ARGUMENTS

You are the MCP Remove agent. Your job is to find the named server in the user's Claude Code settings and remove it cleanly, leaving all other configuration untouched.

---

## Step 1: Parse the Argument

Extract the server name from `$ARGUMENTS`.

If no argument is provided, stop and print:

```
Usage: /mcp-remove <server-name>

Run /mcp-list to see installed servers and their exact names.
```

---

## Step 2: Read Current Settings

Read `~/.claude/settings.json`:

```bash
cat ~/.claude/settings.json
```

If the file does not exist or cannot be read, stop:

```
Could not read ~/.claude/settings.json. Is Claude Code installed?
```

Parse the `mcpServers` object. Collect all keys.

---

## Step 3: Find the Target Entry

Look for the server in `mcpServers` using the following matching strategy (in order):

1. **Exact key match**: the argument equals a key in `mcpServers` exactly
2. **Suffix match**: a key ends with the argument (e.g. argument `filesystem` matches key `mcp-filesystem`)
3. **Partial match** (case-insensitive): a key contains the argument substring

If no match is found, stop:

```
Server '<argument>' is not installed.

Installed servers:
<list all mcpServers keys, one per line>

Run /mcp-list for full details.
```

If multiple keys match (e.g. both `mcp-filesystem` and `lobehub-mcp-filesystem` contain "filesystem"), list them and ask the user to be specific:

```
Multiple installed servers matched '<argument>':

  mcp-filesystem
  lobehub-mcp-filesystem

Re-run with the exact name: /mcp-remove mcp-filesystem
```

Stop here until the user clarifies.

---

## Step 4: Confirm the Removal

Display the entry that will be removed and ask for confirmation:

```
About to remove:

  Key:       <matched-key>
  Command:   <command> <args...>    (for stdio)
  URL:       <url>                  (for http)
  Env vars:  <list of env var keys, values redacted>

Proceed? [y/N]
```

Wait for user confirmation. If the user responds with anything other than `y` or `yes` (case-insensitive), abort:

```
Removal cancelled. No changes made.
```

---

## Step 5: Remove the Entry

Use `jq` to delete the key if available:

```bash
jq 'del(.mcpServers["<matched-key>"])' ~/.claude/settings.json > /tmp/settings-patch.json \
  && mv /tmp/settings-patch.json ~/.claude/settings.json
```

If `jq` is unavailable, read the JSON, remove only the target key from `mcpServers`, and write the file back — preserving all other content exactly.

Verify the key is gone after writing:

```bash
jq '.mcpServers | keys' ~/.claude/settings.json
```

---

## Step 6: Report Success

```
MCP server '<matched-key>' removed.

Restart Claude Code to deactivate the server.

Remaining installed servers: <count>
Run /mcp-list to see what's still installed.
```

---

## Rules

- NEVER remove more than one key per invocation unless the user explicitly passes multiple names
- NEVER modify any other section of settings.json — only the target key inside `mcpServers`
- ALWAYS confirm with the user before deleting (Step 4 is mandatory)
- If `jq` is available, always prefer it for JSON manipulation
- After writing, verify the key was actually removed before declaring success
- Do not display env var values in any output — show only the keys
