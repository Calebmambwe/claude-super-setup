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

const QUESTION_LABELS: Record<string, string> = {
  what: "What",
  who: "Who",
  constraints: "Limits",
  scope: "Scope",
  why_now: "Why",
};

export function TranscriptSidebar({
  entries,
  interimText,
  questionsAnswered,
  questionsRemaining,
  className = "",
}: TranscriptSidebarProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [entries, interimText]);

  return (
    <div className={`flex h-full flex-col ${className}`}>
      {/* Header */}
      <div className="border-b border-[#1c1c1f] px-5 py-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[#fafafa]">Transcript</h2>
          <span className="text-xs text-[#3f3f46]">
            {questionsAnswered.length}/5
          </span>
        </div>

        {/* Progress bar with labels */}
        <div className="mt-3 flex gap-1">
          {["what", "who", "constraints", "scope", "why_now"].map((q) => (
            <div key={q} className="flex-1">
              <div
                className={`h-1 rounded-full transition-all duration-500 ${
                  questionsAnswered.includes(q)
                    ? "bg-violet-500"
                    : "bg-[#1c1c1f]"
                }`}
              />
              <span className={`mt-1 block text-center text-[10px] ${
                questionsAnswered.includes(q) ? "text-violet-400" : "text-[#27272a]"
              }`}>
                {QUESTION_LABELS[q]}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Transcript entries */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-5 py-4">
        {entries.length === 0 && !interimText && (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-full bg-[#111113] border border-[#1c1c1f]">
              <svg className="h-4 w-4 text-[#3f3f46]" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
              </svg>
            </div>
            <p className="text-sm text-[#3f3f46]">Waiting for speech...</p>
            <p className="mt-1 text-xs text-[#27272a]">Tap the mic and start talking</p>
          </div>
        )}

        <div className="space-y-4">
          {entries.map((entry, i) => (
            <div
              key={i}
              className={`rounded-lg px-3.5 py-3 ${
                entry.role === "user"
                  ? "bg-[#111113] border border-[#1c1c1f]"
                  : "bg-violet-500/5 border border-violet-500/10"
              }`}
            >
              <div className="mb-1.5 flex items-center justify-between">
                <span className={`text-xs font-semibold ${
                  entry.role === "user" ? "text-[#a1a1aa]" : "text-violet-400"
                }`}>
                  {entry.role === "user" ? "You" : "Claude"}
                </span>
                <span className="text-[10px] text-[#3f3f46]">
                  {formatTime(entry.timestamp)}
                </span>
              </div>
              <p className={`text-sm leading-relaxed ${
                entry.isFinal ? "text-[#d4d4d8]" : "text-[#71717a] italic"
              }`}>
                {entry.text}
              </p>
            </div>
          ))}

          {/* Interim (live listening) */}
          {interimText && (
            <div className="rounded-lg border border-violet-500/20 bg-violet-500/5 px-3.5 py-3">
              <div className="mb-1.5 flex items-center gap-2">
                <span className="text-xs font-semibold text-violet-400/60">Hearing...</span>
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-violet-400" />
              </div>
              <p className="text-sm italic text-violet-300/70">{interimText}</p>
            </div>
          )}
        </div>
      </div>

      {/* Footer — topics remaining */}
      {questionsRemaining.length > 0 && entries.length > 0 && (
        <div className="border-t border-[#1c1c1f] px-5 py-3">
          <p className="text-[11px] text-[#3f3f46]">
            Still to cover:{" "}
            <span className="text-[#71717a]">
              {questionsRemaining.map((q) => QUESTION_LABELS[q] ?? q).join(", ")}
            </span>
          </p>
        </div>
      )}
    </div>
  );
}

function formatTime(timestamp: string): string {
  try {
    return new Date(timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  } catch {
    return "";
  }
}
