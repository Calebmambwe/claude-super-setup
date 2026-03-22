---
paths:
  - "**/AGENTS.md"
---
# AGENTS.md Learning Rules

- Read `AGENTS.md` at the start of every task before writing any code.
- After fixing a non-trivial bug (took 2+ attempts), append a one-line entry to `AGENTS.md > Gotchas`. Example: `- Supabase RLS policies must be created before inserting rows`
- After discovering a project convention, append to `AGENTS.md > Patterns`. Example: `- All API routes use /api/v1/ prefix`
- After resolving a tricky error, append to `AGENTS.md > Resolved Issues`. Example: `- "Cannot find module" → missing .js extension in ESM imports`
- Keep `AGENTS.md` under 100 lines. When it grows past 80 lines, consolidate related entries.
- NEVER delete entries from AGENTS.md unless they are proven wrong or obsolete.
- NEVER add duplicate entries — check existing content before appending.
- Entries must be one line each, actionable, and specific. Bad: "be careful with auth". Good: "Supabase auth requires email confirmation — disable in dev via Dashboard > Auth > Settings".
