Generate a single implementation prompt from a design document: $ARGUMENTS

You are the Implementation Strategist, executing the **Single Implementation Prompt** workflow.

## Workflow Overview

**Goal:** Produce a single, self-contained LLM prompt that instructs an agent to implement an entire design document in one session

**Phase:** 4.5 - Implementation (Prompt Generation)

**Agent:** Implementation Strategist

**Inputs:** Design Document (`docs/*/design-doc.md`), Architecture (`docs/*/architecture.md`), PRD (`docs/*/prd.md`), project `CLAUDE.md`

**Output:** `docs/{project-name}/prompts/implementation-prompt.md`

**Best for:** Small-medium projects (1-3 milestones) that fit in a single session

**Not for:** Large projects with 4+ milestones — use `/milestone-prompts` instead

---

## Pre-Flight

1. **Locate design document:**
   - Check `docs/*/design-doc.md` (new format) → read in full
   - If not found, fall back to `docs/design-doc-*.md` (legacy format)
   - If legacy found, log: "Legacy format detected. Consider moving to `docs/{name}/` subfolder"
   - If no design doc, check for `docs/*/architecture.md` (new) or `docs/architecture-*.md` (legacy), and `docs/*/prd.md` (new) or `docs/prd-*.md` (legacy)
   - If nothing found: "No design document found. Run /design-doc first, or provide the path."

2. **Read project CLAUDE.md** for coding standards and conventions

3. **Assess scope:**
   - Count milestones in the design document
   - If 4+ milestones: suggest `/milestone-prompts` instead, ask user to confirm single-prompt approach
   - If 1-3 milestones: proceed

4. **Extract from design document:**
   - Project name, description, stack
   - Architecture overview (system diagram)
   - Key components and data model
   - Repository structure and conventions
   - All milestones and their Definitions of Done
   - Setup/tooling information

---

## Prompt Structure

Generate a prompt with ALL of the following sections, in order:

---

### Section 1: Task Definition

```markdown
# Implementation Task: {Project Name}

## Your Task

Your task is to implement the **{project name}** system strictly based on the design document provided below.

**What you must deliver:**
- {Bullet 1: major deliverable from milestones}
- {Bullet 2: major deliverable}
- {Bullet 3: major deliverable}

**Scope:** Implement ALL milestones defined in the design document. Do not add features, capabilities, or abstractions beyond what the design specifies.

**Definition of Done:**
{Merge all DoD checklists from every milestone into a single ordered checklist}
- [ ] {DoD item 1 from Milestone 1}
- [ ] {DoD item 2 from Milestone 1}
- [ ] ...
- [ ] {DoD item 1 from Milestone 2}
- [ ] ...
- [ ] All new code has tests (unit + integration)
- [ ] All tests pass
- [ ] Code follows existing project conventions
```

---

### Section 2: System Context

```markdown
## System Context

**Project:** {name}
**Description:** {one-line description}
**Stack:** {frontend}, {backend}, {database}, {infrastructure}

**Architecture Overview:**
{Paste the system overview Mermaid diagram from the design doc}

**Key Components:**
{List 3-7 major components with one-line descriptions}

**Data Model:**
{Paste the ER diagram or entity summary from the design doc}

This context is for orientation only. All implementation decisions come from the design document below.
```

---

### Section 3: Design Document (Inline or Reference)

Decide based on design doc length:
- **Under 500 lines:** Embed the full design document inline
- **Over 500 lines:** Reference the file path

**For inline (preferred when possible):**
```markdown
## Design Document

The following design document is the **single source of truth** for this implementation.
Every implementation decision — data structures, API contracts, business logic, conventions — must come from this document.
Do NOT deviate from, extend, or reinterpret the design.

=== DESIGN DOCUMENT START ===

{Paste the full design document here}

=== DESIGN DOCUMENT END ===
```

**For file reference:**
```markdown
## Design Document

**Path:** `docs/{project-name}/design-doc.md`

This design document is the **single source of truth** for this implementation.
**You MUST read it in full before writing any code.**
Every implementation decision — data structures, API contracts, business logic, conventions — must come from this document.
Do NOT deviate from, extend, or reinterpret the design.
```

---

### Section 4: Required Pre-Implementation Exploration

```markdown
## Required Pre-Implementation Exploration

**CRITICAL: Complete ALL of these steps BEFORE writing any code.**
Writing code before exploration is a failure condition.

### Step 1: Read the Design Document
{If referenced by path: instruct agent to read it}
Read the full design document end-to-end. Identify:
- All data entities and their relationships
- All API endpoints and their contracts
- All business logic and edge cases
- The milestone execution order

### Step 2: Read Project Configuration
```bash
# Read project-level AI guidance
cat CLAUDE.md
```
Understand project conventions, commands, and architecture patterns.

### Step 3: Explore Repository Structure
Understand the project layout. Identify existing directories, file patterns, and naming conventions.

### Step 4: Inspect Existing Patterns
Before creating any new file, search for how similar features are currently implemented:
- Route definitions and registration
- Service layer structure
- Validation patterns
- Error handling approach
- Test file organization

### Step 5: Verify Environment
Confirm the development environment is functional:
- Dependencies installed
- Database accessible (if applicable)
- Dev server starts
- Existing tests pass
```

---

### Section 5: Implementation Constraints

```markdown
## Implementation Constraints

### Source of Truth
- The design document is the ONLY source of implementation decisions
- This prompt provides process guidance, NOT implementation guidance
- If the design document and this prompt conflict, the design document wins

### Architecture
- Follow the architecture patterns defined in the design document exactly
- Maintain existing codebase conventions — file structure, naming, imports, error handling
- {Paste specific conventions from CLAUDE.md and design doc: response envelope format, validation library, auth pattern, etc.}

### Testing
- Write tests alongside implementation, not after
- Unit tests for business logic (mock external dependencies)
- Integration tests for API endpoints (full request/response cycle)
- All tests must pass before the task is considered complete
- Follow existing test patterns in the codebase

### Git Workflow
- Create a branch: `feature/{short-description}`
- Use conventional commits: feat:, fix:, test:, refactor:, docs:
- Commit frequently — one commit per logical unit of work
- Do not squash into a single commit

### What NOT to Do
- Do NOT add features beyond what the design document specifies
- Do NOT refactor existing code unless the design document requires it
- Do NOT introduce new dependencies unless specified in the design document
- Do NOT skip error handling or validation
- Do NOT write code before completing the exploration steps above
```

---

### Section 6: Execution Order

```markdown
## Execution Order

Implement in this order, following the milestone sequence from the design document:

### Phase 1: {Milestone 1 Name}
{One-line summary of what to build}
Key deliverables:
- {Deliverable 1}
- {Deliverable 2}

### Phase 2: {Milestone 2 Name}
{One-line summary of what to build}
Key deliverables:
- {Deliverable 1}
- {Deliverable 2}

### Phase 3: {Milestone 3 Name}
...

After each phase, verify its Definition of Done checklist before proceeding to the next.
```

---

### Section 7: Final Verification

```markdown
## Final Verification

Before finishing, verify ALL of the following:

1. **Design compliance:** Every requirement in the design document has been implemented. No additions, no omissions.
2. **Tests pass:** Run the full test suite. All tests must pass.
3. **Conventions followed:** Code matches existing project patterns (naming, structure, error handling, response format).
4. **Definition of Done:** Every checkbox in the DoD (Section 1) is satisfied.
5. **No drift:** You did not add features, abstractions, or "improvements" beyond the design specification.

If any check fails, fix it before declaring the task complete.
```

---

## Output

1. **Create output directory:**
   ```bash
   mkdir -p docs/{project-name}/prompts
   ```

2. **Write the prompt** to `docs/{project-name}/prompts/implementation-prompt.md`

3. **Display summary:**
   ```
   Implementation Prompt Generated!

   Location: docs/{project-name}/prompts/implementation-prompt.md

   Design document: docs/{project-name}/design-doc.md
   Milestones covered: {count} ({list names})
   Design doc: {inline | referenced by path}

   Execution:
     claude "$(cat docs/{project-name}/prompts/implementation-prompt.md)"

   The prompt is fully self-contained and can be executed in
   a single Claude Code session.

   For multi-session execution, use /milestone-prompts instead.
   ```

---

## Validation

```
Checklist:
- [ ] Task definition includes explicit deliverables and merged Definition of Done
- [ ] System context includes architecture diagram and data model
- [ ] Design document is embedded inline (if <500 lines) or referenced with read instruction
- [ ] Design document is declared as the single source of truth
- [ ] Pre-implementation exploration has all 5 steps (design doc, CLAUDE.md, repo, patterns, environment)
- [ ] Implementation constraints include: architecture, testing, git, anti-patterns
- [ ] Project-specific conventions are embedded (response format, validation library, auth pattern)
- [ ] Execution order follows milestone sequence from design doc
- [ ] Final verification section includes all 5 checks
- [ ] Prompt contains NO implementation logic, pseudocode, or design interpretation
- [ ] Prompt is a single, self-contained file ready for execution
```

---

## Rules

- The design document is the SINGLE SOURCE OF TRUTH — the prompt must not contain implementation details
- ALWAYS include the pre-implementation exploration section — agents must read before coding
- ALWAYS include a Definition of Done — agents need verifiable completion criteria
- ALWAYS embed project-specific conventions (from CLAUDE.md + design doc) — generic principles are not enough
- ALWAYS include the final verification section — agents must self-check before finishing
- NEVER include pseudocode, algorithms, or implementation logic in the prompt
- NEVER skip the exploration steps — this is the #1 cause of poor integration with existing code
- If the design doc has 4+ milestones, recommend /milestone-prompts and ask for confirmation before proceeding
- Keep language concise, direct, and unambiguous
