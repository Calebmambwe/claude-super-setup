---
name: agent-import
description: Import a LobeHub agent into the local catalog — fetches, converts, saves, and registers the agent
---
Import LobeHub agent: $ARGUMENTS

You are the Agent Import agent. Fetch an agent from the LobeHub marketplace, convert it to the local Markdown agent format, save it, and register it in the catalog.

---

## Step 1: Parse the Input

Extract the agent reference from $ARGUMENTS. Two input forms are accepted:

| Input form | Example | Extracted lobehub_id |
|------------|---------|----------------------|
| Full LobeHub URL | `https://lobehub.com/discover/agent/sql-expert` | `sql-expert` |
| Agent ID slug | `sql-expert` | `sql-expert` |

Rules:
- Strip trailing slashes from URLs before extracting the slug.
- If $ARGUMENTS is empty, print usage and stop:
  ```
  Usage: /agent-import <lobehub-url-or-id>

  Examples:
    /agent-import https://lobehub.com/discover/agent/sql-expert
    /agent-import sql-expert
  ```

Set:
- `lobehub_id` = extracted slug
- `agent_page_url` = `https://lobehub.com/discover/agent/<lobehub_id>`
- `agent_json_url` = `https://chat-agents.lobehub.com/<lobehub_id>.json`

---

## Step 2: Check for Existing Import

Read `agents/catalog.json`. Check whether any entry in the `"agents"` array already has `"lobehub_id": "<lobehub_id>"`.

If a match is found, print:

```
Agent '<lobehub_id>' is already in the local catalog as '<name>'.
File: <file path>

To re-import and overwrite, delete the existing entry from agents/catalog.json first.
```

Then stop.

---

## Step 3: Fetch Agent Data from LobeHub

**Primary method — fetch the JSON API endpoint:**

Use WebFetch to retrieve:
```
https://chat-agents.lobehub.com/<lobehub_id>.json
```

Parse the response as JSON. The LobeHub agent JSON schema looks like:

```json
{
  "identifier": "sql-expert",
  "meta": {
    "title": "SQL Expert",
    "description": "Expert in SQL query design and optimisation",
    "tags": ["sql", "database", "query"]
  },
  "config": {
    "systemRole": "You are an expert SQL developer...",
    "model": "gpt-4"
  }
}
```

Key fields to extract:
- `identifier` → lobehub_id (verify it matches)
- `meta.title` → agent display name
- `meta.description` → short description
- `meta.tags` → list of tags / capabilities
- `config.systemRole` → the system prompt
- `config.model` → model hint (used for tier mapping)

**Fallback method — scrape the agent page:**

If the JSON endpoint fails (non-200, malformed JSON, or missing `config.systemRole`), use WebFetch on the agent page URL and attempt to extract embedded JSON:

```
https://lobehub.com/discover/agent/<lobehub_id>
```

Look for a `<script id="__NEXT_DATA__" type="application/json">` block in the HTML and parse the JSON within it to locate the agent definition. Extract the same fields as above.

**Graceful failure:** If both methods fail to yield a usable agent definition (no `meta.title` or no `config.systemRole`), print:

```
Import failed for '<lobehub_id>'.

Could not retrieve agent data from LobeHub. The agent page may have changed structure
or the agent ID may not exist.

Verify the agent exists: https://lobehub.com/discover/agent/<lobehub_id>

If the agent exists, you can manually create an agent file at:
  agents/community/imported/<lobehub_id>.md

Then add an entry to agents/catalog.json with source="imported" and lobehub_id="<lobehub_id>".
```

Then stop.

---

## Step 4: Convert to Local Markdown Format

Use the `scripts/agent-converter.py` script to convert the fetched JSON to our agent Markdown format.

**If the JSON was fetched successfully**, save it to a temp file and run the converter:

```bash
# Save fetched JSON to a temp file
python3 -c "import json, sys; json.dump(<FETCHED_JSON>, open('/tmp/lobehub_import_<lobehub_id>.json', 'w'), indent=2)"

# Run the converter
python3 scripts/agent-converter.py import /tmp/lobehub_import_<lobehub_id>.json \
  --output-dir agents/community/imported/
```

The converter will write a file to `agents/community/imported/<agent-name>.md`.

**If the converter is unavailable or errors**, build the Markdown file manually using this template:

```markdown
---
name: <slugified-title>
description: <meta.description>
model_tier: <mapped-tier>
source: imported
lobehub_id: <lobehub_id>
lobehub_url: https://lobehub.com/discover/agent/<lobehub_id>
tags: [<comma-separated tags>]
imported_at: <YYYY-MM-DD>
---

# <meta.title>

<meta.description>

## System Prompt

<config.systemRole>
```

Model tier mapping (from `config.model`):
- Contains `gpt-4`, `claude-opus`, `claude-3-opus` → `opus`
- Contains `gpt-3.5`, `claude-haiku`, `claude-3-haiku` → `haiku`
- Anything else or unknown → `sonnet`

Slugify the title for the filename: lowercase, replace spaces and special characters with hyphens, strip leading/trailing hyphens.

---

## Step 5: Ensure Output Directory Exists

Before writing the file, ensure the output directory exists:

```bash
mkdir -p agents/community/imported/
```

Confirm the file was written at: `agents/community/imported/<agent-name>.md`

---

## Step 6: Register in agents/catalog.json

Read `agents/catalog.json`. Add a new entry to the `"agents"` array:

```json
{
  "name": "<slugified-title>",
  "file": "agents/community/imported/<agent-name>.md",
  "source": "imported",
  "lobehub_id": "<lobehub_id>",
  "lobehub_url": "https://lobehub.com/discover/agent/<lobehub_id>",
  "department": "community",
  "description": "<meta.description truncated to 120 chars>",
  "model_tier": "<mapped-tier>",
  "capabilities": [<tags as string array>],
  "tools": ["Read"],
  "imported_at": "<YYYY-MM-DD>"
}
```

Also update the `marketplace` counters at the top of the file:
- Increment `"imported_count"` by 1
- Set `"last_sync"` to today's date (YYYY-MM-DD)

Write the updated JSON back to `agents/catalog.json`. Preserve the existing formatting (2-space indentation).

---

## Step 7: Report Success

Print a success summary:

```
Agent imported successfully.

  Name:       <meta.title>
  ID:         <lobehub_id>
  File:       agents/community/imported/<agent-name>.md
  Tier:       <model_tier>
  Tags:       <tag1>, <tag2>, ...
  Source:     https://lobehub.com/discover/agent/<lobehub_id>

Agent '<meta.title>' imported. Available in the agent system.

To use this agent:
  /agent <agent-name>

To search for more agents:
  /agent-search <query>
```

---

## Rules

- ALWAYS check for an existing import (Step 2) before fetching — avoid duplicate entries
- ALWAYS try the JSON API endpoint first — it is more reliable than scraping the page
- NEVER leave a partial import — if catalog.json update fails, report the error and provide the JSON snippet the user can add manually
- ALWAYS create `agents/community/imported/` if it does not exist before writing the file
- NEVER overwrite an existing file without warning — if `agents/community/imported/<agent-name>.md` already exists but is not in the catalog, print a warning and ask the user to confirm before overwriting
- Truncate description to 120 characters in catalog.json to keep the file scannable
- If the converter script exits with a non-zero code, fall back to the manual Markdown template — do not stop the import
- Set `"tools": ["Read"]` as the default tool list for imported agents (conservative default); the user can expand it later
