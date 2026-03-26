---
name: adr
description: Create an Architecture Decision Record documenting a technical decision with context and rationale
---
Create an Architecture Decision Record: $ARGUMENTS

You are the System Architect, executing the **ADR** workflow.

## Workflow Overview

**Goal:** Document an architectural decision with context, alternatives considered, and rationale — so future engineers (and LLM agents) understand WHY a choice was made

**Output:** `docs/adr/NNNN-{title}.md`

**Best for:** Any technical decision that affects the architecture, is hard to reverse, or will be questioned later

---

## Step 1: Set Up ADR Directory

```bash
mkdir -p docs/adr
```

Check for existing ADRs:
```bash
ls docs/adr/ 2>/dev/null
```

Determine the next ADR number (0001, 0002, etc.).

## Step 2: Gather Context

If the user provided a decision topic, research the codebase for context:
- Read relevant code and configuration
- Understand the current state and constraints
- Identify alternatives that were considered (or should be)

If the topic is vague, ask the user to clarify the decision being made.

## Step 3: Write the ADR

Use this exact format (based on Michael Nygard's template):

```markdown
# ADR-{NNNN}: {Title}

**Date:** {date}
**Status:** {Proposed | Accepted | Deprecated | Superseded by ADR-XXXX}
**Deciders:** {who made or is making this decision}

## Context

{What is the issue that we're seeing that is motivating this decision or change?}
{What are the forces at play — technical constraints, business requirements, team capabilities?}
{2-4 paragraphs maximum. Be specific, not abstract.}

## Decision

{What is the change that we're proposing and/or doing?}
{State it clearly and directly: "We will use X for Y because Z."}

## Alternatives Considered

### Alternative 1: {Name}
{Brief description}
**Pros:** {list}
**Cons:** {list}
**Why rejected:** {specific reason}

### Alternative 2: {Name}
{Brief description}
**Pros:** {list}
**Cons:** {list}
**Why rejected:** {specific reason}

## Consequences

### Positive
- {Good thing that follows from this decision}
- {Another good thing}

### Negative
- {Trade-off or downside we're accepting}
- {Risk we're aware of}

### Neutral
- {Side effect that's neither good nor bad}

## References

- {Link to relevant PR, design doc, or discussion}
- {Link to documentation for the chosen tool/pattern}
```

## Step 4: Save and Index

Write ADR to `docs/adr/{NNNN}-{kebab-case-title}.md`.

If an `docs/adr/README.md` index exists, update it. If not, create one:

```markdown
# Architecture Decision Records

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-use-postgresql.md) | Use PostgreSQL for primary database | Accepted | 2026-02-28 |
| [0002](0002-jwt-authentication.md) | JWT-based authentication | Accepted | 2026-02-28 |
```

---

## Rules

- ALWAYS include alternatives considered — a decision without alternatives isn't a decision
- ALWAYS include consequences (positive AND negative) — every decision has trade-offs
- ALWAYS state the decision clearly in one sentence: "We will use X for Y"
- NEVER write ADRs for trivial decisions (variable naming, formatting)
- NEVER modify the decision section of an accepted ADR — supersede it with a new ADR instead
- Keep context concise — 2-4 paragraphs, not a research paper
- ADRs are immutable records — append, don't edit
- Status lifecycle: Proposed → Accepted → (optionally) Deprecated or Superseded
