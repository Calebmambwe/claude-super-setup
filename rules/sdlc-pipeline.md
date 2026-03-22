---
paths:
  - "**/docs/**"
  - "**/design-doc*"
  - "**/reverse-doc*"
  - "**/prompts/**"
  - "**/prd*"
  - "**/architecture*"
  - "**/brief.md"
---
# SDLC Pipeline Rules

Pipeline order:
0. `/brainstorm` → `docs/{name}/brief.md` (new idea entry point — ask 3–5 questions, confirm name, write brief)
1. `/reverse-doc` → `docs/{name}/reverse-doc.md` (existing code only)
2. `/design-doc` → `docs/{name}/design-doc.md` (accepts brief.md as input when no PRD/Architecture exists)
3. Prompt generation (choose one):
   - `/milestone-prompts` — 4+ milestones, multi-session (self-contained prompts per milestone)
   - `/implement-design` — 1-3 milestones, single session
   - `/sdlc-meta-prompt` — any stack, flexible
4. `/implement-meta-prompt` — execute a generated prompt

Shortcut: `/prompt <your ask>` routes to the correct step automatically (including `/brainstorm` for new ideas).

Templates stored at: `~/.claude/config/prompts/` (brainstorm-brief.md, design-document.md, milestone-prompts.md, single-implementation.md, reverse-documentation.md)

## Prompt Versioning

Before overwriting any prompt in `docs/{name}/prompts/`, archive the old version:
- Archive destination: `docs/{name}/prompts/.archive/{name}.{YYYYMMDD-HHMMSS}.md`
- The `version-prompt.sh` hook handles this automatically via PreToolUse
- Never delete `.archive/` — it's the version history

## Feature Registry

After creating any SDLC artifact, update `docs/FEATURES.md`:
- Status values: `📝 Brief` → `🔨 Design Doc` → `⚙️ Prompts Ready` → `✅ Done`
- Format: `| [feature-name](docs/feature-name/brief.md) | status | link | link | notes |`

After completing any SDLC artifact, proactively suggest the next step.
