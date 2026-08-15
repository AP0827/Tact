# Tact — Developer Control Surface

Tact turns your phone into a developer control surface for your laptop. The desktop agent runs locally, exposes safe allowlisted actions, and streams state to clients over WebSocket.

There are three moving parts:

- **Tact Agent** — a Python/FastAPI desktop agent running on the laptop (the brain)
- **Tact phone client** — a Flutter app that renders the interface and executes actions
- **Tact host companion** — a Flutter desktop tray app on the laptop that shows the pairing OTP and handles pairing approvals without touching the terminal


## What this contains

- FastAPI desktop agent with WebSocket server
- Allowlisted action registry (`system`, `vscode`, `git`)
- System telemetry (CPU, RAM, disk)
- Secure local pairing with 6-digit OTP and laptop-side approval
- JSON persistence for paired devices in `~/.tact/config.json`
- Event bus with severity levels and actionable notifications
- Git state, tree visualization, branch switching, pull/push/commit
- VS Code open workspace detection and recent workspaces dropdown
- Flutter phone client (dashboard, action grid, git + VS Code cards)
- Flutter host companion tray app (OTP display, pairing approvals, agent port config)
- mDNS agent discovery on the client (agent-side advertisement pending)
- Responsive web client fallback with orange/white theme

## Quick start

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

## VS Code workspace detection

`vscode.workspaces` reads VS Code's own state instead of scraping process
command lines (which are polluted by extension/language-server helper
processes). It parses each `~/.config/Code/User/workspaceStorage/<hash>/workspace.json`
(`folder` field, `file://` decoded), filters out VS Code install/extension
and cache directories, and sorts by storage-directory mtime so the currently
open workspace is listed first. Process cmdline scanning is kept only as a
fallback when the storage directory is unavailable.

## Available actions

- `system.open_url`
- `system.volume_up`
- `system.volume_down`
- `system.mute`
- `system.lock_screen`
- `system.screenshot`
- `system.open_terminal`
- `system.open_project`
- `vscode.open_workspace`
- `vscode.status`
- `vscode.workspaces`
- `git.status`
- `git.branches`
- `git.tree`
- `git._switch_branch`
- `git.pull`
- `git.push`
- `git.commit`

## Project structure

```
tact/                        # Python desktop agent
├── agent/
│   ├── __main__.py          # uvicorn entrypoint
│   ├── main.py              # FastAPI app, HTTP + WebSocket endpoints
│   ├── actions.py           # allowlisted action registry
│   ├── config.py            # pairing/OTP state, ~/.tact/config.json
│   ├── events.py            # Event + EventBus (severity, actions)
│   ├── monitoring.py        # periodic git/vscode state -> events
│   ├── ws_manager.py
│   └── integrations/
│       ├── git.py
│       ├── vscode.py
│       └── system.py        # OS-isolated system actions
app/                         # Flutter client
├── lib/
│   ├── main.dart            # phone client entrypoint
│   ├── main_tray.dart       # host companion (desktop tray) entrypoint
│   ├── protocol/message.dart
│   ├── services/            # tact_client (WS), pairing, discovery (mDNS)
│   ├── state/               # Riverpod providers (connection, telemetry)
│   ├── features/            # dashboard, actions grid, git card, vscode card
│   ├── host/                # tray controller, status service, settings
│   └── billing/             # entitlements (all unlocked for now)
├── android/ ios/ linux/ macos/ windows/
client/
└── index.html               # single-file web client fallback
tests/                       # agent tests (unittest/pytest)
└── test_domain.py
└── test_integrations.py
scripts/                     # legacy OptiLab DB helpers (unrelated)
```

## Tests

```bash
python3 -m pytest tests/ -q        # agent unit tests
cd app && flutter test             # Flutter widget smoke test
```

## Color scheme

The clients use a vibrant orange/white palette adapted from OptiLab:
- Primary: `#f07316` (orange-500)
- Background: `#ffffff`
- Accents: warm orange gradients

## Next steps

- add Docker integration (status + start/stop/restart/logs)
- add build/test actions and richer event types (`build.failed`, `tests.failed`)
- advertise the agent over mDNS (client already supports it)
- improve client reconnect and offline handling
- add a local metrics collector inspired by OptiLab's `combined_monitor.py`