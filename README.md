# Tact — Native Developer Control Surface

Tact turns a phone or tablet into a secure control surface for a computer. A
local FastAPI agent exposes an allowlisted action protocol, publishes live
telemetry and context, and connects to separate native clients for every
supported operating system.

The client stack is fully native:

| Platform | Technology | Location |
| --- | --- | --- |
| iOS and iPadOS | Swift, SwiftUI | `native/apple/Tact` |
| macOS | Swift, SwiftUI, MenuBarExtra | `native/apple/TactApple` |
| Android | Kotlin, Jetpack Compose, Material 3 | `native/android` |
| Windows | C#, WinUI 3, Win32 notification area | `native/windows/TactWindows` |
| Linux | Rust, GTK4, libadwaita, StatusNotifierItem | `native/linux` |
| Shared Apple services | Swift actors, URLSession, Keychain | `native/core/TactCore` |

The legacy cross-platform client has been removed. Native clients and the
Python agent communicate through the same REST and WebSocket contracts without
a shared UI runtime.

## Features

- Native, adaptive phone and tablet interfaces for iOS, iPadOS, and Android.
- Liquid Glass on Apple 26+ with system-material fallback on iOS/iPadOS 17+
  and macOS 14+.
- Material 3 components, dynamic color, edge-to-edge layout, system light/dark
  themes, and adaptive navigation on Android.
- Host-only menu-bar macOS app and notification-area Windows/Linux apps. Their
  panels show the host address and OTP, approve or reject controllers, and
  terminate active authorizations. Computers never expose controller actions.
- Email/password, Sign in with Apple, Google Sign-In, and direct IP + one-time
  code authentication.
- Account-scoped trusted-device registry with platform icons, active state,
  endpoint discovery, and one-tap connection.
- Secure LAN pairing with a six-digit, single-use code and host approval.
- Live CPU, memory, disk, battery, Git, Docker, media, clipboard, window, and
  developer-workflow state.
- Context-aware surfaces driven by the focused app, project, branch, Docker
  activity, and manual overrides.
- An allowlisted action registry covering system controls, VS Code, Git,
  Docker, media, clipboard, browsers, meetings, windows, projects, and terminals.

## Architecture

```text
native/
├── apple/
│   ├── Tact/                 # iOS and iPadOS Xcode project
│   ├── TactApple/            # macOS menu-bar application
│   └── TactHost/             # lightweight Apple host companion
├── android/                  # Android Gradle project
├── windows/TactWindows/      # Windows App SDK / WinUI 3 project
├── linux/                    # GTK4/libadwaita application
└── core/TactCore/            # shared Apple networking and secure storage

tact/agent/
├── main.py                   # FastAPI REST and WebSocket endpoints
├── accounts.py               # accounts, sessions, providers, device registry
├── actions.py                # allowlisted action registry
├── config.py                 # local pairing and trusted-device state
├── events.py                 # event bus
├── monitoring.py             # state-change monitoring
└── integrations/             # platform and developer integrations

client/index.html             # minimal browser fallback
tests/                        # backend and integration tests
docs/                         # architecture and roadmap documentation
```

The agent sends an initial snapshot after authentication, refreshes telemetry,
and publishes state-change events. Phone and tablet controllers build their
complete control catalog from the actions advertised in that snapshot. The
agent executes only actions registered in `ActionRegistry`.

## Quick start

### 1. Run the desktop agent

Python 3.11 or newer is recommended.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m tact.agent
```

For development with reload:

```bash
uvicorn tact.agent.main:app --reload --host 0.0.0.0 --port 8000
```

The default service listens on port `8000`. Keep the computer and phone on the
same trusted network when using direct pairing.

### 2. Configure account providers

Email/password and direct LAN pairing require no external provider secret.
Apple and Google authentication use deployment configuration:

```text
TACT_ACCOUNT_SERVICE_URL
TACT_GOOGLE_CLIENT_ID
TACT_GOOGLE_REDIRECT_URI
TACT_APPLE_CLIENT_ID
TACT_APPLE_TEAM_ID
TACT_APPLE_KEY_ID
TACT_APPLE_PRIVATE_KEY
TACT_APPLE_REDIRECT_URI
```

Never commit private keys or provider secrets. Register
`/api/auth/apple/callback` as the Apple service callback. Android reads
`tactAccountServiceUrl` and `tactGoogleClientId` from Gradle properties. Apple
builds read the corresponding Xcode build settings or environment values.

### 3. Build a native client

#### iOS and iPadOS

Open `native/apple/Tact/Tact.xcodeproj` in Xcode, select the `Tact` scheme and
an iPhone or iPad destination, configure signing, then run.

An unsigned command-line verification build can be run with:

```bash
xcodebuild -project native/apple/Tact/Tact.xcodeproj \
  -scheme Tact \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

#### macOS

```bash
swift run --package-path native/apple/TactApple
```

Tact starts in the menu bar as a host utility. Its Liquid Glass panel shows the
host IP, current OTP, pending approvals, and connection status. Settings exposes
OTP regeneration and per-controller or global termination.

#### Android

Open `native/android` in Android Studio, or build from the command line:

```bash
cd native/android
./gradlew :app:assembleDebug
```

Install the generated APK on a device or run the app from Android Studio. For a
local agent reached from the Android emulator, the default account service is
`http://10.0.2.2:8000`; set `tactAccountServiceUrl` for physical devices and
deployed environments.

#### Windows

Install Visual Studio with the .NET desktop and Windows App SDK workloads, then:

```powershell
dotnet build native/windows/TactWindows/TactWindows.csproj
```

Launch the packaged application. It starts in the Windows notification area;
left-click opens the dashboard and the context menu exposes Preferences and
Quit.

#### Linux

Install Rust, GTK4, libadwaita, and development headers. On Debian/Ubuntu:

```bash
sudo apt install build-essential libgtk-4-dev libadwaita-1-dev
cargo build --release --manifest-path native/linux/Cargo.toml
```

The app publishes a StatusNotifierItem. GNOME users need an
AppIndicator/StatusNotifier shell extension.

## Authentication and connection

### Account sign-in

1. Choose email/password, Apple, or Google in a supported native client.
2. The agent verifies the credentials or provider identity and issues a
   revocable 30-day session.
3. The client registers its stable device identity and loads every device for
   that account.
4. Active computers display their platform, model, and connection state.
5. Selecting a connectable computer grants a device-specific WebSocket token
   and opens the control surface.

Passwords are stored as salted `scrypt` hashes. Session tokens are stored only
as SHA-256 digests. Provider identity tokens are checked against issuer,
audience, expiry, and provider signing keys.

### Direct IP + one-time code

1. Start the agent and copy the six-digit code from its startup output.
2. Enter the computer address and code in the native client.
3. Approve the pending request at:

   ```text
   http://<computer-address>:8000/admin/pair/pending
   ```

4. The client stores its device token securely and reconnects without another
   code until the device is revoked.

Codes expire after five minutes, are single use, and still require explicit
host approval.

## Optional desktop integrations

The agent degrades gracefully when an optional integration is unavailable.
Common Linux packages are:

```bash
sudo apt install git playerctl xdotool wmctrl xclip x11-utils pulseaudio-utils
```

- `git` enables repository state and actions.
- `playerctl` enables MPRIS media status and transport.
- `xdotool` provides media-key fallback and focused-app shortcuts on X11.
- `wmctrl` enables app discovery, focus, window controls, and layouts.
- `xclip`, `xsel`, or `wl-clipboard` enables the text clipboard bridge.
- `xprop` provides focused-window context on X11.
- `pactl` provides volume and audio-device controls.
- Docker CLI access enables container state and lifecycle actions.

## Protocol

Authenticated clients connect to `/ws` and exchange three message classes:

| Channel | Direction | Purpose |
| --- | --- | --- |
| State | Agent → client | Initial snapshot and live telemetry |
| Events | Agent → client | Context, Git, Docker, and other state changes |
| Actions | Client → agent | Allowlisted request and structured result |

Slow system commands run outside the event loop. State-changing actions trigger
an immediate refreshed snapshot.

The browser fallback remains available at:

```text
http://<computer-address>:8000/client/index.html
```

## Tests

Run the complete backend and integration suite:

```bash
python3 -m unittest discover -s tests -v
```

Useful native verification commands:

```bash
swift build --package-path native/core/TactCore
swift build --package-path native/apple/TactApple
swift build --package-path native/apple/TactHost

cd native/android
./gradlew :app:compileDebugKotlin
```

Run the Windows and Linux builds on their target operating systems for final
packaging and tray-integration validation.

## Documentation

- [`docs/NATIVE_APPS.md`](docs/NATIVE_APPS.md) — platform architecture,
  provider configuration, lifecycle, and build details.
- [`docs/GITHUB_ROADMAP_AUDIT.md`](docs/GITHUB_ROADMAP_AUDIT.md) — current issue
  and milestone implementation audit.
- [`docs/PHASE_TRACKER.md`](docs/PHASE_TRACKER.md) — detailed product roadmap.

## Security

- Every remote action is explicitly registered and allowlisted.
- WebSocket clients must authenticate before receiving state or executing an
  action.
- Direct pairing requires a short-lived code and host approval.
- Provider secrets stay in deployment configuration.
- Account sessions can be revoked independently.
- Device records are scoped to their owning account.
