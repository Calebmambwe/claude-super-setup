import { useState, useEffect, useRef, useCallback } from "react";

interface ChatMessage { role: "user" | "assistant"; content: string; }

export function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [streaming, setStreaming] = useState("");
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [connected, setConnected] = useState(false);
  const [exchanges, setExchanges] = useState(0);
  const [voiceOn, setVoiceOn] = useState(true);
  const [briefPath, setBriefPath] = useState("");
  const [liveMode, setLiveMode] = useState(false); // continuous conversation
  const [isListening, setIsListening] = useState(false);
  const [liveTranscript, setLiveTranscript] = useState("");
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [ttsProvider, setTtsProvider] = useState<"gemini"|"openai"|"browser">("gemini");
  const wsRef = useRef<WebSocket | null>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const recRef = useRef<SpeechRecognition | null>(null);
  const silenceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // --- WebSocket ---
  useEffect(() => {
    const ws = new WebSocket(`${location.protocol === "https:" ? "wss:" : "ws:"}//${location.host}/ws`);
    ws.onopen = () => setConnected(true);
    ws.onclose = () => setConnected(false);
    ws.onmessage = (e) => {
      const d = JSON.parse(e.data);
      if (d.type === "stream_start") { setBusy(true); setStreaming(""); }
      if (d.type === "stream_chunk") setStreaming((p) => p + d.text);
      if (d.type === "stream_end") {
        setBusy(false); setStreaming("");
        setMessages((p) => [...p, { role: "assistant", content: d.fullText }]);
        setExchanges(d.exchangeCount);
        if (voiceOn) speak(d.fullText);
        else if (liveMode) startListening(); // no voice, restart listening immediately
      }
      if (d.type === "brief_saved") setBriefPath(d.path);
      if (d.type === "exported") setMessages((p) => [...p, { role: "assistant", content: "Exported" + (d.telegramSent ? " + sent to Telegram" : "") + ". Brief ready for /design-doc pipeline." }]);
      if (d.type === "error") { setBusy(false); setStreaming(""); setMessages((p) => [...p, { role: "assistant", content: "Error: " + d.message }]); if (liveMode) startListening(); }
    };
    wsRef.current = ws;
    return () => ws.close();
  }, [voiceOn, liveMode]);

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, streaming]);

  // --- TTS (Gemini / OpenAI / Browser) ---
  const speak = useCallback(async (text: string) => {
    if (!voiceOn) return;
    const clean = text.replace(/#{1,6}\s/g,"").replace(/\*{1,2}/g,"").replace(/`[^`]*`/g,"").replace(/---[^-]*---/g,"").slice(0, 3000);
    
    if (ttsProvider === "browser") {
      if (!window.speechSynthesis) return;
      window.speechSynthesis.cancel();
      const utt = new SpeechSynthesisUtterance(clean);
      utt.rate = 1.1;
      const voices = window.speechSynthesis.getVoices();
      const good = voices.find(v => v.name.includes("Google UK English Female")) || voices.find(v => v.name.includes("Samantha")) || voices.find(v => v.lang.startsWith("en"));
      if (good) utt.voice = good;
      utt.onstart = () => setIsSpeaking(true);
      utt.onend = () => { setIsSpeaking(false); if (liveMode) startListening(); };
      utt.onerror = () => { setIsSpeaking(false); if (liveMode) startListening(); };
      window.speechSynthesis.speak(utt);
      return;
    }

    // API TTS (Gemini or OpenAI)
    try {
      if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; }
      setIsSpeaking(true);
      const resp = await fetch("/api/tts", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text: clean, provider: ttsProvider }) });
      if (!resp.ok) { setIsSpeaking(false); if (liveMode) startListening(); return; }
      const blob = await resp.blob();
      const url = URL.createObjectURL(blob);
      const audio = new Audio(url);
      audioRef.current = audio;
      audio.onended = () => { URL.revokeObjectURL(url); setIsSpeaking(false); if (liveMode) startListening(); };
      audio.onerror = () => { setIsSpeaking(false); if (liveMode) startListening(); };
      audio.play();
    } catch { setIsSpeaking(false); if (liveMode) startListening(); }
  }, [voiceOn, liveMode, ttsProvider]);

  // --- Speech Recognition (continuous with silence detection) ---
  const startListening = useCallback(() => {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR || busy) return;
    if (recRef.current) { try { recRef.current.stop(); } catch {} }
    
    const rec = new SR();
    rec.continuous = true;
    rec.interimResults = true;
    rec.lang = "en-US";
    
    let final = "";
    
    rec.onresult = (ev: SpeechRecognitionEvent) => {
      let interim = "";
      for (let i = ev.resultIndex; i < ev.results.length; i++) {
        if (ev.results[i].isFinal) final += ev.results[i][0].transcript + " ";
        else interim += ev.results[i][0].transcript;
      }
      setLiveTranscript(final + interim);
      
      // Reset silence timer on every result
      if (silenceRef.current) clearTimeout(silenceRef.current);
      silenceRef.current = setTimeout(() => {
        // 1.5s of silence = send the message
        if (final.trim()) {
          rec.stop();
        }
      }, 1500);
    };
    
    rec.onend = () => {
      setIsListening(false);
      if (final.trim()) {
        send(final.trim());
        setLiveTranscript("");
      }
    };
    
    rec.onerror = () => { setIsListening(false); setLiveTranscript(""); };
    
    recRef.current = rec;
    rec.start();
    setIsListening(true);
    setLiveTranscript("");
  }, [busy]);
  
  const stopListening = useCallback(() => {
    if (recRef.current) { try { recRef.current.stop(); } catch {} recRef.current = null; }
    if (silenceRef.current) { clearTimeout(silenceRef.current); silenceRef.current = null; }
    setIsListening(false);
  }, []);

  // --- Send ---
  const send = useCallback((text: string) => {
    if (!text.trim() || !wsRef.current) return;
    setMessages((p) => [...p, { role: "user", content: text.trim() }]);
    wsRef.current.send(JSON.stringify({ type: "message", text: text.trim() }));
    setInput("");
  }, []);

  // --- Live mode toggle ---
  const toggleLive = useCallback(() => {
    if (liveMode) {
      setLiveMode(false);
      stopListening();
      window.speechSynthesis?.cancel();
      setIsSpeaking(false);
    } else {
      setLiveMode(true);
      startListening();
    }
  }, [liveMode, stopListening, startListening]);

  // --- Manual mic (non-live) ---
  const handleMic = useCallback(() => {
    if (isListening) { stopListening(); }
    else { window.speechSynthesis?.cancel(); setIsSpeaking(false); startListening(); }
  }, [isListening, stopListening, startListening]);

  const hasVoice = typeof window !== "undefined" && (window.SpeechRecognition || window.webkitSpeechRecognition);

  return (
    <div style={S.root}>
      <header style={S.hdr}>
        <div style={S.hdrL}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#a78bfa" strokeWidth="2"><path d="M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z"/><path d="M10 21h4"/></svg>
          <span style={S.brand}>BrainChat</span>
          <span style={{...S.statusDot, background: connected ? "#22c55e" : "#ef4444"}} />
        </div>
        <div style={S.hdrR}>
          {exchanges > 0 && <span style={S.xBadge}>{exchanges}</span>}
          <button onClick={() => setVoiceOn(!voiceOn)} style={S.hBtn}>{voiceOn ? "\u{1F50A}" : "\u{1F507}"}</button>
          <select value={ttsProvider} onChange={(e) => setTtsProvider(e.target.value as "gemini"|"openai"|"browser")} style={S.sel}><option value="gemini">Gemini</option><option value="openai">OpenAI</option><option value="browser">Browser</option></select>
          <button onClick={() => { setMessages([]); setExchanges(0); setBriefPath(""); stopListening(); setLiveMode(false); }} style={S.hBtn}>New</button>
          <button onClick={() => wsRef.current?.send(JSON.stringify({ type: "export" }))} style={{...S.hBtn, ...(messages.length ? {background:"#1e1b4b",color:"#a78bfa"} : {})}} disabled={!messages.length}>Export</button>
        </div>
      </header>

      <main style={S.chat}>
        {!messages.length && !busy && (
          <div style={S.hero}>
            <div style={S.glow} />
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#a78bfa" strokeWidth="1.5" style={{position:"relative",zIndex:1}}><path d="M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z"/><path d="M10 21h4"/><path d="M12 17v4"/></svg>
            <h1 style={S.heroTitle}>What are you building?</h1>
            <p style={S.heroSub}>Tap <b>Live</b> for hands-free voice conversation, or type below.</p>
          </div>
        )}

        {messages.map((m, i) => (
          <div key={i} style={m.role === "user" ? S.uRow : S.aRow}>
            {m.role === "assistant" && <div style={S.av}>C</div>}
            <div style={m.role === "user" ? S.uBub : S.aBub}>
              {m.content.split("\n").map((ln, j) => {
                if (ln.startsWith("# ")) return <h2 key={j} style={{fontSize:17,fontWeight:700,color:"#fafafa",margin:"6px 0 3px"}}>{ln.slice(2)}</h2>;
                if (ln.startsWith("## ")) return <h3 key={j} style={{fontSize:14,fontWeight:600,color:"#a78bfa",margin:"6px 0 2px"}}>{ln.slice(3)}</h3>;
                if (ln.startsWith("- ")) return <div key={j} style={{paddingLeft:6}}>{ln}</div>;
                if (ln.match(/^\d+\./)) return <div key={j} style={{paddingLeft:6}}>{ln}</div>;
                return <span key={j}>{ln}{"\n"}</span>;
              })}
            </div>
            {m.role === "user" && <div style={{...S.av,background:"#2563eb"}}>Y</div>}
          </div>
        ))}

        {busy && (<div style={S.aRow}><div style={S.av}>C</div><div style={S.aBub}>{streaming || <span style={{color:"#555"}}>Thinking</span>}<span style={S.caret}/></div></div>)}
        {isListening && liveTranscript && (<div style={{...S.uRow, opacity:0.5}}><div style={S.uBub}>{liveTranscript}</div><div style={{...S.av,background:"#dc2626"}}>...</div></div>)}
        {briefPath && (<div style={S.briefBanner}><span>Brief saved for SDLC</span><span style={{fontFamily:"monospace",fontSize:11,color:"#8b5cf6"}}>{briefPath.split("/").pop()}</span></div>)}
        <div ref={endRef} />
      </main>

      {/* Status strip */}
      {(isListening || isSpeaking) && (
        <div style={{...S.strip, borderColor: isListening ? "#3f1111" : "#1f1f3f", background: isListening ? "#1c0a0a" : "#0a0a1c"}}>
          <div style={S.waves}>{Array.from({length:16}).map((_,i) => <div key={i} style={{...S.wBar, background: isListening ? "#ef4444" : "#a78bfa", animationDelay: i*0.03+"s"}} />)}</div>
          <span style={{color: isListening ? "#f87171" : "#a78bfa", fontWeight:500, fontSize:13}}>{isListening ? "Listening..." : "Speaking..."}</span>
        </div>
      )}

      <footer style={S.ftr}>
        <form onSubmit={(e) => { e.preventDefault(); if (input.trim()) { send(input); if (liveMode) { stopListening(); setLiveMode(false); } } }} style={S.form}>
          <input value={input} onChange={(e) => setInput(e.target.value)} placeholder={isListening ? "Listening..." : "Describe your idea..."} style={S.inp} disabled={isListening || busy} />
          {input.trim() && <button type="submit" style={S.sndBtn} disabled={busy}>{"\u2191"}</button>}
        </form>

        {/* Manual mic (tap to talk) */}
        {!liveMode && (
          <button onClick={handleMic} style={isListening ? S.micAct : S.mic} disabled={!hasVoice || busy}>
            {isListening ? "\u25A0" : (<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0"/><path d="M12 18v4"/><path d="M8 22h8"/></svg>)}
          </button>
        )}

        {/* Live mode button */}
        <button onClick={toggleLive} style={liveMode ? S.liveAct : S.live} disabled={!hasVoice || busy} title="Continuous voice conversation">
          {liveMode ? "END" : "Live"}
        </button>
      </footer>

      <style>{`
        @keyframes blink{0%,100%{opacity:1}50%{opacity:0}}
        @keyframes wave{0%,100%{height:3px}50%{height:18px}}
        *{box-sizing:border-box;margin:0}
        body{background:#09090b;overflow:hidden}
        ::-webkit-scrollbar{width:4px}
        ::-webkit-scrollbar-thumb{background:#222;border-radius:4px}
        input:focus{border-color:#a78bfa!important;outline:none}
      `}</style>
    </div>
  );
}

declare global { interface Window { SpeechRecognition: typeof SpeechRecognition; webkitSpeechRecognition: typeof SpeechRecognition; } }

const S: Record<string, React.CSSProperties> = {
  root:{display:"flex",flexDirection:"column",height:"100dvh",background:"#09090b",color:"#e4e4e7",fontFamily:"-apple-system,Inter,system-ui,sans-serif",maxWidth:640,margin:"0 auto"},
  hdr:{display:"flex",justifyContent:"space-between",alignItems:"center",padding:"10px 16px",borderBottom:"1px solid #18181b"},
  hdrL:{display:"flex",alignItems:"center",gap:8},hdrR:{display:"flex",alignItems:"center",gap:6},
  brand:{fontWeight:600,fontSize:16,color:"#fafafa",letterSpacing:"-0.02em"},
  statusDot:{width:7,height:7,borderRadius:"50%"},
  xBadge:{fontSize:11,color:"#71717a",background:"#18181b",padding:"2px 7px",borderRadius:10,fontWeight:600},
  sel:{background:"#18181b",border:"1px solid #27272a",borderRadius:8,padding:"4px 6px",color:"#a1a1aa",fontSize:11,cursor:"pointer"},
  hBtn:{background:"transparent",border:"1px solid #27272a",borderRadius:8,padding:"5px 10px",color:"#a1a1aa",cursor:"pointer",fontSize:13,fontWeight:500},
  chat:{flex:1,overflowY:"auto" as const,padding:"16px 12px",display:"flex",flexDirection:"column",gap:14},
  hero:{display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",flex:1,textAlign:"center" as const,position:"relative" as const},
  glow:{position:"absolute" as const,width:120,height:120,borderRadius:"50%",background:"radial-gradient(circle, rgba(167,139,250,0.15) 0%, transparent 70%)",top:"50%",left:"50%",transform:"translate(-50%, -70%)"},
  heroTitle:{fontSize:22,fontWeight:600,color:"#fafafa",marginTop:16,letterSpacing:"-0.02em"},
  heroSub:{fontSize:14,color:"#71717a",marginTop:8,maxWidth:320,lineHeight:1.5},
  uRow:{display:"flex",gap:8,justifyContent:"flex-end",alignItems:"flex-end"},
  aRow:{display:"flex",gap:8,alignItems:"flex-start"},
  av:{width:26,height:26,borderRadius:13,background:"#a78bfa",color:"#000",display:"flex",alignItems:"center",justifyContent:"center",fontSize:11,fontWeight:700,flexShrink:0},
  uBub:{background:"#2563eb",color:"#fff",padding:"9px 13px",borderRadius:"16px 16px 4px 16px",maxWidth:"78%",fontSize:15,lineHeight:1.45,whiteSpace:"pre-wrap" as const},
  aBub:{background:"#18181b",color:"#e4e4e7",padding:"9px 13px",borderRadius:"16px 16px 16px 4px",maxWidth:"78%",fontSize:15,lineHeight:1.45,whiteSpace:"pre-wrap" as const,border:"1px solid #27272a"},
  caret:{display:"inline-block",width:2,height:16,background:"#a78bfa",marginLeft:2,animation:"blink 0.7s infinite",verticalAlign:"text-bottom"},
  briefBanner:{display:"flex",justifyContent:"space-between",alignItems:"center",background:"#1a1625",border:"1px solid #2e1065",borderRadius:10,padding:"8px 14px",fontSize:13,color:"#c4b5fd"},
  strip:{display:"flex",alignItems:"center",gap:10,margin:"0 12px",padding:"6px 12px",borderRadius:10,border:"1px solid"},
  waves:{display:"flex",alignItems:"center",gap:1.5,height:20},
  wBar:{width:2.5,height:3,borderRadius:2,animation:"wave 0.5s ease-in-out infinite"},
  ftr:{display:"flex",gap:8,padding:"10px 12px",paddingBottom:"max(10px, env(safe-area-inset-bottom))",borderTop:"1px solid #18181b",background:"#09090b"},
  form:{flex:1,display:"flex",gap:8},
  inp:{flex:1,padding:"11px 16px",background:"#18181b",border:"1px solid #27272a",borderRadius:22,color:"#fafafa",fontSize:15,transition:"border-color 0.2s"},
  sndBtn:{width:36,height:36,borderRadius:18,background:"#7c3aed",color:"#fff",border:"none",fontSize:16,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center"},
  mic:{width:42,height:42,borderRadius:21,background:"#18181b",border:"2px solid #27272a",color:"#a1a1aa",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",transition:"all 0.2s"},
  micAct:{width:42,height:42,borderRadius:21,background:"#dc2626",border:"2px solid #ef4444",color:"#fff",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",boxShadow:"0 0 16px #dc26264d",fontSize:14},
  live:{height:42,borderRadius:21,background:"#18181b",border:"2px solid #27272a",color:"#a78bfa",cursor:"pointer",padding:"0 16px",fontSize:13,fontWeight:600,letterSpacing:"0.02em"},
  liveAct:{height:42,borderRadius:21,background:"#7c3aed",border:"2px solid #a78bfa",color:"#fff",cursor:"pointer",padding:"0 16px",fontSize:13,fontWeight:700,boxShadow:"0 0 20px #7c3aed4d",letterSpacing:"0.02em"},
};
