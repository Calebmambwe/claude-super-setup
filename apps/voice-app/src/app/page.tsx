import Link from "next/link";

export default function HomePage() {
  return (
    <main className="min-h-screen bg-[#09090b] flex flex-col">
      {/* Nav */}
      <nav className="flex items-center justify-between px-6 py-4 border-b border-[#1c1c1f]">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded-full bg-violet-500 flex items-center justify-center">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <circle cx="6" cy="6" r="4" fill="white" opacity="0.9" />
              <circle cx="6" cy="6" r="2" fill="white" className="animate-pulse" />
            </svg>
          </div>
          <span className="text-sm font-semibold text-[#fafafa] tracking-tight">Voice Brainstorm</span>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-xs text-[#71717a] hidden sm:block">Powered by Claude</span>
          <div className="w-2 h-2 rounded-full bg-emerald-500" title="API connected" />
        </div>
      </nav>

      {/* Hero */}
      <section className="flex-1 flex flex-col items-center justify-center px-6 py-20 text-center">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-violet-500/20 bg-violet-500/10 mb-8">
          <div className="w-1.5 h-1.5 rounded-full bg-violet-400 animate-pulse" />
          <span className="text-xs text-violet-300 font-medium tracking-wide">Real-time voice AI</span>
        </div>

        {/* Heading */}
        <h1 className="text-4xl sm:text-5xl md:text-6xl font-bold text-[#fafafa] tracking-tight leading-[1.1] mb-5 max-w-2xl">
          Voice Brainstorm
        </h1>
        <p className="text-lg sm:text-xl text-[#71717a] mb-12 max-w-md leading-relaxed">
          Speak your ideas.{" "}
          <span className="text-[#a1a1aa]">Claude builds them.</span>
        </p>

        {/* CTA */}
        <div className="flex flex-col sm:flex-row items-center gap-3">
          <Link
            href="/session/new"
            className="group relative inline-flex items-center gap-2 px-6 py-3 rounded-lg text-sm font-semibold text-white overflow-hidden transition-all duration-200 hover:scale-[1.02] active:scale-[0.98]"
            style={{
              background: "linear-gradient(135deg, #7c3aed 0%, #6d28d9 50%, #5b21b6 100%)",
              boxShadow: "0 0 0 1px rgba(139,92,246,0.3), 0 4px 15px rgba(109,40,217,0.4)",
            }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className="transition-transform group-hover:scale-110">
              <circle cx="8" cy="8" r="3" fill="white" opacity="0.9" />
              <path d="M8 1v2M8 13v2M1 8h2M13 8h2" stroke="white" strokeWidth="1.5" strokeLinecap="round" opacity="0.5" />
            </svg>
            New Session
          </Link>
          <a
            href="#past-sessions"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-lg text-sm font-medium text-[#a1a1aa] border border-[#1c1c1f] hover:border-[#3f3f46] hover:text-[#fafafa] transition-all duration-200"
          >
            View Past Sessions
          </a>
        </div>

        {/* Feature pills */}
        <div className="flex flex-wrap items-center justify-center gap-2 mt-14">
          {[
            "Deepgram STT",
            "Claude 3.5 Sonnet",
            "Cartesia TTS",
            "LiveKit WebRTC",
          ].map((tech) => (
            <span
              key={tech}
              className="px-3 py-1 rounded-full text-xs text-[#71717a] bg-[#111113] border border-[#1c1c1f]"
            >
              {tech}
            </span>
          ))}
        </div>
      </section>

      {/* Past Sessions */}
      <section id="past-sessions" className="px-6 py-12 border-t border-[#1c1c1f] max-w-3xl mx-auto w-full">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-sm font-semibold text-[#fafafa] tracking-tight">Past Sessions</h2>
          <span className="text-xs text-[#3f3f46]">0 sessions</span>
        </div>

        {/* Empty state */}
        <div className="flex flex-col items-center justify-center py-16 rounded-xl border border-dashed border-[#1c1c1f]">
          <div className="w-10 h-10 rounded-full bg-[#111113] border border-[#1c1c1f] flex items-center justify-center mb-3">
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
              <circle cx="9" cy="9" r="5" stroke="#3f3f46" strokeWidth="1.5" />
              <path d="M7 9h4M9 7v4" stroke="#3f3f46" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </div>
          <p className="text-sm text-[#3f3f46]">No sessions yet</p>
          <p className="text-xs text-[#27272a] mt-1">Start a new session to begin brainstorming</p>
        </div>
      </section>

      {/* Footer */}
      <footer className="px-6 py-4 border-t border-[#1c1c1f] flex items-center justify-between">
        <span className="text-xs text-[#3f3f46]">Voice Brainstorm — Twendai Software Ltd</span>
        <span className="text-xs text-[#27272a]">v0.1.0</span>
      </footer>
    </main>
  );
}
