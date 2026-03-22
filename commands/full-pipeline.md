---
name: full-pipeline
description: Run the unified BMAD + Spec-Kit pipeline end-to-end for a major feature
---
Execute the full spec-driven development pipeline for: $ARGUMENTS

## Pipeline Steps

### Phase 0: Technical Research (runs before BMAD)

**Always runs for Full Pipeline.** Major features need library/framework verification.

1. Invoke researcher agent: "Research the technical landscape for: {$ARGUMENTS}"
2. Questions the researcher must answer:
   - What libraries/frameworks are appropriate for this feature?
   - What are the current (Context7-verified) API signatures?
   - Any known incompatibilities with the project's stack?
   - What patterns do industry projects use for this?
3. Output: `docs/{feature}/research.md`
4. **PAUSE** — present findings to user, get approval before Phase 1

Architecture decisions in Phase 1 MUST reference Phase 0 research findings.

### Phase 1: Business Layer (BMAD)
1. Run /bmad:product-brief if no brief exists for this feature
2. Run /bmad:prd to generate requirements with FRs, NFRs, and epics
3. Run /bmad:architecture to produce system design and ADRs

### Phase 2: Technical Layer (Spec-Kit)
4. Run /speckit.constitution to create or verify project constraints
5. Run /speckit.specify to generate a detailed specification from the PRD
6. Run /speckit.clarify to identify and resolve ambiguities in the spec
7. Run /speckit.plan to create a technical implementation plan
8. Run /speckit.analyze to validate the plan against constraints

### Phase 3: Task Decomposition
9. Run /bmad:sprint-planning to break epics into sprint backlog
10. Run /speckit.tasks to decompose the plan into independently implementable tasks

### Phase 4: Implementation
11. Present the task list for human review and approval
12. Offer: "Ready to implement. Run /parallel-implement to execute tasks in parallel worktrees, or implement sequentially?"

## Artifacts Created
- docs/{feature}/research.md (Phase 0 — technical research)
- docs/{feature}/prd.md
- docs/{feature}/architecture.md
- .specify/memory/constitution.md (if new)
- specs/{feature}.spec.md
- specs/{feature}.plan.md
- specs/{feature}.tasks.md

## Rules
- Stop after each phase for human review before proceeding
- All artifacts are versioned in git
- If any phase reveals a contradiction with the constitution, stop and flag it
