# Mac-VPS Collaboration Specification

## Architecture

Two Claude instances working in parallel:
- **Mac (local):** Primary builder, has Playwright, direct file access, ngrok tunnels
- **VPS (remote):** Background tasks, long-running builds, Ollama local models, cron jobs

## Task Distribution Strategy

### Mac handles:
- Interactive development (user is present)
- Visual verification (Playwright screenshots)
- Clone pipeline (needs browser)
- Human-in-the-loop testing
- PR creation and reviews

### VPS handles:
- Background research (WebSearch, Context7)
- Test suite execution (long-running E2E)
- Benchmark runs
- Cron jobs (healthcheck, learning consolidation)
- Ollama-based tasks (when API budget is tight)
- Bulk file processing (knowledge ingestion)

## Communication Protocol

### Mac → VPS (dispatch)
```
/dispatch-remote "Run full E2E test suite on supabase-clone"
```
- Uses Telegram bot-to-bot messaging
- VPS listener receives, parses, executes
- Result sent back via Telegram

### VPS → Mac (results)
```
/dispatch-local "E2E results: 32/32 passed. Screenshots saved to e2e/screenshots/"
```

### Shared State
- Git repository is the single source of truth
- Both push to feature branches
- Conflicts resolved by Mac (primary)
- tasks.json tracks which agent has which task

## Reliability

### Healthcheck
- VPS healthcheck runs every 2 minutes
- Checks: tmux session alive, Claude process running, disk space
- Auto-restarts crashed sessions
- Alerts via Telegram on failure

### Task Verification
- After dispatching to VPS, Mac checks for results within 30 minutes
- After 2 unanswered dispatches, Mac does the work itself
- All VPS commits are cherry-picked (not merged) to avoid deletions

## Parallel Execution Patterns

### Pattern 1: Research + Build
Mac builds while VPS researches next task's requirements

### Pattern 2: Build + Test
Mac builds new features while VPS runs E2E on completed features

### Pattern 3: Clone + Verify
Mac generates clone while VPS runs visual comparison against reference

### Pattern 4: Multi-Clone
Mac clones site A while VPS clones site B (both push to separate branches)
