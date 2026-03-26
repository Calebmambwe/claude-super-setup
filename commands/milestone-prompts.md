---
name: milestone-prompts
description: Decompose a design document into multiple self-contained LLM prompts, one per milestone
---
Break a design document into milestone implementation prompts: $ARGUMENTS

You are the Implementation Strategist, executing the **Milestone Prompts** workflow.

## Workflow Overview

**Goal:** Decompose a design document into multiple self-contained LLM prompts — one per milestone — that can be executed in independent Claude Code sessions with no shared context

**Phase:** 4.5 - Implementation (Prompt Generation)

**Agent:** Implementation Strategist

**Inputs:** Design Document (`docs/*/design-doc.md`), Architecture (`docs/*/architecture.md`), PRD (`docs/*/prd.md`)

**Output:** `docs/{project-name}/prompts/milestone-{N}-{name}.md` (one file per milestone)

**Duration:** 20-40 minutes

**Best for:** Any project with 3+ milestones that will be implemented across multiple sessions

---

## Why This Exists

Each milestone prompt will be executed in an **independent LLM agent thread with no shared conversational context**. This means:

- The agent running Milestone 3 has **zero knowledge** of what happened in Milestones 1-2
- Each prompt must be **fully self-contained** — all context must be embedded
- Scope must be **surgically precise** — the agent must not drift into other milestones
- The design document is the **single source of truth** — the agent must read it before coding

This enables **parallel execution**, **consistent quality**, and **strict scope control**.

---

## Pre-Flight

1. **Locate design document:**
   - Check `docs/*/design-doc.md` (new format) → read in full
   - If not found, fall back to `docs/design-doc-*.md` (legacy format)
   - If legacy found, log: "Legacy format detected. Consider moving to `docs/{name}/` subfolder"
   - If no design doc, check for `docs/*/architecture.md` (new) or `docs/architecture-*.md` (legacy), and `docs/*/prd.md` (new) or `docs/prd-*.md` (legacy)
   - If nothing found: "No design document found. Run /design-doc first, or provide the path."

2. **Extract milestones from design document:**
   - Find Section 6 (Development Milestones) or equivalent
   - List all milestones with their Definition of Done checklists
   - Note milestone dependencies

3. **Extract supporting context:**
   - Project name, description, stack
   - Architecture overview (diagrams, components)
   - Data structures (entities, types)
   - Conventions & patterns
   - Tooling & setup

4. **Read project CLAUDE.md** for coding standards

---

## Prompt Generation Process

Use TodoWrite to track: Pre-flight → Extract Context → Generate Prompts → Validate → Output

Approach: **Precise, self-contained, scope-enforced.**

---

### Step 1: Build the Shared Context Block

Every milestone prompt needs a common context section. Build it once, embed it in each prompt.

**Extract and format:**

```markdown
## Project Background & Architectural Context

**Project:** {name}
**Description:** {one-line description}
**Stack:** {frontend}, {backend}, {database}, {infrastructure}

**Architecture:**
{Paste the system overview Mermaid diagram from the design doc}

**Key Components:**
{List 3-7 major components with one-line descriptions}

**Data Model:**
{Paste the ER diagram or entity summary from the design doc}

**Repository Structure:**
```
{Paste the folder structure from conventions section}
```

**Coding Conventions:**
- Files: {naming convention}
- Functions: {naming convention}
- Error handling: {pattern}
- Validation: {pattern}
- Auth: {pattern}
- Response format: {envelope format}

**Design Document Location:** `docs/{project-name}/design-doc.md`
```

**Store as:** `{{shared_context}}`

---

### Step 2: Generate One Prompt Per Milestone

For EACH milestone in the design document, generate a complete, self-contained prompt file.

**Each prompt MUST follow this exact structure:**

---

#### Section 1: Task Summary (Immediate Clarity)

```markdown
# Milestone {N}: {Milestone Name}

## Task Summary

Your task is to implement **{milestone name}** for the {project name} project.

**What you must do:**
- {Bullet 1: specific deliverable}
- {Bullet 2: specific deliverable}
- {Bullet 3: specific deliverable}

**What is IN SCOPE:**
- {Specific feature/component 1}
- {Specific feature/component 2}
- {Specific file/module to create or modify}

**What is OUT OF SCOPE (do NOT implement):**
- {Future milestone feature 1}
- {Future milestone feature 2}
- {Anything from other milestones}

**Definition of Done:**
{Paste the exact DoD checklist from the design document for this milestone}
```

---

#### Section 2: Project Background

```markdown
## Project Background & Architectural Context

{Paste {{shared_context}} here — identical in every prompt}
```

---

#### Section 3: Current Task Context

```markdown
## Current Task Context

This is **Milestone {N} of {total}** in the implementation plan.

**What has been completed before this milestone (assume done, do not re-implement):**
- Milestone 1: {name} — {one-line summary of what it delivered}
- Milestone 2: {name} — {one-line summary of what it delivered}
- ...up to N-1

**What this milestone enables (but is OUT OF SCOPE):**
- Milestone {N+1}: {name} — {one-line summary}
- ...

**How this milestone connects:**
{2-3 sentences explaining why this milestone exists and what value it delivers independently}

**Dependencies from previous milestones that you can assume exist:**
- {Database table X exists with columns Y, Z}
- {Auth middleware is in place at path/to/file}
- {API endpoint POST /api/v1/foo already works}
```

---

#### Section 4: Design Documentation Reference

```markdown
## Design Documentation

The following design document describes the complete feature across all milestones.
**You MUST read it carefully before writing any code.**
Identify and implement ONLY the portions relevant to Milestone {N}.
Other milestones in the document must be acknowledged but NOT implemented.

**Design document path:** `docs/{project-name}/design-doc.md`

**Relevant sections for this milestone:**
- Section 3.X: {Entity name} (data structures)
- Section 4.X: {Endpoint group} (API implementation)
- Section 5: Conventions (follow all)
- Section 7: Tooling (setup reference)

Read the full document. Focus implementation on the sections listed above.
```

---

#### Section 5: Required Pre-Implementation Exploration

```markdown
## Required Pre-Implementation Exploration

**CRITICAL: You must complete ALL of these steps BEFORE writing any code.**
Writing code before exploration is a failure condition.

### Step 1: Read the Design Document
```bash
# Read the full design document
cat docs/{project-name}/design-doc.md
```
Understand the full system design. Identify the sections relevant to this milestone.

### Step 2: Explore Repository Structure
```bash
# Understand the project layout
find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.py" | head -50
```

### Step 3: Inspect Existing Code
Look at these specific files/directories that are relevant to this milestone:
- `{path/to/relevant/file1}` — understand existing patterns
- `{path/to/relevant/dir}` — identify conventions in use
- `{path/to/config}` — check configuration

### Step 4: Search for Existing Patterns
```bash
# Find how similar features are currently implemented
grep -r "{pattern}" src/
```

Look for:
- How routes are defined and registered
- How services are structured
- How validation is applied
- How errors are handled
- How tests are organized

### Step 5: Verify Prerequisites
Confirm that dependencies from previous milestones exist:
- [ ] {Database table X exists} — check migrations or schema
- [ ] {Auth middleware exists} — check middleware directory
- [ ] {Relevant config exists} — check config files

If any prerequisite is missing, note it but proceed with implementation.
Do NOT implement the missing prerequisite — that belongs to a different milestone.
```

---

#### Section 6: Implementation Instructions

```markdown
## Implementation Instructions & Conventions

### Coding Standards
{Paste relevant conventions from the design doc and CLAUDE.md}

### Architecture Constraints
- Follow the {pattern} architecture: Route → Service → Repository → Database
- All API responses use the standard envelope: `{ success, data, error, meta }`
- Validation at system boundaries using {Zod/Pydantic}
- Error handling: {describe the pattern}

### What to Build (Ordered)
1. **{First thing to implement}**
   - File: `{path/to/file}`
   - Purpose: {what it does}
   - Key details: {from design doc}

2. **{Second thing to implement}**
   - File: `{path/to/file}`
   - Purpose: {what it does}
   - Key details: {from design doc}

3. **{Third thing to implement}**
   ...

### Testing Requirements
- Write tests alongside implementation, not after
- Unit tests for business logic (mock dependencies)
- Integration tests for API endpoints
- Target: 80%+ coverage for new code
- Test file location: `{test directory pattern}`

### Git Workflow
- Branch: `feature/milestone-{N}-{short-name}`
- Commit messages: conventional commits (feat:, fix:, test:)
- Commit frequently — one commit per logical unit of work
```

---

#### Section 7: Final Reminders (MUST be in every prompt)

```markdown
## Final Reminders

**These rules are non-negotiable:**

1. **Read the design document before coding.** The design doc is the authoritative source of truth. Do not skip, partially read, or selectively interpret it.

2. **Explore the existing codebase before coding.** List directories, inspect files, search for patterns. New code must integrate cleanly with existing code.

3. **Implement ONLY the task described in this prompt.** This is Milestone {N} of {total}. Do not implement future milestones. Do not refactor unrelated code. Do not "get ahead" of later prompts. Do not backfill work from previous milestones.

4. **Assume other milestones are handled in separate prompts.** Each milestone runs in an independent session with no shared context.

5. **Do not introduce speculative or forward-looking changes.** Build exactly what this milestone requires — no more, no less.

6. **Verify the Definition of Done before finishing.** Every checkbox in the DoD must be satisfied.

Failure to follow any of the above rules results in an incorrect implementation.
```

---

### Step 3: Generate the Milestone Map

Create an index file that shows the full milestone plan:

```markdown
# Milestone Implementation Plan

**Project:** {name}
**Generated:** {date}
**Total Milestones:** {count}
**Design Document:** `docs/{project-name}/design-doc.md`

## Execution Order

```
Milestone 1: {name}
    └── Milestone 2: {name} (depends on 1)
        └── Milestone 3: {name} (depends on 2)
    └── Milestone 4: {name} (depends on 1, can parallel with 2-3)
        └── Milestone 5: {name} (depends on 3, 4)
```

## Milestone Summary

| # | Name | Depends On | Key Deliverables | Prompt File |
|---|------|-----------|------------------|-------------|
| 1 | {name} | None | {deliverables} | `prompts/milestone-1-{name}.md` |
| 2 | {name} | M1 | {deliverables} | `prompts/milestone-2-{name}.md` |
| 3 | {name} | M2 | {deliverables} | `prompts/milestone-3-{name}.md` |

## Parallel Execution Opportunities

These milestones can run in parallel:
- {Milestone X} and {Milestone Y} (independent after Milestone Z)

## How to Execute

### Sequential (recommended for solo developer):
```bash
# Start a new Claude Code session for each milestone
claude "$(cat docs/{project-name}/prompts/milestone-1-foundation.md)"
# Wait for completion, verify DoD
claude "$(cat docs/{project-name}/prompts/milestone-2-data-layer.md)"
# Continue...
```

### Parallel (for teams or multiple sessions):
```bash
# Session 1:
claude "$(cat docs/{project-name}/prompts/milestone-1-foundation.md)"

# Session 2 (after M1 completes):
claude "$(cat docs/{project-name}/prompts/milestone-2-data-layer.md)"

# Session 3 (after M1 completes, parallel with M2):
claude "$(cat docs/{project-name}/prompts/milestone-4-frontend-shell.md)"
```
```

**Save as:** `docs/{project-name}/prompts/README.md`

---

## Output

1. **Create output directory:**
   ```bash
   mkdir -p docs/{project-name}/prompts
   ```

2. **Write each milestone prompt** to `docs/{project-name}/prompts/milestone-{N}-{kebab-name}.md`

3. **Write the milestone map** to `docs/{project-name}/prompts/README.md`

4. **Display summary:**
   ```
   Milestone Prompts Generated!

   Location: docs/{project-name}/prompts/

   Files created:
     docs/{project-name}/prompts/README.md                    — Milestone map & execution guide
     docs/{project-name}/prompts/milestone-1-foundation.md    — {summary}
     docs/{project-name}/prompts/milestone-2-data-layer.md    — {summary}
     docs/{project-name}/prompts/milestone-3-auth.md          — {summary}
     docs/{project-name}/prompts/milestone-4-core-features.md — {summary}
     docs/{project-name}/prompts/milestone-5-polish.md        — {summary}

   Execution:
     Sequential: Run prompts in order (M1 → M2 → M3 → M4 → M5)
     Parallel:   M2 and M4 can run simultaneously after M1

   Each prompt is fully self-contained and can be executed in
   an independent Claude Code session with no shared context.

   Next: Start with milestone-1-foundation.md
   ```

---

## Validation

```
Checklist:
- [ ] Every milestone from the design doc has a corresponding prompt file
- [ ] Every prompt contains ALL 7 sections (Task Summary through Final Reminders)
- [ ] Every prompt includes the full shared context block (architecture, stack, conventions)
- [ ] Every prompt has explicit IN SCOPE and OUT OF SCOPE lists
- [ ] Every prompt references the design document path and relevant sections
- [ ] Every prompt includes the pre-implementation exploration steps
- [ ] Every prompt lists what previous milestones delivered (assumed done)
- [ ] Every prompt includes the Definition of Done from the design doc
- [ ] Every prompt ends with the Final Reminders section (verbatim)
- [ ] The milestone map shows dependency chain and parallel opportunities
- [ ] No prompt references another prompt's content (each is self-contained)
- [ ] Scope boundaries are airtight — no overlap between prompts
```

---

## Rules

- EVERY prompt must be fully self-contained — assume zero shared context between sessions
- EVERY prompt must include the complete shared context block (architecture, stack, conventions)
- EVERY prompt must explicitly state what is IN SCOPE and OUT OF SCOPE
- EVERY prompt must instruct the agent to read the design document BEFORE coding
- EVERY prompt must instruct the agent to explore the codebase BEFORE coding
- EVERY prompt must end with the Final Reminders section — word for word, no shortcuts
- NEVER let scope bleed between prompts — if Milestone 3 touches auth, and auth was built in Milestone 2, Milestone 3 must say "assume auth middleware exists" not "build auth"
- NEVER include time estimates — milestones are defined by deliverables, not duration
- NEVER assume the executing agent knows anything about other milestones
- ALWAYS include the dependency chain so milestones can be parallelized where safe
- ALWAYS include the Definition of Done checklist from the design document
- The design document is the SINGLE SOURCE OF TRUTH — prompts must not contradict it
