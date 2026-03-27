/**
 * Voice Session Store
 *
 * File-based JSON session management shared between
 * Telegram (Approach A) and Web App (Approach B).
 */

import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync, unlinkSync } from "fs";
import { join } from "path";
import { z } from "zod";

const SESSION_DIR = process.env.VOICE_SESSION_DIR ?? "/tmp/voice-sessions";

const ExchangeSchema = z.object({
  turn: z.number(),
  role: z.enum(["user", "assistant"]),
  text: z.string(),
  audio_path: z.string().nullable().optional(),
  timestamp: z.string(),
});

const SessionSchema = z.object({
  id: z.string().regex(/^vs-\d{8}-\d{6}$/),
  approach: z.enum(["telegram", "web"]),
  status: z.enum(["active", "paused", "completed", "shipped"]),
  started_at: z.string(),
  ended_at: z.string().nullable(),
  topic: z.string(),
  chat_id: z.string().nullable().optional(),
  exchanges: z.array(ExchangeSchema),
  questions_answered: z.array(z.string()),
  questions_remaining: z.array(z.string()),
  transcript_path: z.string().nullable().optional(),
  brief_path: z.string().nullable().optional(),
});

export type VoiceSession = z.infer<typeof SessionSchema>;
export type Exchange = z.infer<typeof ExchangeSchema>;

function ensureDir(): void {
  if (!existsSync(SESSION_DIR)) {
    mkdirSync(SESSION_DIR, { recursive: true, mode: 0o700 });
  }
}

function sessionPath(id: string): string {
  return join(SESSION_DIR, `${id}.json`);
}

function generateId(): string {
  const now = new Date();
  const date = now.toISOString().slice(0, 10).replace(/-/g, "");
  const time = now.toTimeString().slice(0, 8).replace(/:/g, "");
  return `vs-${date}-${time}`;
}

export function createSession(
  approach: "telegram" | "web",
  topic: string,
  chatId?: string
): VoiceSession {
  ensureDir();
  const session: VoiceSession = {
    id: generateId(),
    approach,
    status: "active",
    started_at: new Date().toISOString(),
    ended_at: null,
    topic,
    chat_id: chatId ?? null,
    exchanges: [],
    questions_answered: [],
    questions_remaining: ["what", "who", "constraints", "scope", "why_now"],
  };
  writeFileSync(sessionPath(session.id), JSON.stringify(session, null, 2), { mode: 0o600 });
  return session;
}

export function getSession(id: string): VoiceSession | null {
  const path = sessionPath(id);
  if (!existsSync(path)) return null;
  const data = JSON.parse(readFileSync(path, "utf-8"));
  return SessionSchema.parse(data);
}

export function addExchange(
  id: string,
  role: "user" | "assistant",
  text: string,
  audioPath?: string
): VoiceSession {
  const session = getSession(id);
  if (!session) throw new Error(`Session not found: ${id}`);
  if (session.status !== "active") throw new Error(`Session is ${session.status}, not active`);

  const exchange: Exchange = {
    turn: session.exchanges.length + 1,
    role,
    text,
    audio_path: audioPath ?? null,
    timestamp: new Date().toISOString(),
  };

  session.exchanges.push(exchange);
  writeFileSync(sessionPath(id), JSON.stringify(session, null, 2), { mode: 0o600 });
  return session;
}

export function endSession(id: string): VoiceSession {
  const session = getSession(id);
  if (!session) throw new Error(`Session not found: ${id}`);

  session.status = "completed";
  session.ended_at = new Date().toISOString();
  writeFileSync(sessionPath(id), JSON.stringify(session, null, 2), { mode: 0o600 });
  return session;
}

export function updateSessionMeta(
  id: string,
  updates: Partial<Pick<VoiceSession, "topic" | "questions_answered" | "questions_remaining" | "transcript_path" | "brief_path" | "status">>
): VoiceSession {
  const session = getSession(id);
  if (!session) throw new Error(`Session not found: ${id}`);

  Object.assign(session, updates);
  writeFileSync(sessionPath(id), JSON.stringify(session, null, 2), { mode: 0o600 });
  return session;
}

export function listSessions(filter?: { status?: string; approach?: string }): VoiceSession[] {
  ensureDir();
  const files = readdirSync(SESSION_DIR).filter((f) => f.endsWith(".json"));
  const sessions: VoiceSession[] = [];

  for (const file of files) {
    try {
      const data = JSON.parse(readFileSync(join(SESSION_DIR, file), "utf-8"));
      const session = SessionSchema.parse(data);
      if (filter?.status && session.status !== filter.status) continue;
      if (filter?.approach && session.approach !== filter.approach) continue;
      sessions.push(session);
    } catch {
      // skip malformed session files
    }
  }

  return sessions.sort((a, b) => b.started_at.localeCompare(a.started_at));
}

export function cleanupOldSessions(maxAgeHours = 24): number {
  ensureDir();
  const cutoff = Date.now() - maxAgeHours * 60 * 60 * 1000;
  const files = readdirSync(SESSION_DIR).filter((f) => f.endsWith(".json"));
  let removed = 0;

  for (const file of files) {
    try {
      const path = join(SESSION_DIR, file);
      const data = JSON.parse(readFileSync(path, "utf-8"));
      const session = SessionSchema.parse(data);
      const startedAt = new Date(session.started_at).getTime();

      if (startedAt < cutoff && session.status !== "active") {
        unlinkSync(path);
        removed++;
      }
    } catch {
      // skip
    }
  }

  return removed;
}

export function generateTranscript(session: VoiceSession): string {
  const startTime = new Date(session.started_at).getTime();

  const lines = session.exchanges.map((e) => {
    const elapsed = new Date(e.timestamp).getTime() - startTime;
    const minutes = Math.floor(elapsed / 60000);
    const seconds = Math.floor((elapsed % 60000) / 1000);
    const ts = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    const speaker = e.role === "user" ? "User" : "Claude";
    return `**[${ts}] ${speaker}:** ${e.text}`;
  });

  let duration = "unknown";
  if (session.ended_at) {
    const ms = new Date(session.ended_at).getTime() - startTime;
    duration = String(Math.round(ms / 60000));
  }

  return `# Voice Session: ${session.topic}

**Date:** ${session.started_at.slice(0, 10)}
**Duration:** ${duration} minutes
**Exchanges:** ${session.exchanges.length}
**Approach:** ${session.approach === "telegram" ? "Telegram" : "Web App"}

## Transcript

${lines.join("\n\n")}

## Key Decisions
_(To be extracted by Claude during brief generation)_

## Action Items
_(To be extracted by Claude during brief generation)_
`;
}
