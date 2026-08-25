import SwiftUI
import TactCore
import AuthenticationServices

@main
struct TactApp: App {
    @StateObject private var model = TactAppModel()

    var body: some Scene {
        #if os(macOS)
        WindowGroup("Tact") { RootView().environmentObject(model).frame(minWidth: 980, minHeight: 680) }
            .windowStyle(.hiddenTitleBar)
            .commands { TactCommands(model: model) }
        Settings { SettingsView().environmentObject(model).frame(width: 620, height: 520) }
        #else
        WindowGroup { RootView().environmentObject(model) }
        #endif
    }
}

struct TactCommands: Commands {
    @ObservedObject var model: TactAppModel
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Disconnect") { Task { await model.disconnect() } }.keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
