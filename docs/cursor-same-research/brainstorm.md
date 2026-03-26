# Brainstorm: Cursor + Same.new Patterns for claude-super-setup

## Priority Improvements (Implementable Now)

### 1. Checkpoint System (from Cursor) — HIGH IMPACT
**What:** Auto-save git stash before destructive operations. Restore with `/checkpoint restore`.
**Why:** Cursor's most-loved safety feature. We have no equivalent.
**Implementation:** PreToolUse hook on Write/Edit that creates a git stash checkpoint.
**Files:** hooks/checkpoint.sh, commands/checkpoint.md

### 2. URL-to-App Cloning (from Same.new) — HIGH IMPACT
**What:** `/clone-app <url>` — scrapes a website, identifies the stack, scaffolds a replica.
**Why:** Same.new's killer feature. Zero-friction entry point.
**Implementation:** WebFetch the URL, identify components/layout, generate with our templates.
**Files:** commands/clone-app.md

### 3. Enhanced @Docs Integration (from Cursor) — MEDIUM IMPACT
**What:** Auto-inject Context7 docs into any command when a library is detected.
**Why:** Cursor's @Docs is beloved. We have Context7 but it's manual.
**Implementation:** PreToolUse hook that detects library references and auto-fetches docs.
**Files:** hooks/auto-docs.sh (enhanced session-start)

### 4. Auto-Fix on PR Review (from Cursor BugBot) — HIGH IMPACT
**What:** `/review` not only finds issues but auto-generates fixes.
**Why:** Cursor's BugBot doesn't just comment — it proposes fixes.
**Implementation:** Enhance /check to generate fix commits for each finding.
**Files:** commands/auto-fix-review.md

### 5. Parallel Agent Expansion (from Cursor) — MEDIUM IMPACT
**What:** Expand from 3 parallel Telegram agents to 8 using worktrees.
**Why:** Cursor does 8 parallel agents. We're limited to 3.
**Implementation:** Update telegram-parallel.md limit, use git worktrees for isolation.
**Files:** commands/telegram-parallel.md update

### 6. Smart Template Selection (from Same.new) — MEDIUM IMPACT
**What:** `/new-app` asks what you're building and auto-selects the best template.
**Why:** Same.new's opinionated defaults reduce decision fatigue.
**Implementation:** NLP routing in /new-app to match description -> template.
**Files:** commands/new-app.md enhancement
