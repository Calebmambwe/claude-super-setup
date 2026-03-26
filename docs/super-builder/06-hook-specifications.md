# 06 — Hook Specifications

## Overview

This document is the canonical specification for every Claude Code hook in the super-builder pipeline. It defines what fires, when, why, and what the hook must do. Hooks are configured in `.claude/settings.json` (project-level, committed) and `.claude/settings.local.json` (personal overrides, gitignored).

---

## Reference: Claude Code Hook Event Taxonomy

Claude Code fires hooks at 27 lifecycle points. The complete event list:

### Session lifecycle
- `SessionStart` — new, resumed, cleared, or compacted session
- `SessionEnd` — session terminates
- `InstructionsLoaded` — CLAUDE.md or rules file loaded

### User input
- `UserPromptSubmit` — user submits a prompt (pre-processing, can block)

### Tool execution
- `PreToolUse` — before any tool call (can block, can rewrite input)
- `PermissionRequest` — permission dialog appears (can approve/deny)
- `PostToolUse` — after tool succeeds (can add context, cannot undo)
- `PostToolUseFailure` — after tool fails (logging, context injection)

### Agent lifecycle
- `Stop` — main agent finishes a turn (can block, forcing continuation)
- `SubagentStart` — subagent spawned
- `SubagentStop` — subagent finishes (can block)
- `StopFailure` — API error on turn end (logging only)

### Team operations
- `TeammateIdle` — team teammate going idle (can redirect)
- `TaskCompleted` — task marked complete (can block if criteria unmet)

### Environment
- `CwdChanged` — working directory changes (can set watch paths)
- `FileChanged` — watched file changes (can set watch paths)
- `ConfigChange` — config file changes (can block)

### Context
- `PreCompact` — before context compaction
- `PostCompact` — after context compaction

### Worktrees
- `WorktreeCreate` — isolated worktree created (returns path)
- `WorktreeRemove` — worktree removed

### MCP
- `Elicitation` — MCP server requests user input
- `ElicitationResult` — user responds to MCP elicitation

### Notifications
- `Notification` — Claude Code sends a notification to the user

---

## Exit Code Semantics

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| `0` | Success | Proceed; parse JSON on stdout for structured control |
| `2` | Blocking error | Block the action; stderr message fed to Claude |
| `1`, `3+` | Non-blocking error | Log in verbose mode; execution continues |

For `PreToolUse`, exit 2 blocks the tool call entirely and feeds stderr to Claude as context for why it was blocked. Claude can then try a different approach.

---

## Hook 1: Security Gate (PreToolUse/Bash)

**Purpose:** Block destructive filesystem commands, credential access, and system directory writes before they execute.

**Event:** `PreToolUse`
**Matcher:** `Bash`
**Type:** `command`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/security-gate.sh",
            "timeout": 5,
            "statusMessage": "Security check..."
          }
        ]
      }
    ]
  }
}
```

**Script: `.claude/hooks/security-gate.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

COMMAND=$(cat /dev/stdin | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))")

# Block rm -rf variants
if echo "$COMMAND" | grep -qE 'rm\s+.*-[a-z]*r[a-z]*f|rm\s+--recursive\s+--force'; then
  echo "BLOCKED: Destructive rm variant detected: $COMMAND" >&2
  exit 2
fi

# Block direct writes to system directories
if echo "$COMMAND" | grep -qE '>\s*/(etc|usr|bin|sbin|lib|boot)'; then
  echo "BLOCKED: Write to system directory blocked" >&2
  exit 2
fi

# Block chmod 777 (too permissive)
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
  echo "BLOCKED: chmod 777 is forbidden" >&2
  exit 2
fi

exit 0
```

**What it blocks:** `rm -rf`, `rm -fr`, `rm --recursive --force`, writes to `/etc/`, `/usr/`, chmod 777.

**What it allows:** All other bash commands proceed normally.

---

## Hook 2: Sensitive File Protection (PreToolUse/Write|Edit|MultiEdit)

**Purpose:** Prevent overwriting `.env` files, lockfiles, and git internals.

**Event:** `PreToolUse`
**Matcher:** `Write|Edit|MultiEdit`
**Type:** `command`

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        {
          "type": "command",
          "command": "python3 -c \"import json,sys; d=json.load(sys.stdin); p=d.get('tool_input',{}).get('file_path',''); forbidden=['.env','.env.local','.env.production','package-lock.json','yarn.lock','.git/']; blocked=any(f in p for f in forbidden if not p.endswith('.env.example') and not p.endswith('.env.sample')); sys.exit(2) if blocked else sys.exit(0)\"",
          "timeout": 3,
          "statusMessage": "Checking file protection..."
        }
      ]
    }
  ]
}
```

**Protects:** All `.env*` files (except `.env.example` and `.env.sample`), `package-lock.json`, `yarn.lock`, any path containing `.git/`.

---

## Hook 3: Design System Compliance (PreToolUse/Write|Edit)

**Purpose:** Block hardcoded hex colors, arbitrary pixel values, and raw z-index values in UI files. Enforce that all values come from design tokens.

**Event:** `PreToolUse`
**Matcher:** `Write|Edit|MultiEdit`
**Type:** `command`

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        {
          "type": "command",
          "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/design-system-gate.py",
          "timeout": 10,
          "statusMessage": "Design system compliance check..."
        }
      ]
    }
  ]
}
```

**Script: `.claude/hooks/design-system-gate.py`**

```python
#!/usr/bin/env python3
import json, sys, re

data = json.load(sys.stdin)
file_path = data.get('tool_input', {}).get('file_path', '')
content = data.get('tool_input', {}).get('content', '') or data.get('tool_input', {}).get('new_string', '')

# Only check UI files
UI_EXTENSIONS = {'.tsx', '.ts', '.css', '.scss', '.module.css'}
if not any(file_path.endswith(ext) for ext in UI_EXTENSIONS):
    sys.exit(0)

# Skip non-design-system files (tokens file, theme config)
EXEMPT_PATHS = ['tokens', 'theme', 'design-system', 'tailwind.config']
if any(p in file_path for p in EXEMPT_PATHS):
    sys.exit(0)

violations = []

# Block raw hex colors (not inside comments or strings that look like token references)
hex_pattern = re.compile(r'(?<!var\(--)[#][0-9a-fA-F]{3,8}\b')
hex_matches = hex_pattern.findall(content)
# Allow #000, #fff, #000000, #ffffff as they are safe universals
safe_hex = {'#000', '#fff', '#000000', '#ffffff', '#0000', '#ffff', '#00000000', '#ffffffff'}
flagged_hex = [h for h in hex_matches if h.lower() not in safe_hex]
if flagged_hex:
    violations.append(f"Hardcoded colors found: {flagged_hex}. Use CSS variables (var(--color-*)) or Tailwind tokens instead.")

# Block raw z-index > 9 (must use z-index scale tokens)
zindex_pattern = re.compile(r'z-index\s*:\s*(\d{2,})')
zindex_matches = zindex_pattern.findall(content)
if zindex_matches:
    violations.append(f"Raw z-index values {zindex_matches}. Use z-index scale tokens (z-10, z-20, etc.) instead.")

# Block magic pixel values > 4px outside of specific whitelist
# (catches things like padding: 17px that should be spacing-4)
magic_px = re.compile(r'(?<!border-radius)(?<!border):\s*(\d{2,})px')
px_matches = [m for m in magic_px.findall(content) if int(m) not in {16, 24, 32, 48, 64, 80, 96, 128, 256, 320, 384, 448, 512, 640, 768}]
if px_matches:
    violations.append(f"Magic pixel values {px_matches}px. Use Tailwind spacing tokens or CSS custom properties.")

if violations:
    print("DESIGN SYSTEM VIOLATION:", file=sys.stderr)
    for v in violations:
        print(f"  - {v}", file=sys.stderr)
    print("\nReference: ~/.claude/skills/design-system/SKILL.md", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
```

---

## Hook 4: Component Reuse Check (PreToolUse/Write)

**Purpose:** Before creating a new component file, check that a similar component does not already exist. Prevents duplicate components from proliferating.

**Event:** `PreToolUse`
**Matcher:** `Write`
**Type:** `command`

```bash
#!/usr/bin/env bash
# .claude/hooks/component-reuse-check.sh

FILE_PATH=$(cat /dev/stdin | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")

# Only fire on component files
if [[ "$FILE_PATH" != *"/components/"* ]] && [[ "$FILE_PATH" != *"/ui/"* ]]; then
  exit 0
fi

# Extract the component name from the file path
COMPONENT_NAME=$(basename "$FILE_PATH" .tsx | sed 's/index//')

if [[ -z "$COMPONENT_NAME" ]]; then
  exit 0
fi

# Check for existing similar components
EXISTING=$(find "$CLAUDE_PROJECT_DIR/src" -name "*.tsx" 2>/dev/null | xargs grep -l "export.*$COMPONENT_NAME" 2>/dev/null | head -3)

if [[ -n "$EXISTING" ]]; then
  echo "POTENTIAL DUPLICATE COMPONENT: $COMPONENT_NAME" >&2
  echo "Existing implementations found:" >&2
  echo "$EXISTING" >&2
  echo "" >&2
  echo "Extend or reuse an existing component rather than creating a new one." >&2
  echo "If this is intentional, proceed — this is a warning, not a block." >&2
  # Exit 1 = warning, not block (execution continues, message shown to Claude)
  exit 1
fi

exit 0
```

Note: This hook exits 1 (warning), not 2 (block). Claude sees the message as context and can decide whether to proceed or pivot to extending the existing component.

---

## Hook 5: Auto-Format on File Write (PostToolUse/Write|Edit|MultiEdit)

**Purpose:** Run Prettier and ESLint fix on every written TypeScript/TSX file immediately after the write. Keeps all files formatted without a separate step.

**Event:** `PostToolUse`
**Matcher:** `Write|Edit|MultiEdit`
**Type:** `command`

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        {
          "type": "command",
          "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format.sh",
          "async": true,
          "timeout": 30,
          "statusMessage": "Formatting..."
        }
      ]
    }
  ]
}
```

**Script: `.claude/hooks/auto-format.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

FILE_PATH=$(cat /dev/stdin | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")

# Only format TypeScript and CSS files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.css|*.scss|*.json|*.md)
    ;;
  *)
    exit 0
    ;;
esac

cd "$CLAUDE_PROJECT_DIR"

# Run prettier if available
if command -v pnpm &>/dev/null && [ -f "package.json" ]; then
  pnpm prettier --write "$FILE_PATH" 2>/dev/null || true
fi

exit 0
```

`async: true` is intentional — formatting should not block the next tool call. Claude continues writing while formatting runs in the background.

---

## Hook 6: TypeScript Check on File Write (PostToolUse/Write|Edit)

**Purpose:** Run `tsc --noEmit` on the affected file after every write. Surfaces type errors immediately, not at the end of a batch.

**Event:** `PostToolUse`
**Matcher:** `Write|Edit|MultiEdit`
**Type:** `command`

```bash
#!/usr/bin/env bash
# .claude/hooks/typecheck-on-write.sh

FILE_PATH=$(cat /dev/stdin | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")

# Only typecheck TypeScript files
if [[ "$FILE_PATH" != *.ts ]] && [[ "$FILE_PATH" != *.tsx ]]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

if ! pnpm tsc --noEmit --skipLibCheck 2>&1 | head -20; then
  echo "TypeScript errors detected after writing $FILE_PATH" >&2
  exit 1  # Warning, not block — Claude will see the error and fix it
fi

exit 0
```

Exit 1 here means Claude sees the TypeScript errors as context and will attempt a fix before moving to the next task.

---

## Hook 7: Test Suite Guard (Stop)

**Purpose:** Prevent Claude from declaring a task complete until all tests pass. Implements the "verify before stopping" principle from the Ralph Loop.

**Event:** `Stop`
**Type:** `command`

```json
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tests-must-pass.sh",
          "timeout": 120,
          "statusMessage": "Verifying tests before stopping..."
        }
      ]
    }
  ]
}
```

**Script: `.claude/hooks/tests-must-pass.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Only enforce if there are test files
if ! find "$CLAUDE_PROJECT_DIR/src" -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" 2>/dev/null | grep -q .; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# Check if tests pass
if pnpm test --passWithNoTests 2>&1; then
  exit 0
else
  # Block the stop — force Claude to fix the tests
  python3 -c "
import json, sys
result = {
    'decision': 'block',
    'reason': 'Tests are failing. Fix all test failures before marking the task complete. Run pnpm test to see the failures.'
}
print(json.dumps(result))
"
  exit 0
fi
```

Note: This outputs structured JSON and exits 0 (not exit 2). The `decision: block` in the JSON body is what blocks the stop. This is the correct pattern for `Stop` hooks.

---

## Hook 8: Error Context Injector (PostToolUseFailure)

**Purpose:** When any tool fails, enrich Claude's context with structured error information and suggest the most likely fix path.

**Event:** `PostToolUseFailure`
**Matcher:** `*` (all tools)
**Type:** `command`

```bash
#!/usr/bin/env bash
# .claude/hooks/error-context-injector.sh

INPUT=$(cat /dev/stdin)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))")
ERROR=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',''))")

# Write structured context to stdout (Claude reads this as additional context)
python3 -c "
import json, sys

tool = '$TOOL_NAME'
error = '''$ERROR'''

context_map = {
    'Bash': 'Check: (1) command syntax, (2) working directory, (3) required environment variables, (4) file permissions.',
    'Write': 'Check: (1) directory exists, (2) file path is valid, (3) no permission denied.',
    'Edit': 'Check: (1) old_string matches exactly (whitespace sensitive), (2) file has not changed since last read.',
    'Read': 'Check: (1) file path is correct, (2) file exists, (3) no permission denied.',
}

output = {
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUseFailure',
        'additionalContext': f'Tool {tool} failed. {context_map.get(tool, \"\")} Error: {error[:500]}'
    }
}
print(json.dumps(output))
"
exit 0
```

---

## Hook 9: Session Checkpoint (SessionEnd)

**Purpose:** At the end of every session, write a checkpoint file with the current task state, files modified, and any outstanding errors. Enables clean resumption.

**Event:** `SessionEnd`
**Type:** `command`

```json
{
  "SessionEnd": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-checkpoint.sh",
          "async": true,
          "timeout": 30
        }
      ]
    }
  ]
}
```

**Script: `.claude/hooks/session-checkpoint.sh`**

```bash
#!/usr/bin/env bash
CHECKPOINT_FILE="$CLAUDE_PROJECT_DIR/.claude/checkpoint.json"

python3 -c "
import json, subprocess, os
from datetime import datetime

# Get modified files from git
result = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True, cwd='$CLAUDE_PROJECT_DIR')
modified = [line[3:] for line in result.stdout.strip().split('\n') if line]

checkpoint = {
    'timestamp': datetime.now().isoformat(),
    'session_end': True,
    'modified_files': modified,
    'tasks_file_exists': os.path.exists('$CLAUDE_PROJECT_DIR/tasks.json'),
}

with open('$CHECKPOINT_FILE', 'w') as f:
    json.dump(checkpoint, f, indent=2)
print('Checkpoint saved to $CHECKPOINT_FILE')
"
```

---

## Hook 10: Observability Event Emitter (All Events)

**Purpose:** Forward every hook event to the local observability server (SQLite + WebSocket dashboard). Enables real-time pipeline visibility.

**Event:** All events via wildcard matcher
**Type:** `http`

```json
{
  "PreToolUse": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "http",
          "url": "http://localhost:4000/events",
          "async": true,
          "timeout": 2
        }
      ]
    }
  ],
  "PostToolUse": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "http",
          "url": "http://localhost:4000/events",
          "async": true,
          "timeout": 2
        }
      ]
    }
  ],
  "Stop": [
    {
      "hooks": [
        {
          "type": "http",
          "url": "http://localhost:4000/events",
          "async": true,
          "timeout": 2
        }
      ]
    }
  ]
}
```

`async: true` + `timeout: 2` means observability events never slow down the pipeline. If the server is not running, the hook fails silently (exit 1 = non-blocking).

---

## Hook 11: Telegram Phase Notification (TaskCompleted)

**Purpose:** Send a Telegram message when a task completes, including pass/fail status and time elapsed.

**Event:** `TaskCompleted`
**Type:** `command`

```bash
#!/usr/bin/env bash
# .claude/hooks/telegram-notify.sh

INPUT=$(cat /dev/stdin)
TASK_SUBJECT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('task_subject','unknown task'))")

python3 -c "
import os, json, urllib.request, urllib.parse

token = os.environ.get('TELEGRAM_BOT_TOKEN', '')
chat_id = os.environ.get('TELEGRAM_CHAT_ID', '')

if not token or not chat_id:
    exit(0)

message = f'[super-builder] Task complete: $TASK_SUBJECT'
data = urllib.parse.urlencode({'chat_id': chat_id, 'text': message}).encode()
req = urllib.request.Request(f'https://api.telegram.org/bot{token}/sendMessage', data=data)
urllib.request.urlopen(req, timeout=5)
"
exit 0
```

---

## Complete `.claude/settings.json` for Super-Builder

The full wired configuration:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/security-gate.sh",
            "timeout": 5,
            "statusMessage": "Security check..."
          }
        ]
      },
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import json,sys; d=json.load(sys.stdin); p=d.get('tool_input',{}).get('file_path',''); forbidden=['.env','.env.local','.env.production','package-lock.json','yarn.lock','.git/']; blocked=any(f in p for f in forbidden if not p.endswith('.env.example') and not p.endswith('.env.sample')); sys.exit(2) if blocked else sys.exit(0)\"",
            "timeout": 3,
            "statusMessage": "Checking file protection..."
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/design-system-gate.py",
            "timeout": 10,
            "statusMessage": "Design system compliance..."
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/component-reuse-check.sh",
            "timeout": 10,
            "statusMessage": "Checking for existing components..."
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:4000/events",
            "async": true,
            "timeout": 2
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format.sh",
            "async": true,
            "timeout": 30,
            "statusMessage": "Formatting..."
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/typecheck-on-write.sh",
            "async": true,
            "timeout": 60,
            "statusMessage": "Type checking..."
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:4000/events",
            "async": true,
            "timeout": 2
          }
        ]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/error-context-injector.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tests-must-pass.sh",
            "timeout": 120,
            "statusMessage": "Verifying tests before stopping..."
          },
          {
            "type": "http",
            "url": "http://localhost:4000/events",
            "async": true,
            "timeout": 2
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-checkpoint.sh",
            "async": true,
            "timeout": 30
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/telegram-notify.sh",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

---

## Hook Directory Structure

```
.claude/
├── settings.json                    # Hook wiring (committed)
├── settings.local.json              # Personal overrides (gitignored)
├── checkpoint.json                  # Auto-written by SessionEnd hook
└── hooks/
    ├── security-gate.sh             # Hook 1
    ├── design-system-gate.py        # Hook 3
    ├── component-reuse-check.sh     # Hook 4
    ├── auto-format.sh               # Hook 5
    ├── typecheck-on-write.sh        # Hook 6
    ├── tests-must-pass.sh           # Hook 7
    ├── error-context-injector.sh    # Hook 8
    ├── session-checkpoint.sh        # Hook 9
    └── telegram-notify.sh           # Hook 11
```

All scripts must be executable: `chmod +x .claude/hooks/*.sh .claude/hooks/*.py`

---

## Sources

- [Claude Code Hooks Reference (official)](https://code.claude.com/docs/en/hooks)
- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery)
- [Claude Code Hook SDK (TypeScript)](https://github.com/mizunashi-mana/claude-code-hook-sdk)
- [Claude Code Hooks: Production CI/CD Patterns](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns)
- [Claude Code Hooks Tutorial](https://blakecrosley.com/blog/claude-code-hooks-tutorial)
- [Claude Code Hooks DataCamp Guide](https://www.datacamp.com/tutorial/claude-code-hooks)
- Context7 library ID: `/mizunashi-mana/claude-code-hook-sdk`
- Context7 library ID: `/disler/claude-code-hooks-mastery`
