/**
 * Voice Session API Routes
 *
 * POST /api/session — Create a new session
 * GET /api/session?id=xxx — Get a session
 * GET /api/session?list=true — List all sessions
 */

import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import {
  createSession,
  getSession,
  listSessions,
  endSession,
  addExchange,
} from "@/lib/session-store";

const CreateSessionSchema = z.object({
  topic: z.string().min(1).max(200),
  approach: z.enum(["telegram", "web"]).default("web"),
  chatId: z.string().optional(),
});

const AddExchangeSchema = z.object({
  sessionId: z.string().regex(/^vs-\d{8}-\d{6}$/),
  role: z.enum(["user", "assistant"]),
  text: z.string().min(1),
  audioPath: z.string().optional(),
});

export async function GET(request: NextRequest): Promise<NextResponse> {
  const searchParams = request.nextUrl.searchParams;
  const id = searchParams.get("id");
  const list = searchParams.get("list");

  if (list === "true") {
    const status = searchParams.get("status") ?? undefined;
    const approach = searchParams.get("approach") ?? undefined;
    const sessions = listSessions({ status, approach });
    return NextResponse.json({ sessions });
  }

  if (id) {
    const session = getSession(id);
    if (!session) {
      return NextResponse.json({ error: "Session not found" }, { status: 404 });
    }
    return NextResponse.json({ session });
  }

  return NextResponse.json({ error: "Provide ?id=xxx or ?list=true" }, { status: 400 });
}

export async function POST(request: NextRequest): Promise<NextResponse> {
  try {
    const body = await request.json();
    const { topic, approach, chatId } = CreateSessionSchema.parse(body);
    const session = createSession(approach, topic, chatId);
    return NextResponse.json({ session }, { status: 201 });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return NextResponse.json({ error: "Validation failed", details: err.errors }, { status: 400 });
    }
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}

export async function PUT(request: NextRequest): Promise<NextResponse> {
  try {
    const body = await request.json();
    const action = body.action as string;

    if (action === "add-exchange") {
      const { sessionId, role, text, audioPath } = AddExchangeSchema.parse(body);
      const session = addExchange(sessionId, role, text, audioPath);
      return NextResponse.json({ session });
    }

    if (action === "end") {
      const id = z.string().regex(/^vs-\d{8}-\d{6}$/).parse(body.sessionId);
      const session = endSession(id);
      return NextResponse.json({ session });
    }

    return NextResponse.json({ error: "Unknown action" }, { status: 400 });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return NextResponse.json({ error: "Validation failed", details: err.errors }, { status: 400 });
    }
    const message = err instanceof Error ? err.message : "Internal server error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
