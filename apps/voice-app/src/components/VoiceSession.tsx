"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { AudioVisualizer } from "./AudioVisualizer";
import { SessionControls } from "./SessionControls";
import { TranscriptSidebar } from "./TranscriptSidebar";

interface TranscriptEntry {
  role: "user" | "assistant";
  text: string;
  timestamp: string;
  isFinal: boolean;
}

interface VoiceSessionProps {
  sessionId: string;
  topic: string;
}

export function VoiceSession({ sessionId, topic }: VoiceSessionProps) {
  const [isRecording, setIsRecording] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [sessionActive, setSessionActive] = useState(false);
  const [entries, setEntries] = useState<TranscriptEntry[]>([]);
  const [interimText, setInterimText] = useState("");
  const [questionsAnswered, setQuestionsAnswered] = useState<string[]>([]);
  const [questionsRemaining, setQuestionsRemaining] = useState<string[]>([
    "what", "who", "constraints", "scope", "why_now",
  ]);
  const [duration, setDuration] = useState(0);
  const [isShipping, setIsShipping] = useState(false);

  const mediaStreamRef = useRef<MediaStream | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Duration timer
  useEffect(() => {
    if (sessionActive && !isPaused) {
      timerRef.current = setInterval(() => {
        setDuration((d) => d + 1);
      }, 1000);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [sessionActive, isPaused]);

  const startSession = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;
      setSessionActive(true);
      setIsRecording(true);
      setDuration(0);

      // TODO: Connect to LiveKit/Pipecat voice pipeline
      // For now, show the UI and handle mic access
    } catch (err) {
      console.error("Microphone access denied:", err);
    }
  }, []);

  const pauseSession = useCallback(() => {
    setIsPaused(true);
    setIsRecording(false);
    mediaStreamRef.current?.getTracks().forEach((t) => (t.enabled = false));
  }, []);

  const resumeSession = useCallback(() => {
    setIsPaused(false);
    setIsRecording(true);
    mediaStreamRef.current?.getTracks().forEach((t) => (t.enabled = true));
  }, []);

  const stopSession = useCallback(() => {
    setSessionActive(false);
    setIsRecording(false);
    setIsPaused(false);
    mediaStreamRef.current?.getTracks().forEach((t) => t.stop());
    mediaStreamRef.current = null;
    if (timerRef.current) clearInterval(timerRef.current);
  }, []);

  const shipIt = useCallback(async () => {
    setIsShipping(true);
    stopSession();

    try {
      // End session via API
      await fetch("/api/session", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "end", sessionId }),
      });

      // Trigger SDLC pipeline
      const res = await fetch("/api/sdlc", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionId, featureName: topic }),
      });

      const data = await res.json();
      // TODO: Show success modal with brief path and next steps
      console.log("SDLC triggered:", data);
    } catch (err) {
      console.error("Ship failed:", err);
    } finally {
      setIsShipping(false);
    }
  }, [sessionId, topic, stopSession]);

  return (
    <div className="flex h-[calc(100vh-4rem)] gap-0">
      {/* Main area */}
      <div className="flex flex-1 flex-col items-center justify-center gap-8 p-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-zinc-100">{topic || "Voice Brainstorm"}</h1>
          <p className="mt-1 text-sm text-zinc-500">
            {sessionActive ? "Speak naturally — Claude is listening" : "Ready to brainstorm"}
          </p>
        </div>

        <AudioVisualizer
          stream={mediaStreamRef.current}
          isActive={isRecording && !isPaused}
          className="w-full max-w-md"
        />

        <SessionControls
          isRecording={isRecording}
          isPaused={isPaused}
          sessionActive={sessionActive}
          onStart={startSession}
          onPause={pauseSession}
          onResume={resumeSession}
          onStop={stopSession}
          onShip={shipIt}
          duration={duration}
          exchangeCount={entries.filter((e) => e.isFinal).length}
        />

        {isShipping && (
          <div className="flex items-center gap-2 text-sm text-emerald-400">
            <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Generating brief and triggering SDLC pipeline...
          </div>
        )}
      </div>

      {/* Transcript sidebar */}
      <div className="w-80 border-l border-zinc-800 bg-zinc-950 lg:w-96">
        <TranscriptSidebar
          entries={entries}
          interimText={interimText}
          questionsAnswered={questionsAnswered}
          questionsRemaining={questionsRemaining}
        />
      </div>
    </div>
  );
}
