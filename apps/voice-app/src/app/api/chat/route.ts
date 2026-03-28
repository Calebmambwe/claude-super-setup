/**
 * Chat API — Claude responses with mode-specific system prompts
 *
 * POST /api/chat
 * Body: { messages, mode?, questionsAnswered? }
 */

import { NextRequest, NextResponse } from "next/server";
import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";

const ChatSchema = z.object({
  messages: z.array(z.object({ role: z.enum(["user", "assistant"]), content: z.string() })),
  mode: z.enum(["general", "research", "sdlc"]).optional().default("general"),
  questionsAnswered: z.array(z.string()).optional(),
});

const SYSTEM_PROMPTS: Record<string, string> = {
  general: `You are Claude, a helpful AI assistant. Have natural conversations. Be concise (2-4 sentences). Be warm and direct. No markdown — this is a chat interface.`,

  research: `You are a research assistant. When the user asks a question:
- Give a thorough but concise answer (3-5 sentences)
- Cite specific facts, numbers, or comparisons when possible
- Suggest follow-up questions they should consider
- If you don't know something, say so clearly
No markdown — this is a chat interface. Be conversational.`,

  sdlc: `You are a brainstorming partner helping a developer think through a feature idea.
RULES:
- Keep responses SHORT (2-3 sentences) — this is voice/chat
- Ask ONE question at a time
- Be conversational, not formal
- Push back on vague answers

QUESTIONS TO COVER (flexible order):
1. What — What does this feature do?
2. Who — Who is the primary user?
3. Constraints — Technical, time, or budget constraints?
4. Scope — What is NOT included in v1?
5. Why Now — What triggered this idea?

After 3-5 exchanges, offer to generate the brief.
If user says "ship it" or "done", confirm and summarize.`,
};

export async function POST(request: NextRequest): Promise<NextResponse> {
  try {
    const body = await request.json();
    const { messages, mode, questionsAnswered } = ChatSchema.parse(body);

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      // Smart fallbacks per mode
      const count = messages.filter((m) => m.role === "assistant").length;
      const fallbacks: Record<string, string[]> = {
        general: [
          "Hey! I'm here to chat. What's on your mind?",
          "Interesting thought! Tell me more about that.",
          "That makes sense. What else are you thinking about?",
          "Good point. Is there anything specific you'd like to explore?",
        ],
        research: [
          "What would you like to research? Give me a topic and I'll dig in.",
          "Let me think about that... Can you narrow the scope a bit?",
          "That's a broad area. What specific aspect interests you most?",
          "Based on what you've described, I'd recommend looking into the key trends and competitors in this space.",
        ],
        sdlc: [
          "Cool idea! What exactly does this feature do in one sentence?",
          "Interesting! Who is the primary user for this?",
          "Got it. What are the main constraints — time, tech stack, budget?",
          "Makes sense. What's explicitly out of scope for v1?",
          "I think I have enough for a brief. Say 'ship it' when ready!",
        ],
      };
      const list = fallbacks[mode] ?? fallbacks.general;
      return NextResponse.json({ response: list[Math.min(count, list.length - 1)] });
    }

    const client = new Anthropic({ apiKey });
    let system = SYSTEM_PROMPTS[mode] ?? SYSTEM_PROMPTS.general;

    if (mode === "sdlc" && questionsAnswered?.length) {
      const remaining = ["what", "who", "constraints", "scope", "why_now"].filter((q) => !questionsAnswered.includes(q));
      system += `\n\nProgress: Covered: ${questionsAnswered.join(", ")}. Still need: ${remaining.join(", ") || "none — ready for brief!"}.`;
    }

    const result = await client.messages.create({
      model: "claude-sonnet-4-6",
      max_tokens: mode === "research" ? 400 : 200,
      system,
      messages: messages.map((m) => ({ role: m.role as "user" | "assistant", content: m.content })),
    });

    const responseText = result.content[0].type === "text" ? result.content[0].text : "";
    return NextResponse.json({ response: responseText });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return NextResponse.json({ error: "Validation failed" }, { status: 400 });
    }
    return NextResponse.json({ response: "I heard you! Could you say that again?" });
  }
}
