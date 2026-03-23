---
name: preview-templates
description: "Show visual previews of stack templates for approval before building — supports local gallery and Telegram remote approval"
---

Show visual template previews for: $ARGUMENTS

You are the **Template Previewer**. Your job is to show the user visual examples of the stack templates that will be used for their feature, and get explicit approval before the pipeline continues.

## Step 0: Read Context

Parse `$ARGUMENTS` to determine which stacks to preview:

**If $ARGUMENTS is a file path** (e.g., `docs/user-auth/brief.md`):
1. Read the brief file
2. Scan the Proposed Solution, Constraints, and Notes sections for stack mentions
3. Match against known stack names: `web-app`, `saas-starter`, `web-t3`, `web-astro`, `web-sveltekit`, `web-remix`, `api-service`, `api-fastapi`, `api-hono-edge`, `ai-ml-app`, `mobile-app`, `mobile-expo-revenucat`, `mobile-nativewind`, `mobile-flutter`, `chrome-extension`, `cli-tool`
4. Also match tech keywords: "Next.js" -> `web-app`, "SaaS" -> `saas-starter`, "T3" -> `web-t3`, "Astro" -> `web-astro`, "SvelteKit" -> `web-sveltekit`, "Remix" -> `web-remix`, "Hono" -> `api-service`, "FastAPI" -> `api-fastapi`, "Cloudflare Workers" -> `api-hono-edge`, "AI" / "ML" / "LLM" -> `ai-ml-app`, "React Native" / "Expo" -> `mobile-app`, "RevenueCat" -> `mobile-expo-revenucat`, "NativeWind" / "Tailwind RN" -> `mobile-nativewind`, "Flutter" -> `mobile-flutter`, "Chrome Extension" -> `chrome-extension`, "CLI" -> `cli-tool`

**If $ARGUMENTS is a comma-separated list** (e.g., `web-app,saas-starter`):
1. Split on commas and use directly

**If $ARGUMENTS is a feature description** (neither a file path nor comma-separated stack names):
1. Infer stacks from keywords in the description using the keyword map above
2. If no stacks can be inferred, ask the user: "Which stack template should I preview?" and list all 16 options grouped by category (web, api, mobile, other)

Build a `RELEVANT_STACKS` list. Cap at **4 stacks maximum** — if more are matched, keep the most relevant (primary stack first, alternatives second). Display: "Previewing {n} stack template(s): {list}"

---

## Step 1: Resolve Stack YAMLs

For each stack in `RELEVANT_STACKS`, read `~/.claude/config/stacks/{stack-name}.yaml` and extract:
- `name`
- `description`
- `short_label`
- `preview_url` (may be empty)
- First 3 items from `init_commands` (as tech fingerprint)

Store these as the preview metadata.

---

## Step 2: Generate Previews (3-Tier Waterfall)

For each stack, try tiers in order until one succeeds:

### Tier 1: Cached Screenshot
```bash
bash ~/.claude/hooks/preview-helpers.sh check_tier1 {stack-name}
```
If a path is returned (non-empty), use that PNG. Log: "Using cached preview for {stack-name}"

### Tier 2: Live Screenshot from preview_url
If `preview_url` is set and non-empty in the YAML:
1. `mcp__plugin_playwright_playwright__browser_navigate` to the `preview_url`
2. `mcp__plugin_playwright_playwright__browser_resize` to width: 1280, height: 720
3. Wait 3 seconds for page to fully render: `mcp__plugin_playwright_playwright__browser_wait_for` with timeout 3000
4. `mcp__plugin_playwright_playwright__browser_take_screenshot` — save to `/tmp/preview-{stack-name}.png`
5. Log: "Captured live preview for {stack-name} from {preview_url}"

### Tier 3: Synthetic Preview
If Tier 1 and Tier 2 both fail (no cached PNG, no preview_url or screenshot failed):
1. Build an HTML string that renders a mock UI using the design system tokens:

```html
<!DOCTYPE html>
<html>
<head>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=DM+Sans:wght@400;500&display=swap');
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #0f172a; color: #f8fafc; font-family: 'DM Sans', sans-serif; }
  .nav { background: #1e293b; padding: 16px 32px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); }
  .nav-brand { font-family: 'Space Grotesk', sans-serif; font-size: 20px; font-weight: 700; color: #6366f1; }
  .nav-links { display: flex; gap: 24px; color: #94a3b8; font-size: 14px; }
  .hero { padding: 80px 32px; text-align: center; }
  .hero h1 { font-family: 'Space Grotesk', sans-serif; font-size: 48px; font-weight: 700; margin-bottom: 16px; background: linear-gradient(135deg, #6366f1, #22d3ee); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
  .hero p { color: #94a3b8; font-size: 18px; max-width: 600px; margin: 0 auto 32px; }
  .btn { display: inline-block; background: #6366f1; color: white; padding: 12px 24px; border-radius: 8px; font-weight: 500; font-size: 16px; }
  .cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; padding: 0 32px 64px; max-width: 1200px; margin: 0 auto; }
  .card { background: #1e293b; border-radius: 16px; padding: 24px; border: 1px solid rgba(255,255,255,0.05); }
  .card h3 { font-family: 'Space Grotesk', sans-serif; font-size: 18px; margin-bottom: 8px; color: #f8fafc; }
  .card p { color: #94a3b8; font-size: 14px; line-height: 1.6; }
  .badge { display: inline-block; background: rgba(99,102,241,0.15); color: #818cf8; padding: 4px 12px; border-radius: 9999px; font-size: 12px; margin: 4px 4px 0 0; }
  .stack-label { position: absolute; top: 16px; right: 16px; background: #6366f1; color: white; padding: 6px 16px; border-radius: 8px; font-size: 14px; font-weight: 500; }
  .container { position: relative; min-height: 100vh; }
</style>
</head>
<body>
<div class="container">
  <div class="stack-label">STACK_LABEL</div>
  <nav class="nav">
    <div class="nav-brand">STACK_NAME</div>
    <div class="nav-links"><span>Dashboard</span><span>Features</span><span>Docs</span><span>Settings</span></div>
  </nav>
  <div class="hero">
    <h1>STACK_NAME</h1>
    <p>STACK_DESCRIPTION</p>
    <div class="btn">Get Started</div>
  </div>
  <div class="cards">
    <div class="card"><h3>TECH_1</h3><p>Core framework powering this stack with production-ready defaults.</p></div>
    <div class="card"><h3>TECH_2</h3><p>Data layer with type-safe queries and automatic migrations.</p></div>
    <div class="card"><h3>TECH_3</h3><p>Additional tooling for testing, styling, and developer experience.</p></div>
  </div>
  <div style="padding: 0 32px 32px; max-width: 1200px; margin: 0 auto;">
    BADGES_HTML
  </div>
</div>
</body>
</html>
```

2. Replace placeholders:
   - `STACK_NAME` -> stack name from YAML
   - `STACK_LABEL` -> short_label from YAML
   - `STACK_DESCRIPTION` -> description from YAML
   - `TECH_1`, `TECH_2`, `TECH_3` -> extracted from first 3 init_commands (the primary packages)
   - `BADGES_HTML` -> `<span class="badge">{tech}</span>` for each technology in the description

3. Navigate Playwright to `data:text/html,` + URL-encoded HTML, or use `mcp__plugin_playwright_playwright__browser_navigate` to `about:blank` then `mcp__plugin_playwright_playwright__browser_evaluate` to set `document.documentElement.innerHTML` to the HTML

4. `mcp__plugin_playwright_playwright__browser_resize` to width: 1280, height: 720
5. `mcp__plugin_playwright_playwright__browser_take_screenshot` -> `/tmp/preview-{stack-name}.png`
6. Log: "Generated synthetic preview for {stack-name}"

**On any Playwright failure:** Log the error, set this stack's preview to `null`, continue with remaining stacks. Never abort the entire preview flow for a single stack failure.

---

## Step 3: Present Gallery

### Build Gallery Summary

Display a formatted text summary in the terminal:

```
## Template Preview Gallery

### 1. {stack-name} ({short_label})
   {description}
   Preview: /tmp/preview-{stack-name}.png
   Tech: {comma-separated tech list}

### 2. {stack-name} ({short_label})
   ...

Screenshots saved to /tmp/preview-*.png
```

### Open Gallery in Browser (optional)

If Playwright is available and at least one screenshot was generated:

1. Build a gallery HTML page that displays all preview screenshots side-by-side:

```html
<html>
<head>
<style>
  body { background: #0f172a; color: #f8fafc; font-family: system-ui; padding: 32px; }
  h1 { font-size: 28px; margin-bottom: 24px; }
  .gallery { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 24px; }
  .card { background: #1e293b; border-radius: 16px; overflow: hidden; border: 1px solid rgba(255,255,255,0.05); }
  .card img { width: 100%; height: auto; }
  .card-body { padding: 16px; }
  .card-body h3 { font-size: 18px; margin-bottom: 4px; }
  .card-body p { color: #94a3b8; font-size: 14px; }
</style>
</head>
<body>
  <h1>Template Preview Gallery</h1>
  <div class="gallery">
    <!-- One card per stack with embedded screenshot -->
  </div>
</body>
</html>
```

2. Navigate Playwright to this gallery page
3. Take a gallery screenshot -> `/tmp/preview-gallery.png`

---

## Step 4: Send to Telegram (if configured)

Check for Telegram configuration in this priority order:
1. Read `~/.claude/ghost-config.json` — check for `"telegram_approval": true` and `"telegram_chat_id"`
2. If not found, read `~/.claude/config/telegram.json` — check for `"chat_id"`

**If Telegram is configured:**

For each stack with a successful preview screenshot:
1. Send the screenshot as a photo via `mcp__plugin_telegram_telegram__reply`:
   - `chat_id`: the resolved chat ID
   - `text`: "{stack-name} — {description}"
   - `files`: ["/tmp/preview-{stack-name}.png"]

2. After all photos are sent, send the approval prompt:
   ```
   mcp__plugin_telegram_telegram__reply with:
   - chat_id: {chat_id}
   - text: "These are the template(s) for your feature. Reply YES to approve and continue, or NO to stop and revise."
   ```

3. Log: "Sent {n} preview(s) to Telegram chat {chat_id}"

**If Telegram is NOT configured:**
- Skip this step. Log: "Telegram not configured — using local approval only"

---

## Step 5: Wait for Approval

### Mode A: Local Terminal (default)

Ask the user directly:
```
Review the template previews above.

Type YES to approve and continue the pipeline.
Type NO to reject and revise the feature brief.
Type SKIP to continue without visual approval.
```

Wait for the user's response.

### Mode B: Telegram (when telegram is configured and running in ghost mode)

After sending the Telegram approval prompt in Step 4:
- The pipeline will receive the user's Telegram reply as an incoming channel message
- Parse the reply text for "YES", "NO", or similar affirmative/negative
- On YES: react to the message with a checkmark emoji via `mcp__plugin_telegram_telegram__react`
- On NO: react with an X emoji, send a follow-up: "Pipeline halted. Run /brainstorm to revise."

**Important:** In ghost mode, the Telegram reply arrives as a channel event. The ghost-run pipeline should check for the reply within its execution context. If no reply arrives within 30 minutes, fall back to auto-approve with a warning logged.

---

## Step 6: Return Signal

Based on the approval response, output one of these signals (the calling command reads this):

- **`PREVIEW_APPROVED`** — user said YES or SKIP. Pipeline continues.
- **`PREVIEW_REJECTED`** — user said NO. Pipeline halts. Suggest: "Run /brainstorm to revise your feature brief."
- **`PREVIEW_SKIPPED`** — all preview generation failed OR Playwright unavailable. Pipeline continues with a warning: "Visual preview could not be generated. Continuing without visual approval."

---

## Step 7: Cleanup

After approval signal is determined:
```bash
bash ~/.claude/hooks/preview-helpers.sh clean_previews
```

Close the Playwright browser if it was opened for previews:
```
mcp__plugin_playwright_playwright__browser_close
```

---

## Rules

- NEVER hard-block the pipeline if preview generation fails — degrade to PREVIEW_SKIPPED
- NEVER show more than 4 stacks in a single preview session
- ALWAYS clean up temporary preview files after the approval gate
- ALWAYS close the Playwright browser after previews are done
- If no stacks can be inferred from the brief, ASK the user before proceeding
- If Telegram send fails, fall back to local terminal approval immediately
- The synthetic Tier 3 preview must use the design system tokens (colors, fonts, radii) from `~/.claude/skills/design-system/SKILL.md` — never hardcode arbitrary values
- This command is called by `/brainstorm` (Step 6.5) and `/ghost-run` (Step 3.5) — it must work both interactively and autonomously
