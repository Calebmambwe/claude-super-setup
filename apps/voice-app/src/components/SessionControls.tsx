"use client";

interface SessionControlsProps {
  isRecording: boolean;
  isPaused: boolean;
  sessionActive: boolean;
  onStart: () => void;
  onPause: () => void;
  onResume: () => void;
  onStop: () => void;
  onShip: () => void;
  duration: number; // seconds
  exchangeCount: number;
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

export function SessionControls({
  isRecording,
  isPaused,
  sessionActive,
  onStart,
  onPause,
  onResume,
  onStop,
  onShip,
  duration,
  exchangeCount,
}: SessionControlsProps) {
  if (!sessionActive) {
    return (
      <div className="flex flex-col items-center gap-4">
        <button
          onClick={onStart}
          className="group relative flex h-20 w-20 items-center justify-center rounded-full bg-gradient-to-b from-blue-500 to-blue-600 text-white shadow-lg shadow-blue-500/25 transition-all hover:scale-105 hover:shadow-blue-500/40 active:scale-95"
          aria-label="Start voice session"
        >
          <svg className="h-8 w-8" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z" />
            <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z" />
          </svg>
        </button>
        <span className="text-sm text-zinc-500">Tap to start brainstorming</span>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-4">
      {/* Status indicators */}
      <div className="flex items-center gap-4 text-sm text-zinc-400">
        <span className="flex items-center gap-1.5">
          {isRecording && !isPaused ? (
            <span className="h-2 w-2 animate-pulse rounded-full bg-red-500" />
          ) : (
            <span className="h-2 w-2 rounded-full bg-zinc-600" />
          )}
          {isRecording && !isPaused ? "Listening" : isPaused ? "Paused" : "Processing"}
        </span>
        <span className="font-mono">{formatDuration(duration)}</span>
        <span>{exchangeCount} exchanges</span>
      </div>

      {/* Control buttons */}
      <div className="flex items-center gap-3">
        {/* Pause / Resume */}
        {isRecording && !isPaused ? (
          <button
            onClick={onPause}
            className="flex h-12 w-12 items-center justify-center rounded-full bg-zinc-800 text-zinc-300 transition-colors hover:bg-zinc-700"
            aria-label="Pause"
          >
            <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
            </svg>
          </button>
        ) : isPaused ? (
          <button
            onClick={onResume}
            className="flex h-12 w-12 items-center justify-center rounded-full bg-zinc-800 text-zinc-300 transition-colors hover:bg-zinc-700"
            aria-label="Resume"
          >
            <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
        ) : null}

        {/* Stop */}
        <button
          onClick={onStop}
          className="flex h-12 w-12 items-center justify-center rounded-full bg-zinc-800 text-red-400 transition-colors hover:bg-red-950"
          aria-label="Stop session"
        >
          <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M6 6h12v12H6z" />
          </svg>
        </button>

        {/* Ship It */}
        <button
          onClick={onShip}
          className="flex h-12 items-center gap-2 rounded-full bg-gradient-to-r from-emerald-600 to-emerald-500 px-5 text-sm font-medium text-white shadow-lg shadow-emerald-500/20 transition-all hover:scale-105 hover:shadow-emerald-500/30 active:scale-95"
          aria-label="End session and build"
        >
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
          </svg>
          End &amp; Build
        </button>
      </div>
    </div>
  );
}
