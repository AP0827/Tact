# Tact — Phase-by-Phase Project Tracker

Merged roadmap combining **PRODUCT_SPEC.md** (architectural phases, definitions of done, gates), **PRIORITY_FEATURES.md** (practical build order, priorities, version grouping), and the **Tact Surface** concept (context-first UI modeled on Apple's Touch Bar interaction model).

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

## THE TACT SURFACE — core product concept

The product is **not** a collection of feature tabs. It is a **contextual surface for the developer's entire computer** — the interaction model of Apple's Touch Bar taken much further (more screen real estate, understanding the whole computer, not just the focused app).

### What the user should experience

> "The controls I need are appearing where I need them."

Tact knows:

```text
Active App: VS Code
Project: MTWS
Branch: main
```

And dynamically produces the relevant controls — **controls change when the developer changes what they're doing.**

### Three-layer model

```text
┌─────────────────────────────────┐
│         CONTEXT SURFACE         │
│     changes with active app     │
│   VS Code → Run/Debug/Test      │
│   Terminal → Jobs/Logs          │
│   Teams → Meeting controls      │
│   Chrome → Browser controls     │
│   Spotify → Transport           │
├─────────────────────────────────┤
│         WORKSPACE STATE         │
│   Build ✓   Tests ✓   Git ↑2   │
│   Docker ●●⚠   CI ●             │
│   (always visible "mini display")│
├─────────────────────────────────┤
│         CONTROL STRIP           │
│   🔊 Volume   ☀ Brightness      │
│   ▶ Media    🔒 Lock            │
│   (persistent, always present)  │
└─────────────────────────────────┘
```

### Navigation model (replaces the 4 feature tabs)

```text
                    TACT
                     │
        ┌────────────┼────────────┐
        ↓            ↓            ↓
    CONTEXT       ALWAYS-ON     ATTENTION
        │         CONTROLS         │
        ↓            ↓              ↓
     VS Code      Volume         Build failed
     Chrome       Brightness     Test failed
     Teams        Media          Docker down
     Spotify      Lock           PR review
     Terminal     Screenshot     Meeting
```

The user should never think *"I need to go to Developer → Git → Repository → …"* — Tact surfaces the relevant controls.

### Five adopted Touch Bar principles

1. **Contextual controls (#1)** — controls change with the active application. Start with five excellent contexts (VS Code, Terminal, Chrome, Spotify, Teams), not 50 mediocre ones.
2. **Persistent Control Strip (#2)** — small always-present bottom strip (volume / brightness / media / lock). Media controls live here, not in their own nav tab.
3. **Glanceable state (#3)** — workspace health at the top at all times (Build ✓ / Tests ✓ / Git ↑2 / ⚠ Docker). Improves on the Touch Bar, which was input-only.
4. **Contextual gestures (#4)** — touch-native: swipe between contexts, swipe media cards (previous/next), drag sliders, swipe to dismiss events.
5. **Contextual information + action together (#5)** — interface changes on **state**, not just app:

```text
BUILD
✓ Passing
Last run: 2m ago

[REBUILD]
```

```text
BUILD
✕ FAILED
main.go:182 · undefined: foo

[OPEN] [DEBUG] [REBUILD]
```

### Tact's evolution formula

```text
Active App + Project + Current State + Recent Events → TACT SURFACE
```

---

## Summary table

| # | Phase | Merged version | Status | Priority |
| - | ----- | -------------- | ------ | -------- |
| 0 | Foundation / Proof of Concept | V0.1 | COMPLETE | S |
| 1 | Developer Control Surface | V0.1 | ~95% complete | S |
| 2 | Context Engine | V0.2 | ~80% complete | S |
| 3 | Contextual Controls (context surfaces) | V0.3 | Not started | S |
| 4 | Persistent Control Strip | V0.4 | ~40% complete | A |
| 5 | Glanceable Developer State | V0.5 | ~50% complete | S |
| 6 | Actionable Events / Attention | V0.5 | ~30% complete | S |
| 7 | Clipboard / Quick Capture | V0.6 | ~50% complete | A+ |
| 8 | Developer Workflows | V0.7 | Not started | C+ |
| 9 | Deep Developer Integrations | V0.8 | Not started | B+ |
| 10 | Glanceability / Widgets / Lock screen | V0.9 | Not started | B |
| 11 | Plugin / Customization Platform | V1.0 | Not started | D |
| 12 | AI Workspace Generation + Assistant | V1.1 | Not started | E |
| 13 | Productization (beta / commercial / cloud) | V1.2 | Not started | — |
| 14 | Physical Tact Hardware | V2.0 | Not started | — |

**Current position:** Phases 0–1 complete; **Phase 2 Context Engine ~80% done** (detection, project/branch resolution, workflow map, override, `context.changed`, phone banner — all live). Next: Phase 2 signal aggregation → **Phase 3 Contextual Controls** (surface switching), the identity-defining work per the Tact Surface model.

**Modularity note (built into Phase 2 work):** the agent runs on the Integration pattern with **folder-per-app separation** — `integrations/<name>/` (integration.py + helper files like state.py/apps.py/detection.py) registered explicitly in `ActionRegistry`, generic `StateMonitor`. Adding a capability (figma, video editing) is one new folder + one registry line; see `tact/agent/integrations/README.md`.

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
| [x] | Responsive Flutter app (currently 4 tabs: System / Developer / Media / Events) |
| [x] | Portrait, touch-friendly, information-dense, dark theme |
| [ ] | Declarative layout protocol (agent describes UI) — *currently hardcoded Flutter tabs; replaced by Tact Surface in Phase 2–3* |

> Note: PRODUCT_SPEC §23 specifies a React/Vite/Tailwind web client; the implementation moved to a **Flutter app** (`app/`). Accepted architectural deviation — tracker follows the actual stack.

### System integration

| Status | Item |
| ------ | ---- |
| [x] | CPU / RAM / disk gauges |
| [x] | Volume get/set/up/down (pactl) |
| [x] | Mute |
| [x] | Lock screen |
| [x] | Screenshot |
| [x] | Open terminal / open project / open URL |
| [x] | Battery level + charging state (psutil sensors_battery) |

> Note: hostname / OS / uptime are deliberately **not** planned — they add no glanceable value for the phone surface.

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
| [x] | Container list (name, state, image, uptime) via `docker ps -a` |
| [x] | start / stop / restart / logs actions |
| [x] | Docker status in snapshot + `docker.state_changed` events (StateMonitor) |
| [x] | Graceful degradation: permission-denied / daemon-down reported to UI |
| [ ] | Status widget in the glanceable Workspace State layer (Phase 5) |

**V0.1 → V0.2 gate:** working phone client, reliable connection, safe actions, system telemetry, VS Code, Git, Docker, declarative UI, persistence, pairing. *(Declarative UI outstanding — superseded by Tact Surface in Phase 2–3.)*

**Status: ~95% COMPLETE** — system/git/vscode/docker/clipboard/battery all working. Declarative UI replaced by the Tact Surface model in Phase 2–3.

---

## PHASE 2 — CONTEXT ENGINE

**Sources:** PRODUCT_SPEC §10 · PRIORITY_FEATURES Phase 7, V0.7 · Tact Surface concept #1

**Priority: S — the #1 priority.** This is the foundation of the Tact Surface. Nothing contextual works without it.

**Goal:** Tact understands *what the developer is doing right now*: active app, project, repo, workflow.

### 2.1 Active application detection

| Status | Item |
| ------ | ---- |
| [x] | **Detect focused window/app** — On X11: read `_NET_ACTIVE_WINDOW` via `xprop -root` + `WM_CLASS`/`_NET_WM_NAME` (xdotool fallback). Map window class/title → friendly app name (vscode, terminal, chrome, teams, spotify). |
| [x] | **Emit into snapshot** — `snapshot.context = {active_app, window_title, project, branch, workflow, override}`. Broadcast on change (not on every poll). |
| [x] | **Integration whitelist** — `ContextIntegration.APP_MAP` maps detected apps to a known context id; unknown apps → workflow `null` (fallback surface in Phase 3). |

### 2.2 Project / repo resolution

| Status | Item |
| ------ | ---- |
| [x] | **Derive project from window title** — For editors/terminals, parse the folder/basename out of the title (e.g. "main.dart — Tact"). |
| [x] | **Derive branch** — Use `git discover_root` + `git status` on the resolved path; attach `branch`. |
| [x] | **Workspace fallback** — If no project resolvable from window, fall back to the agent's current workspace (`system.set_workspace`). |

### 2.3 Workflow detection

| Status | Item |
| ------ | ---- |
| [~] | **Multi-app signal aggregation** — Current: active-app → workflow map (`development`, `meeting`, `media`, …). Full aggregation (docker + git activity signals) pending. |
| [x] | **Surface context object** — Produce `snapshot.context.workflow` so Phase 3 can choose a surface. |

### 2.4 Context change notification

| Status | Item |
| ------ | ---- |
| [x] | **Push on change** — Broadcast `context.changed` event over WebSocket when active app or project changes; client switches surface without a manual refresh. |
| [x] | **User override** — `context.override` / `context.clear_override` actions pin/clear the auto context from the app (survives until next explicit unpin). |

**Context engine rules (reference):**

```text
active_app = focused_window_class  (xprop _NET_ACTIVE_WINDOW + WM_CLASS)
project    = parse(window_title)  ?? current_workspace
branch     = git(project).branch
workflow   = WORKFLOW_MAP[active_app]  (signal aggregation pending)
```

**Status: ~80% COMPLETE** — detection, project/branch resolution, workflow map, override, and `context.changed` all live (`integrations/context.py`); snapshot + phone banner (ContextBanner) shipped. Remaining: signal aggregation (docker/git inputs) and surface switching (Phase 3).

---

## PHASE 3 — CONTEXTUAL CONTROLS (CONTEXT SURFACES)

**Sources:** PRODUCT_SPEC §10.2, §11 · PRIORITY_FEATURES Phase 1, 5 · Tact Surface concept #1, #5

**Priority: S.** Five excellent contexts are more valuable than 50 mediocre ones.

**Goal:** The Context Surface layer — controls change with the active app. Each surface = a set of actions + a state card, rendered when the matching context is active.

### 3.1 Surface framework (shared)

| Status | Item |
| ------ | ---- |
| [ ] | **Surface registry** — Map `context_id → surface definition` (title, action buttons, state widget). Shared across all contexts so adding Chrome ≠ copying code. |
| [ ] | **Surface widget** — A Flutter widget that renders the active surface: action grid + optional state card (build/tests/git per context). |
| [ ] | **Fallback surface** — For unknown apps, show generic system controls (volume, lock, screenshot, open terminal) so the surface is never empty. |

### 3.2 VS Code surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Run | Execute the active project's run task (agent: `vscode.run` via `code --command workbench.action.tasks.runTask` or `code --run`). Show running state + elapsed. |
| [ ] | Debug | Launch debug session (`workbench.action.debug.start`); stop/continue on second tap. |
| [ ] | Test | Run tests (`workbench.action.tasks.test`); surface pass/fail count via state card. |
| [ ] | Build | Run build task; reflect build state in the workspace state layer. |
| [ ] | Terminal | Open integrated terminal in project (`workbench.action.terminal.new`). |
| [ ] | Git | Open source control panel (`workbench.view.scm`); quick actions: pull / push / stage all. |
| [ ] | State card | Build ✓/✕ + last run time; test counts; git branch ↑2. |

### 3.3 Terminal surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | New | Open a new terminal window at the current workspace (reuse `system.open_terminal`). |
| [ ] | Clear | Send `clear` to the focused terminal (agent keys via `ydotool`/`xdotool` or a thin tty bridge). |
| [ ] | Rerun | Repeat the last executed command (agent keeps a per-terminal command history). |
| [ ] | Copy output | Copy the last command output to the clipboard. |
| [ ] | Kill | Send Ctrl-C / close the running foreground job. |
| [ ] | State card | Running job name + elapsed time (Phase 9 terminal jobs feed this). |

### 3.4 Chrome surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Back / Forward / Refresh | Browser nav via `xdotool key ctrl+Left` etc., or a Chrome DevTools Protocol (CDP) connection to the running instance. |
| [ ] | New tab / Close tab | CDP `Target.createTarget` / `Page.close`. |
| [ ] | DevTools | CDP open devtools for active tab. |
| [ ] | Copy URL | CDP `Page.getNavigationHistory` → copy current URL to clipboard. |
| [ ] | State card | Active tab title + URL (from CDP). |

### 3.5 Spotify surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Previous / Play-Pause / Next | Reuse `media.previous/play_pause/next` (playerctl **with xdotool media-key fallback** — snap Spotify's MPRIS registration drops intermittently; XF86Audio keys keep working). |
| [ ] | Volume | Reuse `system.volume` / `media.volume` slider (already implemented). |
| [ ] | State card | Now-playing title/artist + position (already in `media.status` details). |

### 3.6 Teams surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Mute / Camera | Toggle via `xdotool` key combos (Ctrl+Shift+M / Ctrl+Shift+O) targeting the Teams window, or a Teams accessibility bridge. |
| [ ] | Screen share | Start/stop share (Ctrl+Shift+E), confirm prompt state. |
| [ ] | Leave | End call (Ctrl+Shift+B). |
| [ ] | State card | Meeting state + duration (Phase 9 meeting controls feed this). |

### 3.7 Contextual gestures

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Swipe between contexts | Horizontal swipe swaps surface (`VS Code ⇄ Terminal ⇄ Docker`); respect user's pinned override. |
| [ ] | Swipe media card | Left/right swipe on now-playing = previous/next. |
| [ ] | Swipe to dismiss event | Swipe an attention event away (marks read, does not dismiss the underlying state). |
| [ ] | Drag sliders | Volume/brightness/seek are drag sliders (volume already is; ensure brightness + seek match). |

**Status: NOT STARTED**

---

## PHASE 4 — PERSISTENT CONTROL STRIP

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 4–5, Iteration C (ranks 9, 10, 11, 12, 14) · Tact Surface concept #2

**Priority: A.** Small persistent bottom strip, always visible on every surface.

**Goal:** System controls that never change context — the Control Strip. **Media controls move out of their own nav tab into this strip.**

### 4.1 Control Strip layout

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Volume | Slider + mute. Already implemented (`system.volume`, pactl). |
| [~] | Media | Now-playing title + transport (◀ ▶/❚❚ ▶) — move from `media_tab.dart` into the persistent strip widget. |
| [ ] | Brightness | Slider via `xrandr --brightness` (or `/sys/class/backlight/*/brightness`); range slider + % label. |
| [ ] | Lock | One-tap lock (`system.lock_screen`). |
| [ ] | Screenshot | One-tap screenshot (`system.screenshot`), optionally preview on phone. |
| [ ] | Dim | Reduce screen brightness below hardware minimum (xrandr overlay). |
| [ ] | Expandable sheets | Tap a strip item → bottom sheet with the full control (volume: slider + mute; brightness: slider; media: full transport + seek). |

### 4.2 Open / focus applications

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Open app list | Quick-open row (VS Code, Chrome, Terminal, Spotify, Teams, Docker) via existing `system.open_*` actions. |
| [ ] | Focus window | Bring a running app to foreground (window activation, not just launch). |

**Status: ~40% COMPLETE** — volume done; media partially done (needs relocation); brightness/lock/screenshot/dim need strip UI.

---

## PHASE 5 — GLANCEABLE DEVELOPER STATE

**Sources:** PRODUCT_SPEC §8–9 · PRIORITY_FEATURES Phase 2, Iteration B (ranks 2, 3, 4, 6, 19) · Tact Surface concept #3

**Priority: S.** The "mini display" — workspace health always visible at the top.

**Goal:** The developer glances and immediately knows: *everything is fine* or *something broke*.

### 5.1 Workspace state layer

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Git state | branch, clean/dirty, ahead/behind (in snapshot). |
| [x] | Battery state | level + charging in `system.battery` (snapshot + System tab chip). |
| [ ] | Build state | ✓ PASS / ✕ FAILED / ● RUNNING + last run time. Feed from VS Code task output (Phase 1/3) or a shell runner. |
| [ ] | Test state | `124/124` + failed counts. Feed from test runner output parsing. |
| [~] | Docker state | Per-container ● running / ✕ stopped / ⚠ restarting — data live (`docker.status`), glanceable widget pending. |
| [ ] | CI state | Eventually: `● Running · lint ✓ tests ✓ build ●` (Phase 9). |
| [ ] | Unified state widget | One row/card rendering all of the above with the shared status palette: `✓ HEALTHY / ● RUNNING / ⚠ ATTENTION / ✕ FAILED`. |

### 5.2 State broadcast

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Snapshot state | `snapshot_state()` broadcasts system/media/workspace/actions. |
| [ ] | State-diff broadcasting | Only push changed state sections to reduce bandwidth (state-changing actions already re-broadcast). |
| [ ] | Staleness indicator | Show "updated Xs ago" so the developer trusts the data. |

**Status: ~40% COMPLETE** — git state + snapshot exist; build/test/docker/CI state widgets pending.

---

## PHASE 6 — ACTIONABLE EVENTS / ATTENTION

**Sources:** PRODUCT_SPEC §8 · PRIORITY_FEATURES Phase 3 (rank 3) · Tact Surface concept #5

**Priority: S.** The Attention layer — **Tact tells the developer when something important happens**, and lets them act on it immediately.

### 6.1 Event bus (foundation exists)

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Central `EventBus` | Event: type, timestamp, severity, source, title, message, data, actions. |
| [x] | git.state_changed / vscode.state_changed / docker.state_changed | Emitted by `StateMonitor` on poll changes. |
| [x] | Event feed broadcast | `{type: "event"}` pushed over WebSocket; rendered in `event_feed.dart`. |

### 6.2 Additional event sources

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | build.started / succeeded / failed | Hook into VS Code task execution (Phase 3) and any build invocation. |
| [ ] | tests.started / passed / failed | Hook into test runner invocations; parse summary output for counts. |
| [ ] | container.started / stopped / failed | Docker event subscription (`docker events`) — container *state* events already live via `docker.state_changed`. |
| [ ] | battery.low / high.resource_usage | Threshold checks in the state monitor (battery ≤ 20%, CPU/RAM sustained high). |
| [ ] | repository.changed / branch.changed | Finer-grained git events beyond a single `state_changed`. |

### 6.3 Actionable notifications

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Actions on events | Events carry `actions: ["open.error", "debug.error", "rebuild"]`; notification renders tappable buttons. |
| [ ] | Execute from phone | Tapping a notification action runs the registered action with event context (file/line). |
| [ ] | Attention banner | Important events surface as a dismissible banner atop the surface (severity error/warning), not just a feed row. |
| [ ] | Feed filtering | Filter by severity / source / type. |
| [ ] | Toast + haptics | Light feedback on attention events (mobile). |

**Status: ~30% COMPLETE** — event bus + git/vscode events + feed exist; build/test/docker events and actionable buttons pending.

---

## PHASE 7 — CLIPBOARD / QUICK CAPTURE

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 4 (ranks 7, 25) · Tact Surface (daily utility)

**Priority: A+.** High-frequency developer utility — potentially a killer daily-use feature.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Clipboard read (laptop → phone) | `clipboard.get` reads the desktop clipboard (xsel/xclip/wl-paste/pbpaste/powershell); shows current text + history in the System tab. |
| [x] | Clipboard overwrite (phone → laptop) | `clipboard.set` writes phone text to the desktop clipboard; send box + one-tap copy-to-phone on history entries. |
| [x] | History (last 20, deduped) | In-agent rolling history; snapshot carries current text + history. |
| [x] | Image clipboard detection | `capabilities()` probes X11 TARGETS via xclip; reports `image_supported` (no image transfer yet — text only). |
| [ ] | Phone → active terminal / application | Send text via `xdotool type`/`ydotool type` into the focused app. |
| [ ] | Quick Capture | Text capture box; send to clipboard / file / terminal / project notes. |
| [ ] | Snippet library | Star frequently used snippets for one-tap copy. |

**Status: NOT STARTED**

---

## PHASE 8 — DEVELOPER WORKFLOWS

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 6 (rank 26)

**Priority: C+.** Predefined developer workflows first; custom builder later. Differentiator = *developer workflows*, not "we also have macros".

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Predefined workflows | **Start Work** (open VS Code + project + Docker + terminal + browser + Spotify), **Debug Environment** (open project + terminal + docker logs + VS Code), **Meeting** (open Teams → pause Spotify → volume 40% → DND → open meeting). |
| [ ] | Sequential action runner | Execute a list of actions with small delays; require confirmation for any destructive step. |
| [ ] | Workflow result feedback | Show each step ✓/✕ as it runs; stop-on-error option. |
| [ ] | Custom command builder (later) | Compose new workflows from registered actions. |

**Status: NOT STARTED**

---

## PHASE 9 — DEEP DEVELOPER INTEGRATIONS

**Sources:** PRODUCT_SPEC §11, §13.2 · PRIORITY_FEATURES Phase 7 (ranks 17, 18, 19, 21)

**Priority: B+.** Make Tact useful across the full workday; feeds the Terminal / Teams / CI state cards from Phase 3 & 5.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | GitHub / GitLab | PR status, CI checks, review count, comments; `[OPEN]` opens the PR. Auth via stored PAT (allowlisted, never logged). |
| [ ] | CI/CD status | Pipeline runs per repo: `● Running · lint ✓ tests ✓ build ●`; rerun/failed-job open actions. |
| [ ] | Database status/control | PostgreSQL: connections, queries/s, CPU; `[OPEN] [RESTART]` (restart requires confirmation). |
| [ ] | Process / service monitor | Process list + CPU/mem; start/stop/restart for known services. |
| [ ] | Terminal jobs + output | Live running jobs (`npm test`, `docker build`, `pytest`) with status + elapsed; tap → full output; feeds the Terminal surface state card. |
| [ ] | Find / open specific file | Path search over the workspace; open in VS Code at line. |
| [ ] | Meeting controls | Teams/Slack/Zoom: mute, camera, share, timer, leave; feeds the Teams surface state card. |
| [ ] | AI-tool integration foundations | Open ChatGPT/Claude/Gemini; optionally send a selected snippet/error. |

**Status: NOT STARTED**

---

## PHASE 10 — GLANCEABILITY / WIDGETS / LOCK SCREEN

**Sources:** PRODUCT_SPEC §15.3 · PRIORITY_FEATURES Phase 8 (rank 23) · Tact Surface concept #3

**Priority: B.** Interact with Tact without opening the full app.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Android home-screen widget | Workspace health mini-display (Build ✓ / Tests ✓ / ⚠ Redis / Git ↑2). |
| [ ] | Media widget | `◀ ▶/❚❚ ▶` + volume from the lock screen / home screen. |
| [ ] | Notification quick actions | Media transport + common actions as notification-area buttons. |
| [ ] | PWA polish / native notifications | If a web client returns; native notifications + haptics where justified. |

**Status: NOT STARTED**

---

## PHASE 11 — PLUGIN / CUSTOMIZATION PLATFORM

**Sources:** PRODUCT_SPEC §14, §19 · PRIORITY_FEATURES V0.8 (ranks 28–30, 32)

**Priority: D.** Let developers extend Tact without touching core. *Deliberately after core workflows.*

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Stable integration/plugin API | Actions, events, widgets, layouts, context providers as first-class pluggable units. |
| [ ] | Security boundaries | Plugins cannot bypass pairing/auth/action allowlisting. |
| [ ] | Profiles / pages / custom widgets / variables | User-defined layouts and reusable widgets. |
| [ ] | Marketplace | Only after plugin model stable + demand demonstrated. |

**Status: NOT STARTED**

---

## PHASE 12 — AI WORKSPACE GENERATION + ASSISTANT

**Sources:** PRODUCT_SPEC §12, §13 · PRIORITY_FEATURES V0.9 (ranks 30, 31)

**Priority: E.** AI as multiplier, not the product. **Deliberately last.**

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Environment inspection | Authorized scan (apps, docker, git, browser) → offer workspace/surface generation. |
| [ ] | Surface generation | Generate valid context surfaces with allowlisted actions; user edits result. |
| [ ] | Provider-agnostic | OpenAI / Anthropic / Google / local models. |
| [ ] | Build-failure assistant | `[OPEN] [EXPLAIN] [DEBUG WITH AI] [REBUILD]` on a failed build event. |
| [ ] | Confirmation for code changes | Any AI-generated code modification requires explicit user confirmation. |

**Status: NOT STARTED**

---

## PHASE 13 — PRODUCTIZATION

**Sources:** PRODUCT_SPEC §15, §16, §17, §18 · PRIORITY_FEATURES V1.0

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Simple install | `Download → Install → Start → QR → Connected` (no Python commands). |
| [ ] | Desktop packaging | Windows / Linux / macOS installers. |
| [ ] | Onboarding + pairing polish | Guided first-run, clear error handling, updates, docs. |
| [ ] | Performance + reliability | Diagnostics with explicit consent. |
| [ ] | Free/Pro boundary | Validated, not assumed. |
| [ ] | Cloud / sync | Only after demonstrated need; local-first remains fundamental. |

**Status: NOT STARTED**

---

## PHASE 14 — PHYSICAL TACT HARDWARE

**Sources:** PRODUCT_SPEC §20, §21 · PRIORITY_FEATURES (hardware much later)

**Principle:** hardware is *another client of the Tact platform*, never the foundation. Build only if software usage demonstrates demand for physical controls.

**Status: NOT STARTED**

---

## Recommended development-time allocation

> **40% Developer State/Events → 25% UI/UX → 20% Developer Actions/Workflows → 15% PC utilities. 0% AI. 0% plugin marketplace. 0% elaborate customization.**

### Next three iterations

| Iteration | Focus | Maps to |
| --------- | ----- | ------ |
| **A** | **Tact Surface prototype**: context engine + one or two context surfaces + control strip + glanceable state on a single screen | Phases 2, 3, 4, 5 |
| **B** | Developer state + events: Build / Tests / Docker / Git / CI + actionable events | Phases 5, 6 |
| **C** | Daily utility: Clipboard, Quick Capture, Brightness, Dim, Open App, Lock, Wake | Phases 4, 7 |

**Immediate next work:** the **Context Engine is live** (`context.status/override`, `context.changed`, phone ContextBanner). Next: Phase 2 signal aggregation, then wire the **VS Code surface** + **Control Strip** onto a single screen (Phase 3–4) — that one screen demonstrates the entire product concept. Codebase is modular: one integration file per capability (`tact/agent/integrations/README.md`).