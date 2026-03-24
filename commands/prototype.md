---
name: prototype
description: "Generate UI mockup images from a text description using Gemini image generation"
---

Generate a UI prototype mockup for: $ARGUMENTS

## What This Does

`/prototype` takes a UI description and generates visual mockup images using Gemini's image generation capabilities. The mockups are saved locally and sent via Telegram if in a Telegram context.

```
/prototype "a habit tracker app with streaks, dark mode, and a progress chart"
  ├── Parse description
  ├── Generate detailed image prompt
  ├── Call Gemini image generation
  ├── Save to docs/{project}/mockups/
  └── Send via Telegram (if applicable)
```

## Process

### Step 1: Parse Arguments

Extract the UI description from $ARGUMENTS.

If $ARGUMENTS is empty, ask: "What UI would you like me to prototype? Describe the screen, app, or component."

### Step 2: Determine Project Context

Detect the current project context:
- If inside a project directory with a `docs/` folder, use that project name
- If a feature name is mentioned, use it as the subfolder
- Default: use `prototype` as the folder name

Set `MOCKUP_DIR` to `docs/{project-name}/mockups/`

### Step 3: Generate Image Prompt

Transform the user's description into a detailed image generation prompt. Include:
- UI/UX best practices (proper spacing, hierarchy, readable typography)
- Mobile-first layout (unless desktop is specified)
- Modern design system aesthetics (rounded corners, subtle shadows, clean grid)
- Specific screen dimensions (e.g., iPhone 15 Pro: 393x852)
- Dark mode or light mode based on description

Example transformation:
- Input: "a habit tracker with streaks"
- Prompt: "A mobile app UI mockup for a habit tracker, iPhone 15 Pro screen (393x852px). Shows a list of daily habits with streak counts, progress rings, and a weekly calendar strip at the top. Modern design with rounded cards, subtle shadows, and a warm color palette. Clean typography with SF Pro font. Light mode."

### Step 4: Generate Image

Call the Gemini image generation MCP tool. The tool name depends on the available Gemini MCP tools — look for tools matching:
- `generate_image` or `imagen` or `create_image`

If no Gemini MCP tools are available:
1. Check if Gemini MCP is configured: suggest running `bash scripts/setup-gemini-mcp.sh`
2. As fallback, generate a detailed text description of the mockup instead

### Step 5: Save Output

Create the mockup directory if it doesn't exist:
```bash
mkdir -p docs/{project-name}/mockups/
```

Save the generated image with a descriptive filename:
- Format: `{feature}-{variant}-{timestamp}.png`
- Example: `habit-tracker-main-20260324.png`

### Step 6: Telegram Delivery

If running inside a Telegram context (detected by `<channel source="telegram">` tags):
1. Send the image via Telegram `reply` tool with `files` parameter
2. Include a caption: "Prototype: {description}"
3. Ask: "Want me to iterate on this? Describe what to change."

If not in Telegram:
1. Display the file path
2. Ask: "Want me to iterate, generate a different variant, or create a demo video from this?"

### Step 7: Iteration Loop

If the user provides feedback:
1. Modify the prompt based on feedback
2. Regenerate with the updated prompt
3. Save as a new variant (increment variant number)
4. Repeat until user is satisfied

## Output Format

```
## Prototype Generated

Mockup: docs/{project}/mockups/{filename}.png
Prompt: {the prompt used}
Model: Gemini Imagen 3

Want to:
- Iterate? Describe changes
- Generate more variants? Say "more"
- Create a demo video? Run /demo-video
```

## Rules

- ALWAYS generate a detailed, specific prompt — never pass the user's raw text directly
- ALWAYS include screen dimensions in the prompt for consistent results
- ALWAYS save to `docs/{project}/mockups/` — never to temp directories
- If Gemini MCP is not available, tell the user how to set it up instead of failing silently
- In Telegram context, ALWAYS send the image as a reply attachment
- Keep iteration history — never overwrite previous mockups
- Default to mobile-first unless the user specifies desktop
