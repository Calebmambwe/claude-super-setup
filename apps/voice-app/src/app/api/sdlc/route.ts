/**
 * SDLC Pipeline Trigger API
 *
 * POST /api/sdlc — Trigger voice-to-SDLC pipeline for a completed session
 */

import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { exec } from "child_process";
import { promisify } from "util";
import { getSession, updateSessionMeta, generateTranscript } from "@/lib/session-store";
import { writeFileSync, mkdirSync, existsSync } from "fs";
import { join } from "path";

const execAsync = promisify(exec);

const TriggerSchema = z.object({
  sessionId: z.string().regex(/^vs-\d{8}-\d{6}$/),
  featureName: z.string().min(1).max(100).optional(),
  autoTrigger: z.boolean().default(false),
});

export async function POST(request: NextRequest): Promise<NextResponse> {
  try {
    const body = await request.json();
    const { sessionId, featureName, autoTrigger } = TriggerSchema.parse(body);

    const session = getSession(sessionId);
    if (!session) {
      return NextResponse.json({ error: "Session not found" }, { status: 404 });
    }

    if (session.status === "active") {
      return NextResponse.json(
        { error: "Session is still active. End it first." },
        { status: 400 }
      );
    }

    // Generate transcript markdown
    const transcript = generateTranscript(session);
    const name = featureName ?? session.topic.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");

    // Save transcript
    const projectDir = process.env.PROJECT_DIR ?? process.cwd();
    const transcriptDir = join(projectDir, "docs", "voice-sessions");
    if (!existsSync(transcriptDir)) {
      mkdirSync(transcriptDir, { recursive: true });
    }
    const date = session.started_at.slice(0, 10);
    const transcriptPath = join(transcriptDir, `${date}-${name}.md`);
    writeFileSync(transcriptPath, transcript);

    // Update session with transcript path
    updateSessionMeta(sessionId, {
      transcript_path: transcriptPath,
      status: "shipped",
    });

    // If auto-trigger, call voice-to-sdlc.sh
    if (autoTrigger) {
      const scriptPath = join(projectDir, "scripts", "voice-to-sdlc.sh");
      try {
        const { stdout } = await execAsync(
          `bash ${scriptPath} ${sessionId} --feature-name ${name} --auto`,
          { timeout: 30000 }
        );
        return NextResponse.json({
          status: "triggered",
          sessionId,
          featureName: name,
          transcriptPath,
          output: stdout,
        });
      } catch (err) {
        const message = err instanceof Error ? err.message : "Script execution failed";
        return NextResponse.json({
          status: "transcript_saved",
          warning: `SDLC trigger failed: ${message}`,
          sessionId,
          featureName: name,
          transcriptPath,
        });
      }
    }

    return NextResponse.json({
      status: "transcript_saved",
      sessionId,
      featureName: name,
      transcriptPath,
      nextStep: `Run: /auto-dev ${name}`,
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return NextResponse.json({ error: "Validation failed", details: err.errors }, { status: 400 });
    }
    const message = err instanceof Error ? err.message : "Internal server error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
