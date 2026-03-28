"use client";

import { use, useEffect, useState, useRef, useCallback } from "react";

type Mode = "general" | "research" | "sdlc";

interface Message {
  role: "user" | "assistant";
  content: string;
  timestamp: string;
}

const MODE_CONFIG: Record<Mode, { label: string; color: string; description: string }> = {
  general: { label: "General", color: "#8b5cf6", description: "Open conversation with Claude" },
  research: { label: "Research", color: "#3b82f6", description: "Deep research & analysis" },
  sdlc: { label: "SDLC", color: "#10b981", description: "Brainstorm → Brief → Auto-dev" },
};

export default function SessionPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [sessionId, setSessionId] = useState(id === "new" ? "" : id);
  const [mode, setMode] = useState<Mode>("general");
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [interimSpeech, setInterimSpeech] = useState("");
  const [voiceEnabled, setVoiceEnabled] = useState(true);
  const [questionsAnswered, setQuestionsAnswered] = useState<string[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const finalTextRef = useRef("");

  // Create session on mount
  useEffect(() => {
    if (id === "new") {
      fetch("/api/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ topic: "New Session", approach: "web" }),
      })
        .then((r) => r.json())
        .then((data) => {
          if (data.session) {
            setSessionId(data.session.id);
            window.history.replaceState(null, "", `/session/${data.session.id}`);
          }
        })
        .catch(console.error);
    }
  }, [id]);

  // Auto-scroll
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isLoading]);

  // Speak Claude's response using browser TTS
  const speak = useCallback((text: string) => {
    if (!voiceEnabled || typeof window === "undefined") return;
    window.speechSynthesis?.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.05;
    utterance.pitch = 1;
    utterance.volume = 1;
    // Try to use a natural voice
    const voices = window.speechSynthesis?.getVoices() ?? [];
    const preferred = voices.find((v) => v.name.includes("Samantha") || v.name.includes("Google") || v.name.includes("Daniel"));
    if (preferred) utterance.voice = preferred;
    window.speechSynthesis?.speak(utterance);
  }, [voiceEnabled]);

  // Send message to Claude
  const sendMessage = useCallback(async (text: string) => {
    if (!text.trim() || isLoading) return;

    const userMsg: Message = { role: "user", content: text.trim(), timestamp: new Date().toISOString() };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setIsLoading(true);

    // Detect SDLC questions answered
    if (mode === "sdlc") {
      const lower = text.toLowerCase();
      const detected: string[] = [];
      if (lower.length > 10) detected.push("what");
      if (/\b(for|user|people|developer|me)\b/.test(lower)) detected.push("who");
      if (/\b(constraint|budget|time|days?|week|solo|tech)\b/.test(lower)) detected.push("constraints");
      if (/\b(not|skip|v2|out of scope|won't|exclude)\b/.test(lower)) detected.push("scope");
      if (/\b(because|need|problem|frustrat|trigger)\b/.test(lower)) detected.push("why_now");
      setQuestionsAnswered((prev) => [...new Set([...prev, ...detected])]);
    }

    // Save to session API
    if (sessionId) {
      fetch("/api/session", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "add-exchange", sessionId, role: "user", text: text.trim() }),
      }).catch(() => {});
    }

    try {
      const allMsgs = [...messages, userMsg].map((m) => ({ role: m.role, content: m.content }));
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: allMsgs, mode, questionsAnswered }),
      });
      const data = await res.json();
      const reply = data.response ?? "I hear you! Tell me more.";

      const assistantMsg: Message = { role: "assistant", content: reply, timestamp: new Date().toISOString() };
      setMessages((prev) => [...prev, assistantMsg]);
      speak(reply);

      // Save assistant response
      if (sessionId) {
        fetch("/api/session", {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ action: "add-exchange", sessionId, role: "assistant", text: reply }),
        }).catch(() => {});
      }
    } catch {
      const fallback = "Sorry, I couldn't connect. Try again or check your API key.";
      setMessages((prev) => [...prev, { role: "assistant", content: fallback, timestamp: new Date().toISOString() }]);
    } finally {
      setIsLoading(false);
      inputRef.current?.focus();
    }
  }, [isLoading, messages, mode, questionsAnswered, sessionId, speak]);

  // Voice input
  const toggleListening = useCallback(() => {
    if (isListening) {
      recognitionRef.current?.stop();
      recognitionRef.current = null;
      setIsListening(false);
      // Process remaining text
      const text = finalTextRef.current.trim();
      if (text) {
        finalTextRef.current = "";
        setInterimSpeech("");
        sendMessage(text);
      }
      return;
    }

    const SpeechRecognitionAPI = window.SpeechRecognition ?? window.webkitSpeechRecognition;
    if (!SpeechRecognitionAPI) {
      alert("Speech recognition not supported. Use Chrome or Edge.");
      return;
    }

    const recognition = new SpeechRecognitionAPI();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = "en-US";
    recognitionRef.current = recognition;

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      let interim = "";
      let final = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (event.results[i].isFinal) {
          final += event.results[i][0].transcript;
        } else {
          interim += event.results[i][0].transcript;
        }
      }
      if (final) {
        finalTextRef.current += " " + final;
        setInterimSpeech(finalTextRef.current.trim());
        // Reset silence timer — send after 2s pause
        if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
        silenceTimerRef.current = setTimeout(() => {
          const text = finalTextRef.current.trim();
          if (text) {
            finalTextRef.current = "";
            setInterimSpeech("");
            setIsListening(false);
            recognitionRef.current?.stop();
            recognitionRef.current = null;
            sendMessage(text);
          }
        }, 2000);
      } else if (interim) {
        setInterimSpeech((finalTextRef.current + " " + interim).trim());
      }
    };

    recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      if (event.error !== "no-speech" && event.error !== "aborted") {
        console.error("Speech error:", event.error);
      }
    };

    recognition.onend = () => {
      if (isListening && recognitionRef.current) {
        try { recognition.start(); } catch { /* */ }
      }
    };

    recognition.start();
    setIsListening(true);
    finalTextRef.current = "";
    setInterimSpeech("");
  }, [isListening, sendMessage]);

  // Ship it (SDLC mode)
  const shipIt = useCallback(async () => {
    if (!sessionId) return;
    setIsLoading(true);
    try {
      await fetch("/api/session", { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "end", sessionId }) });
      const res = await fetch("/api/sdlc", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ sessionId, featureName: "voice-feature" }) });
      const data = await res.json();
      setMessages((prev) => [...prev, { role: "assistant", content: `Brief generated! ${data.nextStep ?? "Run /auto-dev to build it."}`, timestamp: new Date().toISOString() }]);
    } catch {
      setMessages((prev) => [...prev, { role: "assistant", content: "Session saved. Run /auto-dev to continue.", timestamp: new Date().toISOString() }]);
    } finally {
      setIsLoading(false);
    }
  }, [sessionId]);

  const modeColor = MODE_CONFIG[mode].color;

  return (
    <main className="flex h-screen flex-col bg-[#09090b]">
      {/* Top bar */}
      <nav className="flex h-12 shrink-0 items-center justify-between border-b border-[#1c1c1f] px-4">
        <div className="flex items-center gap-3">
          <a href="/" className="flex h-7 w-7 items-center justify-center rounded-md border border-[#1c1c1f] text-[#71717a] hover:text-[#fafafa]">
            <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
          </a>
          <div className="h-2 w-2 rounded-full" style={{ background: modeColor }} />
          <span className="text-sm font-medium text-[#fafafa]">{MODE_CONFIG[mode].label} Mode</span>
          {sessionId && <span className="hidden font-mono text-[10px] text-[#27272a] sm:block">{sessionId}</span>}
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setVoiceEnabled(!voiceEnabled)}
            className={`rounded-md border px-2 py-1 text-[10px] transition-colors ${voiceEnabled ? "border-violet-500/30 bg-violet-500/10 text-violet-400" : "border-[#1c1c1f] text-[#3f3f46]"}`}
            title={voiceEnabled ? "Voice responses ON" : "Voice responses OFF"}
          >
            {voiceEnabled ? "Voice ON" : "Voice OFF"}
          </button>
          <div className="h-2 w-2 rounded-full bg-emerald-500" />
        </div>
      </nav>

      {/* Mode selector */}
      <div className="flex shrink-0 gap-1 border-b border-[#1c1c1f] px-4 py-2">
        {(Object.keys(MODE_CONFIG) as Mode[]).map((m) => (
          <button
            key={m}
            onClick={() => setMode(m)}
            className={`rounded-md px-3 py-1.5 text-xs font-medium transition-all ${
              mode === m
                ? "text-white shadow-sm"
                : "text-[#71717a] hover:text-[#a1a1aa] hover:bg-[#111113]"
            }`}
            style={mode === m ? { background: MODE_CONFIG[m].color } : undefined}
          >
            {MODE_CONFIG[m].label}
          </button>
        ))}
        <span className="ml-auto self-center text-[11px] text-[#3f3f46]">{MODE_CONFIG[mode].description}</span>
      </div>

      {/* SDLC progress (only in SDLC mode) */}
      {mode === "sdlc" && (
        <div className="flex shrink-0 items-center gap-2 border-b border-[#1c1c1f] px-4 py-2">
          {["what", "who", "constraints", "scope", "why_now"].map((q) => (
            <div key={q} className="flex-1">
              <div className={`h-1 rounded-full transition-all duration-500 ${questionsAnswered.includes(q) ? "bg-emerald-500" : "bg-[#1c1c1f]"}`} />
              <span className={`mt-0.5 block text-center text-[9px] ${questionsAnswered.includes(q) ? "text-emerald-400" : "text-[#27272a]"}`}>
                {q.replace("_", " ")}
              </span>
            </div>
          ))}
          {questionsAnswered.length >= 3 && (
            <button onClick={shipIt} className="ml-2 shrink-0 rounded-md px-3 py-1 text-xs font-medium text-white" style={{ background: "linear-gradient(135deg, #059669, #10b981)" }}>
              Ship It
            </button>
          )}
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4">
        {messages.length === 0 && (
          <div className="flex h-full flex-col items-center justify-center text-center">
            <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl" style={{ background: `${modeColor}15`, border: `1px solid ${modeColor}30` }}>
              <svg className="h-6 w-6" style={{ color: modeColor }} fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-[#fafafa]">
              {mode === "general" ? "Chat with Claude" : mode === "research" ? "Research Assistant" : "Brainstorm to Brief"}
            </h2>
            <p className="mt-1 max-w-xs text-sm text-[#71717a]">
              {mode === "general" ? "Type or speak — have a natural conversation about anything." :
               mode === "research" ? "Ask questions and Claude will research, analyze, and explain." :
               "Describe your feature idea. After 3-5 exchanges, hit Ship It to generate a brief and trigger auto-dev."}
            </p>
          </div>
        )}

        <div className="mx-auto max-w-2xl space-y-3">
          {messages.map((msg, i) => (
            <div key={i} className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
              <div
                className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed ${
                  msg.role === "user"
                    ? "bg-violet-600 text-white rounded-br-md"
                    : "bg-[#111113] border border-[#1c1c1f] text-[#d4d4d8] rounded-bl-md"
                }`}
              >
                {msg.content}
                {msg.role === "assistant" && voiceEnabled && (
                  <button
                    onClick={() => speak(msg.content)}
                    className="ml-2 inline-block align-middle text-[#3f3f46] hover:text-violet-400"
                    title="Replay voice"
                  >
                    <svg className="h-3.5 w-3.5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" /></svg>
                  </button>
                )}
              </div>
            </div>
          ))}

          {/* Loading indicator */}
          {isLoading && (
            <div className="flex justify-start">
              <div className="rounded-2xl rounded-bl-md bg-[#111113] border border-[#1c1c1f] px-4 py-3">
                <div className="flex gap-1">
                  <span className="h-2 w-2 animate-bounce rounded-full bg-[#3f3f46]" style={{ animationDelay: "0ms" }} />
                  <span className="h-2 w-2 animate-bounce rounded-full bg-[#3f3f46]" style={{ animationDelay: "150ms" }} />
                  <span className="h-2 w-2 animate-bounce rounded-full bg-[#3f3f46]" style={{ animationDelay: "300ms" }} />
                </div>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Interim speech display */}
      {interimSpeech && (
        <div className="shrink-0 border-t border-violet-500/20 bg-violet-500/5 px-4 py-2">
          <div className="mx-auto flex max-w-2xl items-center gap-2">
            <span className="h-2 w-2 animate-pulse rounded-full bg-violet-500" />
            <span className="text-sm text-violet-300">{interimSpeech}</span>
            <span className="ml-auto text-[10px] text-violet-500">listening... pausing sends</span>
          </div>
        </div>
      )}

      {/* Input area */}
      <div className="shrink-0 border-t border-[#1c1c1f] bg-[#0a0a0c] px-4 py-3">
        <form
          onSubmit={(e) => { e.preventDefault(); sendMessage(input); }}
          className="mx-auto flex max-w-2xl gap-2"
        >
          {/* Mic button */}
          <button
            type="button"
            onClick={toggleListening}
            className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border transition-all ${
              isListening
                ? "animate-pulse border-red-500/50 bg-red-500/10 text-red-400"
                : "border-[#1c1c1f] bg-[#111113] text-[#71717a] hover:text-violet-400 hover:border-violet-500/30"
            }`}
            title={isListening ? "Stop listening" : "Start voice input"}
          >
            <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z" />
              <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z" />
            </svg>
          </button>

          {/* Text input */}
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={isListening ? "Listening... or type here" : "Type your message..."}
            disabled={isLoading}
            className="flex-1 rounded-xl border border-[#1c1c1f] bg-[#111113] px-4 py-2.5 text-sm text-[#fafafa] placeholder-[#3f3f46] outline-none transition-colors focus:border-violet-500/50 disabled:opacity-50"
          />

          {/* Send */}
          <button
            type="submit"
            disabled={!input.trim() || isLoading}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-white transition-all disabled:opacity-20"
            style={{ background: input.trim() ? modeColor : "#1c1c1f" }}
          >
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5" /></svg>
          </button>
        </form>
      </div>
    </main>
  );
}
