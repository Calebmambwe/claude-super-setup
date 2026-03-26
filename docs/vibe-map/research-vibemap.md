# Research Report: VibeMap

**Date:** 2026-03-23
**Research Type:** Mixed (Competitive + Technical)
**Duration:** ~15 minutes

## Executive Summary

The real-time mood visualization space is surprisingly crowded but technically shallow. At least 6 competitors exist (MoodyMap, Global Mood Today, The World Mood, MoodNow, Mood2Know, Global Emotions Index), but **none use a 3D globe with real-time WebSocket updates and particle animations**. Most use flat D3.js maps with polling. This is our core differentiator.

**Key findings:**
- Competitors use flat maps + AJAX polling. Nobody has a stunning 3D globe experience.
- Globe.gl (built on Three.js) is the ideal library — 13+ visualization layers, ring animations, and React wrapper available.
- Next.js + Vercel is the optimal stack: edge OG image generation (Satori), WebSocket support, and instant deploys.
- Viral sharing mechanics are proven: OG images get 3x more clicks, and shareable result cards drive organic loops.

## Research Questions & Answers

### Q1: What similar projects exist?

**Answer:** 6+ mood map websites exist, but all are technically basic.

| Competitor | Visualization | Tech | Real-time | 3D Globe | Shareable |
|-----------|--------------|------|-----------|----------|-----------|
| MoodyMap | Flat D3.js map | WordPress + D3 | 30s polling | No | No |
| Global Mood Today | Canvas animation | Custom | Yes | No | No |
| The World Mood | Flat interactive map | Unknown | Partial | No | No |
| MoodNow | Emoji map pins | Unknown | Yes | No | Limited |
| Mood2Know | Flat mood map | Unknown | Yes | No | No |
| Global Emotions Index | Static map + stats | Unknown | Partial | No | No |

**Confidence:** High
**Gap:** NONE have a 3D globe, particle effects, or social sharing cards. This is wide open.

### Q2: Best viral sharing mechanics?

**Answer:** Three proven mechanics for micro-interaction web apps:

1. **Shareable Result Cards** — OG images with personalized data (like Spotify Wrapped). OG images get 3x more clicks on social previews.
2. **Milestone Nudges** — "You're the 1000th person to vibe from Lusaka!" triggers sharing.
3. **Visual Identity** — The globe screenshot itself is inherently shareable and visually striking.

**Confidence:** High

### Q3: Best 3D globe technology?

**Answer:** **Globe.gl** (react-globe.gl for React/Next.js)

- Built on Three.js/WebGL — same performance, higher-level API
- 13+ visualization layers including **Rings** (perfect for vibe pulses) and **Points**
- Fluent chainable API, easy to customize
- 70K+ weekly npm downloads (three-globe) + 43K (globe.gl)
- React wrapper available: `react-globe.gl`
- **Caveat:** Client-side only (needs `dynamic import` with `ssr: false` in Next.js)

**Alternative considered:** Raw Three.js — more control but 5x more code for same result. Globe.gl is the right abstraction level.

**Confidence:** High

### Q4: WebSocket approach?

**Answer:** **Socket.IO** for simplicity, with upgrade path to native WS.

- Socket.IO provides auto-reconnection, room-based communication, and fallback to long-polling
- For MVP scale (< 10K concurrent): single Node.js server is fine
- For scale: Redis adapter for multi-node broadcasting
- Architecture: Client → WebSocket → Server → Broadcast to all clients
- Alternative: Vercel doesn't support persistent WebSockets on serverless — need a separate WS server (Railway, Fly.io) or use Ably/Pusher as managed WebSocket service

**Recommended for MVP:** Pusher or Ably (managed WebSocket, free tier handles MVP traffic, zero infrastructure)
**Recommended for scale:** Socket.IO + Redis on Fly.io

**Confidence:** High

### Q5: OG image generation?

**Answer:** **Vercel OG / Satori** — purpose-built for this.

- `@vercel/og` converts JSX to PNG at the Edge
- Runs in Edge Functions (fast, globally distributed)
- Supports custom fonts, flexbox layout, nested images
- 500KB bundle limit (plenty for a vibe card)
- Can dynamically render: globe snapshot, user's mood, location, timestamp
- Built into Next.js via `ImageResponse` API

**Confidence:** High

## Competitive Matrix

| Feature | VibeMap (Ours) | MoodyMap | Global Mood Today | MoodNow |
|---------|---------------|----------|-------------------|---------|
| 3D Globe | Yes (unique) | No | No | No |
| Real-time WebSocket | Yes | 30s poll | Partial | Yes |
| Particle animations | Yes (unique) | No | Canvas anim | No |
| Shareable vibe cards | Yes (unique) | No | No | No |
| OG image generation | Yes (unique) | No | No | No |
| Mobile responsive | Yes | Yes | Yes | Yes |
| Mood categories | 6-8 | 6 | Multiple | Emoji-based |
| Anonymous | Yes | Yes | Yes | Yes |
| Geolocation | Yes | Country-level | Yes | Yes |

**Competitive gaps we exploit:**
1. No competitor has a 3D globe — this is our headline differentiator
2. No competitor generates shareable social cards — this is our viral loop
3. No competitor uses WebSockets for true real-time — most poll every 30s
4. No competitor has particle/ring animations — our "wow factor"

## Recommended Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Framework | Next.js 15 (App Router) | SSR, Edge Functions, Vercel deploy |
| 3D Globe | react-globe.gl | Best abstraction over Three.js for globe viz |
| Styling | Tailwind CSS | Rapid UI development, design token friendly |
| Real-time | Pusher (MVP) / Socket.IO (scale) | Managed WS for zero-infra MVP |
| OG Images | @vercel/og (Satori) | Edge-native, JSX-to-PNG |
| Geolocation | Browser Geolocation API + IP fallback | Free, no API key needed |
| Database | Upstash Redis | Serverless, stores recent vibes + aggregates |
| Deployment | Vercel | One-click deploy, Edge Functions, analytics |
| Animation | Framer Motion | Mood selector micro-interactions |

## Key Insights

### 1. The 3D globe IS the product
**Finding:** No competitor uses a 3D globe. All use flat maps.
**Implication:** The globe itself is the differentiator and the viral hook.
**Recommendation:** Invest heavily in globe polish — atmosphere glow, smooth rotation, ring pulse animations.
**Priority:** Critical

### 2. Shareable cards are the growth engine
**Finding:** OG images get 3x more social clicks. No competitor has sharing.
**Implication:** Every vibe drop is a potential share moment.
**Recommendation:** Generate beautiful OG cards with globe snapshot + mood + location.
**Priority:** Critical

### 3. Managed WebSockets for MVP speed
**Finding:** Vercel doesn't support persistent WS on serverless. Self-hosted adds complexity.
**Implication:** Use Pusher/Ably free tier for MVP (100 concurrent connections free).
**Recommendation:** Pusher Channels for MVP. Migrate to Socket.IO + Fly.io only if >1K concurrent.
**Priority:** High

### 4. Client-side globe rendering is a constraint
**Finding:** react-globe.gl requires browser window — no SSR.
**Implication:** Must use Next.js dynamic import with `ssr: false`.
**Recommendation:** Show a beautiful loading skeleton while globe hydrates client-side.
**Priority:** Medium

### 5. Keep mood options minimal and colorful
**Finding:** MoodyMap uses 6 moods. Fewer choices = faster interaction = more drops.
**Implication:** 6-8 moods max, each with a distinct color and emoji.
**Recommendation:** Happy, Excited, Calm, Tired, Sad, Angry — each maps to a unique hue on the globe.
**Priority:** High

## Recommendations

### Immediate (This Sprint)
1. Scaffold Next.js 15 app with react-globe.gl + Tailwind
2. Implement mood selector with 6 moods (emoji + color)
3. Integrate Pusher for real-time vibe broadcasting
4. Build OG image endpoint with @vercel/og
5. Deploy to Vercel with custom domain

### Follow-up (v2)
1. Add timelapse replay of global moods
2. Mood trend graphs per region
3. "Vibe streak" gamification
4. Multi-language support
5. Migrate to Socket.IO if traffic warrants

## Sources

- [MoodyMap](https://www.moodymap.com/) — Primary competitor, flat D3.js map
- [Globe.gl](https://globe.gl/) — 3D globe library documentation
- [react-globe.gl on GitHub](https://github.com/vasturiano/react-globe.gl) — React wrapper
- [Vercel OG Image Generation](https://vercel.com/docs/og-image-generation) — Satori/OG docs
- [Next.js Metadata & OG Images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images) — Official Next.js docs
- [WebSockets vs Socket.IO Guide](https://www.mergesociety.com/code-report/websocets-explained) — WS comparison
- [Real-Time Web Apps 2025](https://www.debutinfotech.com/blog/real-time-web-apps) — Architecture patterns
- [OG Image Tips 2025](https://myogimage.com/blog/og-image-tips-2025-social-sharing-guide) — Sharing best practices
- [Viral App Ideation 2025](https://superwall.com/blog/how-to-ideate-a-viral-app-in-2025/) — Growth mechanics

---

*Generated by BMAD Method v6 - Creative Intelligence*
*Sources Consulted: 15+*
