# Native applications

Tact uses platform-native clients backed by the FastAPI desktop agent. The
clients share the WebSocket action protocol and account/device REST API, not a
cross-platform UI runtime.

| Platform | UI/runtime | Project |
| --- | --- | --- |
| iOS and iPadOS | SwiftUI | `native/apple/Tact` |
| macOS | SwiftUI, MenuBarExtra | `native/apple/TactApple` |
| Android | Kotlin, Jetpack Compose Material 3 | `native/android` |
| Windows | C#, WinUI 3, Win32 notification area | `native/windows/TactWindows` |
| Linux | Rust, GTK4/libadwaita, StatusNotifierItem | `native/linux` |
| Apple shared core | Swift actors, URLSession, Keychain | `native/core/TactCore` |

## Identity and trusted devices

The agent exposes four authentication paths:

- email and password, stored with salted `scrypt` password hashes;
- Sign in with Apple, using verified Apple identity tokens;
- Google Sign-In, using verified Google identity tokens;
- direct LAN pairing with a six-digit, single-use OTP and host approval.

Account sessions expire after 30 days and are stored by their SHA-256 digest.
Provider tokens are verified against the provider JWKS, issuer, audience, and
expiry. The registry records platform, model, endpoint, last-seen time, active
state, and whether a device can accept a connection. Selecting an account-owned
desktop grants a device-specific WebSocket token. Direct pairing still requires
explicit host approval.

Configure deployments without committing provider secrets:

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

For Android, set Gradle properties `tactAccountServiceUrl` and
`tactGoogleClientId`. For Xcode, set `TACT_ACCOUNT_SERVICE_URL`,
`TACT_GOOGLE_CLIENT_ID`, and `TACT_GOOGLE_REDIRECT_URI`. The macOS executable
reads the corresponding environment values. Apple web authentication requires
`/api/auth/apple/callback` to be registered with the Apple service identifier.

## Device roles and desktop lifecycle

Phones and tablets are controllers. Computers are hosts: desktop applications
do not render or execute the phone control surface.

- macOS starts in the menu bar with a Liquid Glass host panel. It displays the
  host IP and OTP, handles pairing approvals, and administers connections.
- Windows starts in the notification area. Left-click opens host status and
  connection administration; the context menu opens separate preferences.
- Linux publishes a freedesktop StatusNotifierItem. Its panel provides the same
  OTP, approval, and authorization controls.

The agent exposes `/api/host/status` for local host UI state. Revoking a device
also closes its active WebSocket rather than merely removing future access.

GNOME requires an AppIndicator/StatusNotifier shell extension, as is customary
for StatusNotifier applications.

## Design compatibility

Apple clients deploy back to iOS/iPadOS 17 and macOS 14. They use native Liquid
Glass APIs on Apple 26+ and fall back to system material on earlier supported
versions. Android uses Material 3 components, dynamic color when available,
adaptive navigation, edge-to-edge layout, Credential Manager, and system theme
behavior.

## Build and verification

```bash
python3 -m unittest discover -s tests -v

xcodebuild -project native/apple/Tact/Tact.xcodeproj \
  -scheme Tact -configuration Debug -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

swift build --package-path native/apple/TactApple

cd native/android
./gradlew :app:compileDebugKotlin

cd native/linux
cargo build --release

dotnet build native/windows/TactWindows/TactWindows.csproj
```

Windows packaging requires Windows App SDK/MSIX. Linux requires GTK4,
libadwaita, Rust, and a D-Bus session with StatusNotifier support.
