# Tact — Phase-by-Phase Project Tracker

Merged roadmap combining **PRODUCT_SPEC.md** (architectural phases, definitions of done, gates), **PRIORITY_FEATURES.md** (practical build order, priorities, version grouping), the **Tact Surface** concept (context-first UI modeled on Apple's Touch Bar interaction model), and **Stream Deck user-research reviews** (how people actually use physical macro-keypads — app profiles, window/workspace control, project pages, snippets, multi-action workflows).

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
| 2 | Context Engine | V0.2 | ~95% complete | S |
| 3 | Application Surfaces / Profiles (Contextual Controls) | V0.3 | ~70% complete | S |
| 4 | Persistent Control Strip | V0.4 | ~70% complete | A |
| 5 | Glanceable State | V0.5 | ~60% complete | S |
| 6 | Actionable Events / Attention | V0.5 | ~30% complete | S |
| 7 | Clipboard / Snippets / Quick Capture | V0.6 | ~50% complete | A+ |
| 8 | Workflows & Macros | V0.7 | Not started | A |
| 9 | Deep Integrations: Remote Control + External Devices | V0.8 | Not started | B+ |
| 10 | Glanceability / Widgets / Lock screen | V0.9 | Not started | B |
| 11 | Plugin / Customization Platform | V1.0 | Not started | D |
| 12 | AI Workspace Generation + Assistant | V1.1 | Not started | E |
| 13 | Productization (beta / commercial / cloud) | V1.2 | Not started | — |
| 14 | Physical Tact Hardware | V2.0 | Not started | — |

**Current position:** Phases 0–2 complete (Context Engine ~95%); **Phase 3 Application Surfaces ~85% done** — the full app-surface set is live: VS Code Run/Debug/Test, Chrome browser nav (xdotool), Teams meeting controls, Spotify transport, **Terminal surface** (3.3: New/Clear/Rerun/Kill + terminal state card), **App Launcher** (3.8), **Window/Workspace Controls** (3.9), **Project Workspace** (3.10), and **contextual gestures** (3.7: swipe between surfaces, swipe media prev/next, swipe-to-dismiss events). **Phase 4 Control Strip ~85% live** (persistent strip + volume/brightness/audio-output/**microphone** sheet). Remaining: terminal jobs + copy output (Phase 9 feed), build/test state cards, running tasks + meeting state (Phase 5), actionable events (Phase 6), workflows (Phase 8).

**Modularity note (built into Phase 2 work):** the agent runs on the Integration pattern with **folder-per-app separation** — `integrations/<name>/` (integration.py + helper files like state.py/apps.py/detection.py) registered explicitly in `ActionRegistry`, generic `StateMonitor`. Adding a capability (figma, video editing) is one new folder + one registry line; see `tact/agent/integrations/README.md`.

**Stream Deck research note (applies to Phases 3–10):** reviews show users treat their keypad as an *extension of the desktop* — app profiles, arranging windows across monitors, project pages that open everything at once, one-tap snippets, and multi-action buttons. Tact's phone form factor beats a physical device on exactly these: it can carry full project/workspace state and act on it remotely. Additions from this research are marked with 🎛 in the phase tables below.

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
| [x] | Responsive native iOS/iPadOS and Android applications |
| [x] | Portrait, touch-friendly, information-dense, dark theme |
| [ ] | Declarative layout protocol (agent describes UI) — native surfaces currently use shared protocol models with platform-specific layouts |

> The production UI is implemented as separate native clients under `native/`.

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
| [x] | **Derive project from window title** — For editors/terminals, parse the folder/basename out of the title (e.g. "MainActivity.kt — Tact"). |
| [x] | **Derive branch** — Use `git discover_root` + `git status` on the resolved path; attach `branch`. |
| [x] | **Workspace fallback** — If no project resolvable from window, fall back to the agent's current workspace (`system.set_workspace`). |

### 2.3 Workflow detection

| Status | Item |
| ------ | ---- |
| [x] | **Multi-app signal aggregation** — `workflow = active-app map`, falling back to signal aggregation: active git repo (branch resolvable from the context project) or running docker containers → `development`. Signals exposed in snapshot (`context.signals`). |
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

**Status: ~95% COMPLETE** — detection, project/branch resolution, signal aggregation (git + docker → workflow), override, and `context.changed` all live (`integrations/context/`, `surfaces.py`); snapshot + phone banner (ContextBanner) shipped. Remaining: workflow signals beyond git/docker and surface switching polish (Phase 3).

---

## PHASE 3 — APPLICATION SURFACES / PROFILES (CONTEXTUAL CONTROLS)

**Sources:** PRODUCT_SPEC §10.2, §11 · PRIORITY_FEATURES Phase 1, 5 · Tact Surface concept #1, #5 · Stream Deck research (app profiles, window/workspace control, project pages)

**Priority: S.** Five excellent contexts are more valuable than 50 mediocre ones.

**Goal:** The Context Surface layer — controls change with the active app. Each surface = a profile: a set of actions + a state card, rendered when the matching context is active. Profiles may be **auto-switched** by the Context Engine, **manually pinned** via `context.override`, or **nested** (application → project → workflow).

```text
VS Code        Blender        Photoshop        Teams
├── Run        ├── Render     ├── Undo         ├── Mute
├── Debug      ├── Play       ├── Brush        ├── Camera
├── Test       ├── Camera     ├── Export       ├── Share
├── Terminal   ├── Save       ├── Save         └── Leave
└── Git
```

### 3.1 Surface framework (shared)

| Status | Item |
| ------ | ---- |
| [x] | **Surface registry** — Map `context_id → profile` (title, action buttons, state card kind). Lives in `integrations/context/surfaces.py`; buttons reference allowlisted registry actions; `context.surfaces` lists them. |
| [x] | **Surface view** — native clients render the active profile with a header, workflow state, action grid, and state card. |
| [x] | **Fallback surface** — Unknown apps and unavailable detection get the "Desktop" surface (generic system controls) so the surface is never empty. |
| [x] | **Manual pin** — `context.override` / `context.clear_override` + pin toggle in the surface header (pins the current app/project context). |
| [x] | **Per-app action sets** — vscode/terminal/chrome/edge/firefox/spotify/fallback each define their own action lists; unknown apps get the fallback. |
| [~] | **Per-app state cards** — `state_card` kinds shipped: `git` (branch/dirty/ahead/behind) + `media` (now playing); more kinds (vscode build, meeting) as Phase 3.2+ actions land. |

### 3.2 VS Code surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Run | Execute the active project's run task (`vscode.run_task` via `code --command workbench.action.tasks.runTask`; no task label → VS Code's task picker). |
| [x] | Debug | Launch debug session (`vscode.debug` → `workbench.action.debug.start`). |
| [x] | Test | Run tests (`vscode.test` → `workbench.action.tasks.test`). |
| [ ] | Build | Run build task; reflect build state in the workspace state layer (run_task covers arbitrary tasks — dedicated build state pending). |
| [~] | Terminal | New terminal window at the project (`system.open_terminal` on the surface); integrated-terminal command pending. |
| [x] | Git | Pull / push / status on the surface (project-aware via the Context Engine's resolved project). |
| [~] | State card | `git` card live (branch/dirty/ahead/behind); build ✓/✕ + test counts pending. |
| [x] | Open file | `vscode.open_file` (`code --goto path:line`) with a text-prompt button on the phone. |

### 3.3 Terminal surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | New | Open a new terminal window at the current workspace (reuse `system.open_terminal`). |
| [x] | Clear | `terminal.clear` — xdotool ctrl+l to the focused terminal (safe: Context Engine guarantees the terminal is active when this surface shows). |
| [x] | Rerun | `terminal.rerun` — xdotool Up then Return (shell history replays the last command; no per-terminal history needed). |
| [x] | Kill | `terminal.kill` — xdotool ctrl+c to interrupt the foreground job. |
| [ ] | Copy output | Needs scrollback access (konsole DBus / tty bridge) — deferred with Phase 9 terminal jobs. |
| [~] | State card | Terminal card live on the Surface tab: window title (most terminals mirror the running command there) + project + branch from the Context Engine. Job name + elapsed time lands with Phase 9. |

### 3.4 Chrome surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Back / Forward / Refresh | xdotool key combos (alt+Left / alt+Right / ctrl+r) sent to the focused Chrome window — safe because the Context Engine guarantees Chrome is active when this surface shows. |
| [x] | New tab / Close tab / Reopen | `chrome.new_tab/close_tab/reopen_tab` (ctrl+t / ctrl+w / ctrl+shift+t). |
| [x] | DevTools | `chrome.devtools` (ctrl+shift+i). |
| [x] | Copy URL | `chrome.copy_url` (ctrl+l then ctrl+c). |
| [ ] | State card | Active tab title + URL — deferred with CDP (needs Chrome launched with `--remote-debugging-port`; xdotool works with zero config). The surface is backend-swappable: a CDP client can replace the xdotool calls without touching surface definitions. |

### 3.5 Spotify surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Previous / Play-Pause / Next | Reuse `media.previous/play_pause/next` (playerctl **with xdotool media-key fallback** — snap Spotify's MPRIS registration drops intermittently; XF86Audio keys keep working). |
| [x] | Volume | Reuse `system.volume` / `media.volume` slider (already implemented). |
| [~] | State card | Now-playing title/artist + position (already in `media.status` details; Media tab shows it — move into the Spotify profile). |

### 3.6 Teams surface

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Mute / Camera | `teams.mute/camera` — `wmctrl -a Teams` then xdotool Ctrl+Shift+M / Ctrl+Shift+O (the wmctrl activation is the same proven `open_spotify` path). |
| [x] | Screen share | `teams.share` (Ctrl+Shift+E). |
| [x] | Leave | `teams.leave` (Ctrl+Shift+B). |
| [ ] | State card | Meeting state + duration (Phase 9 meeting controls feed this). |

### 3.7 Contextual gestures

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Swipe between contexts | Horizontal swipe on the Surface tab cycles surfaces (sends `context.override`, so the choice pins exactly like the pin button; pin button still clears). Velocity threshold avoids accidental swipes while scrolling. |
| [x] | Swipe media card | Left/right swipe on the now-playing card = `media.next` / `media.previous`. |
| [x] | Swipe to dismiss event | Dismissible event cards — swipe marks read (dismissed-set keyed by type+timestamp); underlying state untouched. |
| [x] | Drag sliders | Volume/brightness strip sliders use drag + onChangeEnd commit; media seek slider matches (drag updates local, onChangeEnd seeks). |

### Physical Stream Deck → Tact translation (interaction model)

Stream Deck+ users value the **knobs**; Tact replaces them with touch gestures, not physical controls:

| Stream Deck hardware | Tact equivalent |
| -------------------- | --------------- |
| Button | Action tile |
| Button screen/icon | Dynamic state card |
| Folder | Surface / nested surface |
| Profile | Application / project surface |
| Knob | Slider / drag gesture |
| Knob press | Tap |
| Swipe | Context / media navigation |
| Multi-action | Workflow (Phase 8) |
| Virtual Stream Deck | Tact itself |

Implications for Phase 3/4 (extend the existing interaction model, don't invent a new feature):

| Status | Item |
| ------ | ---- |
| [x] | Volume slider (drag) — live |
| [x] | Brightness slider (drag) — live (Control Strip sheet, xrandr overlay) |
| [ ] | Media seek (drag on now-playing timeline) |
| [ ] | Timeline controls (scrub) for running tasks/processes |
| [~] | Variable adjustment — volume/brightness share one slider primitive in the Control Strip sheet |
| [ ] | Horizontal / vertical drag actions — swipe gestures that trigger actions (media prev/next, context switching) |

### 3.8 🎛 Application Launcher

Users use Stream Decks as an **extension of the desktop** — launching/focusing apps instead of hunting icons. Mostly a surface-level capability on top of the existing `system.open_*` actions.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | App launcher surface | **Apps tab**: known-app registry grouped into Development / Communication / Media, one tap launches (`system.open_app` → binary + focus-after-launch poll) or focuses a running app (`system.focus_app`); running indicator dot. |
| [x] | Recent applications | Context Engine keeps a rolling app-history deque → `context.recent_apps`, rendered as a Recent row in the Apps tab. |
| [x] | App folders | Groups Development / Communication / Media ship with the registry (`system.apps.groups`). |

### 3.9 🎛 Window / Workspace Controls

Comes from Stream Deck users who arrange applications across multiple monitors. Particularly appropriate for Tact: **the phone controls layout without being physically beside the computer.**

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Focus application | `window.focus` / `system.focus_app` (wmctrl `-a`); running-window list from `wmctrl -lx` (title + WM_CLASS parsed). |
| [x] | Move window | `window.move` (`wmctrl -r <title> -e gravity,desktop,x,y,w,h`); move to another desktop included. |
| [x] | Window layout presets | **Coding / Meeting / Media** presets in `integrations/window/` — `window.apply_layout` tiles each app's window to its preset geometry; missing windows reported back. |
| [~] | Workspace preset | Layout presets include which apps the workspace needs — "open missing apps" is next (currently moves existing windows only). |
| [x] | Minimize / maximize / close | `window.minimize/maximize/close` (`wmctrl -b add,hidden` / `-b add,maximized_vert,maximized_horz` / `-c`) — per-window buttons in the Apps tab. |

### 3.10 🎛 Project Workspace

Stream Deck "project pages" open all the files, applications and tools associated with a project. One tap means: **"put me back into my Tact development environment."**

```text
TACT
├── VS Code
├── Terminal
├── Chrome → localhost:3000
├── Docker
├── GitHub
├── Project folder
```

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Project launcher | `project.open` — composite: VS Code + terminal at the project path + file manager, one tap from the phone's project card. |
| [x] | Project resources | `project.resources` resolves the git remote → repo URL; the Surface tab's project card renders Workspace / Terminal / Browser / Folder / Repo resource chips bound to existing actions. |
| [ ] | Project commands | Expose commands associated with that project (run, test, build, deploy — from the project's detected toolchain); `vscode.run_task {label}` partially covers this. |
| [x] | Project surface | ProjectCard on the Surface tab when `context.project` is active — nested under the app surface, per the Tact Surface model. |
| [ ] | Project presets | Save a project-specific workspace configuration. |

**Status: ~85% COMPLETE** — full app-surface set live (VS Code Run/Debug/Test/Open File, Chrome nav, Teams meeting controls, Spotify, Terminal New/Clear/Rerun/Kill + state card), App Launcher tab (3.8), Window/Workspace controls + layout presets (3.9), Project Workspace card + resources (3.10), contextual gestures (3.7). Remaining: terminal jobs + copy output (Phase 9), build/test state, CDP state card.

---

## PHASE 4 — PERSISTENT CONTROL STRIP

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 4–5, Iteration C (ranks 9, 10, 11, 12, 14) · Tact Surface concept #2

**Priority: A.** Small persistent bottom strip, always visible on every surface. **The strip stays small — no 20-button walls.** Only frequent, cross-app controls live here.

**Goal:** System controls that never change context — the Control Strip. **Media controls move out of their own nav tab into this strip.**

### 4.1 Control Strip layout

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Volume | Compact slider + mute in the persistent strip and the expandable sheet (`system.volume`, pactl). |
| [~] | Media | Transport (▶ play/pause) lives in the strip; now-playing title remains in the Media tab — full title card in the sheet pending. |
| [x] | Brightness | Slider via `xrandr --brightness` overlay; get+set live (`system.brightness`); % label in the sheet. |
| [x] | Lock | One-tap lock (`system.lock_screen`) in the strip. |
| [x] | Screenshot | One-tap screenshot (`system.screenshot`) in the strip. |
| [ ] | Dim | Reduce screen brightness below hardware minimum — the xrandr overlay covers 0–100% already; explicit "dim" mode pending. |
| [x] | Expandable sheets | Tap volume in the strip → bottom sheet with volume + brightness sliders and the audio-output switcher. |

### 4.2 🎛 Quick app switcher

| Status | Item | Description |
| ------ | ---- | ----------- |
| [~] | Pinned apps row | The Apps tab is the launcher (all apps + recent); a compact pinned row *inside the strip itself* pending. |
| [~] | Recent-app rotation | Recent row in the Apps tab from Context Engine history (`context.recent_apps`); rotating the strip's pinned slot pending. |

### 4.3 🎛 Audio output switcher

From the review mentioning switching between audio devices (headphones ↔ speakers ↔ Bluetooth).

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Audio output device switching | `system.sinks` (pactl `list short sinks` + default) rendered as ChoiceChips in the Control Strip sheet; `system.set_sink` switches with one tap. |
| [x] | Microphone device switching | `system.sources` / `system.set_source` (pactl `get-default-source` / `list short sources` / `set-default-source`) — `.monitor` loopbacks filtered out so only real capture devices show; ChoiceChips in the strip sheet under the sink row. |

**Status: ~85% COMPLETE** — persistent Control Strip live on every tab (volume slider, play/pause, lock, screenshot) with an expandable sheet for volume + brightness + audio output + microphone switching. Remaining: now-playing title in the strip, pinned quick-switcher row.

---

## PHASE 5 — GLANCEABLE STATE

**Sources:** PRODUCT_SPEC §8–9 · PRIORITY_FEATURES Phase 2, Iteration B (ranks 2, 3, 4, 6, 19) · Tact Surface concept #3 · Stream Deck research (users want to know *whether something is happening*, not raw telemetry)

**Priority: S.** The "mini display" — workspace health always visible at the top.

**Goal:** The developer glances and immediately knows: *everything is fine* or *something broke* — and the top of Tact stays useful **outside pure development** (meetings, media, away-from-desk).

### 5.1 Glanceable state layer

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Active application | Current focused app — live via Context Engine (`snapshot.context.active_app`, phone banner). |
| [x] | Active project | Current project/workspace — live via Context Engine (`snapshot.context.project/branch`, phone banner). |
| [x] | Git state | branch, clean/dirty, ahead/behind (in snapshot). |
| [x] | Battery state | level + charging in `system.battery` (snapshot + System tab chip). |
| [ ] | Running tasks | Builds, scripts, downloads, training jobs, etc. with status + elapsed (feeds from Phase 9 process monitor / terminal jobs). |
| [~] | Media state | Currently playing/paused media — data live (`media.status`); glanceable card pending (Media tab only today). |
| [ ] | Meeting state | Current meeting / muted / camera / sharing state when applicable (feeds from Phase 9 meeting controls). |
| [~] | Connection state | Laptop online/offline — pairing `last_seen` exists; phone-side **"updated Xs ago" staleness chip is live** in the Surface tab glance row (accent-colored when stale). |
| [ ] | Build state | ✓ PASS / ✕ FAILED / ● RUNNING + last run time. Feed from VS Code task output (Phase 1/3) or a shell runner. |
| [ ] | Test state | `124/124` + failed counts. Feed from test runner output parsing. |
| [~] | Docker state | Per-container ● running / ✕ stopped / ⚠ restarting — data live (`docker.status`), glanceable chip in the Surface tab glance row. |
| [ ] | CI state | Eventually: `● Running · lint ✓ tests ✓ build ●` (Phase 9). |
| [ ] | Unified state widget | One row/card rendering all of the above with the shared status palette: `✓ HEALTHY / ● RUNNING / ⚠ ATTENTION / ✕ FAILED`. |

### 5.2 State broadcast

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Snapshot state | `snapshot_state()` broadcasts system/media/workspace/actions. |
| [ ] | State-diff broadcasting | Only push changed state sections to reduce bandwidth (state-changing actions already re-broadcast). |
| [x] | Staleness indicator | "updated Xs ago" chip live in the Surface tab glance row (from `TactStateNotifier.lastUpdated`). |

**Status: ~60% COMPLETE** — context (app/project/branch) + git + battery + docker chips + staleness live in the glance row; running tasks / meeting / build / test / CI widgets pending.

---

## PHASE 6 — ACTIONABLE EVENTS / ATTENTION

**Sources:** PRODUCT_SPEC §8 · PRIORITY_FEATURES Phase 3 (rank 3) · Tact Surface concept #5

**Priority: S.** The Attention layer — **Tact tells the developer when something important happens**, and lets them act on it immediately.

### 6.1 Event bus (foundation exists)

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Central `EventBus` | Event: type, timestamp, severity, source, title, message, data, actions. |
| [x] | git.state_changed / vscode.state_changed / docker.state_changed | Emitted by `StateMonitor` on poll changes. |
| [x] | Event feed broadcast | `{type: "event"}` pushed over WebSocket and rendered by native event views. |

### 6.2 Additional event sources

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | build.started / succeeded / failed | Hook into VS Code task execution (Phase 3) and any build invocation. |
| [ ] | tests.started / passed / failed | Hook into test runner invocations; parse summary output for counts. |
| [ ] | container.started / stopped / failed | Docker event subscription (`docker events`) — container *state* events already live via `docker.state_changed`. |
| [ ] | process.exited | Notify when a **monitored process stops unexpectedly** (Phase 9 process monitor — e.g. dev server, database). |
| [ ] | download.completed | Detect completed downloads (directory scan / `inotify`) → `[OPEN FOLDER] [OPEN FILE] [DISMISS]`. |
| [ ] | meeting.started | Meeting window/process detected (Teams/Zoom/Slack call) → offer meeting controls. |
| [ ] | application.state_changed | Surface relevant controls when an app becomes active — `context.changed` **already live**; wire it to profile switching (Phase 3). |
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
| [ ] | 🎛 Away notification | Task outcome pushed while the phone is away — not a mirror of desktop notifications, a *stronger* interaction: |

```text
Tact build failed

[ View Logs ] [ Re-run ] [ Open VS Code ]
```

**Status: ~30% COMPLETE** — event bus + git/vscode events + feed exist; build/test/docker/process/download/meeting events and actionable buttons pending.

---

## PHASE 7 — CLIPBOARD / SNIPPETS / QUICK CAPTURE

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 4 (ranks 7, 25) · Tact Surface (daily utility) · Stream Deck research (comment-bank / text-template use cases, e.g. teachers reusing the same feedback)

**Priority: A+.** High-frequency developer utility — potentially a killer daily-use feature.

### 7.1 Clipboard

| Status | Item | Description |
| ------ | ---- | ----------- |
| [x] | Laptop → phone clipboard | `clipboard.get` reads the desktop clipboard (xsel/xclip/wl-paste/pbpaste/powershell); shows current text + history in the System tab. |
| [x] | Phone → laptop clipboard | `clipboard.set` writes phone text to the desktop clipboard; send box + one-tap copy-to-phone on history entries. |
| [x] | History (last 20, deduped) | In-agent rolling history; snapshot carries current text + history. |
| [x] | Image clipboard detection | `capabilities()` probes X11 TARGETS via xclip; reports `image_supported` (no image transfer yet — text only). |
| [ ] | Send clipboard item to active application | Send selected text into the focused app (`xdotool type`/`ydotool type`). |
| [ ] | Copy selected history item directly into active application | One-tap "paste into app" from history (same mechanism, targeted at the active window). |

### 7.2 Snippets

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Pinned snippets | Star frequently used snippets for one-tap copy. |
| [ ] | Snippet folders | Organize snippets into folders (Development, Communication, Templates…). |
| [ ] | One-tap paste | Tap a snippet → copy to clipboard and/or type directly into the active application. |
| [ ] | Developer command snippets | `git status`, `docker compose up`, `npm run dev`, TODO:, FIXME: |
| [ ] | Text templates | Reusable text blocks (Email: "Thanks for reaching out…"; Teacher: "Good work… Please revise…"). |
| [ ] | Application-specific snippets | Snippets bound to a context (`context.override` or active-app): VS Code commands, Email templates, grading comments. |

**Status: ~50% COMPLETE** — clipboard read/write/history + image detection live; send-to-app + full snippet library pending.

---

## PHASE 8 — WORKFLOWS & MACROS

**Sources:** PRODUCT_SPEC §11 · PRIORITY_FEATURES Phase 6 (rank 26) · Stream Deck research (multi-action buttons are the #1 power-user pattern)

**Priority: A.** Moved up from C+ — the multi-action button is what makes a macro-keypad indispensable. **No drag-and-drop automation editor yet.** First make *button → sequence of existing Tact actions* work extremely well.

**Goal:** One button executes multiple existing Tact actions sequentially — the workflow is a first-class citizen of the action registry, not a separate subsystem.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Multi-action button | One button executes multiple actions sequentially (composed from registered Tact actions). |
| [ ] | Action sequencing | Run actions in defined order with optional delays between steps. |
| [ ] | Stop on failure | Stop the workflow when an action fails (configurable per workflow). |
| [ ] | Confirmation steps | Require confirmation for destructive actions (stop containers, git reset, shutdown…). |
| [ ] | Workflow progress | Show ✓/✕ for individual steps as it runs. |
| [ ] | Predefined workflows | **Start Work** (open VS Code + project + Docker + terminal + browser + Spotify), **Debug Environment** (open project + terminal + docker logs + VS Code), **Meeting** (open Teams → pause Spotify → volume 40% → DND → open meeting). |
| [ ] | Custom workflow builder (later) | User composes workflows from registered Tact actions — simple list-of-actions UI first, not a visual editor. |
| [ ] | Application-triggered workflows (optional, later) | Run a workflow when an application becomes active (feeds on `context.changed`). |

**Status: NOT STARTED** — build the sequential runner on top of the existing action registry; Phase 3 surfaces and Phase 6 events consume it.

---

## PHASE 9 — DEEP INTEGRATIONS: REMOTE CONTROL + EXTERNAL DEVICES

**Sources:** PRODUCT_SPEC §11, §13.2 · PRIORITY_FEATURES Phase 7 (ranks 17, 18, 19, 21) · Stream Deck research (audio device switching, external controls) · Tact's mobile form factor (remote computer control is the opportunity a physical Stream Deck can't offer)

**Priority: B+.** Make Tact useful across the full workday; feeds the Terminal / Teams / CI state cards from Phase 3 & 5.

### 9.1 Deep developer integrations

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | GitHub / GitLab | PR status, CI checks, review count, comments; `[OPEN]` opens the PR. Auth via stored PAT (allowlisted, never logged). |
| [ ] | CI/CD status | Pipeline runs per repo: `● Running · lint ✓ tests ✓ build ●`; rerun/failed-job open actions. |
| [ ] | Database status/control | PostgreSQL: connections, queries/s, CPU; `[OPEN] [RESTART]` (restart requires confirmation). |
| [ ] | Process / service monitor | Process list + CPU/mem; start/stop/restart for known services. Feeds Phase 5 "running tasks" + Phase 6 `process.exited`. |
| [ ] | Terminal jobs + output | Live running jobs (`npm test`, `docker build`, `pytest`) with status + elapsed; tap → full output; feeds the Terminal surface state card. |
| [ ] | Find / open specific file | Path search over the workspace; open in VS Code at line. |
| [ ] | Meeting controls | Teams/Slack/Zoom: mute, camera, share, timer, leave; feeds the Teams surface state card + Phase 5 meeting state. |
| [ ] | AI-tool integration foundations | Open a configured assistant; optionally send a selected snippet/error. |

### 9.2 🎛 Remote computer control

Not Stream Deck functionality — this is Tact's own opportunity: **the laptop keeps running while you're away, and Tact becomes its remote control.** Example:

```text
MY LAPTOP
● Online

RUNNING
Android build      ●
Docker             ●
Model training     ● 67%

[ View Logs ] [ Stop Build ] [ Restart Build ]
[ Lock ] [ Sleep ]
```

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Remote laptop status | Online/offline + last seen (pairing `last_seen` exists; surface it as a status card). |
| [ ] | Remote application launch | Launch an application remotely (existing `system.open_*`). |
| [ ] | Remote process control | Start/stop/restart **approved** processes (from 9.1 process monitor; destructive actions need confirmation). |
| [ ] | Remote command execution | Execute **allowlisted** commands/scripts (project commands from Phase 3.10 / custom allowlist). |
| [ ] | Remote task status | See running builds/scripts/training/downloads (Phase 5 running tasks, remote). |
| [ ] | Remote logs | View recent output from running jobs (9.1 terminal jobs, remote view). |
| [ ] | Remote lock | Lock computer remotely. |
| [ ] | Remote sleep | Put computer to sleep remotely. |
| [ ] | Remote shutdown | Shutdown with confirmation. |
| [ ] | Remote restart | Restart with confirmation. |

### 9.3 🎛 External controls

From the review mentioning switching audio devices, streaming controls, OBS and smart lighting. **Don't build all of these yet** — the generic HTTP/webhook action covers most ecosystems without a native integration.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Audio output device switching | Sinks via pactl (also in Phase 4.3 — shared capability). |
| [ ] | Microphone device switching | Sources via pactl. |
| [ ] | OBS basic controls | Start/stop stream & recording (OBS WebSocket API). |
| [ ] | Smart-light controls | Hue / WLED etc. (via generic webhook). |
| [ ] | Generic HTTP/webhook actions | Define a webhook/URL as an action (GET/POST, allowlisted endpoints) — lets Tact control anything without a native integration per ecosystem. |
| [ ] | External device integrations | Anything else as demand is demonstrated. |

**Status: NOT STARTED**

---

## PHASE 10 — GLANCEABILITY / WIDGETS / LOCK SCREEN

**Sources:** PRODUCT_SPEC §15.3 · PRIORITY_FEATURES Phase 8 (rank 23) · Tact Surface concept #3

**Priority: B.** Interact with Tact without opening the full app. **Where Tact beats a physical Stream Deck:** Android home screen → "Build failed" → tap **Rebuild**.

| Status | Item | Description |
| ------ | ---- | ----------- |
| [ ] | Laptop status widget | Online/offline + last seen + battery on the home screen. |
| [ ] | Running task widget | Currently running builds/scripts/training with status + elapsed. |
| [ ] | Build/test status widget | Build ✓ / Tests ✓ with last run; failed → tap to act. |
| [ ] | Media controls widget | `◀ ▶/❚❚ ▶` + volume from the lock screen / home screen. |
| [ ] | Pinned action widget | A few user-pinned one-tap actions on the home screen. |
| [ ] | Recent event widget | Last attention events (build failed, PR comment) with quick actions. |
| [ ] | Android home-screen widget | Combined workspace-health mini-display (Build ✓ / Tests ✓ / ⚠ Redis / Git ↑2). |
| [ ] | Notification quick actions | Media transport + common actions as notification-area buttons. |
| [ ] | PWA polish / native notifications | If a web client returns; native notifications + haptics where justified. |

**Status: NOT STARTED**

---

## WHAT NOT TO BUILD YET (deferred, per Stream Deck research)

The reviews tempt you to add everything. These are proofs of breadth, not things that prove the product. **Deliberately deferred:**

- Gaming profiles / MMO controls
- Elaborate OBS Studio integration (basic start/stop only, Phase 9.3)
- Extensive smart-home ecosystem (generic webhook instead, Phase 9.3)
- CAD-specific controls
- Blender-specific controls (example only in Phase 3 docs)
- Photoshop-specific controls (example only in Phase 3 docs)
- Marketplace / arbitrary plugin ecosystem (Phase 11, after demand is demonstrated)
- 64-button customization / huge grid layouts (Tact is a contextual surface, not a button grid)
- AI-generated profiles (Phase 12)

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
| [ ] | Provider-agnostic | Support configurable cloud and local model providers. |
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
| **C** | Daily utility: Clipboard + Snippets, Brightness, Dim, Open App, Lock, Wake | Phases 4, 7 |

**Immediate next work:** Phase 3 is ~85% shipped — the full app-surface set (VS Code Run/Debug/Test, Chrome nav, Teams meeting controls, Spotify, **Terminal Clear/Rerun/Kill + state card**), **App Launcher tab**, **window/workspace layout presets**, the **project workspace card**, and the **contextual gestures** (swipe surfaces / media / dismiss events) are all live, and the **Phase 4 Control Strip** (volume/brightness/audio-output/microphone sheet) sits on every tab. Natural next iterations: build/test state cards (3.2, 5.1), then **Phase 6 actionable events** (build failure → `[View Logs] [Re-run]`) and **Phase 8 Workflows & Macros** (compose `project.open`-style sequences from the registry — the stream-deck multi-action pattern). Terminal jobs + copy output wait for the Phase 9 tty bridge. Codebase stays modular: one integration file per capability (`tact/agent/integrations/README.md`).
