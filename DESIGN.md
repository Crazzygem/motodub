# DESIGN.md — MotoDub design system (v1, locked)

> **Winner of the UI direction review (2026-08-21): Amber — Tinder-style warm light.**
> This file is the canonical spec for how the app looks and moves. The 8 HTML mockups
> that produced it live in the planning workspace (`motodub-sketch/`) as the visual
> reference; where this file and a mockup disagree, **this file wins**.
> Follow it in Tasks 0.5, 3.3, 3.4, 7.2 and every screen built afterward.

## 1. Direction statement

Warm, playful, card-forward — the product IS "dating with taxis", so the UI leans into
it: big rounded photo cards, taxi-amber primary on a warm near-white canvas, bold Sora
headlines, generous motion. Borrowed from the Dark contender: **muted text hierarchy**
(car/status lines sit visually beneath the name — color + weight, not just size).

## 2. Palette (core tokens)

| Token | Value | Usage |
|---|---|---|
| `bg` | `#FAFAF9` | app canvas |
| `surface` | `#FFFFFF` | cards, sheets, nav |
| `ink` | `#111827` | primary text, dark elements, admin logo mark |
| `amber` | `#F59E0B` | **primary brand** — CTA background, active tabs, asking-rate pill, driver avatar ring |
| `amber-hover` | `#FBBF24` | CTA hover |
| `amber-deep` | `#B45309` | text-on-amber-pill, active nav color |
| `book-green` | `#10B981` | BOOK action, accept, pickup pin, success |
| `pass-red` | `#EF4444` | PASS action, decline, destructive |
| `muted` | `#6B7280` | secondary text |
| `faint` | `#9CA3AF` | tertiary text, placeholders |
| `line` | `#E5E7EB` | borders, dividers |
| `surface-2` | `#F9FAFB` | inset fields, trip boxes |
| `warn-bg` | `#FEF3C7` | asking-rate / pending chips (text `#B45309`) |
| `ok-bg` | `#D1FAE5` | verified chip (text `#047857`) |
| `bad-bg` | `#FEE2E2` | suspended chip (text `#B91C1C`) |

Contrast rule: amber backgrounds **always** carry `ink` text (never white); green/red
CTA carry white text.

## 3. Typography

- Headings: **Sora** 800/700 (loaded via `google_fonts`).
- Body/UI: **Plus Jakarta Sans** 400–800.
- Scale (mobile: 393 pt design width): display 26 · screen title 18–20 · card name 16–17 ·
  body 13.5–14 · meta 11.5–12.5 · micro 10.5.
- Hierarchy = weight + color (Sora 800 ink vs Jakarta 600 muted), never size alone.

## 4. Radius, spacing, elevation

- Cards: **24–28 px radius** (deck cards 28, sheets 32 top, request/admin cards 18–26).
- Chips/pills/toggles: full-round `999`.
- Fields: 14–16 radius, `surface-2` bg, `line` border.
- Screen horizontal padding: 20–22. Card gutters: 14–18.
- Elevation: `0 18px 40px rgba(17,24,39,.18)` cards · `0 -20px 60px … .25` sheets ·
  buttons `0 10px 24px … .16`. Phone frame only in mockups — the app is edge-to-edge.

## 5. Components (anatomy + states)

**Bottom nav (customer app)** — 3 items: Swipe / Trips / Profile. Pill-less,
icon+micro-label column; active = `amber-deep` icon, inactive `#9CA3AF`. Border-top `line`.

**Driver swipe card (the showpiece)** — anatomy, top→bottom:
1. Full-bleed photo (`object-fit: cover`), muted `saturate(.9)`.
2. Gradient shade: transparent→42%, tint 58%, `ink .85` 100%.
3. "MOTODUB" watermark (Sora 800, 13, white 75%, letterspaced) top-left.
4. Info block bottom: name (Sora 800 26) + rating chip (star ★, `ink .55` glass, amber
   star `#FCD34D`); car line (Jakarta 600 13.5, white 85%); chips row — ETA chip
   (glass, white) + asking-rate pill (**amber bg, ink text**).
5. Stack peek: next 2 cards scaled `.945`/`.89`, `translateY` 14/28, `brightness(.88)`,
   z-order **10/9/8** (front card always on top).
6. Fling overlays: "BOOK" (green text+border, rotate −12°) / "PASS" (red, +12°),
   opacity ∝ drag.

**Deck empty state** — 🛺 emoji 52, Sora 800 20 title, muted body, ink Refresh pill.

**Booking sheet** — grab handle; driver mini-header (photo 52 with amber ring 2.5px,
name, meta, asking-rate badge); fake-map→**real flutter_map** 170px: **pickup pin
`book-green`, dropoff pin `amber`, dashed amber route**, ETA ribbon (ink .82 glass,
white 11.5 700); two address fields (green/amber dot icons); footer: cash chip
(warn-bg/amber-deep) + CTA "Request {Name} →" (amber, ink, Sora 800 15, radius 18);
note line (faint 11.5). Success overlay: centered card, 💛, "Request sent!", pulse chip
with blinking amber dot.

**Driver app** — earnings pill top-right (surface + line border, `amber-deep` figure).
Status card: dot (grey offline → green online w/ glow ring), Sora 800 title, hint line;
toggle 58×32 (`line` bg, white knob → `book-green` + knob right, 250ms).
Request card: customer avatar + name/rating/trips, amber trip-km pill, pickup (green
dot rail) → dropoff (ink dot) block + distance meta; Accept (`book-green`, white) /
Decline (white bg, red text, red border) buttons 50/50.
Ride panel: 4-step stepper (Accepted → On my way → Riding → Done; done=green,
active=amber, pending=line) + ride-control CTA (amber → "On my way", "Start ride",
"End ride ✓", final state green "Completed 🎉").

**Admin** — header: ink logo mark w/ amber M, "ADMIN" warn-bg tag. Tabs: pill row,
active = **ink bg white text** (admin-only inversion of customer tabs). KPI cards 2×2
(surface, Sora 800 24, live figure `amber-deep`). Live feed: ink bar, blinking green
dot, white bold event line. Status chips: verified `ok-bg/#047857` · pending
`warn-bg/#B45309` · suspended `bad-bg/#B91C1C` · offline `line/#6B7280`.
Actions: Approve = ink pill; destructive (Suspend) = red-tinted; **destructive &
verification actions live in confirm modal dialogs** (dim ink overlay + blur, surface
card, pop-in .35s, cancel + confirm buttons).

## 6. Motion spec

| Motion | Spec |
|---|---|
| Deck drag | `transform: translate(dx, dy·.35) rotate(dx/16deg)`; BOOK/PASS opacity `clamp(\|dx\|/110, 0, 1)` |
| Deck release < 110px | spring-back `.35s cubic-bezier(.2,.8,.3,1.2)` |
| Deck release ≥ 110px | fly-out `.45s ease-in`, translate ±640, rotate ±34°, fade; next card in |
| Sheet slide-up | `.45s cubic-bezier(.2,.9,.3,1)` from +420px |
| Modal / success pop | `.35–.4s cubic-bezier(.2,.9,.3,1.3)` scale .85→1 |
| Status dot / feed pulse | 1s blink, opacity .25 (driver online dot, admin live feed) |
| Button press | scale `.96–.97`, 100ms |
| Toggle | 250ms knob slide + bg |

Rules: no motion longer than .5s; state changes animate **in**, never draw attention
on exit (except the fly-out, which IS the gesture).

## 7. Maps

`flutter_map` + **light OSM tiles** (no key). Pins: pickup `book-green`,
dropoff `amber`, dashed amber route. ETA ribbon glass-over-map. In the real app the
map sits on `surface` — no dark-map theming needed (another reason Amber won).

## 8. Imagery & avatars

- **Driver cards are photo-first** ⇒ every seeded driver needs a portrait. Production:
  bundle 6 portraits in `app/assets/avatars/driver_{1..6}.jpg` (same people as the
  seeded accounts); customer avatars in-app = initials circle
  (`conic` amber gradient, ink letter, white 2px ring). Mockups used pravatar.cc — swap
  for bundled assets in Task 2.2/3.3.
- Avatar fallback everywhere: initials tile, no broken-image icons.

## 9. States (never ship a blank screen)

Loading = skeleton blocks (surface, `line` shimmer) · error = mapped message banner
(ARN codes → friendly copy, see ARCHITECTURE §4) + retry · empty = emoji + Sora title
+ muted body + action. All lists: skeleton / error-retry / empty / content.

## 10. Design debts (accepted)

1. No dark mode (Dark direction rejected; `amber` on `ink` admin bar is the only dark
   surface). 2. Motion tuned by feel on-device at Task 3.6 — thresholds above are the
   starting calibration. 3. Booking sheet map is a static pin editor in v1 (no
   geocoding, per ARCHITECTURE §15). 4. Status chips take `--muted` when a ride is
   cancelled/declined (history screen only).