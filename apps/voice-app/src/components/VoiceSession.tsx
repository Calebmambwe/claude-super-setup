"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { AudioVisualizer } from "./AudioVisualizer";
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

type SessionStatus = "idle" | "listening" | "processing" | "paused" | "shipped" | "error";

export function VoiceSession({ sessionId, topic }: VoiceSessionProps) {
  const [status, setStatus] = useState<SessionStatus>("idle");
  const [entries, setEntries] = useState<TranscriptEntry[]>([]);
  const [interimText, setInterimText] = useState("");
  const [questionsAnswered, setQuestionsAnswered] = useState<string[]>([]);
  const [questionsRemaining, setQuestionsRemaining] = useState<string[]>(["what", "who", "constraints", "scope", "why_now"]);
  const [duration, setDuration] = useState(0);
  const [isShipping, setIsShipping] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");
  const [statusText, setStatusText] = useState("Tap the mic or type below to start brainstorming");
  const [textInput, setTextInput] = useState("");
  const [speechSupported, setSpeechSupported] = useState(true);

  const mediaStreamRef = useRef<MediaStream | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const finalTranscriptRef = useRef("");

  const isActive = status === "listening" || status === "processing";

  // Duration timer
  useEffect(() => {
    if (isActive) {
      timerRef.current = setInterval(() => setDuration((d) => d + 1), 1000);
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [isActive]);

  // Detect answered questions
  const detectQuestions = useCallback((text: string) => {
    const lower = text.toLowerCase();
    const detected: string[] = [];
    if (lower.length > 15) detected.push("what");
    if (/\b(for|user|people|developer|team|me|myself|everyone)\b/.test(lower)) detected.push("who");
    if (/\b(constraint|budget|time|days?|weeks?|limit|solo|tech|stack)\b/.test(lower)) detected.push("constraints");
    if (/\b(not|skip|later|exclude|v2|out of scope|won't|without)\b/.test(lower)) detected.push("scope");
    if (/\b(because|noticed|trend|need|problem|frustrat|trigger)\b/.test(lower)) detected.push("why_now");
    setQuestionsAnswered((prev) => {
      const next = [...new Set([...prev, ...detected])];
      setQuestionsRemaining(["what", "who", "constraints", "scope", "why_now"].filter((q) => !next.includes(q)));
      return next;
    });
  }, []);

  // Send user message and get Claude response
  const sendMessage = useCallback(async (userText: string) => {
    if (!userText.trim()) return;

    // Check ship-it triggers
    const lower = userText.toLowerCase();
    if (["ship it", "build this", "build it", "done", "that's enough", "generate the brief"].some((t) => lower.includes(t))) {
      // Add user entry first
      setEntries((prev) => [...prev, { role: "user", text: userText, timestamp: new Date().toISOString(), isFinal: true }]);
      shipIt();
      return;
    }

    // Add user entry
    setEntries((prev) => [...prev, { role: "user", text: userText, timestamp: new Date().toISOString(), isFinal: true }]);
    detectQuestions(userText);

    setStatus("processing");
    setStatusText("Claude is thinking...");

    // Save to session
    try {
      await fetch("/api/session", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "add-exchange", sessionId, role: "user", text: userText }),
      });
    } catch { /* non-critical */ }

    // Get Claude response
    const allMessages = [
      ...entries.filter((e) => e.isFinal).map((e) => ({ role: e.role, content: e.text })),
      { role: "user" as const, content: userText },
    ];

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: allMessages, questionsAnswered, questionsRemaining }),
      });
      const data = await res.json();
      const reply = data.response ?? "Tell me more about that idea!";

      setEntries((prev) => [...prev, { role: "assistant", text: reply, timestamp: new Date().toISOString(), isFinal: true }]);

      // Save assistant response
      try {
        await fetch("/api/session", {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ action: "add-exchange", sessionId, role: "assistant", text: reply }),
        });
      } catch { /* non-critical */ }
    } catch {
      const fallbacks = [
        "Interesting! Who is the primary user for this?",
        "Got it. What are the main constraints — time, tech stack, budget?",
        "Makes sense. What's explicitly out of scope for v1?",
        "Nice. What triggered this idea?",
        "I think I have enough. Say 'ship it' when ready!",
      ];
      const idx = Math.min(entries.filter((e) => e.role === "assistant").length, fallbacks.length - 1);
      setEntries((prev) => [...prev, { role: "assistant", text: fallbacks[idx], timestamp: new Date().toISOString(), isFinal: true }]);
    }

    setStatus("listening");
    setStatusText("Listening... speak or type your next thought");
  }, [entries, sessionId, questionsAnswered, questionsRemaining, detectQuestions]);

  // Reset silence timer — processes speech after 2s of silence
  const resetSilenceTimer = useCallback(() => {
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    silenceTimerRef.current = setTimeout(() => {
      const text = finalTranscriptRef.current.trim();
      if (text.length > 2) {
        finalTranscriptRef.current = "";
        setInterimText("");
        sendMessage(text);
      }
    }, 2000);
  }, [sendMessage]);

  // Start voice session
  const startSession = useCallback(async () => {
    setErrorMsg("");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;
      setStatus("listening");
      setDuration(0);

      const SpeechRecognitionAPI = window.SpeechRecognition ?? window.webkitSpeechRecognition;
      if (!SpeechRecognitionAPI) {
        setSpeechSupported(false);
        setStatusText("Speech not supported in this browser. Use the text input below, or try Chrome.");
        return;
      }

      const recognition = new SpeechRecognitionAPI();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = "en-US";
      recognitionRef.current = recognition;

      recognition.onresult = (event: SpeechRecognitionEvent) => {
        let interim = "";
        let finalText = "";

        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalText += transcript;
          } else {
            interim += transcript;
          }
        }

        if (finalText) {
          finalTranscriptRef.current += " " + finalText;
          setInterimText(finalTranscriptRef.current.trim());
          setStatusText("Hearing you... (will process after you pause)");
          resetSilenceTimer();
        } else if (interim) {
          setInterimText((finalTranscriptRef.current + " " + interim).trim());
          setStatusText("Hearing you...");
          resetSilenceTimer();
        }
      };

      recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
        if (event.error === "no-speech") {
          setStatusText("No speech detected. Speak louder or use the text input.");
          return;
        }
        if (event.error === "aborted") return;
        console.error("Speech error:", event.error);
        setStatusText(`Speech error: ${event.error}. Try the text input instead.`);
      };

      recognition.onend = () => {
        // Auto-restart unless we're stopping
        if (recognitionRef.current && status !== "idle" && status !== "shipped" && status !== "paused") {
          try { recognition.start(); } catch { /* already started */ }
        }
      };

      recognition.start();
      setStatusText("Listening... describe your idea (or type below)");
    } catch {
      setErrorMsg("Microphone access denied. Use the text input below instead.");
      setSpeechSupported(false);
      setStatus("listening"); // Still allow text input
      setStatusText("Type your idea below to start brainstorming");
    }
  }, [resetSilenceTimer, status]);

  const pauseSession = useCallback(() => {
    recognitionRef.current?.stop();
    setStatus("paused");
    setStatusText("Paused. Resume or type to continue.");
  }, []);

  const resumeSession = useCallback(() => {
    try { recognitionRef.current?.start(); } catch { /* */ }
    setStatus("listening");
    setStatusText("Listening...");
  }, []);

  const stopSession = useCallback(() => {
    recognitionRef.current?.stop();
    recognitionRef.current = null;
    mediaStreamRef.current?.getTracks().forEach((t) => t.stop());
    mediaStreamRef.current = null;
    if (timerRef.current) clearInterval(timerRef.current);
    if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    setStatus("idle");
    setStatusText("Session ended. Start a new one anytime.");
  }, []);

  const shipIt = useCallback(async () => {
    setIsShipping(true);
    setStatus("shipped");
    setStatusText("Generating brief...");
    recognitionRef.current?.stop();
    recognitionRef.current = null;
    mediaStreamRef.current?.getTracks().forEach((t) => t.stop());
    if (timerRef.current) clearInterval(timerRef.current);

    try {
      await fetch("/api/session", { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "end", sessionId }) });
      const res = await fetch("/api/sdlc", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ sessionId, featureName: topic }) });
      const data = await res.json();
      setEntries((prev) => [...prev, { role: "assistant", text: `Brief generated! ${data.nextStep ?? "Run /auto-dev to build it."}`, timestamp: new Date().toISOString(), isFinal: true }]);
      setStatusText("Brief generated! Review and run /auto-dev.");
    } catch {
      setStatusText("Session saved. Run /auto-dev manually.");
    } finally {
      setIsShipping(false);
    }
  }, [sessionId, topic]);

  // Handle text input submit
  const handleTextSubmit = useCallback((e: React.FormEvent) => {
    e.preventDefault();
    if (!textInput.trim()) return;
    const msg = textInput.trim();
    setTextInput("");
    if (status === "idle") {
      setStatus("listening");
      setDuration(0);
    }
    sendMessage(msg);
  }, [textInput, sendMessage, status]);

  const formatDuration = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  return (
    <div className="flex h-[calc(100vh-3.5rem)]">
      {/* Main area */}
      <div className="flex flex-1 flex-col bg-[#09090b]">
        {/* Top status bar */}
        <div className="flex items-center justify-between border-b border-[#1c1c1f] px-5 py-2.5">
          <div className="flex items-center gap-3">
            {isActive && (
              <span className="flex items-center gap-1.5 rounded-full bg-red-500/10 px-2.5 py-1 text-xs text-red-400">
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-red-500" />
                {status === "listening" ? "Listening" : "Thinking"}
              </span>
            )}
            {status === "paused" && (
              <span className="rounded-full bg-amber-500/10 px-2.5 py-1 text-xs text-amber-400">Paused</span>
            )}
            {status === "shipped" && (
              <span className="rounded-full bg-emerald-500/10 px-2.5 py-1 text-xs text-emerald-400">Shipped</span>
            )}
            {status === "idle" && (
              <span className="rounded-full bg-[#111113] border border-[#1c1c1f] px-2.5 py-1 text-xs text-[#3f3f46]">Ready</span>
            )}
            {isActive && <span className="font-mono text-xs text-[#3f3f46]">{formatDuration(duration)}</span>}
          </div>
          <span className="text-xs text-[#3f3f46]">
            {entries.filter((e) => e.role === "user" && e.isFinal).length} exchanges
          </span>
        </div>

        {/* Center */}
        <div className="flex flex-1 flex-col items-center justify-center gap-5 px-6">
          <h2 className="text-xl font-semibold text-[#fafafa]">{topic}</h2>
          <p className="max-w-md text-center text-sm text-[#71717a]">{statusText}</p>

          {errorMsg && (
            <div className="max-w-md rounded-lg border border-red-500/20 bg-red-500/5 px-4 py-3 text-sm text-red-400">{errorMsg}</div>
          )}

          <AudioVisualizer stream={mediaStreamRef.current} isActive={status === "listening"} className="w-full max-w-sm" />

          {/* Live speech feedback */}
          {interimText && (
            <div className="max-w-md rounded-lg border border-violet-500/20 bg-violet-500/5 px-4 py-2.5">
              <div className="mb-1 flex items-center gap-2">
                <span className="text-[10px] font-semibold uppercase tracking-wider text-violet-500">Hearing</span>
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-violet-400" />
              </div>
              <p className="text-sm text-violet-300">{interimText}</p>
            </div>
          )}

          {/* Processing dots */}
          {status === "processing" && (
            <div className="flex items-center gap-2.5 text-sm text-[#71717a]">
              <div className="flex gap-1">
                <span className="h-2 w-2 animate-bounce rounded-full bg-violet-500" style={{ animationDelay: "0ms" }} />
                <span className="h-2 w-2 animate-bounce rounded-full bg-violet-500" style={{ animationDelay: "150ms" }} />
                <span className="h-2 w-2 animate-bounce rounded-full bg-violet-500" style={{ animationDelay: "300ms" }} />
              </div>
              Claude is thinking...
            </div>
          )}

          {isShipping && (
            <div className="flex items-center gap-2.5 text-sm text-emerald-400">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-emerald-500/30 border-t-emerald-500" />
              Generating brief...
            </div>
          )}
        </div>

        {/* Bottom controls + text input */}
        <div className="border-t border-[#1c1c1f] px-5 py-4">
          {/* Voice controls */}
          <div className="mb-3 flex items-center justify-center gap-3">
            {status === "idle" && !isShipping && (
              <button
                onClick={startSession}
                className="flex h-14 w-14 items-center justify-center rounded-full transition-all hover:scale-105 active:scale-95"
                style={{ background: "linear-gradient(135deg, #7c3aed, #5b21b6)", boxShadow: "0 4px 20px rgba(109,40,217,0.4)" }}
                aria-label="Start voice session"
              >
                <svg className="h-6 w-6 text-white" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z" />
                  <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z" />
                </svg>
              </button>
            )}
            {(status === "listening" || status === "processing") && (
              <>
                <button onClick={pauseSession} className="flex h-10 w-10 items-center justify-center rounded-full border border-[#1c1c1f] bg-[#111113] text-[#71717a] hover:text-[#fafafa]" aria-label="Pause">
                  <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
                </button>
                <button onClick={stopSession} className="flex h-10 w-10 items-center justify-center rounded-full border border-[#1c1c1f] bg-[#111113] text-red-400 hover:border-red-500/30" aria-label="Stop">
                  <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24"><path d="M6 6h12v12H6z" /></svg>
                </button>
                <button onClick={shipIt} className="flex h-10 items-center gap-2 rounded-full px-4 text-xs font-medium text-white" style={{ background: "linear-gradient(135deg, #059669, #10b981)", boxShadow: "0 4px 15px rgba(5,150,105,0.3)" }} aria-label="Ship it">
                  <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>
                  End &amp; Build
                </button>
              </>
            )}
            {status === "paused" && (
              <>
                <button onClick={resumeSession} className="flex h-10 items-center gap-2 rounded-full border border-violet-500/30 bg-violet-500/10 px-4 text-xs text-violet-300 hover:bg-violet-500/20">
                  <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg> Resume
                </button>
                <button onClick={stopSession} className="flex h-10 items-center rounded-full border border-[#1c1c1f] bg-[#111113] px-4 text-xs text-[#71717a]">End</button>
              </>
            )}
          </div>

          {/* Text input — always available */}
          <form onSubmit={handleTextSubmit} className="flex gap-2">
            <input
              type="text"
              value={textInput}
              onChange={(e) => setTextInput(e.target.value)}
              placeholder={status === "idle" ? "Or type your idea here..." : "Type to continue the conversation..."}
              className="flex-1 rounded-lg border border-[#1c1c1f] bg-[#111113] px-4 py-2.5 text-sm text-[#fafafa] placeholder-[#3f3f46] outline-none transition-colors focus:border-violet-500/50 focus:ring-1 focus:ring-violet-500/20"
            />
            <button
              type="submit"
              disabled={!textInput.trim()}
              className="rounded-lg border border-[#1c1c1f] bg-[#111113] px-4 py-2.5 text-sm text-[#71717a] transition-colors hover:border-violet-500/30 hover:text-violet-400 disabled:opacity-30 disabled:cursor-not-allowed"
            >
              Send
            </button>
          </form>
        </div>
      </div>

      {/* Transcript sidebar */}
      <div className="hidden w-80 border-l border-[#1c1c1f] bg-[#0a0a0c] md:block lg:w-96">
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
