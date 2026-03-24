# Feature Brief: Enterprise Agent Platform

**Created:** 2026-03-24
**Status:** Draft

---

## Problem

claude-super-setup is powerful but local-only, not portable, and missing enterprise-grade development rigor. The setup dies when the laptop sleeps, can't be reproduced on a new machine without manual effort, lacks Google-level testing/review/release processes, has no voice input, no media generation capabilities, and no proactive personal assistant behaviors. The user manages multiple high-stakes projects (Twendai Ride, NVFA Platform, Reinvent, Smart Desk, Smart Hub) and needs an always-on AI brain that works from anywhere — phone, VPS, or any new computer — with the development rigor of Google/Anthropic/Stripe.

---

## Proposed Solution

Transform claude-super-setup into a **portable, enterprise-grade, always-on AI development and personal assistant platform** with 8 upgrade pillars:

1. **Portable Setup** — chezmoi-managed dotfiles + `setup-vps.sh` bootstrap script + systemd services. One command deploys the full stack (claude-super-setup + smart-desk + all MCP servers) to any Ubuntu VPS or new Mac.

2. **Enterprise Dev Process** — Google-level design docs (mandatory Alternatives Considered + Cross-Cutting Concerns), SMURF test classification, 3-gate code review, canary deploy simulation, feature flags, Amazon PR/FAQ in brainstorm, Stripe-style API review gates, blameless postmortems.

3. **Gemini Media Integration** — RLabs Gemini MCP (37 tools) for image generation (free tier), Veo video generation, and text-to-speech. UI prototyping from description, video demos from static mockups.

4. **Voice Brainstorming** — Telegram voice message transcription via Whisper API ($0.006/min). Send a voice note from phone, get structured requirements back. Future: real-time voice via Pipecat/LiveKit.

5. **Always-On Personal Assistant** — VPS-deployed Claude with Telegram as primary interface. Proactive behaviors via cron: morning briefing (calendar + tasks + project status), end-of-day summary, weekly project health report, PR review reminders.

6. **VS Code Advanced Integration** — Agent Teams with custom presets, Remote Control for mobile access, worktree isolation for parallel agents, URI handler for automation.

7. **Smart Hub Dashboard** — Tauri 2.0 native app + web dashboard for monitoring all agent activity, pipeline status, learning ledger, and task queue from browser.

8. **Fully Autonomous Development Agent** — A new `/auto-develop` command that chains the COMPLETE SDLC with zero human gates: raw idea → `/bmad:research` → `/brainstorm` → `/design-doc` → `/auto-plan` → `/auto-build-all` → `/check` → `/ship` → `/reflect`. The "senior engineer brain" that knows when to use each command and how to chain them. Configurable with `--skip-research`, `--from-brief <path>`, and Telegram progress notifications throughout.

---

## Target Users

**Primary:** Caleb Mambwe — solo developer running Twendai Software Ltd, managing 5+ active projects, wants mobile-first AI-augmented development with enterprise rigor.

**Secondary:** Any developer who clones claude-super-setup and wants a turnkey enterprise AI dev environment.

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Must build on existing claude-super-setup architecture (80+ commands, 50+ agents, 12 hooks). No new frameworks — extend what exists. |
| Timeline | Full design doc first, then incremental implementation. No fixed deadline — quality over speed. |
| Team | 1 engineer (solo) + AI agents. Leverage Ghost Mode and parallel agents for implementation. |
| Integration | Must integrate with existing Telegram plugin, Ghost Mode, Smart Desk, Smart Hub, learning ledger. Must not break any existing functionality. |
| VPS | User provides their own VPS. Bootstrap script must work on Ubuntu 24.04 LTS with Node 22 + Python 3.12. |
| Auth | Headless auth via `claude setup-token` (one-year OAuth). API key fallback for non-interactive. |

---

## Scope

### In Scope

**Pillar 1: Portable Setup**
- `setup-vps.sh` bootstrap script (installs deps, clones repos, runs install.sh, configures systemd)
- chezmoi integration for `~/.claude/` dotfiles with encrypted secrets
- `~/.mcp.json` template with path variables for cross-machine portability
- MCP servers (`learning-server.py`, `sandbox-server.py`) tracked in repo
- systemd unit files for: Telegram listener, learning server, Ghost Mode
- Tailscale setup instructions for secure remote access
- Smart Desk + Smart Hub clone and setup in bootstrap

**Pillar 2: Enterprise Dev Process**
- Enhanced design doc template (add Alternatives Considered, Cross-Cutting Concerns sections)
- SMURF test classification in `/generate-tests` (tag tests as Small/Medium/Large)
- 3-gate code review enhancement for `/check` (correctness + ownership + readability)
- Feature flag system (wrap changes in flags, flip separately from deploy)
- Canary deploy simulation (staged rollout with metrics check between stages)
- Amazon PR/FAQ step added to `/brainstorm` (write press release before spec)
- Stripe-style API review gate in `/api-spec`
- Enhanced `/post-mortem` with Google SRE template (timeline, root cause, where we got lucky, action items)

**Pillar 3: Gemini Media Integration**
- Add RLabs Gemini MCP to `~/.mcp.json` template
- Add fal.ai MCP as alternative (cheaper video)
- `/prototype` command — describe a UI, get mockup images from Gemini
- `/demo-video` command — generate short video demos from mockups via Veo
- Image generation accessible from all agents via MCP tools

**Pillar 4: Voice Brainstorming**
- Telegram voice message handler (OGG → MP3 → Whisper → text)
- Voice notes transcribed and processed as regular commands/conversations
- `/voice-brief` command — speak scattered thoughts, get structured feature brief
- Future: Pipecat real-time voice agent (design only, implement later)

**Pillar 5: Always-On Personal Assistant**
- Proactive cron jobs:
  - Morning briefing (7:30am): calendar, tasks, project status, overnight alerts
  - End-of-day summary (6pm): what was done, what's blocked, tomorrow's priorities
  - Weekly health report (Monday 9am): all projects status, learning stats, metrics
  - PR review reminders (every 2h): flag open PRs needing review
- Gmail triage: summarize unread, draft replies for routine emails
- Calendar awareness: don't schedule ghost runs during meetings
- Context switching: when you say "switch to Twendai Ride", load project context

**Pillar 6: VS Code Advanced Integration**
- Agent Teams presets: `review` (3 agents), `feature` (architect + frontend + backend), `debug` (reproducer + analyzer + fixer)
- Remote Control as default startup mode
- Worktree isolation for parallel agents
- URI handler integration for automation scripts

**Pillar 7: Smart Hub Dashboard**
- Web-accessible dashboard (not just Tauri desktop)
- Pipeline status view (all active Ghost Mode + dispatch sessions)
- Task queue view (Telegram dispatch queue)
- Learning ledger browser
- Metrics dashboard (session counts, token usage, task completion rates)

**Pillar 8: Fully Autonomous Development Agent**
- `/auto-develop` command — zero-gate pipeline from raw idea to shipped PR
- Chains: `/bmad:research` → `/brainstorm` → `/design-doc` → `/auto-plan` → `/auto-build-all` → `/check` → `/ship` → `/reflect`
- Context-aware phase skipping (skip research if brief exists, skip design if tasks.json exists)
- `--skip-research`, `--skip-design`, `--from-brief <path>` flags
- Telegram progress notifications at each phase transition
- Reads project state to decide which phases to run
- Fallback: if any phase fails, notify via Telegram and pause for human input
- Uses all existing commands — orchestrates, doesn't replace

### Out of Scope (deferred, not excluded)
- Multi-model reasoning (Gemini/GPT as thinking models — Gemini only for media)
- OpenClaw orchestrator integration
- WhatsApp/Discord/Slack channels (Telegram only for now)
- Mobile app (Telegram IS the mobile interface)
- Billing/monetization for other users
- Real-time voice agent (Pipecat — design only, implement in future sprint)

---

## Feature Name

**Kebab-case identifier:** `enterprise-agent-platform`

**Folder:** `docs/enterprise-agent-platform/`

---

## Notes

1. **Research completed:** Full research report at `docs/research/research-enterprise-upgrade.md` covering all 6 areas with 30+ sources. Reference files saved to `~/.claude/agent-memory/researcher/`.

2. **Existing infrastructure to reuse:**
   - Telegram dispatch system (just built): `commands/telegram-dispatch.md`, `hooks/telegram-dispatch-runner.sh`
   - Ghost Mode: `commands/ghost.md`, `hooks/ghost-watchdog.sh`
   - BMAD workflow: `skills/bmad/` (PRD, architecture, sprint planning)
   - Learning ledger: `~/.claude/mcp-servers/learning-server.py`
   - Design system: `skills/design-system/`
   - CI pipeline: `.github/workflows/ci.yml`

3. **Key technical decisions from research:**
   - chezmoi > stow for dotfiles (templates + encrypted secrets)
   - `claude setup-token` for headless VPS auth (one-year OAuth)
   - RLabs Gemini MCP (37 tools) over direct SDK (less boilerplate)
   - Whisper API for voice ($0.006/min) over Deepgram (simpler, async OK for Telegram)
   - systemd over supervisor/pm2 for VPS services (native Ubuntu)
   - Pipecat for future real-time voice (open source, Claude support built in)

4. **Enterprise process mapping (what exists vs. what's needed):**

   | Google Process | Your Current | Gap |
   |---------------|-------------|-----|
   | Design Doc | `/bmad:architecture` + `/design-doc` | Add Alternatives Considered, Cross-Cutting Concerns |
   | 3-Approval Review | `/check` (code-review + security) | Add readability gate, ownership check |
   | SMURF Testing | `/generate-tests` | Add test size classification, perf/load testing |
   | Canary Deploy | `/ship` (straight to PR) | Add staged rollout simulation |
   | Feature Flags | None | New system needed |
   | Incident Response | `/post-mortem` | Add IMAG roles, runbook template |
   | PR/FAQ | `/brainstorm` | Add press release step |
   | API Review Gate | `/api-spec` | Add review brief requirement |

5. **Implementation order (recommended):**
   - Sprint 1: Portability (setup-vps.sh, chezmoi, MCP servers in repo) + `/auto-develop` command
   - Sprint 2: Gemini MCP + Voice transcription
   - Sprint 3: Enterprise process upgrades (design doc, testing, review, feature flags)
   - Sprint 4: Personal assistant crons + proactive behaviors
   - Sprint 5: VS Code Agent Teams presets + Smart Hub dashboard
   - Sprint 6: Polish, documentation, release

6. **Open questions:**
   - Should the learning ledger move to PostgreSQL for cloud portability, or stay SQLite with rsync?
   - Should feature flags use a dedicated service (LaunchDarkly-style) or simple JSON config?
   - Should the morning briefing include weather and news, or just dev-related status?
