# Feature Brief: VibeMap

**Created:** 2026-03-23
**Status:** Draft

---

## Problem

There's no fun, visual way to see how the world is feeling right now. Social media is noisy and text-heavy. People want a quick, beautiful, shareable way to express and explore collective mood — a living emotional pulse of the planet. Current mood-tracking apps are private and clinical; there's nothing that turns collective emotion into art.

---

## Proposed Solution

VibeMap is a real-time interactive 3D globe where visitors drop their current "vibe" — a mood, emoji, and color. Vibes appear as glowing pulses on the globe at the visitor's location, creating a mesmerizing, ever-changing visualization of global mood. WebSocket connections keep the globe updating live. Visitors can explore hotspots, see mood trends by region, and generate shareable "vibe cards" — beautiful OG-image snapshots of their contribution on the globe.

---

## Target Users

**Primary:** Social media users (18-35) who love aesthetic, shareable micro-interactions — the kind of people who share Spotify Wrapped, wordle scores, and personality quizzes.

**Secondary:** Developers and designers who appreciate beautiful web experiences and will share it in tech communities (HN, Twitter/X, Reddit).

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | 3D globe (Three.js/Globe.gl), WebSockets for real-time, serverless-friendly backend |
| Timeline | MVP in 1 sprint (6 days) |
| Team | Solo engineer + Claude autonomous pipeline |
| Integration | Geolocation API for visitor location, OG image generation for social sharing |

---

## Scope

### In Scope
- Interactive 3D globe with smooth rotation and zoom
- Mood selector (6-8 core moods with emoji + color mapping)
- Real-time vibe drops appearing as animated pulses on the globe
- Live mood statistics (global mood breakdown, trending vibes)
- Shareable "vibe card" with OG meta tags for social sharing
- Responsive design — works beautifully on mobile and desktop
- Smooth animations and micro-interactions throughout

### Out of Scope
- User accounts or authentication
- Historical data / analytics dashboard
- Native mobile app
- Moderation system (v2)
- Monetization features
- Multi-language support (v2)

---

## Feature Name

**Kebab-case identifier:** `vibe-map`

**Folder:** `docs/vibe-map/`

---

## Notes

- Viral mechanic: the shareable vibe card creates a natural sharing loop — "I just vibed from Lusaka" with a gorgeous globe snapshot
- Prior art: Globe.gl demos, Spotify Wrapped, r/place — combines the best of real-time collaboration and beautiful data viz
- Tech inspiration: Three.js globe visualizations, WebSocket-based live dashboards
- The "drop a vibe" interaction should feel magical — particle burst, sound effect, satisfying haptic-like animation
