import SwiftUI
import TactCore
import AuthenticationServices
#if os(macOS)
import AppKit
#endif

@main
struct TactApp: App {
    @StateObject private var model = TactAppModel()

    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.accessory)
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("Tact", systemImage: menuBarIcon) {
            TactMenuBarView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Tact", id: "dashboard") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 680)
        }
            .windowStyle(.hiddenTitleBar)
            .commands { TactCommands(model: model) }
        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 620, height: 520)
        }
        #else
        WindowGroup { RootView().environmentObject(model) }
        #endif
    }

    private var menuBarIcon: String {
        model.connection == .connected
            ? "bolt.horizontal.circle.fill"
            : "bolt.horizontal.circle"
    }
}

#if os(macOS)
struct TactMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: TactAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundStyle(Color.tactCyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tact").font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Button("Open Tact") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            }
            SettingsLink { Text("Preferences…") }
            if model.connection == .connected {
                Button("Disconnect") { Task { await model.disconnect() } }
            }
            Divider()
            Button("Quit Tact") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 250)
    }

    private var statusText: String {
        switch model.connection {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .reconnecting: "Reconnecting"
        case .disconnected: "Ready to connect"
        }
    }
}
#endif

struct TactCommands: Commands {
    @ObservedObject var model: TactAppModel
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Disconnect") { Task { await model.disconnect() } }.keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
