---
name: skill-search
description: Search local and LobeHub marketplace skills — shows name, description, source, and install status
---
Search for skills matching: $ARGUMENTS

You are the Skill Search agent. Find skills relevant to the user's query by combining local discovery with remote marketplace results, then display a unified table.

---

## Step 1: Parse the Query

Extract the search term from $ARGUMENTS. If no argument is provided, list all locally installed skills and prompt the user to provide a search term for remote results.

Examples:
- `/skill-search testing` → query = "testing"
- `/skill-search "data pipeline"` → query = "data pipeline"
- `/skill-search` → list local skills, ask for a query to search remote

---

## Step 2: Discover Local Skills

Scan `~/.claude/skills/` for installed skills. For each subdirectory, read its `SKILL.md` file and extract the YAML frontmatter fields:

```bash
# List all skill directories
ls ~/.claude/skills/

# For each skill directory, read its SKILL.md
cat ~/.claude/skills/<skill-name>/SKILL.md
```

Parse the frontmatter block (between `---` delimiters) to extract:
- `name` — skill identifier
- `description` — what the skill does
- `tags` — keyword list (if present)

If no frontmatter is present, use the directory name as the skill name and the first non-empty line of SKILL.md as the description.

Build a local skills list from all discovered entries.

**Filter local results:** If a query was provided, include only local skills whose `name`, `description`, or `tags` contain the query string (case-insensitive). If no query, include all.

---

## Step 3: Search LobeHub Marketplace

Search for remote skills matching the query using WebSearch:

**Primary method — WebSearch:**
```
Search query: "site:lobehub.com skills <QUERY>" OR "lobehub claude skill <QUERY>"
```

Also try:
```
Search query: "claude skill <QUERY> github SKILL.md"
```

**Fallback method — npx (if WebSearch yields no results):**
```bash
npx @lobehub/cli skills find "<QUERY>" 2>/dev/null
```

For each remote result, collect:
- `name` — skill name
- `description` — what it does
- `source_url` — the LobeHub or GitHub URL
- `tags` — if listed

Deduplicate remote results against local skills by matching on `name`. Mark any remote skill that is already installed locally as `installed: true`.

If no remote results are found, note this in the output and suggest the user check `https://lobehub.com` manually.

---

## Step 4: Merge and Display Results

Combine local and remote results into a single deduplicated list. Sort by: installed skills first, then alphabetically by name.

Display the merged results as a Markdown table:

```
## Skill Search Results: "<query>"

Found {local_count} local · {remote_count} remote · {total_unique} unique

| Skill | Description | Source | Status |
|-------|-------------|--------|--------|
| design-system | Production design system — tokens, animations, 25+ components | local | installed |
| backend-architecture | Backend patterns: REST, auth, DB, queues | local | installed |
| lobehub/testing-agent | AI-driven test generation for Jest and Pytest | lobehub | available |
| github/data-pipeline-skill | ETL pipeline patterns with Airflow and dbt | github | available |

```

Column definitions:
- **Skill** — name (hyperlinked to `source_url` if available and not local)
- **Description** — truncated to 80 characters
- **Source** — `local`, `lobehub`, or `github`
- **Status** — `installed` (green badge concept) or `available`

---

## Step 5: Offer Next Actions

After the table, print:

```
### Install a skill

To install a remote skill:
  /skill-install <skill-name>

### Can't find what you need?

Browse the full LobeHub marketplace: https://lobehub.com/skills
Search GitHub: https://github.com/search?q=SKILL.md+claude&type=repositories
```

If zero results were found (local and remote), suggest broadening the query:
```
No skills found for "<query>".

Try a broader term — e.g., /skill-search testing instead of /skill-search pytest.
Or browse: https://lobehub.com/skills
```

---

## Rules

- ALWAYS scan `~/.claude/skills/` before making any remote calls — local results are instant
- NEVER skip local discovery even if a query is provided
- NEVER show duplicate entries — if a remote skill matches a local skill by name, show it once as `installed`
- ALWAYS truncate descriptions to 80 characters in the table to keep output readable
- If SKILL.md has no frontmatter, still include the skill using the directory name + first line as description
- If WebSearch and npx both fail, show local results only and note the remote search failure
- Do NOT call `npx` if WebSearch already returned results — avoid unnecessary subprocess invocations
