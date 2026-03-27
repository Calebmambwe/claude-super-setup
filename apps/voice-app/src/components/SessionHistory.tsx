"use client";

import { useEffect, useState } from "react";

interface SessionSummary {
  id: string;
  topic: string;
  approach: "telegram" | "web";
  status: string;
  started_at: string;
  exchanges: { turn: number }[];
}

export function SessionHistory() {
  const [sessions, setSessions] = useState<SessionSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/session?list=true")
      .then((r) => r.json())
      .then((data) => {
        setSessions(data.sessions ?? []);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center gap-2 text-sm text-zinc-500">
        <div className="h-4 w-4 animate-spin rounded-full border-2 border-zinc-700 border-t-zinc-400" />
        Loading sessions...
      </div>
    );
  }

  if (sessions.length === 0) {
    return (
      <p className="text-sm text-zinc-600">
        No past sessions yet. Start your first voice brainstorm above.
      </p>
    );
  }

  return (
    <div className="space-y-2">
      {sessions.map((s) => (
        <a
          key={s.id}
          href={`/session/${s.id}`}
          className="flex items-center justify-between rounded-lg border border-zinc-800/50 px-4 py-3 transition-colors hover:border-zinc-700 hover:bg-zinc-900/50"
        >
          <div className="min-w-0">
            <p className="truncate text-sm font-medium text-zinc-300">
              {s.topic}
            </p>
            <p className="mt-0.5 text-xs text-zinc-600">
              {new Date(s.started_at).toLocaleDateString()} · {s.exchanges.length} exchanges · {s.approach}
            </p>
          </div>
          <span
            className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${
              s.status === "shipped"
                ? "bg-emerald-500/10 text-emerald-400"
                : s.status === "completed"
                  ? "bg-blue-500/10 text-blue-400"
                  : "bg-yellow-500/10 text-yellow-400"
            }`}
          >
            {s.status}
          </span>
        </a>
      ))}
    </div>
  );
}
