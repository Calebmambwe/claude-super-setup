import express from "express";
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "http";
import Anthropic from "@anthropic-ai/sdk";
import { writeFileSync, mkdirSync, existsSync, readFileSync } from "fs";
import { join } from "path";

const PORT = 3011;
const SESSIONS_DIR = join(
  process.env.HOME || "~",
  ".claude",
  "brainchat-sessions"
);
mkdirSync(SESSIONS_DIR, { recursive: true });

// Load Telegram config for export
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || "8328233140";

const app = express();
app.use(express.json());

const server = createServer(app);
const wss = new WebSocketServer({ server, path: "/ws" });

// Session storage
interface Message {
  role: "user" | "assistant";
  content: string;
  timestamp: string;
}

interface Session {
  id: string;
  messages: Message[];
  createdAt: string;
  title: string;
}

const activeSessions = new Map<string, Session>();

// Claude client
const anthropic = new Anthropic();

const SYSTEM_PROMPT = `You are a creative brainstorming partner. Your role is to help the user develop their ideas through conversation.

Guidelines:
- Ask probing questions to clarify and expand ideas
- Suggest creative alternatives and improvements
- Challenge assumptions constructively
- Keep responses concise (2-4 sentences) so the conversation flows naturally like a voice chat
- After 5+ exchanges, offer to summarize the idea into a structured brief
- Be enthusiastic and encouraging

When the user says "done", "finish", "wrap up", or similar:
1. Produce a structured feature brief in markdown
2. Include: Problem, Solution, Key Features, Target Users, Success Metrics
3. Mark it with --- BRIEF START --- and --- BRIEF END --- markers`;

wss.on("connection", (ws: WebSocket) => {
  const sessionId = `bc-${Date.now()}`;
  const session: Session = {
    id: sessionId,
    messages: [],
    createdAt: new Date().toISOString(),
    title: "New Brainstorm",
  };
  activeSessions.set(sessionId, session);

  ws.send(
    JSON.stringify({
      type: "session",
      sessionId,
      message: "Connected. Start speaking or typing your idea.",
    })
  );

  ws.on("message", async (data: Buffer) => {
    try {
      const msg = JSON.parse(data.toString());

      if (msg.type === "message") {
        const userMessage: Message = {
          role: "user",
          content: msg.text,
          timestamp: new Date().toISOString(),
        };
        session.messages.push(userMessage);

        // Set title from first message
        if (session.messages.length === 1) {
          session.title = msg.text.slice(0, 60);
        }

        // Send to Claude
        ws.send(JSON.stringify({ type: "thinking" }));

        const apiMessages = session.messages.map((m) => ({
          role: m.role as "user" | "assistant",
          content: m.content,
        }));

        const response = await anthropic.messages.create({
          model: "claude-sonnet-4-6-20250514",
          max_tokens: 1024,
          system: SYSTEM_PROMPT,
          messages: apiMessages,
        });

        const assistantText =
          response.content[0].type === "text" ? response.content[0].text : "";

        const assistantMessage: Message = {
          role: "assistant",
          content: assistantText,
          timestamp: new Date().toISOString(),
        };
        session.messages.push(assistantMessage);

        // Check for brief markers
        const hasBrief =
          assistantText.includes("--- BRIEF START ---") ||
          assistantText.includes("## Problem") ||
          assistantText.includes("# Feature Brief");

        ws.send(
          JSON.stringify({
            type: "response",
            text: assistantText,
            hasBrief,
            exchangeCount: Math.floor(session.messages.length / 2),
          })
        );
      }

      if (msg.type === "export") {
        const transcript = formatTranscript(session);
        const filePath = join(SESSIONS_DIR, `${sessionId}.md`);
        writeFileSync(filePath, transcript);

        // Send to Telegram if configured
        if (TELEGRAM_BOT_TOKEN && TELEGRAM_CHAT_ID) {
          await sendToTelegram(session);
        }

        ws.send(
          JSON.stringify({
            type: "exported",
            path: filePath,
            telegramSent: !!TELEGRAM_BOT_TOKEN,
          })
        );
      }

      if (msg.type === "history") {
        ws.send(
          JSON.stringify({
            type: "history",
            sessions: listSessions(),
          })
        );
      }
    } catch (err) {
      ws.send(
        JSON.stringify({
          type: "error",
          message: err instanceof Error ? err.message : "Unknown error",
        })
      );
    }
  });

  ws.on("close", () => {
    // Auto-save session on disconnect
    if (session.messages.length > 0) {
      const filePath = join(SESSIONS_DIR, `${sessionId}.md`);
      writeFileSync(filePath, formatTranscript(session));
    }
  });
});

function formatTranscript(session: Session): string {
  let md = `# Brainstorm: ${session.title}\n`;
  md += `**Date:** ${session.createdAt}\n`;
  md += `**Session:** ${session.id}\n`;
  md += `**Exchanges:** ${Math.floor(session.messages.length / 2)}\n\n---\n\n`;

  for (const msg of session.messages) {
    const label = msg.role === "user" ? "You" : "Claude";
    md += `**${label}** *(${new Date(msg.timestamp).toLocaleTimeString()})*\n`;
    md += `${msg.content}\n\n`;
  }

  return md;
}

function listSessions(): Array<{ id: string; title: string; date: string }> {
  if (!existsSync(SESSIONS_DIR)) return [];
  const { readdirSync } = require("fs");
  return readdirSync(SESSIONS_DIR)
    .filter((f: string) => f.endsWith(".md"))
    .map((f: string) => {
      const content = readFileSync(join(SESSIONS_DIR, f), "utf-8");
      const titleMatch = content.match(/^# Brainstorm: (.+)/m);
      const dateMatch = content.match(/\*\*Date:\*\* (.+)/m);
      return {
        id: f.replace(".md", ""),
        title: titleMatch?.[1] || "Untitled",
        date: dateMatch?.[1] || "",
      };
    })
    .reverse();
}

async function sendToTelegram(session: Session): Promise<void> {
  const summary = `🧠 BrainChat Session Complete\n\n${session.title}\n\nExchanges: ${Math.floor(session.messages.length / 2)}\nSession: ${session.id}\n\nTranscript saved. Run /voice-brief to process into a feature spec.`;

  try {
    await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: TELEGRAM_CHAT_ID,
          text: summary,
        }),
      }
    );
  } catch {
    // Telegram send is best-effort
  }
}

// REST endpoints
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", sessions: activeSessions.size });
});

app.get("/api/sessions", (_req, res) => {
  res.json(listSessions());
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`BrainChat server running on port ${PORT}`);
});
