---
name: demo-video
description: "Generate a short demo video from mockup images using Gemini Veo video generation"
---

Generate a demo video for: $ARGUMENTS

## What This Does

`/demo-video` takes existing mockup images (from `/prototype` or manually provided) and generates a short video demo using Gemini's Veo video generation. Useful for quick product demos, investor pitches, or Telegram previews.

```
/demo-video "show the onboarding flow transitioning between screens"
  ├── Find mockup images
  ├── Generate video prompt with transitions
  ├── Call Gemini Veo video generation
  ├── Save to docs/{project}/demos/
  └── Send via Telegram (if applicable)
```

## Process

### Step 1: Parse Arguments

Extract the video description from $ARGUMENTS.

If $ARGUMENTS is empty:
1. Check `docs/*/mockups/` for existing mockup images
2. If found, ask: "I found mockups in {path}. What kind of demo video should I create from these?"
3. If none found, ask: "No mockups found. Run /prototype first, or describe the video you want."

### Step 2: Locate Mockup Images

Search for mockup images in order of priority:
1. `docs/{project}/mockups/*.png` (from /prototype)
2. Any image paths mentioned in $ARGUMENTS
3. Recently generated images in the current session

If no images are found and $ARGUMENTS describes a scene, generate the video from text description alone (Veo supports text-to-video).

### Step 3: Generate Video Prompt

Create a detailed video generation prompt. Include:
- Start frame description (first mockup or scene)
- End frame description (last mockup or final state)
- Transition style (smooth fade, slide, zoom)
- Duration hint (5-10 seconds for demos)
- Camera movement (if applicable)

Example:
- Input: "show the app onboarding flow"
- Prompt: "A smooth screen recording style video showing a mobile app onboarding flow. Start with a welcome screen showing the app logo, transition to a feature highlights carousel with smooth slide animations, end on the main dashboard. Modern UI with rounded corners and subtle motion. 8 seconds, 1080x1920 portrait."

### Step 4: Generate Video

Call the Gemini Veo video generation MCP tool. Look for tools matching:
- `generate_video` or `veo` or `create_video`

If using image-to-video:
- Pass the first mockup as the starting frame
- Pass the last mockup as the ending frame reference in the prompt

If no Gemini MCP tools are available:
1. Suggest running `bash scripts/setup-gemini-mcp.sh`
2. As fallback, suggest using fal.ai: `claude mcp add --transport http fal-ai https://mcp.fal.ai/mcp`

### Step 5: Save Output

Create the demos directory if it doesn't exist:
```bash
mkdir -p docs/{project-name}/demos/
```

Save the generated video:
- Format: `{feature}-demo-{timestamp}.mp4`
- Example: `onboarding-demo-20260324.mp4`

### Step 6: Telegram Delivery

If running inside a Telegram context:
1. Send the video via Telegram `reply` tool with `files` parameter
2. Include a caption: "Demo: {description}"
3. Ask: "Want me to adjust the video or generate a different version?"

If not in Telegram:
1. Display the file path
2. Suggest: "View the video at: {path}"

## Output Format

```
## Demo Video Generated

Video: docs/{project}/demos/{filename}.mp4
Duration: ~{N} seconds
Source: {N} mockup images from docs/{project}/mockups/
Prompt: {the prompt used}
Model: Gemini Veo 2

Want to:
- Regenerate with different transitions? Describe changes
- Create from different mockups? Specify which ones
- Generate more mockups first? Run /prototype
```

## Rules

- ALWAYS check for existing mockups before asking the user to provide images
- ALWAYS save to `docs/{project}/demos/` — never to temp directories
- If Gemini MCP is not available, provide setup instructions — don't fail silently
- In Telegram context, ALWAYS send the video as a reply attachment
- Keep all generated videos — never overwrite previous versions
- Default to portrait (1080x1920) for mobile demos, landscape (1920x1080) for desktop
- Video duration should be 5-15 seconds for demos (short enough for Telegram)
