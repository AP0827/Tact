# Tact — Phase-by-Phase Project Tracker

Merged roadmap combining **PRODUCT_SPEC.md** (architectural phases, definitions of done, gates) and **PRIORITY_FEATURES.md** (practical build order, priorities, version grouping).

## Status legend

| Marker | Meaning |
| ------ | ------- |
| `[x]`  | Complete |
| `[~]`  | Partial / in progress |
| `[ ]`  | Not started |

## Priority scale (from PRIORITY_FEATURES.md)

**S** build immediately · **A** high priority · **B** after core · **C** useful/expected · **D** later · **E** last

Guiding principle:

> First make Tact useful without customization. Then make it powerful. Then make it intelligent. Only after that make it infinitely customizable. → **glance → understand → act**.

---

## Summary table

| # | Phase | Merged version | Status | Priority |
| - | ----- | -------------- | ------ | -------- |
| 0 | Foundation / Proof of Concept | V0.1 | COMPLETE | S |
| 1 | Developer Control Surface | V0.1 | ~80% complete | S |
| 2 | Developer State & Event System | V0.2 | ~40% complete | S |
| 3 | Developer Cockpit / Home | V0.3 | ~40% complete | S |
| 4 | PC Companion | V0.4 | ~40% complete | A |
| 5 | Developer Workflows | V0.5 | Not started | C+ |
| 6 | Deep Developer Integrations | V0.6 | Not started | B+ |
| 7 | Context-Aware Tact | V0.7 | Not started | A |
| 8 | Glanceability & Mobile UX | V0.8 | Not started | B |
| 9 | Plugin / Customization Platform | V0.9 | Not started | D |
| 10 | AI Workspace Generation + Assistant | V1.0 | Not started | E |
| 11 | Productization (beta / commercial / cloud) | V1.1 | Not started | — |
| 12 | Physical Tact Hardware | V2.0 | Not started | — |

**Current position:** Phase 0 complete; Phase 1 nearly complete (Docker missing). Active work is **Phase 2 + Phase 3** (developer state + cockpit) per Iteration A/B below.

---

## PHASE 0 — FOUNDATION / PROOF OF CONCEPT

**Sources:** PRODUCT_SPEC §6 · PRIORITY_FEATURES V0.1

**Goal:** Prove `Phone → Tact Agent → laptop action` end-to-end.

| Status | Item |
| ------ | ---- |
| [x] | Python desktop agent runs (`python -m tact.agent`) |
| [x] | Mobile client renders Tact interface |
| [x] | WebSocket connection over LAN |
| [x] | Safe, allowlisted laptop action (action registry) |

**Success criterion:** Open Tact on a phone → see interface → press a button → laptop responds immediately.

**Status: COMPLETE**

---

## PHASE 1 — DEVELOPER CONTROL SURFACE

**Sources:** PRODUCT_SPEC §7 · PRIORITY_FEATURES V0.1–V0.2, Phase 1–2 (rank 1–8)

**Goal:** Prove Tact is useful during a real coding session. Integrations: System, VS Code, Git, Docker.

### Desktop agent

| Status | Item |
| ------ | ---- |
| [x] | Start locally, expose HTTP/WebSocket server |
| [x] | Determine local network address |
| [x] | Accept mobile connection, maintain state, handle disconnect/reconnect |
| [x] | Send initial state, receive + execute actions |
| [x] | Emit events (event bus exists) |

### Mobile client

| Status | Item |
| ------ | ---- |
| [x] | Responsive Flutter app (4 tabs: System / Developer / Media / Events) |
| [x] | Portrait, touch-friendly, information-dense, dark theme |
| [ ] | Declarative layout protocol (agent describes UI) — *currently hardcoded Flutter tabs* |

> Note: PRODUCT_SPEC §23 specifies a React/Vite/Tailwind web client; the implementation moved to a **Flutter app** (`app/`). This is an accepted architectural deviation — the tracker follows the actual stack.

### System integration

| Status | Item |
| ------ | ---- |
| [x] | CPU / RAM / disk gauges |
| [x] | Volume get/set/up/down (pactl) |
| [x] | Mute |
| [x] | Lock screen |
| [x] | Screenshot |
| [x] | Open terminal / open project / open URL |
| [ ] | Battery, hostname, OS, uptime |

### VS Code

| Status | Item |
| ------ | ---- |
| [x] | Open workspace |
| [x] | Active workspace detection (workspaceStorage parsing, mtime-sorted) |
| [x] | Status (running/available) |

### Git

| Status | Item |
| ------ | ---- |
| [x] | status (branch, clean/dirty, changed files, ahead/behind) |
| [x] | add / pull / push / commit / switch branch |
| [x] | log (commit graph) / tree |
| [x] | Repo discovery |

### Docker

| Status | Item |
| ------ | ---- |
| [ ] | Container list (name, state, image, uptime) |
| [ ] | start / stop / restart / logs |
| [ ] | Status widget on phone |

**V0.1 → V0.2 gate:** working phone client, reliable connection, safe actions, system telemetry, VS Code, Git, Docker, declarative UI, persistence, pairing. *(Docker + declarative UI outstanding.)*

**Status: ~80% COMPLETE** — all system/git/vscode work; **Docker integration missing**.

---

## PHASE 2 — DEVELOPER STATE & EVENT SYSTEM

**Sources:** PRODUCT_SPEC §8 · PRIORITY_FEATURES Phase 2–3, Iteration B (ranks 2, 3, 4, 6, 19)

**Goal:** Move Tact from *remote control* to *developer companion* with a unified state model (`✓ HEALTHY / ● RUNNING / ⚠ ATTENTION / ✕ FAILED`). **Tact tells the developer when something important happens.**

### Event bus

| Status | Item |
| ------ | ---- |
| [x] | Central `EventBus` (Event: type, timestamp, severity, source, title, message, data, actions) |
| [x] | git.state_changed events (state monitor) |
| [x] | vscode.state_changed events (state monitor) |
| [x] | Event feed broadcast over WebSocket |
| [ ] | build.started / succeeded / failed |
| [ ] | tests.started / passed / failed |
| [ ] | container.started / stopped / failed (needs Phase 1 Docker) |
| [ ] | battery.low / high.resource_usage |

### Build / test state

| Status | Item |
| ------ | ---- |
| [ ] | Build status detection (VS Code tasks / shell) |
| [ ] | Test status detection (runner output parsing) |
| [ ] | Unified status cards: BUILD / TESTS / DOCKER / GIT / CI |

### Actionable notifications

| Status | Item |
| ------ | ---- |
| [ ] | Notifications carry actions (e.g. Build failed → `[OPEN] [REBUILD] [DEBUG]`) |
| [ ] | Execute action directly from the phone |
| [ ] | Event feed filtering (severity / source / type) |

### CI (eventually)

| Status | Item |
| ------ | ---- |
| [ ] | CI status: `● Running · lint ✓ tests ✓ build ●` |

**V0.2 → V0.3 gate:** central event bus, build/test/docker/git events, actionable notifications, event feed, real-time delivery, robust security.

**Status: ~40% COMPLETE** — event bus + git/vscode events + feed exist. Build/test/docker events and actionable notifications remain.

---

## PHASE 3 — DEVELOPER COCKPIT / HOME

**Sources:** PRODUCT_SPEC §9 · PRIORITY_FEATURES Phase 1, Iteration A (ranks 1, 5, 15)

**Goal:** Turn Tact into a persistent developer dashboard. The question on open is *"What's going on with my work?"* — not "how much RAM am I using?"

### Information architecture (Iteration A)

| Status | Item |
| ------ | ---- |
| [x] | System tab (CPU/RAM/disk gauges) |
| [x] | Developer tab (repo selector, git ops, commit graph, VS Code workspaces) |
| [x] | Media tab |
| [x] | Events tab |
| [ ] | **Home** — development health + attention + quick actions (hero area) |
| [ ] | **Workspace** — current project view |
| [ ] | **Controls** — PC + Media + Developer controls |

Proposed home layout (from PRIORITY_FEATURES):

```text
TACT
MTWS · main · Clean
BUILD        ✓ Passing
TESTS        124 / 124
GIT          ↑ 2 commits
DOCKER       ● api ● postgres ⚠ redis
ATTENTION    ⚠ Redis stopped  [RESTART] [LOGS]
QUICK ACTIONS [RUN] [TEST] [BUILD] [GIT] [TERM] [DOCKER]
```

### Workspace model

| Status | Item |
| ------ | ---- |
| [x] | `system.set_workspace` action + current workspace in snapshot |
| [~] | Repo selector (folder-name labels) |
| [ ] | Workspace abstraction: Layout / Widgets / Actions / Integrations / Preferences |
| [ ] | Multiple pages (Development, Infrastructure, Communication, Media, System) |
| [ ] | Workspace state persistence |
| [ ] | Rich widget library (metric, status, progress, log, graph, timer) |

**V0.3 → V0.4 gate:** useful dashboard, multiple layouts/pages, rich widgets, persistent workspace.

**Status: ~40% COMPLETE** — Developer tab + workspace state exist. Home/health hero, build/test/docker cards, widget library, and persistence pending.

---

## PHASE 4 — PC COMPANION

**Sources:** PRODUCT_SPEC §11 (productivity/communication) · PRIORITY_FEATURES Phase 4–5, Iteration C (ranks 7, 8, 9, 10, 11, 12, 14, 24)

**Goal:** Make Tact useful even when not coding — for retention.

| Status | Item | Priority |
| ------ | ---- | -------- |
| [x] | Media control (transport, now-playing, seek, quick-open Spotify/YouTube) | A |
| [x] | Volume / audio-device control (system volume via pactl, per-player MPRIS) | A |
| [ ] | Brightness control + screen dimming | A |
| [ ] | Open / focus applications (VS Code, Chrome, Terminal, Teams, Docker) | A+ |
| [ ] | Remote lock / wake / screen control | A |
| [ ] | Clipboard: view recent clips, send phone text to clipboard/terminal/app | A+ |
| [ ] | Quick Capture (send text to clipboard / file / terminal / project notes) | B |
| [ ] | Notification mirroring → **developer filtering only** (build/test/CI/GitHub/Docker/meetings), not raw dump | B |
| [ ] | Find / locate cursor | B |

**Status: ~40% COMPLETE** — media + system volume done; brightness, clipboard, open-app, lock/wake remain.

---

## PHASE 5 — DEVELOPER WORKFLOWS

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 6 (rank 26)

**Goal:** Predefined developer workflows first; custom builder later. Differentiator = *developer workflows*, not "we also have macros".

| Status | Item |
| ------ | ---- |
| [ ] | Predefined workflows: **Start Work**, **Debug Environment**, **Meeting** (open apps + state changes) |
| [ ] | Multi-action macro execution (sequential actions with confirmation where dangerous) |
| [ ] | Custom command builder (later) |

Example "Meeting": open Teams → pause Spotify → volume 40% → Do Not Disturb → open meeting.

**Status: NOT STARTED**

---

## PHASE 6 — DEEP DEVELOPER INTEGRATIONS

**Sources:** PRODUCT_SPEC §11, §13.2 · PRIORITY_FEATURES Phase 7 (ranks 17, 18, 19, 21)

**Goal:** Make Tact useful across the full workday.

| Status | Item | Priority |
| ------ | ---- | -------- |
| [ ] | GitHub / GitLab: PR status, CI check, reviews, comments, open | B+ |
| [ ] | Database status/control (PostgreSQL: connections, queries/s, CPU) | B+ |
| [ ] | Process / service monitor | B+ |
| [ ] | Terminal jobs + output (`npm test`, `docker build`, `pytest` with live status) | S |
| [ ] | Find / open specific file | B |
| [ ] | Meeting controls (Teams/Slack/Zoom: mute, camera, share, timer) | B+ |
| [ ] | AI-tool integration foundations (open ChatGPT/Claude/Gemini, send prompt) | — |

**Status: NOT STARTED**

---

## PHASE 7 — CONTEXT-AWARE TACT

**Sources:** PRODUCT_SPEC §10 · PRIORITY_FEATURES V0.7 (ranks 20, 28, 29)

**Goal:** Tact understands *what the developer is doing right now* and surfaces relevant controls.

| Status | Item |
| ------ | ---- |
| [ ] | Context engine: active app / window / project / repo / branch / running services |
| [ ] | Context-aware layouts (VS Code → Development, Spotify → Media, Teams → Meeting) |
| [ ] | Development workflow detection (VS Code + Terminal + Docker + Git + DB → Development workflow) |
| [ ] | User override of automatic context selection |

Long-term context formula: `Application + Project + Workflow state + Events → Context → Relevant interface`.

**Status: NOT STARTED**

---

## PHASE 8 — GLANCEABILITY & MOBILE UX

**Sources:** PRODUCT_SPEC §15.3 · PRIORITY_FEATURES Phase 8 (rank 23)

**Goal:** Interact with Tact without opening the full app.

| Status | Item |
| ------ | ---- |
| [ ] | Android home-screen widget (workspace health: build ✓ / tests ✓ / ⚠ redis) |
| [ ] | Media widget (`◀ ▶/❚❚ ▶` + volume) |
| [ ] | Notification-area quick actions |
| [ ] | PWA polish (if web client returns) / native notification + haptics where justified |

**Status: NOT STARTED**

---

## PHASE 9 — PLUGIN / CUSTOMIZATION PLATFORM

**Sources:** PRODUCT_SPEC §14, §19 · PRIORITY_FEATURES V0.8 (ranks 28–30, 32)

**Goal:** Let developers extend Tact without touching core. *Deliberately after core workflows.*

| Status | Item |
| ------ | ---- |
| [ ] | Stable integration/plugin API (actions, events, widgets, layouts, context providers) |
| [ ] | Plugins cannot bypass security boundaries |
| [ ] | Profiles / pages / custom widgets / variables |
| [ ] | Marketplace (only after plugin model stable + demand) |

**Status: NOT STARTED**

---

## PHASE 10 — AI WORKSPACE GENERATION + ASSISTANT

**Sources:** PRODUCT_SPEC §12, §13 · PRIORITY_FEATURES V0.9 (ranks 30, 31)

**Goal:** Reduce configuration burden; AI as multiplier, not the product. **Deliberately last.**

| Status | Item |
| ------ | ---- |
| [ ] | Inspect authorized environment → offer workspace generation |
| [ ] | Generate valid Tact UI primitives with allowlisted actions |
| [ ] | User edits generated workspace |
| [ ] | Provider-agnostic (OpenAI / Anthropic / Google / local) |
| [ ] | Build-failure assistant: `[OPEN] [EXPLAIN] [DEBUG WITH AI] [REBUILD]` |
| [ ] | Relevant-context gathering + explicit confirmation for any code modification |

**Status: NOT STARTED**

---

## PHASE 11 — PRODUCTIZATION

**Sources:** PRODUCT_SPEC §15, §16, §17, §18 · PRIORITY_FEATURES V1.0

| Status | Item |
| ------ | ---- |
| [ ] | Simple install (no Python commands): `Download → Install → Start → QR → Connected` |
| [ ] | Desktop packaging (Windows / Linux / macOS) |
| [ ] | Polished onboarding, pairing, error handling, updates, docs |
| [ ] | Performance + reliability + diagnostics (opt-in) |
| [ ] | Free/Pro boundary (validated, not assumed) |
| [ ] | Cloud / sync only after demonstrated need (local-first remains fundamental) |

**Status: NOT STARTED**

---

## PHASE 12 — PHYSICAL TACT HARDWARE

**Sources:** PRODUCT_SPEC §20, §21 · PRIORITY_FEATURES (hardware much later)

**Principle:** hardware is *another client of the Tact platform*, never the foundation. Build only if software usage demonstrates demand for physical controls.

**Status: NOT STARTED**

---

## Recommended development-time allocation (PRIORITY_FEATURES)

> **40% Developer State/Events → 25% UI/UX → 20% Developer Actions/Workflows → 15% PC utilities. 0% AI. 0% plugin marketplace. 0% elaborate customization.**

### Next three iterations

| Iteration | Focus | Maps to |
| --------- | ----- | ------ |
| **A** | UI overhaul: Home / Workspace / Controls / Events IA | Phase 3 |
| **B** | Developer state: Build / Tests / Docker / Git / CI / Terminal jobs | Phase 2, 6 |
| **C** | Daily utility: Clipboard, Quick Capture, Brightness, Dim, Volume, Media, Open App, Lock, Wake | Phase 4 |

**Immediate next work (current session):** finish Phase 2 developer state (Docker first, then build/test events + actionable notifications) and Phase 3 Home hero — the two highest-value, S-priority gaps.