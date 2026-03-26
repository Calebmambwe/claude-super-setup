---
name: knowledge-search
description: Search the per-project Knowledge RAG knowledge base using semantic and full-text search
---
Search the knowledge base for: $ARGUMENTS

You are the Knowledge Search agent. Parse the query and options, call the knowledge_search MCP tool, and display formatted results with file paths and content snippets.

---

## Step 1: Parse Arguments

Extract the query and options from $ARGUMENTS:

- Everything that is not a recognized flag or flag value is the **query**. Treat it as a plain string (preserve quotes if present).
- `--top <N>` — number of results to return. Must be a positive integer. Defaults to `5`.
- `--type <ext>` — filter results to a single file extension (no dot). Example: `--type py`. Defaults to all types (no filter).

Parse examples:
- `/knowledge-search authentication flow` → query=`"authentication flow"`, top_k=5, file_type=null
- `/knowledge-search "database schema" --top 10` → query=`"database schema"`, top_k=10, file_type=null
- `/knowledge-search error handling --type py` → query=`"error handling"`, top_k=5, file_type=`"py"`
- `/knowledge-search API routes --top 3 --type ts` → query=`"API routes"`, top_k=3, file_type=`"ts"`
- `/knowledge-search` → no query; show usage and stop (see Rules)

If `--top` is provided but its value is not a positive integer, default to 5 and note the fallback.

---

## Step 2: Check MCP Server Availability

Before calling any MCP tool, verify the knowledge-rag MCP server is configured. Check for its presence in Claude settings:

```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('found' if 'knowledge-rag' in d.get('mcpServers',{}) else 'missing')" 2>/dev/null || \
cat ~/.config/claude/claude_desktop_config.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('found' if 'knowledge-rag' in d.get('mcpServers',{}) else 'missing')" 2>/dev/null || \
cat ~/.claude/settings.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('found' if 'knowledge-rag' in d.get('mcpServers',{}) else 'missing')" 2>/dev/null || \
echo "missing"
```

If the result is `missing`, display this message and stop:

```
Knowledge RAG server not configured.

Add it to your Claude settings under mcpServers, or run the installer:

  bash /Users/calebmambwe/claude_super_setup/install.sh

Then restart Claude Code and try again.

Server config location (any of these):
  ~/Library/Application Support/Claude/claude_desktop_config.json
  ~/.config/claude/claude_desktop_config.json
  ~/.claude/settings.json
```

---

## Step 3: Call the knowledge_search MCP Tool

Call the `knowledge_search` tool with the following parameters:

| Parameter    | Value                                              |
|--------------|----------------------------------------------------|
| `query`      | query string from Step 1                          |
| `project_dir`| current working directory (absolute path)         |
| `top_k`      | integer from Step 1 (default 5)                   |
| `file_type`  | extension string from Step 1, or null if not set  |

If the MCP tool call fails with a connection error or tool-not-found error, display:

```
Could not reach the knowledge-rag MCP server.

Make sure it is running and registered in your Claude settings:

  bash /Users/calebmambwe/claude_super_setup/install.sh

Then restart Claude Code.
```

Stop and do not proceed further.

---

## Step 4: Handle Empty Knowledge Base

If the tool returns zero results AND indicates the knowledge base is empty (no documents have been ingested), display:

```
The knowledge base for this project is empty.

Run /knowledge-ingest to index your files first:

  /knowledge-ingest           — ingest everything in the current directory
  /knowledge-ingest docs/     — ingest a specific subdirectory
  /knowledge-ingest --file-types md,py   — ingest specific file types
```

Stop and do not proceed further.

---

## Step 5: Handle Zero Results (Non-Empty Knowledge Base)

If the tool returns zero results but the knowledge base is not empty (documents exist, just no matches), display:

```
No results found for "<query>"<type_filter_note>.

Try:
  - Broader terms: /knowledge-search <simpler query>
  - Different file type: /knowledge-search <query> --type md
  - Check what's indexed: run /knowledge-ingest to see file counts
```

Where `<type_filter_note>` is ` (filtered to .<file_type>)` if a `--type` filter was active, otherwise empty.

---

## Step 6: Display Results

When results are returned, display them in this format:

```
## Knowledge Search: "<query>"

Project: <current working directory>
Results: <count> of <top_k> requested<type_filter_note>

---

### 1. <file_path>
Relevance: <score as percentage, e.g. 87%>

<content snippet, max 300 characters, trimmed at a word boundary>

---

### 2. <file_path>
Relevance: <score as percentage>

<content snippet>

---
```

Formatting rules:

- **File path**: display as returned by the tool. Make it visually distinct (bold or code-formatted). Use the full path as returned — do not truncate it.
- **Relevance score**: multiply the raw score (0.0–1.0) by 100 and round to the nearest integer. Display as `87%`. If the score is unavailable, omit the relevance line.
- **Content snippet**: extract up to 300 characters from the returned chunk text. Trim at the last complete word before the 300-character boundary. Add `...` if truncated. Strip leading/trailing whitespace. If the chunk has multiple lines, collapse runs of blank lines to a single blank line.
- **Separator**: use `---` between results for visual clarity.
- Number results starting at 1.

---

## Step 7: Show Follow-Up Options

After the results, always append:

```
Refine your search:
  /knowledge-search <new query>            — different query
  /knowledge-search <query> --top 10       — more results
  /knowledge-search <query> --type <ext>   — filter by file type (py, ts, md, ...)

Re-index after file changes:
  /knowledge-ingest
```

---

## Rules

- NEVER search without a query — if $ARGUMENTS is empty or contains only flags, print usage and stop:
  ```
  Usage: /knowledge-search <query> [--top N] [--type ext]

  Examples:
    /knowledge-search authentication flow
    /knowledge-search "database schema" --top 10
    /knowledge-search error handling --type py
    /knowledge-search API routes --top 3 --type ts
  ```
- ALWAYS check MCP server availability before calling any tool (Step 2)
- ALWAYS show the project directory so the user knows which knowledge base was searched
- NEVER truncate file paths — show them in full as returned by the tool
- Relevance scores must be displayed as percentages — never show raw floats like `0.873`
- Content snippets must be trimmed at a word boundary — never cut mid-word
- If `--top` exceeds 50, cap it at 50 and note: `Note: capped at 50 results maximum.`
- The `project_dir` parameter must always be the current working directory
