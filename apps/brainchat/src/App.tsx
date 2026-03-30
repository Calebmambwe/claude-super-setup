import { useState, useEffect, useRef, useCallback } from "react";
import { useVoiceRecognition } from "./hooks/useVoiceRecognition";

interface ChatMessage { role: "user" | "assistant"; content: string; }

export function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [streaming, setStreaming] = useState("");
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [connected, setConnected] = useState(false);
  const [exchanges, setExchanges] = useState(0);
  const [hasTTS, setHasTTS] = useState(false);
  const [voiceOn, setVoiceOn] = useState(true);
  const [briefPath, setBriefPath] = useState("");
  const wsRef = useRef<WebSocket | null>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const voice = useVoiceRecognition();

  useEffect(() => {
    const ws = new WebSocket(`${location.protocol === "https:" ? "wss:" : "ws:"}//${location.host}/ws`);
    ws.onopen = () => setConnected(true);
    ws.onclose = () => setConnected(false);
    ws.onmessage = (e) => {
      const d = JSON.parse(e.data);
      if (d.type === "session") setHasTTS(d.hasTTS);
      if (d.type === "stream_start") { setBusy(true); setStreaming(""); }
      if (d.type === "stream_chunk") setStreaming((p) => p + d.text);
      if (d.type === "stream_end") {
        setBusy(false); setStreaming("");
        setMessages((p) => [...p, { role: "assistant", content: d.fullText }]);
        setExchanges(d.exchangeCount);
        if (voiceOn) speakTTS(d.fullText);
      }
      if (d.type === "brief_saved") setBriefPath(d.path);
      if (d.type === "exported") setMessages((p) => [...p, { role: "assistant", content: "Session exported" + (d.telegramSent ? " and sent to Telegram" : "") + ". Ready for SDLC." }]);
      if (d.type === "error") { setBusy(false); setStreaming(""); setMessages((p) => [...p, { role: "assistant", content: "Error: " + d.message }]); }
    };
    wsRef.current = ws;
    return () => ws.close();
  }, []);

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages, streaming]);

  const speakTTS = useCallback(async (text: string) => {
    if (!hasTTS || !voiceOn) return;
    try {
      if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; }
      const clean = text.replace(/#{1,6}\s/g, "").replace(/\*{1,2}/g, "").replace(/`[^`]*`/g, "").slice(0, 2000);
      const resp = await fetch("/api/tts", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text: clean }) });
      if (!resp.ok) return;
      const blob = await resp.blob();
      const url = URL.createObjectURL(blob);
      const audio = new Audio(url);
      audioRef.current = audio;
      audio.play();
      audio.onended = () => URL.revokeObjectURL(url);
    } catch { /* silent */ }
  }, [hasTTS, voiceOn]);

  const send = useCallback((text: string) => {
    if (!text.trim() || !wsRef.current) return;
    setMessages((p) => [...p, { role: "user", content: text.trim() }]);
    wsRef.current.send(JSON.stringify({ type: "message", text: text.trim() }));
    setInput("");
  }, []);

  const handleMic = useCallback(() => {
    if (voice.isListening) { voice.stopListening(); if (voice.transcript.trim()) send(voice.transcript.trim()); }
    else { if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; } voice.startListening(); }
  }, [voice, send]);

  return (
    <div style={S.root}>
      <header style={S.hdr}>
        <div style={S.hdrL}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#a78bfa" strokeWidth="2"><path d="M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z"/><path d="M10 21h4"/><path d="M12 17v4"/></svg>
          <span style={S.brand}>BrainChat</span>
          <span style={{...S.dot, background: connected ? "#22c55e" : "#ef4444"}} />
        </div>
        <div style={S.hdrR}>
          {exchanges > 0 && <span style={S.xCount}>{exchanges}</span>}
          <button onClick={() => { setVoiceOn(!voiceOn); if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; } }} style={S.hBtn}>{voiceOn ? "\u{1F50A}" : "\u{1F507}"}</button>
          <button onClick={() => { setMessages([]); setExchanges(0); setBriefPath(""); }} style={S.hBtn}>New</button>
          <button onClick={() => wsRef.current?.send(JSON.stringify({ type: "export" }))} style={{...S.hBtn, background: messages.length ? "#1e1b4b" : "transparent", color: messages.length ? "#a78bfa" : "#444"}} disabled={!messages.length}>Export</button>
        </div>
      </header>

      <main style={S.chat}>
        {!messages.length && !busy && (
          <div style={S.hero}>
            <div style={S.heroGlow} />
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#a78bfa" strokeWidth="1.5" style={{position:"relative",zIndex:1}}><path d="M12 2a7 7 0 0 1 7 7c0 2.38-1.19 4.47-3 5.74V17a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2v-2.26C6.19 13.47 5 11.38 5 9a7 7 0 0 1 7-7z"/><path d="M10 21h4"/><path d="M12 17v4"/></svg>
            <h1 style={S.heroTitle}>What are you building?</h1>
            <p style={S.heroSub}>Speak or type your idea. I will shape it into a feature brief for your SDLC pipeline.</p>
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} style={m.role === "user" ? S.uMsg : S.aMsg}>
            {m.role === "assistant" && <div style={S.avatar}>C</div>}
            <div style={m.role === "user" ? S.uBub : S.aBub}>
              {m.content.split("\n").map((line, j) => {
                if (line.startsWith("# ")) return <h2 key={j} style={S.mdH1}>{line.slice(2)}</h2>;
                if (line.startsWith("## ")) return <h3 key={j} style={S.mdH2}>{line.slice(3)}</h3>;
                if (line.startsWith("- ")) return <div key={j} style={S.mdLi}>{line}</div>;
                if (line.match(/^\d+\./)) return <div key={j} style={S.mdLi}>{line}</div>;
                return <span key={j}>{line}{"\n"}</span>;
              })}
            </div>
            {m.role === "user" && <div style={{...S.avatar, background:"#2563eb"}}>Y</div>}
          </div>
        ))}
        {busy && (<div style={S.aMsg}><div style={S.avatar}>C</div><div style={S.aBub}>{streaming || <span style={{color:"#555"}}>Thinking</span>}<span style={S.caret} /></div></div>)}
        {voice.isListening && voice.transcript && (<div style={{...S.uMsg, opacity:0.6}}><div style={S.uBub}>{voice.transcript}</div><div style={{...S.avatar, background:"#dc2626"}}>...</div></div>)}
        {briefPath && (<div style={S.briefBar}><span>Brief saved for SDLC</span><span style={S.briefPath}>{briefPath.split("/").pop()}</span></div>)}
        <div ref={endRef} />
      </main>

      {voice.isListening && (<div style={S.listenStrip}><div style={S.waves}>{Array.from({length:20}).map((_,i) => <div key={i} style={{...S.wBar, animationDelay: i*0.03+"s"}} />)}</div><span style={{color:"#f87171", fontWeight:500, fontSize:13}}>Listening...</span></div>)}

      <footer style={S.ftr}>
        <form onSubmit={(e) => { e.preventDefault(); if (input.trim()) send(input); }} style={S.form}>
          <input value={input} onChange={(e) => setInput(e.target.value)} placeholder={voice.isListening ? "Listening..." : "Describe your idea..."} style={S.inp} disabled={voice.isListening || busy} />
          {input.trim() && <button type="submit" style={S.sndBtn} disabled={busy}>{"\u2191"}</button>}
        </form>
        <button onClick={handleMic} style={voice.isListening ? S.micAct : S.mic} disabled={!voice.isSupported || busy}>
          {voice.isListening ? "\u25A0" : (<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0"/><path d="M12 18v4"/><path d="M8 22h8"/></svg>)}
        </button>
      </footer>

      <style>{`
        @keyframes blink{0%,100%{opacity:1}50%{opacity:0}}
        @keyframes wave{0%,100%{height:3px}50%{height:20px}}
        *{box-sizing:border-box;margin:0}
        body{background:#09090b;overflow:hidden}
        ::-webkit-scrollbar{width:4px}
        ::-webkit-scrollbar-thumb{background:#222;border-radius:4px}
        input:focus{border-color:#a78bfa!important;outline:none}
      `}</style>
    </div>
  );
}

const S: Record<string, React.CSSProperties> = {
  root:{display:"flex",flexDirection:"column",height:"100dvh",background:"#09090b",color:"#e4e4e7",fontFamily:"-apple-system,Inter,system-ui,sans-serif",maxWidth:640,margin:"0 auto"},
  hdr:{display:"flex",justifyContent:"space-between",alignItems:"center",padding:"10px 16px",borderBottom:"1px solid #18181b"},
  hdrL:{display:"flex",alignItems:"center",gap:8},hdrR:{display:"flex",alignItems:"center",gap:6},
  brand:{fontWeight:600,fontSize:16,color:"#fafafa",letterSpacing:"-0.02em"},
  dot:{width:7,height:7,borderRadius:"50%"},
  xCount:{fontSize:11,color:"#71717a",background:"#18181b",padding:"2px 7px",borderRadius:10,fontWeight:600},
  hBtn:{background:"transparent",border:"1px solid #27272a",borderRadius:8,padding:"5px 10px",color:"#a1a1aa",cursor:"pointer",fontSize:13,fontWeight:500},
  chat:{flex:1,overflowY:"auto" as const,padding:"16px 12px",display:"flex",flexDirection:"column",gap:16},
  hero:{display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",flex:1,textAlign:"center" as const,position:"relative" as const},
  heroGlow:{position:"absolute" as const,width:120,height:120,borderRadius:"50%",background:"radial-gradient(circle, rgba(167,139,250,0.15) 0%, transparent 70%)",top:"50%",left:"50%",transform:"translate(-50%, -70%)"},
  heroTitle:{fontSize:22,fontWeight:600,color:"#fafafa",marginTop:16,letterSpacing:"-0.02em"},
  heroSub:{fontSize:14,color:"#71717a",marginTop:8,maxWidth:320,lineHeight:1.5},
  uMsg:{display:"flex",gap:8,justifyContent:"flex-end",alignItems:"flex-end"},
  aMsg:{display:"flex",gap:8,alignItems:"flex-start"},
  avatar:{width:28,height:28,borderRadius:14,background:"#a78bfa",color:"#000",display:"flex",alignItems:"center",justifyContent:"center",fontSize:12,fontWeight:700,flexShrink:0},
  uBub:{background:"#2563eb",color:"#fff",padding:"10px 14px",borderRadius:"18px 18px 4px 18px",maxWidth:"78%",fontSize:15,lineHeight:1.45,whiteSpace:"pre-wrap" as const},
  aBub:{background:"#18181b",color:"#e4e4e7",padding:"10px 14px",borderRadius:"18px 18px 18px 4px",maxWidth:"78%",fontSize:15,lineHeight:1.5,whiteSpace:"pre-wrap" as const,border:"1px solid #27272a"},
  caret:{display:"inline-block",width:2,height:16,background:"#a78bfa",marginLeft:2,animation:"blink 0.7s infinite",verticalAlign:"text-bottom"},
  mdH1:{fontSize:17,fontWeight:700,color:"#fafafa",margin:"8px 0 4px"},
  mdH2:{fontSize:15,fontWeight:600,color:"#a78bfa",margin:"8px 0 2px"},
  mdLi:{paddingLeft:8},
  briefBar:{display:"flex",justifyContent:"space-between",alignItems:"center",background:"#1a1625",border:"1px solid #2e1065",borderRadius:10,padding:"8px 14px",fontSize:13,color:"#c4b5fd"},
  briefPath:{fontFamily:"monospace",fontSize:11,color:"#8b5cf6"},
  listenStrip:{display:"flex",alignItems:"center",gap:10,margin:"0 12px",padding:"6px 12px",background:"#1c0a0a",borderRadius:10,border:"1px solid #3f1111"},
  waves:{display:"flex",alignItems:"center",gap:1.5,height:22},
  wBar:{width:2.5,height:3,background:"#ef4444",borderRadius:2,animation:"wave 0.5s ease-in-out infinite"},
  ftr:{display:"flex",gap:8,padding:"10px 12px",paddingBottom:"max(10px, env(safe-area-inset-bottom))",borderTop:"1px solid #18181b",background:"#09090b"},
  form:{flex:1,display:"flex",gap:8},
  inp:{flex:1,padding:"11px 16px",background:"#18181b",border:"1px solid #27272a",borderRadius:22,color:"#fafafa",fontSize:15,transition:"border-color 0.2s"},
  sndBtn:{width:38,height:38,borderRadius:19,background:"#7c3aed",color:"#fff",border:"none",fontSize:17,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center"},
  mic:{width:46,height:46,borderRadius:23,background:"#18181b",border:"2px solid #27272a",color:"#a1a1aa",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",transition:"all 0.2s"},
  micAct:{width:46,height:46,borderRadius:23,background:"#dc2626",border:"2px solid #ef4444",color:"#fff",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",boxShadow:"0 0 20px #dc26264d",fontSize:16},
};
