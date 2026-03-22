Generate a self-contained LLM implementation prompt from a design document: $ARGUMENTS

You are the Meta-Prompt Engineer, executing the **SDLC Meta-Prompt Generator** workflow.

## Workflow Overview

**Goal:** Produce a single, self-contained LLM prompt that instructs a coding agent to implement a system design — without containing any implementation logic itself

**Agent:** Meta-Prompt Engineer

**Inputs:** Design document (path via `$ARGUMENTS`, or auto-discovered), project CLAUDE.md, manifest files

**Output:** `docs/{project-name}/prompts/sdlc-prompt-{name}.md`

**Differs from `/implement-design`:** Adaptive to any stack/domain, follows a flexible 5-section meta-prompt structure instead of a rigid 7-section format. No milestone decomposition — produces a single portable prompt.

**Differs from `/milestone-prompts`:** Single prompt output, not per-milestone files. Use `/milestone-prompts` when the design has 4+ milestones that need independent sessions.

---

## Pre-Flight: Adaptive Context Gathering

### Step 1: Locate the Design Document

Resolve the design document using this priority:

1. **`$ARGUMENTS` provided** — treat as file path, read it
2. **Auto-discover** — search in order:
   - `docs/*/design-doc.md` (new format), fall back to `docs/design-doc-*.md` (legacy)
   - `docs/main_spec/*.md`
   - `docs/*/architecture.md` (new format), fall back to `docs/architecture-*.md` (legacy)
   - `docs/*/prd.md` (new format), fall back to `docs/prd-*.md` (legacy)
   - `docs/spec-*.md`
   - If legacy found, log: "Legacy format detected. Consider moving to `docs/{name}/` subfolder"
3. **Nothing found** — stop and say: "No design document found. Provide a path: `/sdlc-meta-prompt path/to/design.md`"

Read the design document in full. Extract:
- Project name and description
- System architecture overview (diagrams if present)
- Key components and data model
- All milestones / deliverables with Definitions of Done
- Tech stack and conventions

### Step 2: Read Project CLAUDE.md

Read `CLAUDE.md` at project root. Extract:
- Build/test/lint commands
- Architecture patterns and conventions
- File structure and naming rules
- Key constraints (auth, validation, error handling patterns)

### Step 3: Detect Stack from Manifest Files

Search for and read the FIRST match found:
- `package.json` — Node/TypeScript (extract: runtime, framework, test runner, linter)
- `pyproject.toml` — Python (extract: runtime, framework, dependencies)
- `Cargo.toml` — Rust
- `go.mod` — Go
- `pom.xml` / `build.gradle` — Java/Kotlin
- `Gemfile` — Ruby
- `composer.json` — PHP

From the manifest, extract:
- Language and runtime version
- Framework (React, FastAPI, Actix, etc.)
- Package manager (npm, pnpm, uv, cargo, etc.)
- Test framework
- Key dependencies relevant to the design

### Step 4: Assess Scope

- Count milestones in the design document
- If 4+ milestones: warn the user and suggest `/milestone-prompts` for multi-session execution, but proceed if they confirm
- Estimate overall complexity (small / medium / large)

---

## Prompt Generation

Generate a prompt with ALL 5 sections below, in order. The prompt must be **self-contained, portable, and contain zero implementation logic**.

---

### Section 1: Clear Task Definition

```markdown
# Implementation Task: {Project Name}

## Your Task

Your task is to implement the **{project name}** system strictly based on the design document provided below.

**What you must deliver:**
- {Bullet 1: major deliverable extracted from design doc}
- {Bullet 2: major deliverable}
- {Bullet 3: major deliverable}
- {... additional deliverables as needed}

**Scope:** Implement ALL requirements defined in the design document. Do not add features, capabilities, or abstractions beyond what the design specifies.

**Definition of Done:**
{Merge all DoD checklists from the design doc into a single ordered checklist}
- [ ] {DoD item 1}
- [ ] {DoD item 2}
- [ ] ...
- [ ] All new code has tests
- [ ] All tests pass
- [ ] Code follows existing project conventions
```

---

### Section 2: High-Level Context and System Overview

```markdown
## System Context

**Project:** {name}
**Description:** {one-line description from design doc}
**Stack:** {language/runtime}, {framework}, {database if any}, {infrastructure if any}
**Package Manager:** {detected from manifest}
**Test Framework:** {detected from manifest}

**Architecture Overview:**
{Paste the system architecture diagram (Mermaid or ASCII) from the design doc, if present}
{If no diagram, write a 3-5 sentence architectural summary}

**Key Components:**
{List major components with one-line descriptions — extracted from design doc}

**Data Model:**
{Paste ER diagram or entity summary from design doc, if present}
{If none, summarize core entities and relationships}

**Codebase Conventions:**
{Extracted from CLAUDE.md and design doc — be specific, not generic}
- File naming: {pattern}
- Architecture pattern: {e.g., Route → Service → Repository}
- Validation: {library and pattern}
- Error handling: {pattern}
- Auth: {pattern}
- Response format: {envelope format if applicable}

**Development Commands:**
{From CLAUDE.md — the commands the agent needs}
- Install: `{command}`
- Build: `{command}`
- Test: `{command}`
- Lint: `{command}`
- Dev server: `{command}`

This section is for orientation only. All implementation decisions come from the design document below.
```

---

### Section 3: Design Document

Decide based on design doc length:
- **Under 500 lines:** Embed the full document inline
- **Over 500 lines:** Reference by file path with a read instruction

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

**Path:** `{path/to/design-doc.md}`

This design document is the **single source of truth** for this implementation.
**You MUST read it in full before writing any code.**
Every implementation decision — data structures, API contracts, business logic, conventions — must come from this document.
Do NOT deviate from, extend, or reinterpret the design.
```

---

### Section 4: Strict Implementation Constraints

```markdown
## Implementation Constraints

### Source of Truth
- The design document is the ONLY source of implementation decisions
- This prompt provides process guidance, NOT implementation guidance
- If the design document and this prompt conflict, the design document wins

### Pre-Implementation Exploration (MANDATORY)

**You MUST complete ALL of these steps BEFORE writing any code.** Writing code before exploration is a failure condition.

1. **Read the design document** end-to-end. Identify all entities, endpoints, business logic, and edge cases.
2. **Read project CLAUDE.md** (`CLAUDE.md` at project root) for conventions and commands.
3. **Explore the repository structure** — understand existing directories, file patterns, naming conventions.
4. **Inspect existing code patterns** — before creating any new file, search for how similar features are currently implemented (routes, services, validation, error handling, tests).
5. **Verify the development environment** — dependencies installed, dev server starts, existing tests pass.

### Architecture
- Follow the architecture patterns defined in the design document exactly
- Maintain existing codebase conventions — file structure, naming, imports, error handling
- {This line is replaced with specific conventions extracted from CLAUDE.md and design doc}

### Testing
- Write tests alongside implementation, not after
- Unit tests for business logic (mock external dependencies)
- Integration tests for API endpoints (full request/response cycle)
- Follow existing test patterns in the codebase
- All tests must pass before the task is considered complete

### Git Workflow
- Create a branch: `feature/{short-description}`
- Use conventional commits: `feat:`, `fix:`, `test:`, `refactor:`, `docs:`
- Commit frequently — one commit per logical unit of work

### What NOT to Do
- Do NOT add features beyond what the design document specifies
- Do NOT refactor existing code unless the design document requires it
- Do NOT introduce new dependencies unless specified in the design document
- Do NOT skip error handling or validation
- Do NOT write code before completing the exploration steps above
- Do NOT include speculative or forward-looking changes
```

---

### Section 5: General Development Guidelines

```markdown
## Development Guidelines

These are high-level engineering principles for the implementation:

- **Simplicity first** — favor simple, clear solutions that scale effectively. The right amount of complexity is the minimum needed for the current task.
- **Maintainability** — write code that is easy to read, modify, and extend. Descriptive names, focused functions, explicit error handling.
- **Performance and reliability** — assume the system is production-grade and operates under high demand. Handle edge cases, validate inputs at system boundaries.
- **Correctness over speed** — get it right first, then optimize if needed. Every requirement in the design document must be implemented accurately.
- **Convention adherence** — preserve all existing codebase conventions: file structure, naming, data models, architectural patterns. New code must look like it belongs.
- **Professional documentation** — clear, helpful comments where the logic is not self-evident. No verbose or redundant documentation.
- **Composition over inheritance** — prefer composable, modular designs.
- **Explicit over implicit** — make behavior visible and predictable. No magic, no hidden side effects.

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

2. **Derive the prompt name:**
   - From the project name in the design doc
   - Or from the project directory name
   - Fallback: use the design doc's parent folder name

3. **Write the prompt** to `docs/{project-name}/prompts/sdlc-prompt-{name}.md`

4. **Display summary:**
   ```
   SDLC Meta-Prompt Generated!

   Location: docs/{project-name}/prompts/sdlc-prompt-{name}.md

   Design document: {path to design doc used}
   Stack detected: {language} / {framework} / {package manager}
   Design doc: {inline | referenced by path}
   Scope: {milestone count} milestones, {complexity} complexity

   Execution:
     claude "$(cat docs/{project-name}/prompts/sdlc-prompt-{name}.md)"

   The prompt is self-contained and ready for any LLM coding agent.
   ```

---

## Validation

```
Checklist:
- [ ] Section 1 (Task Definition) includes explicit deliverables and merged Definition of Done
- [ ] Section 2 (System Context) includes stack, architecture, conventions, and dev commands — all auto-detected
- [ ] Section 3 (Design Document) is embedded inline (<500 lines) or referenced with mandatory read instruction
- [ ] Section 3 declares the design document as the single source of truth
- [ ] Section 4 (Constraints) includes mandatory pre-implementation exploration (5 steps)
- [ ] Section 4 includes architecture, testing, git, and anti-pattern constraints
- [ ] Section 4 embeds project-specific conventions (not just generic principles)
- [ ] Section 5 (Guidelines) includes engineering principles and final verification checklist
- [ ] Prompt contains NO implementation logic, pseudocode, or design interpretation
- [ ] Prompt is a single, self-contained file ready for execution
- [ ] Output file path follows naming convention: docs/{project-name}/prompts/sdlc-prompt-{name}.md
```

---

## Rules

- The design document is the SINGLE SOURCE OF TRUTH — the prompt must not contain implementation details
- ALWAYS auto-detect stack from manifest files — never assume or hardcode
- ALWAYS read CLAUDE.md for project-specific conventions — generic principles alone are not enough
- ALWAYS include the pre-implementation exploration section — agents must read before coding
- ALWAYS include a Definition of Done — agents need verifiable completion criteria
- ALWAYS include the final verification checklist — agents must self-check before finishing
- NEVER include pseudocode, algorithms, or implementation logic in the generated prompt
- NEVER skip context gathering — the prompt quality depends on accurate project context
- KEEP language concise, direct, and unambiguous throughout
- The generated prompt must be PORTABLE — usable by any LLM coding agent, not just Claude
- If the design doc has 4+ milestones, recommend `/milestone-prompts` and ask for confirmation before proceeding
