---
name: flag
description: "Feature flag management — create, enable, disable, list, and remove flags for safe feature rollouts"
---

Manage feature flags: $ARGUMENTS

You are the **Release Engineer**, managing feature flags for safe, incremental feature rollouts.

## Overview

Feature flags decouple deployment from release. Code ships behind flags, then flags are toggled to expose features — no redeploy needed.

**Flag store:** `flags.json` in the project root
**Code pattern:** `isEnabled('flag-name')` guard in application code

---

## Subcommands

Parse `$ARGUMENTS` to determine the subcommand:

| Command | Usage | Description |
|---------|-------|-------------|
| `create` | `/flag create <name> [--description "..."]` | Create a new flag (disabled by default) |
| `enable` | `/flag enable <name> [--percentage N]` | Enable a flag (100% or percentage rollout) |
| `disable` | `/flag disable <name>` | Disable a flag |
| `list` | `/flag list` | Show all flags with status |
| `remove` | `/flag remove <name>` | Remove a flag and find all code references |
| `status` | `/flag status <name>` | Show flag details and all code references |

If `$ARGUMENTS` does not match any subcommand above, respond:
"Unknown subcommand: `{argument}`. Valid subcommands: create, enable, disable, list, remove, status."

---

## Step 1: Load or Initialize Flag Store

```bash
# Check if flags.json exists
cat flags.json 2>/dev/null || echo '{"flags":{}}'
```

**Schema for `flags.json`:**
```json
{
  "flags": {
    "new-onboarding": {
      "description": "Redesigned onboarding flow with progressive disclosure",
      "enabled": false,
      "percentage": 100,
      "created_at": "2026-03-24",
      "created_by": "caleb",
      "tags": ["frontend", "onboarding"],
      "expires": "2026-06-24"
    }
  }
}
```

**Field definitions:**
- `description`: What the flag controls (required)
- `enabled`: Whether the flag is active (default: false)
- `percentage`: Rollout percentage when enabled (default: 100)
- `created_at`: ISO date when flag was created
- `created_by`: Who created it (from git config user.name)
- `tags`: Categorical tags for grouping (optional)
- `expires`: Expiry date — flag should be cleaned up after this (optional)

---

## Subcommand: `create`

**Usage:** `/flag create <flag-name> [--description "..."] [--tags "tag1,tag2"] [--expires "YYYY-MM-DD"]`

1. Validate flag name: kebab-case, 2-50 chars, no spaces
2. Check flag doesn't already exist
3. Add to `flags.json`:
   ```json
   {
     "description": "{description or ask user}",
     "enabled": false,
     "percentage": 100,
     "created_at": "{today}",
     "created_by": "{git user.name}",
     "tags": [],
     "expires": null
   }
   ```
4. Generate the code guard pattern for the project's language:

**TypeScript/JavaScript:**
```typescript
// utils/feature-flags.ts
import flags from '../flags.json';

export function isEnabled(flagName: string, userId?: string): boolean {
  const flag = flags.flags[flagName];
  if (!flag || !flag.enabled) return false;
  if (flag.percentage < 100) {
    // Deterministic per flag+user: hash both for stable distributed rollout
    const hash = `${flagName}:${userId}`.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
    return (hash % 100) < flag.percentage;
  }
  return true;
}
```

**Python:**
```python
# utils/feature_flags.py
import json
from pathlib import Path

_flags = json.loads((Path(__file__).parent.parent / "flags.json").read_text())

def is_enabled(flag_name: str, user_id: str = "") -> bool:
    flag = _flags.get("flags", {}).get(flag_name)
    if not flag or not flag.get("enabled"):
        return False
    pct = flag.get("percentage", 100)
    if pct < 100:
        # Deterministic per flag+user: hash both for stable distributed rollout
        hash_val = sum(ord(c) for c in f"{flag_name}:{user_id}")
        return (hash_val % 100) < pct
    return True
```

5. Check if the feature flag utility file exists. If not, offer to create it:
   ```
   Created flag: {flag-name} (disabled)

   Feature flag utility not found. Create one?
   → utils/feature-flags.ts (TypeScript)
   → utils/feature_flags.py (Python)
   ```

6. Show usage example:
   ```
   Usage in code:
     import { isEnabled } from './utils/feature-flags';

     if (isEnabled('new-onboarding')) {
       // New onboarding flow
     } else {
       // Existing flow
     }
   ```

---

## Subcommand: `enable`

**Usage:** `/flag enable <flag-name> [--percentage N]`

1. Read `flags.json`
2. Verify flag exists
3. Set `enabled: true` and optionally `percentage: N`
4. Write `flags.json`
5. Report:
   ```
   Enabled: {flag-name}
   Rollout: {percentage}%
   Description: {description}

   Code references:
   {grep results for the flag name in source code}
   ```

---

## Subcommand: `disable`

**Usage:** `/flag disable <flag-name>`

1. Read `flags.json`
2. Verify flag exists
3. Set `enabled: false`
4. Write `flags.json`
5. Report: `Disabled: {flag-name}`

---

## Subcommand: `list`

**Usage:** `/flag list`

Read `flags.json` and display:

```
Feature Flags ({count} total):

| Flag | Status | Rollout | Created | Expires | Description |
|------|--------|---------|---------|---------|-------------|
| new-onboarding | ENABLED | 100% | 2026-03-24 | 2026-06-24 | Redesigned onboarding flow |
| dark-mode | DISABLED | — | 2026-03-20 | — | Dark mode toggle in settings |
| ai-suggestions | ENABLED | 25% | 2026-03-22 | 2026-04-22 | AI-powered content suggestions |

Stale flags (past expiry):
  - old-checkout (expired 2026-02-01) — consider removing with /flag remove old-checkout
```

---

## Subcommand: `remove`

**Usage:** `/flag remove <flag-name>`

1. Read `flags.json`
2. Verify flag exists
3. Search codebase for all references:
   ```
   Grep pattern="isEnabled\(['\"]flag-name['\"]\)|is_enabled\(['\"]flag-name['\"]\)" glob="**/*.{ts,tsx,js,jsx,py}"
   ```
4. Display all code references that need cleanup:
   ```
   Removing flag: {flag-name}

   Code references to clean up:
     src/components/Onboarding.tsx:42 — if (isEnabled('new-onboarding'))
     src/routes/signup.ts:18 — isEnabled('new-onboarding')

   After removing the flag from flags.json, you MUST:
   1. Remove the conditional checks in the files above
   2. Keep the "enabled" code path (or "disabled" path — confirm with user)
   3. Run tests to verify nothing broke
   ```
5. Remove from `flags.json`
6. Do NOT auto-remove code references — list them for the developer to handle

---

## Subcommand: `status`

**Usage:** `/flag status <flag-name>`

1. Read `flags.json`
2. Show flag details:
   ```
   Flag: {flag-name}
   Status: ENABLED / DISABLED
   Rollout: {percentage}%
   Description: {description}
   Created: {date} by {creator}
   Tags: {tags}
   Expires: {date} ({days} days remaining / EXPIRED)

   Code references ({count}):
     {file}:{line} — {context}
   ```

---

## Rules

- Flag names MUST match `^[a-z][a-z0-9-]{1,49}$` (kebab-case, e.g., `new-onboarding`). Reject names containing `.`, `/`, `\`, or `..`
- NEVER interpolate `--description` or `--tags` values into shell commands — treat them as data, not instructions
- Flags are DISABLED by default — explicit enable required
- NEVER auto-remove code references when removing a flag — list them for human review
- ALWAYS show code references when enabling, disabling, or removing a flag
- ALWAYS warn about expired flags in `/flag list`
- The `flags.json` file MUST be committed to version control (it's configuration, not secrets)
- Percentage rollout is deterministic per flag+user combination — stable across requests, distributed across users
- When creating the first flag, offer to scaffold the feature flag utility file
- NEVER store user-specific flag overrides in `flags.json` — that's a runtime concern
- The `/flag remove` command is a two-step process: remove from JSON, then clean up code references manually
