# Tact — Developer Control Surface

Tact turns your phone into a control surface for your laptop. A desktop agent runs locally on the laptop, exposes a allowlisted set of actions, understands *what you are doing right now* (active app, project, branch, workflow), and streams state and events to your phone over a local WebSocket.

There are three moving parts:

- **Tact Agent** — a Python/FastAPI desktop agent running on the laptop (the brain)
- **Tact phone client** — a Flutter app that renders the contextual interface and executes actions
- **Tact host companion** — a Flutter desktop tray app on the laptop that shows the pairing OTP and handles pairing approvals without touching the terminal

## What this contains

- FastAPI desktop agent with WebSocket server and HTTP pairing API
- **Allowlisted action registry** — 42 actions across 7 integrations (`system`, `vscode`, `git`, `media`, `docker`, `clipboard`, `context`); every action runs through the registry, nothing is ad-hoc
- **Context Engine** — detects the focused application, resolves the active project + git branch, classifies the workflow, and pushes `context.changed` events so the phone surface can react
- **Integration pattern** — folder-per-capability separation (`tact/agent/integrations/<name>/`), each integration contributing `actions()`, `snapshot()`, and optionally `monitor()`; see `tact/agent/integrations/README.md`
- System telemetry (CPU, RAM, disk, battery, volume) with circular gauges on the phone
- Git state, tree visualization, branch switching, pull/push/commit, commit graph
- Docker container status + start/stop/restart/logs (degrades gracefully when the daemon or group permissions are unavailable)
- Media controls (Spotify, browser media, VLC via MPRIS) with a media-key fallback for flaky MPRIS players
- Clipboard bridge: laptop → phone, phone → laptop, in-agent history (text only)
- VS Code open-workspace detection and recent-workspaces dropdown
- Secure local pairing with 6-digit OTP and laptop-side approval; device tokens persisted in `~/.tact/config.json`
- Event bus with severity levels, actionable payloads, and a phone-side event feed
- Flutter phone client (context banner + System / Developer / Media / Events tabs)
- Flutter host companion tray app (OTP display, pairing approvals, agent port config)
- mDNS agent discovery on the client (agent-side advertisement pending)
- Single-file web client fallback served by the agent

## Quick start

### 0. System dependencies (Linux)

```bash
sudo apt install git playerctl xdotool wmctrl xclip x11-utils pactl
```

- **git** — required for all git actions (`status`, `branches`, `tree`, `log`, `add`, `pull`, `push`, `switch_branch`, `commit`).
- **playerctl** — primary media transport (MPRIS). Controls Spotify, browser media sessions (Chrome/Chromium/Firefox), VLC, etc. Without it the agent reports `media.status` unavailable.
- **xdotool** — media-key fallback (XF86Audio Play/Next/Prev) when a player's MPRIS registration is unreliable (snap Spotify), and window/keystroke helpers.
- **wmctrl** — window focus/activation (`media.open_spotify` focuses the launched window).
- **xclip** — clipboard read (with `xsel`/`wl-paste` fallbacks) and the image-clipboard capability probe.
- **x11-utils** — `xprop` used by the Context Engine for active-window detection (X11; detection is unavailable under Wayland/headless).

Optional, feature-gated:

- **VS Code** (`code`/`code-insiders`/`codium`) — needed for `vscode.*` actions and workspace detection.
- **pactl** (PulseAudio) — volume get/set/up/down/mute actions.
- **docker CLI** — `docker.*` actions (container status + lifecycle).
- **xdg-open / gio** — `system.open_url`/`system.open_project` launchers.

### 1. Desktop agent

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn tact.agent.main:app --reload --host 0.0.0.0 --port 8000
```

Or:

```bash
python -m tact.agent
```

The agent prints the pairing OTP to the terminal on startup.

### 2. Phone client (Flutter)

```bash
cd app
flutter pub get
flutter run -d <device-id>   # lib/main.dart — runs on a connected phone
```

The phone must have **USB debugging** enabled (*Settings → Developer options*); Flutter will prompt
to allow it on first connect. Find your device id with `flutter devices` (or `adb devices`).
Hot reload: press `r` in the `flutter run` terminal, `R` for hot restart.

#### First-time toolchain setup (Flutter + Android on Linux, no Android Studio)

```bash
# 1. Flutter SDK
git clone -b stable https://github.com/flutter/flutter.git ~/flutter
# add to PATH: export PATH="$HOME/flutter/bin:$PATH"

# 2. Java 17 (current Android Gradle plugin needs it)
sudo apt install -y openjdk-17-jdk

# 3. Android SDK command-line tools (replaces Android Studio)
mkdir -p ~/Android/cmdline-tools && cd ~/Android/cmdline-tools
curl -o tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q tools.zip && mv cmdline-tools latest && rm tools.zip

# 4. SDK packages + licenses
export ANDROID_HOME=~/Android
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "build-tools;28.0.3"

# 5. Verify
flutter doctor        # Android toolchain should show ✓
flutter devices       # should list your connected phone
```

The `ANDROID_HOME`/`PATH` exports are added to `~/.bashrc` automatically during setup.

#### Android build requirements

Flutter 3.47 requires minimum Gradle 8.14.2, AGP 8.11.1, and Kotlin 2.2.20.
Update these in `app/android/gradle/wrapper/gradle-wrapper.properties` and
`app/android/settings.gradle.kts` if your clone predates that:

```bash
cd app && flutter build apk --debug   # verify the Android build compiles
```

### 3. Host companion (desktop tray app)

```bash
cd app
flutter run -d linux   # or -d macos / -d windows
flutter run -t lib/main_tray.dart
```

The tray menu shows the host IP, port, current OTP, and paired-device count, and auto-opens the approval window when a new device requests pairing.

### 4. Web client (fallback)

The agent serves a single-file web client:

```
http://<laptop-ip>:8000/client/index.html
```

## Secure pairing flow

1. Start the desktop agent. It prints a 6-digit OTP to the terminal, e.g.:

```
INFO:tact.startup:Tact Desktop Agent started
INFO:tact.startup:Client URL: http://0.0.0.0:8000/client/index.html
INFO:tact.startup:Pairing OTP (valid 5 min): 832544
INFO:tact.startup:To pair a device: open the client URL, enter the OTP, then approve here: http://0.0.0.0:8000/admin/pair/pending
```

2. On your phone, open the Flutter app, enter the laptop's IP and the 6-digit OTP, and tap **Connect** (or open `http://<laptop-ip>:8000/client/index.html` for the web client).

3. On your laptop, approve the request:
   - **Host companion**: the window pops up automatically — tap **Approve**, or open the tray menu → *Review approvals…*
   - **Terminal/Web**: open `http://<laptop-ip>:8000/admin/pair/pending` and click **Approve**

4. After approval, the phone connects to the WebSocket and can execute safe actions. The device token is persisted on the phone, so future connections skip the OTP step.

**Security notes:**
- The OTP is only shown in the server terminal, not exposed via HTTP endpoints
- Pairing requires explicit approval from the laptop
- OTPs expire after 5 minutes
- Paired devices are stored locally in `~/.tact/config.json`
- The WebSocket requires an auth handshake (`device_id` or OTP) before any message is accepted

## How the agent talks to the phone

The WebSocket protocol (`/ws`) is three channels:

| Channel | Direction | Contents |
| ------- | --------- | -------- |
| State | agent → phone | Full state snapshot on connect (`init`) and every 5s (`telemetry`); a fresh snapshot is pushed immediately after any state-changing action |
| Events | agent → phone | One-way push of `git.state_changed`, `vscode.state_changed`, `docker.state_changed`, `context.changed` events (with severity + optional actions) |
| Actions | phone → agent | `action` request → `action_result` response; every action id is looked up in the allowlisted registry |

Slow subprocess work (git, docker, playerctl) runs in a thread pool so the event loop never blocks.

## Context Engine

The agent knows what you are doing right now, and the phone shows it in a banner and can switch surfaces on change.

```
active_app = focused window class       (xprop _NET_ACTIVE_WINDOW + WM_CLASS, X11)
project    = parse(window title) ?? current workspace
branch     = git(project).branch
workflow   = WORKFLOW_MAP[active_app]   (development / meeting / media / …)
```

- `context.status` — current detection result (`active_app`, `window_title`, `project`, `branch`, `workflow`, `override`)
- `context.override` / `context.clear_override` — pin or clear a manual override (the pinned context survives until explicitly cleared)
- `context.changed` — broadcast when the active app or project changes, so the client reacts without polling

Project resolution falls back from window titles to VS Code workspace storage to the configured workspace (`system.set_workspace`), so a context is almost always resolvable. The Flutter client renders this as the `ContextBanner` (app · project · branch · workflow chip) above the tab content.

## Available actions

All actions are allowlisted in the agent and dispatched by `ActionRegistry`:

**system**
- `system.open_url`, `system.set_workspace` (composite: propagates to all integrations)
- `system.open_terminal`, `system.open_project`
- `system.volume` (get/set 0–100), `system.volume_up`, `system.volume_down`, `system.mute`
- `system.lock_screen`, `system.screenshot`, `system.battery`

**vscode**
- `vscode.open_workspace`, `vscode.status`, `vscode.workspaces`

**git**
- `git.status` (branch, clean/dirty, ahead/behind, changed files)
- `git.branches`, `git.switch_branch`, `git.tree`, `git.log` (commit graph)
- `git.add` (`git add -A`), `git.commit`, `git.pull`, `git.push`

**media**
- `media.status` (player list, now playing, position/length, volume)
- `media.play_pause`, `media.next`, `media.previous` (optionally target a specific `player`)
- `media.volume` (0–1), `media.seek` (seconds)
- `media.open_spotify` (composite: launches the desktop app and focuses its window, web fallback)

**docker**
- `docker.status` (container list: name, state, image, uptime)
- `docker.start`, `docker.stop`, `docker.restart`, `docker.logs` (optional `tail`)

**clipboard**
- `clipboard.get`, `clipboard.set`, `clipboard.status`, `clipboard.clear_history`

**context**
- `context.status`, `context.override`, `context.clear_override`

The current registry (42 actions) is also published in every state snapshot under `actions`, so clients can render dynamic action grids.

## Media controls

The Media tab uses **playerctl** (MPRIS) to control Spotify, browser media
sessions (Chrome/Chromium/Firefox), VLC, and other players from one place.

```bash
sudo apt install playerctl
```

`playerctl` exposes every running MPRIS player; no per-app APIs are needed.
The agent reports `media.status` in its state snapshot, and the transport
actions optionally accept a `player` payload to target a specific app. The
Media tab has a volume slider (follows live telemetry unless you're dragging)
and a seek slider with timestamps.

> **Not seeing the Media tab's controls?** The agent likely doesn't have
> `playerctl` on its PATH. Install it (see System dependencies above), restart
> the agent, and tap **Check Again** in the app.

**MPRIS fallback:** some players register MPRIS unreliably (snap Spotify drops
its D-Bus registration intermittently). When `playerctl` fails, the transport
actions fall back to X11 media keys via `xdotool` (`XF86AudioPlay`/`Next`/`Prev`),
which keep working regardless of MPRIS state. The action result reports which
transport was used (`method: "playerctl" | "xdotool"`).

**Launching Spotify:** `media.open_spotify` launches the app, then runs a
detached focus script that polls `wmctrl -a Spotify` (snap apps take several
seconds to create a window), returning immediately to the phone.

## VS Code workspace detection

`vscode.workspaces` reads VS Code's own state instead of scraping process
command lines (which are polluted by extension/language-server helper
processes). It parses each `~/.config/Code/User/workspaceStorage/<hash>/workspace.json`
(`folder` field, `file://` decoded), filters out VS Code install/extension
and cache directories, and sorts by storage-directory mtime so the currently
open workspace is listed first. Process cmdline scanning is kept only as a
fallback when the storage directory is unavailable.

## Docker integration

`docker.status` lists containers via `docker ps -a` (name, state, image,
uptime); `start`/`stop`/`restart`/`logs` operate on a named container.
Container state changes are pushed as `docker.state_changed` events by the
state monitor. When the daemon is down or the agent runs without docker group
permissions, the integration reports the failure (`docker_permission_denied`,
`docker_failed`) instead of crashing — the phone renders the degraded state.

## Clipboard

`clipboard.get` reads the desktop clipboard (xclip/xsel/wl-paste), `clipboard.set`
writes phone text to it. The agent keeps a rolling, deduplicated history (last
20 entries) and reports `image_supported` by probing X11 TARGETS (requires
xclip) — image transfer is not implemented yet (text only).

## Project structure

```
tact/                        # Python desktop agent
├── agent/
│   ├── __main__.py          # uvicorn entrypoint
│   ├── main.py              # FastAPI app, HTTP + WebSocket endpoints, snapshot composition
│   ├── actions.py           # ActionRegistry: explicit registration + composites
│   ├── config.py            # pairing/OTP state, ~/.tact/config.json
│   ├── events.py            # Event + EventBus (severity, actions)
│   ├── monitoring.py        # generic StateMonitor: polls integrations' monitor()
│   ├── ws_manager.py
│   └── integrations/        # folder-per-capability pattern (see its README)
│       ├── base.py          # Integration contract: actions() / snapshot() / monitor()
│       ├── system/          # OS actions: volume, lock, screenshot, battery, open_*
│       ├── vscode/          # workspace detection + open/status
│       ├── git/             # status/branches/tree/log + commit ops (state.py: parsing)
│       ├── media/           # MPRIS transport + xdotool fallback, open_spotify
│       ├── docker/          # container status + lifecycle + logs
│       ├── clipboard/       # get/set/history
│       └── context/         # Context Engine (apps.py: APP_MAP, detection.py: X11 probe)
app/                         # Flutter client
├── lib/
│   ├── main.dart            # phone client entrypoint
│   ├── main_tray.dart       # host companion (desktop tray) entrypoint
│   ├── protocol/message.dart
│   ├── services/            # tact_client (WS), pairing, discovery (mDNS)
│   ├── state/               # Riverpod providers (connection, telemetry)
│   ├── features/            # dashboard, context banner, actions, developer, media,
│   │                        # docker, clipboard, events, git, vscode
│   ├── host/                # tray controller, status service, settings
│   └── billing/             # entitlements (all unlocked for now)
├── android/ ios/ linux/ macos/ windows/
client/
└── index.html               # single-file web client fallback
tests/                       # agent tests
├── test_domain.py
└── test_integrations.py     # 43 tests, pytest
docs/
└── PHASE_TRACKER.md         # roadmap + status per phase
```

## Tests

```bash
python3 -m pytest tests/ -q        # agent unit tests (43 passing)
cd app && flutter test             # Flutter widget smoke test
```

