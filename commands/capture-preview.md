---
name: capture-preview
description: "Bootstrap or refresh the Tier 1 cached screenshot library for stack template previews"
---

Capture preview screenshots for: $ARGUMENTS

You are the **Preview Capturer**. Your job is to generate and cache preview screenshots for stack templates so that `/preview-templates` can use them instantly (Tier 1).

## Step 1: Determine Scope

Parse `$ARGUMENTS`:
- If `all`: process all 16 stack templates
- If a specific stack name (e.g., `web-app`): process only that stack
- If empty: default to `all`

List all stack YAML files:
```bash
ls ~/.claude/config/stacks/*.yaml
```

## Step 2: Process Each Stack

For each stack template YAML:

1. Read the YAML and extract: `name`, `description`, `short_label`, `preview_url`

2. **If `preview_url` is set and non-empty (Tier 2):**
   - `mcp__plugin_playwright_playwright__browser_navigate` to the `preview_url`
   - `mcp__plugin_playwright_playwright__browser_resize` to width: 1280, height: 720
   - Wait for page load: `mcp__plugin_playwright_playwright__browser_wait_for` with timeout 5000
   - `mcp__plugin_playwright_playwright__browser_take_screenshot`
   - Save to `~/.claude/config/stacks/previews/{name}.png`
   - Log: "Captured live preview for {name} from {preview_url}"

3. **If `preview_url` is empty (Tier 3 — synthetic):**
   - Generate the synthetic preview HTML using the same template from `/preview-templates` Step 2 Tier 3
   - Replace `STACK_NAME`, `STACK_LABEL`, `STACK_DESCRIPTION`, `TECH_1/2/3`, and `BADGES_HTML` with values from the YAML
   - Navigate Playwright to `about:blank`, then use `mcp__plugin_playwright_playwright__browser_evaluate` to inject the HTML via `document.documentElement.innerHTML`
   - `mcp__plugin_playwright_playwright__browser_resize` to width: 1280, height: 720
   - `mcp__plugin_playwright_playwright__browser_take_screenshot`
   - Save to `~/.claude/config/stacks/previews/{name}.png`
   - Log: "Generated synthetic preview for {name}"

4. **On failure for any stack:** Log the error and continue to the next stack. Never abort the entire run.

## Step 3: Close Browser

After all stacks are processed:
```
mcp__plugin_playwright_playwright__browser_close
```

## Step 4: Report

```
## Preview Capture Complete

Captured: {success_count}/{total_count} previews
Stored in: ~/.claude/config/stacks/previews/

| Stack | Source | Status |
|-------|--------|--------|
| {name} | {Tier 2: live / Tier 3: synthetic} | {captured / failed} |
| ... | ... | ... |

Run /preview-templates {stack-name} to test a preview.
```

## Rules

- ALWAYS save screenshots to `~/.claude/config/stacks/previews/{name}.png` — this is the Tier 1 cache path
- NEVER abort the entire run if one stack fails — continue with the rest
- ALWAYS close the Playwright browser when done
- If Playwright is not available at all, report the error and suggest installing it
- This command is idempotent — running it again overwrites existing cached previews
