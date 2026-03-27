"use client";

import { useEffect, useRef } from "react";

interface TranscriptEntry {
  role: "user" | "assistant";
  text: string;
  timestamp: string;
  isFinal: boolean;
}

interface TranscriptSidebarProps {
  entries: TranscriptEntry[];
  interimText?: string;
  questionsAnswered: string[];
  questionsRemaining: string[];
  className?: string;
}

export function TranscriptSidebar({
  entries,
  interimText,
  questionsAnswered,
  questionsRemaining,
  className = "",
}: TranscriptSidebarProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [entries, interimText]);

  return (
    <div className={`flex h-full flex-col ${className}`}>
      {/* Header */}
      <div className="border-b border-zinc-800 px-4 py-3">
        <h2 className="text-sm font-semibold text-zinc-300">Transcript</h2>
        {/* Progress dots */}
        <div className="mt-2 flex gap-1.5">
          {["what", "who", "constraints", "scope", "why_now"].map((q) => (
            <div
              key={q}
              className={`h-1.5 flex-1 rounded-full transition-colors ${
                questionsAnswered.includes(q) ? "bg-emerald-500" : "bg-zinc-700"
              }`}
              title={q}
            />
          ))}
        </div>
        <p className="mt-1 text-xs text-zinc-500">
          {questionsAnswered.length}/5 topics covered
        </p>
      </div>

      {/* Transcript entries */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
        {entries.length === 0 && !interimText && (
          <p className="text-sm text-zinc-600 italic">
            Start speaking to begin the brainstorm...
          </p>
        )}

        {entries.map((entry, i) => (
          <div key={i} className="space-y-1">
            <div className="flex items-center gap-2">
              <span
                className={`text-xs font-medium ${
                  entry.role === "user" ? "text-blue-400" : "text-emerald-400"
                }`}
              >
                {entry.role === "user" ? "You" : "Claude"}
              </span>
              <span className="text-xs text-zinc-600">
                {formatTime(entry.timestamp)}
              </span>
            </div>
            <p className={`text-sm leading-relaxed ${
              entry.isFinal ? "text-zinc-300" : "text-zinc-500 italic"
            }`}>
              {entry.text}
            </p>
          </div>
        ))}

        {/* Interim (partial) transcription */}
        {interimText && (
          <div className="space-y-1">
            <span className="text-xs font-medium text-blue-400/60">You (listening...)</span>
            <p className="text-sm text-zinc-500 italic">{interimText}</p>
          </div>
        )}
      </div>

      {/* Questions remaining */}
      {questionsRemaining.length > 0 && (
        <div className="border-t border-zinc-800 px-4 py-3">
          <p className="text-xs text-zinc-500">
            Still to cover:{" "}
            {questionsRemaining.map((q) => q.replace("_", " ")).join(", ")}
          </p>
        </div>
      )}
    </div>
  );
}

function formatTime(timestamp: string): string {
  try {
    const d = new Date(timestamp);
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  } catch {
    return "";
  }
}
