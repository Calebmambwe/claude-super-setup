---
name: skill-import
description: Import a skill from a GitHub URL, LobeHub identifier, or npx-compatible identifier and install it to ~/.claude/skills/imported/
---
Import skill from: $ARGUMENTS

You are the Skill Import agent. Download a skill from a remote source, install it locally, and register it in the skill registry.

---

## Step 1: Parse the Input

Extract the source identifier from $ARGUMENTS. Determine the source type:

| Pattern | Source type |
|---------|-------------|
| `https://github.com/user/repo` | GitHub repo root |
| `https://github.com/user/repo/tree/<ref>/path` | GitHub subdirectory |
| `https://lobehub.com/...` | LobeHub URL |
| `lobehub/<name>` or `@lobehub/<name>` | LobeHub identifier |
| Any other string without `/` or with `npx:` prefix | npx identifier |

If $ARGUMENTS is empty, print usage and stop:

```
Usage: /skill-import <source>

Sources accepted:
  https://github.com/user/repo
  https://github.com/user/repo/tree/main/path/to/skill
  https://lobehub.com/skills/<name>
  lobehub/<skill-name>
  <npx-compatible-identifier>

Example:
  /skill-import https://github.com/example/my-skill
  /skill-import lobehub/testing-agent
```

---

## Step 2: Derive the Skill Name and Install Path

Derive a `skill-name` slug from the input:

- GitHub URL: use the last path segment of the repo or subdirectory path, lowercased, with spaces replaced by `-`
- LobeHub identifier: use the part after `lobehub/` or `@lobehub/`
- npx identifier: strip any scope prefix (`@scope/`) and use the remaining package name

Set:
- `SKILL_NAME` = derived slug
- `INSTALL_DIR` = `~/.claude/skills/imported/<SKILL_NAME>`

---

## Step 3: Check for Existing Installation

```bash
ls ~/.claude/skills/imported/<SKILL_NAME>/ 2>/dev/null
```

If the directory exists and contains a `SKILL.md`, the skill is already installed. Warn the user:

```
Warning: Skill '<SKILL_NAME>' is already installed at ~/.claude/skills/imported/<SKILL_NAME>/

Options:
  1. Overwrite — reinstall from source (may get newer version)
  2. Skip — keep the existing installation

Enter 1 or 2:
```

Wait for the user's response:
- If `1` (overwrite): remove the existing directory with `rm -rf ~/.claude/skills/imported/<SKILL_NAME>/` and continue
- If `2` (skip): print `Skipped. Existing skill kept.` and stop

---

## Step 4: Download the Skill

Create the parent directory if it does not exist:

```bash
mkdir -p ~/.claude/skills/imported/
```

### 4a. GitHub source

**Full repo:**
```bash
git clone --depth=1 "<GITHUB_URL>" /tmp/skill-import-<SKILL_NAME>
```

Then copy the skill content:
```bash
cp -r /tmp/skill-import-<SKILL_NAME>/ ~/.claude/skills/imported/<SKILL_NAME>/
rm -rf /tmp/skill-import-<SKILL_NAME>/
```

**Subdirectory of a repo** (URL contains `/tree/<ref>/path`):

Reconstruct the raw base URL and use sparse checkout:
```bash
git clone --depth=1 --filter=blob:none --sparse "<REPO_ROOT_URL>" /tmp/skill-import-<SKILL_NAME>
cd /tmp/skill-import-<SKILL_NAME> && git sparse-checkout set "<SUBDIR_PATH>"
cp -r /tmp/skill-import-<SKILL_NAME>/<SUBDIR_PATH> ~/.claude/skills/imported/<SKILL_NAME>/
rm -rf /tmp/skill-import-<SKILL_NAME>/
```

If `git clone` fails (network error, repo not found, permission denied), print:

```
Error: Could not clone repository '<GITHUB_URL>'.
  — Check that the URL is correct and the repo is public.
  — Git error: <stderr output>
```

Then stop.

### 4b. LobeHub URL source

Use WebFetch to retrieve the skill page and locate the raw SKILL.md URL, then download it:

```bash
mkdir -p ~/.claude/skills/imported/<SKILL_NAME>/
curl -fsSL "<RAW_SKILL_MD_URL>" -o ~/.claude/skills/imported/<SKILL_NAME>/SKILL.md
```

If WebFetch or curl fails, fall back to npx:
```bash
npx @lobehub/cli skills add "<SKILL_NAME>" --out ~/.claude/skills/imported/<SKILL_NAME>/ 2>&1
```

If both fail, print:

```
Error: Could not download skill '<SKILL_NAME>' from LobeHub.
  — WebFetch failed: <reason>
  — npx fallback also failed: <stderr>
  — Check https://lobehub.com/skills/<SKILL_NAME> manually.
```

Then stop.

### 4c. LobeHub identifier source (`lobehub/<name>` or `@lobehub/<name>`)

Try npx first:
```bash
npx @lobehub/cli skills add "<SKILL_NAME>" --out ~/.claude/skills/imported/<SKILL_NAME>/ 2>&1
```

If npx is unavailable or fails, use WebFetch to find the GitHub source URL for this skill from `https://lobehub.com/skills/<SKILL_NAME>`, then follow the GitHub download flow from Step 4a.

If both fail, print:

```
Error: Could not install LobeHub skill '<SKILL_NAME>'.
  — npx failed: <stderr>
  — Could not locate a GitHub source URL on LobeHub.
  — Try: /skill-search <SKILL_NAME>  to verify the identifier.
```

Then stop.

### 4d. npx identifier source

```bash
npx @lobehub/cli skills add "<IDENTIFIER>" --out ~/.claude/skills/imported/<SKILL_NAME>/ 2>&1
```

If npx fails, print:

```
Error: Could not install skill via npx using identifier '<IDENTIFIER>'.
  — npx error: <stderr>
  — If this is a GitHub URL, use the full https:// form.
  — If this is a LobeHub skill, try: lobehub/<name>
```

Then stop.

---

## Step 5: Verify SKILL.md Exists

```bash
ls ~/.claude/skills/imported/<SKILL_NAME>/SKILL.md 2>/dev/null
```

If `SKILL.md` is not present in the installed directory, print:

```
Error: SKILL.md not found in the installed skill at ~/.claude/skills/imported/<SKILL_NAME>/.

The source does not appear to be a valid Claude skill. A skill must contain a SKILL.md file.
Files found: <list directory contents>

The partial installation has been removed.
```

Run cleanup:
```bash
rm -rf ~/.claude/skills/imported/<SKILL_NAME>/
```

Then stop.

---

## Step 6: Parse Frontmatter

Read the SKILL.md file. Extract the YAML frontmatter block between the first pair of `---` delimiters.

Parse the following fields:
- `name` (string) — required
- `description` (string) — required
- `version` (string) — optional
- `tags` (array of strings) — optional

**If `name` or `description` are missing**, warn the user but continue:

```
Warning: SKILL.md frontmatter is incomplete — 'name' and/or 'description' fields are missing.
  Falling back to: name='<SKILL_NAME>' (from directory), description='(none)'.
  The skill will still be installed. Edit ~/.claude/skills/imported/<SKILL_NAME>/SKILL.md to add them.
```

Use `<SKILL_NAME>` as the fallback name and an empty string as the fallback description.

---

## Step 7: Update the Skill Registry

The registry file lives at `~/.claude/skill-registry.json`.

Read the existing registry:
```bash
cat ~/.claude/skill-registry.json 2>/dev/null
```

If the file does not exist or is empty, initialize a new registry object:
```json
{
  "$schema": "https://claude-super-setup/schemas/skill-registry.schema.json",
  "version": "1.0.0",
  "installed": []
}
```

Build the new registry entry using the fields parsed in Step 6:

```json
{
  "name": "<name from frontmatter or SKILL_NAME fallback>",
  "path": "~/.claude/skills/imported/<SKILL_NAME>",
  "description": "<description from frontmatter or empty string>",
  "source": "<github | lobehub>",
  "source_url": "<original $ARGUMENTS URL or canonical URL if resolved>",
  "version": "<version from frontmatter if present>",
  "tags": ["<tags from frontmatter if present>"],
  "installed_at": "<current ISO 8601 timestamp>"
}
```

- `source`: set to `"github"` for GitHub URLs, `"lobehub"` for LobeHub identifiers and URLs
- Omit `source_url` only if the source was a bare npx identifier with no resolvable URL
- Omit `version` and `tags` if not present in frontmatter (do not include null values)

**If an entry with the same `name` already exists** in `installed`, replace it (this handles the overwrite path from Step 3).

Write the updated registry back to `~/.claude/skill-registry.json` using the Write tool. Preserve all existing entries and top-level fields (`version`, `available_remote`, `last_sync`) that were already present.

---

## Step 8: Report Success

Print the success summary:

```
Skill '<name>' installed successfully.

  Location : ~/.claude/skills/imported/<SKILL_NAME>/
  Source   : <source_url or identifier>
  Version  : <version if present, otherwise 'not specified'>
  Tags     : <comma-separated tags, or 'none'>

Available in Claude Code. To use it, reference the skill by name in your session or add it to a command with:
  @~/.claude/skills/imported/<SKILL_NAME>/SKILL.md

Registry updated: ~/.claude/skill-registry.json
```

---

## Rules

- NEVER silently swallow errors — every failure path must print a clear error with the reason and recovery hint
- NEVER leave a partial installation on disk after a fatal error — always run `rm -rf` cleanup before stopping
- ALWAYS check for an existing installation before downloading — do not clobber without user consent
- ALWAYS parse frontmatter before writing the registry — the registry must reflect actual file contents
- WARN on missing frontmatter fields but still complete the install — an incomplete SKILL.md is not fatal
- ALWAYS use `--depth=1` for git clone to avoid pulling full history
- NEVER prompt the user for more than one decision (the overwrite prompt in Step 3) — all other branching is automatic
- If npx is not available on the system, skip npx steps and fall back to WebFetch/curl equivalents without surfacing npx errors to the user
