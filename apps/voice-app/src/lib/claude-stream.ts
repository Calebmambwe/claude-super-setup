/**
 * Claude API Streaming Client for Voice Conversation
 *
 * Maintains conversation history, streams responses for TTS,
 * and tracks brainstorming question progress.
 */

import Anthropic from "@anthropic-ai/sdk";

export interface ClaudeStreamConfig {
  apiKey: string;
  model?: string;
  maxTokens?: number;
}

export interface ConversationMessage {
  role: "user" | "assistant";
  content: string;
  timestamp: number;
}

export interface StreamCallbacks {
  onText: (chunk: string) => void;
  onComplete: (fullText: string) => void;
  onError: (error: Error) => void;
}

const BRAINSTORM_QUESTIONS = ["what", "who", "constraints", "scope", "why_now"] as const;
type BrainstormQuestion = (typeof BRAINSTORM_QUESTIONS)[number];

const SYSTEM_PROMPT = `You are a brainstorming partner helping a solo developer think through feature ideas via voice conversation. Your goal is to ask targeted questions that refine a vague idea into a structured feature brief.

## Your Approach
- Keep responses SHORT (2-3 sentences max) — this is a voice conversation, not a document
- Ask ONE question at a time — never multiple questions in one turn
- Be conversational and encouraging, not formal
- Push back gently on vague answers ("Can you be more specific about who would use this?")
- Track what you've learned and what's still unclear

## Questions to Cover (in flexible order)
1. **What** — What does this feature do? (one sentence)
2. **Who** — Who is the primary user?
3. **Constraints** — What are the technical, time, or budget constraints?
4. **Scope** — What is explicitly NOT included in v1?
5. **Why Now** — What triggered this idea? (optional, skip if natural)

## Session Flow
- Start by acknowledging the idea and asking your first clarifying question
- After 3-5 exchanges, when you have enough info, say: "I think I have enough to write a brief. Here's what I'm hearing: [summary]. Should I generate the brief?"
- If the user says "ship it", "build this", "that's enough", or "done" — summarize what you have and confirm they want to proceed

## Response Style
- Use natural spoken language (contractions, casual tone)
- No markdown, no bullet points, no headers — pure conversational text
- Reference what the user just said to show you're listening`;

export class ClaudeStream {
  private client: Anthropic;
  private config: Required<ClaudeStreamConfig>;
  private history: ConversationMessage[] = [];
  private questionsAnswered: Set<BrainstormQuestion> = new Set();

  constructor(config: ClaudeStreamConfig) {
    this.config = {
      apiKey: config.apiKey,
      model: config.model ?? "claude-sonnet-4-6",
      maxTokens: config.maxTokens ?? 300,
    };
    this.client = new Anthropic({ apiKey: this.config.apiKey });
  }

  async streamResponse(userText: string, callbacks: StreamCallbacks): Promise<string> {
    this.history.push({
      role: "user",
      content: userText,
      timestamp: Date.now(),
    });

    this.detectAnsweredQuestions(userText);

    let fullText = "";

    try {
      const stream = this.client.messages.stream({
        model: this.config.model,
        max_tokens: this.config.maxTokens,
        system: this.buildSystemPrompt(),
        messages: this.history.map((m) => ({
          role: m.role,
          content: m.content,
        })),
      });

      for await (const event of stream) {
        if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
          const chunk = event.delta.text;
          fullText += chunk;
          callbacks.onText(chunk);
        }
      }

      this.history.push({
        role: "assistant",
        content: fullText,
        timestamp: Date.now(),
      });

      callbacks.onComplete(fullText);
      return fullText;
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err));
      callbacks.onError(error);
      throw error;
    }
  }

  getHistory(): ConversationMessage[] {
    return [...this.history];
  }

  getTranscript(): string {
    return this.history
      .map((m) => {
        const time = new Date(m.timestamp).toISOString();
        const speaker = m.role === "user" ? "User" : "Claude";
        return `[${time}] ${speaker}: ${m.content}`;
      })
      .join("\n\n");
  }

  getQuestionsAnswered(): BrainstormQuestion[] {
    return [...this.questionsAnswered];
  }

  getQuestionsRemaining(): BrainstormQuestion[] {
    return BRAINSTORM_QUESTIONS.filter((q) => !this.questionsAnswered.has(q));
  }

  get exchangeCount(): number {
    return this.history.length;
  }

  isReadyForBrief(): boolean {
    return this.questionsAnswered.size >= 3 || this.history.length >= 8;
  }

  isShipItTrigger(text: string): boolean {
    const triggers = [
      "ship it",
      "build this",
      "build it",
      "that's enough",
      "thats enough",
      "done",
      "let's go",
      "lets go",
      "generate the brief",
      "write the brief",
      "make it happen",
    ];
    const lower = text.toLowerCase().trim();
    return triggers.some((t) => lower.includes(t));
  }

  reset(): void {
    this.history = [];
    this.questionsAnswered.clear();
  }

  private buildSystemPrompt(): string {
    const answered = this.getQuestionsAnswered();
    const remaining = this.getQuestionsRemaining();

    let context = SYSTEM_PROMPT;

    if (answered.length > 0) {
      context += `\n\n## Progress\nQuestions covered: ${answered.join(", ")}\nStill need: ${remaining.join(", ")}`;
    }

    if (this.isReadyForBrief()) {
      context += `\n\n## Ready for Brief\nYou have enough information. On the next natural opportunity, offer to generate the brief.`;
    }

    return context;
  }

  private detectAnsweredQuestions(text: string): void {
    const lower = text.toLowerCase();

    // Simple heuristics — Claude's questions guide the user to answer these
    if (this.history.length <= 2) {
      // First message usually answers "what"
      this.questionsAnswered.add("what");
    }

    if (lower.includes("for me") || lower.includes("i would") || lower.includes("developer") || lower.includes("user")) {
      this.questionsAnswered.add("who");
    }

    if (lower.includes("constraint") || lower.includes("budget") || lower.includes("time") || lower.includes("days") || lower.includes("limit")) {
      this.questionsAnswered.add("constraints");
    }

    if (lower.includes("not include") || lower.includes("out of scope") || lower.includes("skip") || lower.includes("later") || lower.includes("v2")) {
      this.questionsAnswered.add("scope");
    }

    if (lower.includes("because") || lower.includes("noticed") || lower.includes("trend") || lower.includes("need")) {
      this.questionsAnswered.add("why_now");
    }
  }
}
