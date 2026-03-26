# System Integration Map

## How All Features Work Together

```
┌──────────────────────────────────────────────────────────┐
│                    USER INTERFACE                          │
│  Terminal CLI  │  Telegram Bot  │  ngrok Preview Link     │
└──────┬─────────┴───────┬────────┴────────┬───────────────┘
       │                 │                  │
       ▼                 ▼                  ▼
┌──────────────────────────────────────────────────────────┐
│                    COMMAND ROUTER                          │
│  /new-app  /clone-app  /auto-dev  /build  /check  /ship  │
│  /plan     /brainstorm  /design-doc  /auto-tasks          │
└──────┬─────────────────────────────────────────┬─────────┘
       │                                         │
       ▼                                         ▼
┌─────────────────────┐    ┌──────────────────────────────┐
│   RESEARCH LAYER     │    │   PLANNING LAYER              │
│  Context7 (lib docs) │    │  /brainstorm → brief          │
│  WebSearch (market)   │    │  /design-doc → architecture   │
│  WebFetch (analysis)  │    │  /auto-tasks → tasks.json     │
│  Source repo discovery│    │  /plan → routing to right depth│
└──────┬──────────────┘    └──────────┬───────────────────┘
       │                              │
       ▼                              ▼
┌──────────────────────────────────────────────────────────┐
│                    BUILD LAYER                             │
│                                                           │
│  Template System (22+ stacks)                             │
│    ├── config/stacks/*.yaml                               │
│    ├── Design tokens (OKLCH palette generator)            │
│    └── Component library (premium patterns)               │
│                                                           │
│  Ralph Loop (per task)                                    │
│    ├── Plan → Implement → Verify → Fix                    │
│    ├── Max 3 attempts per task                            │
│    └── Parallel execution where safe (max 3 agents)       │
│                                                           │
│  Skills (loaded contextually)                             │
│    ├── design-system/SKILL.md                             │
│    ├── premium-builder/SKILL.md (NEW)                     │
│    ├── accessibility/SKILL.md                             │
│    └── backend-architecture/SKILL.md                      │
└──────┬──────────────────────────────────────────┬────────┘
       │                                          │
       ▼                                          ▼
┌─────────────────────┐    ┌──────────────────────────────┐
│   HOOK SYSTEM        │    │   VERIFICATION LAYER          │
│                      │    │                               │
│  Pre-write:          │    │  TypeScript check             │
│   design compliance  │    │  ESLint                       │
│   component reuse    │    │  Build verification           │
│                      │    │  E2E tests (Playwright)       │
│  Post-write:         │    │  Visual screenshots           │
│   typecheck          │    │  Accessibility audit          │
│   lint               │    │  Dead link check              │
│   SSR safety         │    │  Console error check          │
│   a11y quick check   │    │  Performance audit            │
│                      │    │  Security scan                │
│  Pre-commit:         │    │  Code review (Opus agent)     │
│   test suite         │    │                               │
│   secret scan        │    │                               │
│                      │    │                               │
│  Monitoring:         │    │                               │
│   budget guard       │    │                               │
│   progress reporter  │    │                               │
└──────┬──────────────┘    └──────────┬───────────────────┘
       │                              │
       ▼                              ▼
┌──────────────────────────────────────────────────────────┐
│                    SHIP LAYER                              │
│  Conventional commit + feature branch                     │
│  PR creation with description + test plan                 │
│  CI/CD pipeline (lint → typecheck → test → build)         │
│  Preview deployment (Vercel/ngrok)                        │
│  Telegram notification                                    │
└──────┬──────────────────────────────────────────┬────────┘
       │                                          │
       ▼                                          ▼
┌─────────────────────┐    ┌──────────────────────────────┐
│   LEARNING LAYER     │    │   COLLABORATION LAYER         │
│                      │    │                               │
│  Learning ledger MCP │    │  Mac (local)                  │
│  Memory files        │    │   ├── Primary builder         │
│  AGENTS.md           │    │   ├── Playwright visual       │
│  Benchmark suite     │    │   └── Human interaction       │
│  Skill evolution     │    │                               │
│  /reflect command    │    │  VPS (remote)                 │
│  /consolidate weekly │    │   ├── Background tasks        │
│                      │    │   ├── Long-running tests      │
│                      │    │   └── Ollama models           │
│                      │    │                               │
│                      │    │  Telegram dispatch             │
│                      │    │   ├── /dispatch-local          │
│                      │    │   ├── /dispatch-remote         │
│                      │    │   └── /coordinate              │
└──────────────────────┘    └──────────────────────────────┘
```

## Feature-to-Command Mapping

| Feature | Primary Command | Supporting Commands |
|---------|----------------|-------------------|
| Build new app | /new-app | /plan, /design-doc, /auto-dev |
| Clone website | /clone-app | /brainstorm, /design-doc, /auto-dev |
| Add feature | /dev or /auto-dev | /plan, /build, /check, /ship |
| Fix bugs | /debug | /check, /auto-fix-review |
| Review code | /check | /code-review, /security-audit |
| Deploy | /ship | /pr, CI pipeline |
| Test | /web-test | /visual-verify, /a11y-audit |
| Learn | /reflect | /consolidate, /benchmark |
| Collaborate | /coordinate | /dispatch-local, /dispatch-remote |

## MCP Tool Usage Map

| MCP Server | Used By | Purpose |
|-----------|---------|---------|
| Context7 | /plan, /build, researcher agent | Library documentation |
| Playwright | /clone-app, /visual-verify, /web-test | Visual capture & testing |
| GitHub | /ship, /pr, /rollback | Git operations |
| Telegram | /dispatch-*, /coordinate, hooks | Communication |
| Memory | Session persistence | Graph-based memory |
| Learning | /reflect, /consolidate | Learning ledger |
| Sequential Thinking | Complex planning | Step-by-step reasoning |
