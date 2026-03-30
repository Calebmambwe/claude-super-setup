import { useState, useEffect, useRef, useCallback } from "react";
import { useVoiceRecognition } from "./hooks/useVoiceRecognition";
import { useTextToSpeech } from "./hooks/useTextToSpeech";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  timestamp: string;
}

type ConnectionStatus = "connecting" | "connected" | "disconnected";

export function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const [status, setStatus] = useState<ConnectionStatus>("connecting");
  const [sessionId, setSessionId] = useState("");
  const [exchangeCount, setExchangeCount] = useState(0);
  const wsRef = useRef<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const voice = useVoiceRecognition();
  const tts = useTextToSpeech();

  // WebSocket connection
  useEffect(() => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const ws = new WebSocket(`${protocol}//${window.location.host}/ws`);

    ws.onopen = () => setStatus("connected");
    ws.onclose = () => setStatus("disconnected");
    ws.onerror = () => setStatus("disconnected");

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      if (data.type === "session") {
        setSessionId(data.sessionId);
      }

      if (data.type === "thinking") {
        setIsThinking(true);
      }

      if (data.type === "response") {
        setIsThinking(false);
        setExchangeCount(data.exchangeCount);
        const msg: ChatMessage = {
          role: "assistant",
          content: data.text,
          timestamp: new Date().toISOString(),
        };
        setMessages((prev) => [...prev, msg]);
        tts.speak(data.text);
      }

      if (data.type === "exported") {
        setMessages((prev) => [
          ...prev,
          {
            role: "assistant",
            content: `Session exported to ${data.path}${data.telegramSent ? " and sent to Telegram" : ""}. You can now run /voice-brief to process this into a feature spec.`,
            timestamp: new Date().toISOString(),
          },
        ]);
      }

      if (data.type === "error") {
        setIsThinking(false);
        setMessages((prev) => [
          ...prev,
          {
            role: "assistant",
            content: `Error: ${data.message}`,
            timestamp: new Date().toISOString(),
          },
        ]);
      }
    };

    wsRef.current = ws;
    return () => ws.close();
  }, []);

  // Auto-scroll
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isThinking]);

  // Send message
  const sendMessage = useCallback(
    (text: string) => {
      if (!text.trim() || !wsRef.current) return;

      const msg: ChatMessage = {
        role: "user",
        content: text.trim(),
        timestamp: new Date().toISOString(),
      };
      setMessages((prev) => [...prev, msg]);
      wsRef.current.send(JSON.stringify({ type: "message", text: text.trim() }));
      setInputText("");
    },
    []
  );

  // Handle voice stop → send transcript
  const handleMicClick = useCallback(() => {
    if (voice.isListening) {
      voice.stopListening();
      if (voice.transcript.trim()) {
        sendMessage(voice.transcript.trim());
      }
    } else {
      tts.stop();
      voice.startListening();
    }
  }, [voice, tts, sendMessage]);

  // Handle text submit
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputText.trim()) {
      sendMessage(inputText);
    }
  };

  // Export session
  const handleExport = () => {
    wsRef.current?.send(JSON.stringify({ type: "export" }));
  };

  // New session
  const handleNewSession = () => {
    setMessages([]);
    setExchangeCount(0);
    wsRef.current?.close();
    // Reconnect
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const ws = new WebSocket(`${protocol}//${window.location.host}/ws`);
    ws.onopen = () => setStatus("connected");
    ws.onclose = () => setStatus("disconnected");
    ws.onmessage = wsRef.current!.onmessage;
    wsRef.current = ws;
  };

  return (
    <div style={styles.container}>
      {/* Header */}
      <header style={styles.header}>
        <div style={styles.headerLeft}>
          <span style={styles.logo}>BrainChat</span>
          <span style={styles.badge}>
            {status === "connected" ? "Live" : status === "connecting" ? "..." : "Offline"}
          </span>
        </div>
        <div style={styles.headerRight}>
          <span style={styles.exchangeCounter}>{exchangeCount} exchanges</span>
          <button onClick={tts.toggleVoice} style={styles.iconBtn} title={tts.voiceEnabled ? "Mute voice" : "Unmute voice"}>
            {tts.voiceEnabled ? "🔊" : "🔇"}
          </button>
          <button onClick={handleNewSession} style={styles.iconBtn} title="New session">
            ✨
          </button>
          <button onClick={handleExport} style={{ ...styles.iconBtn, ...styles.exportBtn }} title="Export & send to Telegram" disabled={messages.length === 0}>
            📤 Export
          </button>
        </div>
      </header>

      {/* Messages */}
      <main style={styles.messages}>
        {messages.length === 0 && (
          <div style={styles.empty}>
            <div style={styles.emptyIcon}>🧠</div>
            <h2 style={styles.emptyTitle}>Start Brainstorming</h2>
            <p style={styles.emptyText}>
              Tap the mic to speak or type your idea below.
              <br />
              Claude will ask questions to help shape your concept.
            </p>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} style={{ ...styles.messageBubble, ...(msg.role === "user" ? styles.userBubble : styles.assistantBubble) }}>
            <div style={styles.messageLabel}>{msg.role === "user" ? "You" : "Claude"}</div>
            <div style={styles.messageText}>{msg.content}</div>
          </div>
        ))}

        {isThinking && (
          <div style={{ ...styles.messageBubble, ...styles.assistantBubble }}>
            <div style={styles.messageLabel}>Claude</div>
            <div style={styles.thinking}>
              <span style={styles.dot}>●</span>
              <span style={{ ...styles.dot, animationDelay: "0.2s" }}>●</span>
              <span style={{ ...styles.dot, animationDelay: "0.4s" }}>●</span>
            </div>
          </div>
        )}

        {voice.isListening && voice.transcript && (
          <div style={{ ...styles.messageBubble, ...styles.userBubble, opacity: 0.7 }}>
            <div style={styles.messageLabel}>Listening...</div>
            <div style={styles.messageText}>{voice.transcript}</div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </main>

      {/* Input Area */}
      <footer style={styles.footer}>
        {/* Voice indicator */}
        {voice.isListening && (
          <div style={styles.listeningBar}>
            <div style={styles.waveform}>
              {[...Array(12)].map((_, i) => (
                <div key={i} style={{ ...styles.waveBar, animationDelay: `${i * 0.05}s` }} />
              ))}
            </div>
            <span style={styles.listeningText}>Listening...</span>
          </div>
        )}

        <div style={styles.inputRow}>
          <form onSubmit={handleSubmit} style={styles.form}>
            <input
              ref={inputRef}
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              placeholder={voice.isListening ? "Listening..." : "Type your idea or tap mic..."}
              style={styles.input}
              disabled={voice.isListening || isThinking}
            />
            {inputText.trim() ? (
              <button type="submit" style={styles.sendBtn} disabled={isThinking}>
                ↑
              </button>
            ) : null}
          </form>

          <button
            onClick={handleMicClick}
            style={{
              ...styles.micBtn,
              ...(voice.isListening ? styles.micBtnActive : {}),
            }}
            disabled={!voice.isSupported || isThinking}
            title={voice.isSupported ? (voice.isListening ? "Stop & send" : "Start speaking") : "Voice not supported in this browser"}
          >
            {voice.isListening ? "◼" : "🎤"}
          </button>
        </div>
      </footer>

      <style>{keyframes}</style>
    </div>
  );
}

const keyframes = `
  @keyframes pulse { 0%, 100% { opacity: 0.3; } 50% { opacity: 1; } }
  @keyframes wave {
    0%, 100% { height: 4px; }
    50% { height: 20px; }
  }
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap');
`;

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: "flex",
    flexDirection: "column",
    height: "100dvh",
    background: "#0a0a0a",
    color: "#e5e5e5",
    fontFamily: "'Inter', -apple-system, sans-serif",
    maxWidth: 640,
    margin: "0 auto",
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "12px 16px",
    borderBottom: "1px solid #1a1a1a",
    background: "#0a0a0a",
    position: "sticky" as const,
    top: 0,
    zIndex: 10,
  },
  headerLeft: { display: "flex", alignItems: "center", gap: 8 },
  headerRight: { display: "flex", alignItems: "center", gap: 8 },
  logo: { fontSize: 18, fontWeight: 600, color: "#fff" },
  badge: {
    fontSize: 11,
    padding: "2px 8px",
    borderRadius: 12,
    background: "#1a3a1a",
    color: "#4ade80",
    fontWeight: 500,
  },
  exchangeCounter: { fontSize: 12, color: "#666" },
  iconBtn: {
    background: "none",
    border: "1px solid #333",
    borderRadius: 8,
    padding: "6px 10px",
    cursor: "pointer",
    fontSize: 14,
    color: "#999",
  },
  exportBtn: {
    background: "#1a1a2e",
    borderColor: "#333366",
    color: "#8b8bff",
  },
  messages: {
    flex: 1,
    overflowY: "auto" as const,
    padding: "16px",
    display: "flex",
    flexDirection: "column",
    gap: 12,
  },
  empty: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    flex: 1,
    textAlign: "center" as const,
    padding: 32,
  },
  emptyIcon: { fontSize: 64, marginBottom: 16 },
  emptyTitle: { fontSize: 24, fontWeight: 600, color: "#fff", margin: "0 0 8px" },
  emptyText: { fontSize: 14, color: "#666", lineHeight: 1.6, margin: 0 },
  messageBubble: {
    maxWidth: "85%",
    padding: "10px 14px",
    borderRadius: 16,
    fontSize: 15,
    lineHeight: 1.5,
  },
  userBubble: {
    alignSelf: "flex-end",
    background: "#2563eb",
    color: "#fff",
    borderBottomRightRadius: 4,
  },
  assistantBubble: {
    alignSelf: "flex-start",
    background: "#1a1a1a",
    color: "#e5e5e5",
    borderBottomLeftRadius: 4,
  },
  messageLabel: {
    fontSize: 11,
    fontWeight: 600,
    marginBottom: 4,
    opacity: 0.6,
    textTransform: "uppercase" as const,
    letterSpacing: 0.5,
  },
  messageText: { whiteSpace: "pre-wrap" as const },
  thinking: { display: "flex", gap: 4, padding: "4px 0" },
  dot: {
    fontSize: 12,
    animation: "pulse 1s infinite",
    color: "#666",
  },
  footer: {
    borderTop: "1px solid #1a1a1a",
    background: "#0a0a0a",
    padding: "12px 16px",
    paddingBottom: "max(12px, env(safe-area-inset-bottom))",
  },
  listeningBar: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    marginBottom: 12,
    padding: "8px 12px",
    background: "#1a0a0a",
    borderRadius: 12,
    border: "1px solid #3a1a1a",
  },
  waveform: { display: "flex", alignItems: "center", gap: 2, height: 24 },
  waveBar: {
    width: 3,
    height: 4,
    background: "#ef4444",
    borderRadius: 2,
    animation: "wave 0.8s ease-in-out infinite",
  },
  listeningText: { fontSize: 13, color: "#ef4444", fontWeight: 500 },
  inputRow: { display: "flex", gap: 10, alignItems: "center" },
  form: { flex: 1, display: "flex", gap: 8 },
  input: {
    flex: 1,
    padding: "12px 16px",
    background: "#141414",
    border: "1px solid #333",
    borderRadius: 24,
    color: "#fff",
    fontSize: 15,
    outline: "none",
  },
  sendBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    background: "#2563eb",
    color: "#fff",
    border: "none",
    fontSize: 18,
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  micBtn: {
    width: 48,
    height: 48,
    borderRadius: 24,
    background: "#1a1a1a",
    border: "2px solid #333",
    fontSize: 22,
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
    transition: "all 0.2s",
  },
  micBtnActive: {
    background: "#dc2626",
    borderColor: "#ef4444",
    color: "#fff",
    boxShadow: "0 0 20px rgba(220,38,38,0.4)",
  },
};
