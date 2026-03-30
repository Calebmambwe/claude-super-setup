import express from "express";
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "http";
import { writeFileSync, mkdirSync, readFileSync, readdirSync } from "fs";
import { join } from "path";

const PORT = 3011;
const HOME = process.env.HOME || "/home/claude";
const SESSIONS_DIR = join(HOME, ".claude", "brainchat-sessions");
const BRIEFS_DIR = join(HOME, ".claude-super-setup", "docs", "briefs");
mkdirSync(SESSIONS_DIR, { recursive: true });
mkdirSync(BRIEFS_DIR, { recursive: true });

const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || "8328233140";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";

function getApiKey(): string {
  try {
    const creds = JSON.parse(readFileSync(join(HOME, ".claude", ".credentials.json"), "utf-8"));
    return creds?.claudeAiOauth?.accessToken || "";
  } catch {
    return process.env.ANTHROPIC_API_KEY || "";
  }
}

const app = express();
app.use(express.json());
const server = createServer(app);
const wss = new WebSocketServer({ server, path: "/ws" });

interface ChatMessage { role: "user" | "assistant"; content: string; timestamp: string; }
interface Session { id: string; messages: ChatMessage[]; createdAt: string; title: string; }

const activeSessions = new Map<string, Session>();

const SYSTEM_PROMPT = `You are a creative brainstorming partner in a real-time voice conversation. Rules:
- Keep responses to 2-3 sentences MAX. This is voice — be concise.
- Ask ONE focused question per response to keep the conversation moving.
- Be enthusiastic but not verbose.
- After 4+ exchanges, proactively offer: "Want me to wrap this into a brief?"
- When user says "done", "wrap up", "finish", "brief", or "summarize":
  Produce a structured brief in this EXACT format:

# Feature Brief: [Name]

## Problem
[1-2 sentences: what problem this solves]

## Solution
[2-3 sentences: the proposed approach]

## Key Features
- [Feature 1]
- [Feature 2]
- [Feature 3]

## Target Users
[Who benefits]

## Success Metrics
- [Metric 1]
- [Metric 2]

## Technical Notes
- [Stack/architecture hints from the conversation]

## Next Steps
1. Run /design-doc to create detailed design
2. Run /milestone-prompts to break into implementation phases
3. Run /auto-dev to build it`;

async function streamClaude(
  messages: Array<{ role: string; content: string }>,
  onChunk: (text: string) => void,
  onDone: (fullText: string) => void,
  onError: (err: string) => void
): Promise<void> {
  const apiKey = getApiKey();
  if (!apiKey) { onError("No API key"); return; }

  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-3-haiku-20240307",
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        stream: true,
        messages: messages.map((m) => ({ role: m.role, content: m.content })),
      }),
    });

    if (!resp.ok) {
      onError(`API ${resp.status}: ${(await resp.text()).slice(0, 200)}`);
      return;
    }

    const reader = resp.body?.getReader();
    if (!reader) { onError("No stream"); return; }

    const decoder = new TextDecoder();
    let fullText = "";
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        const data = line.slice(6).trim();
        if (data === "[DONE]") continue;
        try {
          const event = JSON.parse(data);
          if (event.type === "content_block_delta" && event.delta?.text) {
            fullText += event.delta.text;
            onChunk(event.delta.text);
          }
        } catch { /* skip */ }
      }
    }
    onDone(fullText);
  } catch (err) {
    onError(err instanceof Error ? err.message : "Stream failed");
  }
}

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";

// TTS endpoint — supports gemini, openai, browser (toggle via query param)
app.post("/api/tts", async (req, res) => {
  const { text, provider = "gemini" } = req.body;
  if (!text) { res.status(400).json({ error: "No text" }); return; }

  try {
    if (provider === "gemini" && GEMINI_API_KEY) {
      // Gemini TTS
      const ttsResp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=${GEMINI_API_KEY}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: text.slice(0, 4000) }] }],
            generationConfig: {
              responseModalities: ["AUDIO"],
              speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: "Kore" } } },
            },
          }),
        }
      );
      if (!ttsResp.ok) { res.status(ttsResp.status).json({ error: "Gemini TTS error" }); return; }
      const data = await ttsResp.json();
      const audioPart = data.candidates?.[0]?.content?.parts?.find((p: Record<string, unknown>) => p.inlineData);
      if (!audioPart) { res.status(500).json({ error: "No audio in response" }); return; }

      const pcmBuffer = Buffer.from(audioPart.inlineData.data, "base64");
      // Convert raw PCM to WAV for browser playback
      const wavHeader = createWavHeader(pcmBuffer.length, 24000, 16, 1);
      const wavBuffer = Buffer.concat([wavHeader, pcmBuffer]);
      res.set({ "Content-Type": "audio/wav", "Cache-Control": "no-cache" });
      res.send(wavBuffer);

    } else if (provider === "openai" && OPENAI_API_KEY) {
      // OpenAI TTS
      const ttsResp = await fetch("https://api.openai.com/v1/audio/speech", {
        method: "POST",
        headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ model: "tts-1", input: text.slice(0, 4096), voice: "nova", response_format: "mp3", speed: 1.05 }),
      });
      if (!ttsResp.ok) { res.status(ttsResp.status).json({ error: "OpenAI TTS error" }); return; }
      res.set({ "Content-Type": "audio/mpeg", "Cache-Control": "no-cache" });
      res.send(Buffer.from(await ttsResp.arrayBuffer()));

    } else {
      res.status(503).json({ error: "No TTS provider available", available: { gemini: !!GEMINI_API_KEY, openai: !!OPENAI_API_KEY } });
    }
  } catch (err) {
    res.status(500).json({ error: "TTS failed" });
  }
});

// Available TTS providers
app.get("/api/tts/providers", (_req, res) => {
  res.json({
    providers: [
      ...(GEMINI_API_KEY ? [{ id: "gemini", name: "Gemini (Kore)", active: true }] : []),
      ...(OPENAI_API_KEY ? [{ id: "openai", name: "OpenAI (Nova)", active: true }] : []),
      { id: "browser", name: "Browser Voice", active: true },
    ],
    default: GEMINI_API_KEY ? "gemini" : OPENAI_API_KEY ? "openai" : "browser",
  });
});

function createWavHeader(dataSize: number, sampleRate: number, bitsPerSample: number, channels: number): Buffer {
  const header = Buffer.alloc(44);
  const byteRate = sampleRate * channels * bitsPerSample / 8;
  const blockAlign = channels * bitsPerSample / 8;
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);
  return header;
}

wss.on("connection", (ws: WebSocket) => {
  const sessionId = `bc-${Date.now()}`;
  const session: Session = { id: sessionId, messages: [], createdAt: new Date().toISOString(), title: "New Brainstorm" };
  activeSessions.set(sessionId, session);
  ws.send(JSON.stringify({ type: "session", sessionId, hasTTS: !!OPENAI_API_KEY }));

  ws.on("message", async (data: Buffer) => {
    try {
      const msg = JSON.parse(data.toString());

      if (msg.type === "message") {
        session.messages.push({ role: "user", content: msg.text, timestamp: new Date().toISOString() });
        if (session.messages.length === 1) session.title = msg.text.slice(0, 60);

        ws.send(JSON.stringify({ type: "stream_start" }));

        await streamClaude(
          session.messages.map((m) => ({ role: m.role, content: m.content })),
          (chunk) => ws.send(JSON.stringify({ type: "stream_chunk", text: chunk })),
          (fullText) => {
            session.messages.push({ role: "assistant", content: fullText, timestamp: new Date().toISOString() });
            const hasBrief = /^#\s+Feature Brief/m.test(fullText) || /^##\s+Problem/m.test(fullText);
            ws.send(JSON.stringify({
              type: "stream_end", fullText, hasBrief,
              exchangeCount: Math.floor(session.messages.length / 2),
            }));

            // Auto-save brief if detected
            if (hasBrief) {
              const slug = session.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").slice(0, 40);
              const briefPath = join(BRIEFS_DIR, `${slug}.md`);
              writeFileSync(briefPath, fullText);
              ws.send(JSON.stringify({ type: "brief_saved", path: briefPath }));
            }
          },
          (err) => ws.send(JSON.stringify({ type: "error", message: err })),
        );
      }

      if (msg.type === "export") {
        const transcript = formatTranscript(session);
        const filePath = join(SESSIONS_DIR, `${sessionId}.md`);
        writeFileSync(filePath, transcript);
        if (TELEGRAM_BOT_TOKEN) await sendToTelegram(session);
        ws.send(JSON.stringify({ type: "exported", path: filePath, telegramSent: !!TELEGRAM_BOT_TOKEN }));
      }
    } catch (err) {
      ws.send(JSON.stringify({ type: "error", message: err instanceof Error ? err.message : "Error" }));
    }
  });

  ws.on("close", () => {
    if (session.messages.length > 0) {
      writeFileSync(join(SESSIONS_DIR, `${sessionId}.md`), formatTranscript(session));
    }
  });
});

function formatTranscript(s: Session): string {
  let md = `# Brainstorm: ${s.title}\n**Date:** ${s.createdAt}\n**Exchanges:** ${Math.floor(s.messages.length / 2)}\n\n---\n\n`;
  for (const m of s.messages) md += `**${m.role === "user" ? "You" : "Claude"}**\n${m.content}\n\n`;
  return md;
}

async function sendToTelegram(s: Session): Promise<void> {
  try {
    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: `BrainChat Complete\n\n${s.title}\n${Math.floor(s.messages.length / 2)} exchanges\n\nRun /voice-brief to process into SDLC pipeline.` }),
    });
  } catch { /* best-effort */ }
}

app.get("/api/health", (_req, res) => res.json({ status: "ok", sessions: activeSessions.size, hasKey: !!getApiKey(), hasTTS: !!OPENAI_API_KEY }));

server.listen(PORT, "0.0.0.0", () => {
  console.log(`BrainChat on :${PORT} | API: ${getApiKey() ? "ok" : "MISSING"} | TTS: ${OPENAI_API_KEY ? "OpenAI Nova" : "browser"}`);
});
