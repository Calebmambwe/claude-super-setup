"use client";

import { use, useEffect, useState } from "react";
import { VoiceSession } from "@/components/VoiceSession";

interface SessionPageProps {
  params: Promise<{ id: string }>;
}

export default function SessionPage({ params }: SessionPageProps) {
  const { id } = use(params);
  const [sessionId, setSessionId] = useState(id === "new" ? "" : id);
  const [topic, setTopic] = useState("Voice Brainstorm");

  useEffect(() => {
    if (id === "new") {
      fetch("/api/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ topic: "New Brainstorm", approach: "web" }),
      })
        .then((res) => res.json())
        .then((data) => {
          if (data.session) {
            setSessionId(data.session.id);
            setTopic(data.session.topic);
            window.history.replaceState(null, "", `/session/${data.session.id}`);
          }
        })
        .catch(console.error);
    } else {
      fetch(`/api/session?id=${id}`)
        .then((res) => res.json())
        .then((data) => {
          if (data.session) {
            setTopic(data.session.topic);
          }
        })
        .catch(console.error);
    }
  }, [id]);

  return (
    <main className="h-screen bg-[#09090b]">
      <div className="flex h-16 items-center justify-between border-b border-zinc-800/50 px-6">
        <div className="flex items-center gap-3">
          <a
            href="/"
            className="text-zinc-500 transition-colors hover:text-zinc-300"
            aria-label="Back to home"
          >
            <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </a>
          <h1 className="text-sm font-medium text-zinc-300">{topic}</h1>
          <span className="rounded bg-zinc-800 px-2 py-0.5 font-mono text-xs text-zinc-500">
            {sessionId || "creating..."}
          </span>
        </div>
        <div className="flex items-center gap-2 text-xs text-zinc-600">
          <span className="h-2 w-2 rounded-full bg-emerald-500" />
          Connected
        </div>
      </div>

      {sessionId ? (
        <VoiceSession sessionId={sessionId} topic={topic} />
      ) : (
        <div className="flex h-[calc(100vh-4rem)] items-center justify-center">
          <div className="flex items-center gap-3 text-zinc-500">
            <svg className="h-5 w-5 animate-spin" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Creating session...
          </div>
        </div>
      )}
    </main>
  );
}
