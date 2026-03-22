# Single Implementation Prompt Template

> **Portable prompt template.** Generates one self-contained LLM prompt from a design document — for single-session implementation.
> **Claude Code commands:** `/implement-design` (structured) or `/sdlc-meta-prompt` (flexible, any stack)
> **Use when:** 1-3 milestones. For 4+ milestones, use `milestone-prompts.md` instead.

---

## Meta-Prompt Instructions

You are tasked with writing a prompt for an LLM-based software development agent. Your goal is NOT to implement the design yourself, but to produce a clear, well-structured prompt that instructs another LLM to do so.

---

## Structure of the Generated Prompt

### 1. Clear Task Definition

Begin with:

```
Your task is to implement the [PROJECT NAME] system strictly based on the design document provided below.

What you must deliver:
- [Major deliverable 1]
- [Major deliverable 2]
- [Major deliverable 3]

Scope: Implement ALL requirements defined in the design document. Do not add features beyond what the design specifies.

Definition of Done:
[Merge all DoD checklists from every milestone]
- [ ] [DoD item from Milestone 1]
- [ ] [DoD item from Milestone 2]
- [ ] All new code has tests
- [ ] All tests pass
```

### 2. High-Level Context and System Overview

```
System Context

Project: [name]
Description: [one-line description]
Stack: [language/runtime], [framework], [database]
Package Manager: [detected from manifest]
Test Framework: [detected from manifest]

Architecture Overview:
[Paste system architecture diagram from design doc]

Key Components:
[List major components — extracted from design doc]

Codebase Conventions:
- File naming: [pattern]
- Architecture: [Route → Service → Repository]
- Validation: [library and pattern]
- Error handling: [pattern]
- Response format: [envelope format]

Development Commands:
- Install: [command]
- Build: [command]
- Test: [command]
- Lint: [command]

This section is for orientation only. All implementation decisions come from the design document below.
```

### 3. Design Document

Decide based on length:
- **Under 500 lines:** Embed inline
- **Over 500 lines:** Reference by path

```
=== DESIGN DOCUMENT START ===

[INSERT FULL DESIGN DOCUMENT OR PATH REFERENCE]

=== DESIGN DOCUMENT END ===

This document is the SINGLE SOURCE OF TRUTH.
Every implementation decision must come from this document.
Do NOT deviate from, extend, or reinterpret the design.
```

### 4. Implementation Constraints

```
Source of Truth:
- The design document is the ONLY source of implementation decisions
- This prompt provides process guidance, NOT implementation guidance
- If the design document and this prompt conflict, the design document wins

Pre-Implementation Exploration (MANDATORY):
1. Read the design document end-to-end
2. Read project CLAUDE.md for conventions and commands
3. Explore repository structure
4. Inspect existing code patterns
5. Verify development environment works

Architecture:
- Follow architecture patterns from design document exactly
- Maintain existing codebase conventions

Testing:
- Write tests alongside implementation, not after
- Unit tests for business logic (mock dependencies)
- Integration tests for API endpoints
- All tests must pass before task is complete

What NOT to Do:
- Do NOT add features beyond what the design specifies
- Do NOT refactor existing code unless required by the design
- Do NOT write code before completing the exploration steps
```

### 5. General Development Guidelines

```
- Simplicity first — minimum complexity for the current task
- Maintainability — descriptive names, focused functions
- Correctness over speed — get it right first
- Convention adherence — new code must look like it belongs

Final Verification (before finishing):
1. Design compliance — every requirement implemented
2. Tests pass — run the full test suite
3. Conventions followed — code matches existing patterns
4. Definition of Done — every checkbox satisfied
5. No drift — no features added beyond the design

If any check fails, fix it before declaring the task complete.
```

---

## Key Constraints on the Generated Prompt

- Contains NO implementation logic, pseudocode, or design interpretation
- Is a single, self-contained file ready for execution by any LLM
- If design doc has 4+ milestones, warn and suggest `/milestone-prompts` instead
