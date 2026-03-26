---
name: community-validate
description: Validate a community contribution directory or package manifest — checks schema, artifact existence, naming conventions, frontmatter, and catalog duplicates. Reports PASS/FAIL with specific issues listed.
---
Validate the community contribution at: $ARGUMENTS

You are the Community Contribution Validator. Your job is to run a thorough validation of the given contribution and report a clear PASS or FAIL with every specific issue listed.

---

## Step 1: Parse the Target Path

Extract the target from `$ARGUMENTS`. It can be:
- A path to a directory containing a `package.yaml` or `package.json` manifest
- A path directly to a `package.yaml` or `package.json` file
- A path to a single artifact file (`.md`)

Resolve the path to absolute form. If the path does not exist, immediately report:

```
FAIL — path not found: <path>
```

---

## Step 2: Locate and Load the Package Manifest

If the target is a directory, check for these manifest files in order:

```bash
ls <target>/package.yaml 2>/dev/null
ls <target>/package.json 2>/dev/null
```

If a manifest is found, read it. Parse the fields:
- `name`, `version`, `type`, `author`, `description`, `artifacts`, `requires`, `tags`, `categories`, `model_tier`, `test_command`, `license`

If no manifest is found and the target is a single `.md` file, infer:
- `type` from location (e.g. path contains `agents/` → `agent`, `skills/` → `skill`, `commands/` → `command`)
- `name` from the filename without extension
- Validate only the single file (skip manifest-level checks)

---

## Step 3: Validate Manifest Schema

If a manifest was found, validate these fields:

### Required fields
Check each required field is present and non-empty:
- `name` — required
- `version` — required
- `type` — required
- `author` — required
- `description` — required, minimum 10 characters
- `artifacts` — required, at least 1 item

Record an issue for each missing or empty required field:
```
[FAIL] manifest: missing required field "author"
```

### Field format checks
- `name`: must match `^[a-z][a-z0-9-]*$` (kebab-case, no uppercase, no underscores)
- `version`: must match `^\d+\.\d+\.\d+$` (semver X.Y.Z)
- `type`: must be one of `agent`, `skill`, `command`, `hook`, `team`
- `model_tier` (if present): must be one of `haiku`, `sonnet`, `opus`
- `homepage` (if present): must be a valid URL starting with `http://` or `https://`

Record format violations:
```
[FAIL] manifest: "name" must be kebab-case (^[a-z][a-z0-9-]*$), got "My_Agent"
[FAIL] manifest: "version" must be semver X.Y.Z, got "1.0"
[FAIL] manifest: "type" must be one of agent/skill/command/hook/team, got "plugin"
```

---

## Step 4: Validate Artifact Files Exist

For each entry in `artifacts`, resolve the path relative to the contribution directory and check it exists:

```bash
ls <contribution_dir>/<artifact.path> 2>/dev/null || echo "MISSING"
```

Record missing artifacts:
```
[FAIL] artifact not found: agents/my-agent.md
```

Also check:
- Each artifact `type` is one of: `agent`, `skill`, `command`, `hook`
- Each artifact `path` has the correct extension (`.md` for agent/skill/command/hook)

---

## Step 5: Check Naming Conventions

For every file in the contribution directory (recursively), check:

```bash
find <target> -type f -name "*.md" | sort
```

Rules:
1. All `.md` filenames (except `SKILL.md`, `README.md`, `CHANGELOG.md`) must be kebab-case: `^[a-z][a-z0-9-]*\.md$`
2. Directory names must be kebab-case: `^[a-z][a-z0-9-]*$`
3. `SKILL.md` is the only allowed UPPERCASE filename

Record violations:
```
[FAIL] naming: file "agents/MyAgent.md" must be kebab-case (e.g. "agents/my-agent.md")
[FAIL] naming: directory "skills/MySkill" must be kebab-case (e.g. "skills/my-skill")
```

---

## Step 6: Validate Agent Frontmatter

For each artifact with `type: agent`, read the `.md` file and check:

1. File starts with `---` (YAML frontmatter block)
2. Frontmatter contains `name` field
3. Frontmatter contains `description` field (minimum 10 characters)
4. `name` in frontmatter matches the filename (without `.md`)

To read frontmatter, extract content between the first `---` and second `---`:

```bash
head -20 <file>
```

Record frontmatter issues:
```
[FAIL] agent frontmatter: "agents/my-agent.md" missing frontmatter block (must start with ---)
[FAIL] agent frontmatter: "agents/my-agent.md" missing required field "name"
[FAIL] agent frontmatter: "agents/my-agent.md" missing required field "description"
[WARN] agent frontmatter: "agents/my-agent.md" name in frontmatter ("My Agent") does not match filename ("my-agent")
```

---

## Step 7: Validate Skill Structure

For each artifact with `type: skill`, check:

1. The artifact path resolves to a directory (skills are directories, not single files)
2. The directory contains a `SKILL.md` file
3. `SKILL.md` starts with a frontmatter block (`---`)
4. `SKILL.md` frontmatter contains `name` field
5. `SKILL.md` frontmatter contains `description` field

```bash
ls <skill_dir>/SKILL.md 2>/dev/null || echo "MISSING"
head -20 <skill_dir>/SKILL.md
```

Record skill issues:
```
[FAIL] skill: "skills/my-skill" directory not found — skills must be directories
[FAIL] skill: "skills/my-skill/SKILL.md" not found — every skill directory requires a SKILL.md
[FAIL] skill: "skills/my-skill/SKILL.md" missing frontmatter block
[FAIL] skill: "skills/my-skill/SKILL.md" missing required frontmatter field "name"
[FAIL] skill: "skills/my-skill/SKILL.md" missing required frontmatter field "description"
```

---

## Step 8: Validate Command Structure

For each artifact with `type: command`, check:

1. File ends in `.md`
2. File starts with a frontmatter block (`---`)
3. Frontmatter contains `name` field
4. Frontmatter contains `description` field
5. The body (after frontmatter) is non-empty — commands must have actual instructions

```bash
head -10 <file>
wc -l <file>
```

Record command issues:
```
[FAIL] command: "commands/my-command.md" missing frontmatter block
[FAIL] command: "commands/my-command.md" missing required frontmatter field "name"
[FAIL] command: "commands/my-command.md" missing required frontmatter field "description"
[FAIL] command: "commands/my-command.md" body is empty — command must contain instructions
```

---

## Step 9: Check for Duplicate Names in Existing Catalog

Check whether this contribution's `name` or any artifact `name` conflicts with existing installed items:

```bash
# Check agents
ls ~/.claude/agents/ 2>/dev/null | sed 's/\.md$//'

# Check skills
ls ~/.claude/skills/ 2>/dev/null

# Check commands
ls ~/.claude/commands/ 2>/dev/null | sed 's/\.md$//'
```

Also check the catalog registry if present:
```bash
cat ~/.claude/catalog.yaml 2>/dev/null | grep "^  name:" | awk '{print $2}'
```

If the contribution `name` or any artifact filename matches an existing name, record:
```
[WARN] duplicate: "my-agent" already exists in ~/.claude/agents/ — installing will overwrite it
[WARN] duplicate: package name "my-agent" conflicts with an entry in catalog.yaml
```

Duplicates are warnings, not hard failures — the user may be intentionally updating.

---

## Step 10: Report Results

Collect all issues recorded in Steps 3–9, then print the final report.

### Format

```
## Community Contribution Validation

Target:  <absolute path>
Package: <name> v<version> (<type>) by <author>

Issues:
  [FAIL] manifest: missing required field "author"
  [FAIL] artifact not found: agents/my-agent.md
  [WARN] duplicate: "my-agent" already exists in ~/.claude/agents/

─────────────────────────────────────
Result: FAIL — 2 error(s), 1 warning(s)
```

Or on clean validation:

```
## Community Contribution Validation

Target:  /path/to/my-contribution
Package: my-agent v1.0.0 (agent) by Jane Smith

Issues:
  None

─────────────────────────────────────
Result: PASS — ready to submit as a PR
```

### Rules
- `[FAIL]` issues cause an overall FAIL result — the contribution cannot be accepted until resolved
- `[WARN]` issues are advisory — the contribution can still be accepted but the author should review
- List ALL issues — never stop at the first failure
- If no manifest was found, note it: `Warning: no package.yaml found — validating file only`
- After a PASS, print: `Next step: open a PR to github.com/calebmambwe/claude-super-setup`
- After a FAIL, print: `Fix the listed issues and re-run: /community-validate <path>`

---

## Rules

- NEVER declare PASS if any `[FAIL]` issue was recorded
- ALWAYS list every issue found — partial reporting is not acceptable
- Treat missing artifact files as hard failures — a package with missing files cannot be installed
- Treat naming convention violations as hard failures — they break install scripts
- Treat missing SKILL.md as a hard failure — skills without SKILL.md cannot be loaded
- Treat duplicate warnings as soft — warn but do not fail
- If the target path does not exist, fail immediately without running further checks
