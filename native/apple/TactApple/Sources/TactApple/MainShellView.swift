import SwiftUI
import TactCore

struct MainShellView: View {
    @EnvironmentObject private var model: TactAppModel
    @State private var showingProfile = false
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(TactScreen.allCases, id: \.self, selection: $model.screen) { screen in
                Label(screen.title, systemImage: screen.symbol).tag(screen)
            }.navigationTitle("Tact")
        } detail: { content }
        .toolbar { ToolbarItem(placement: .primaryAction) { ProfileMenu(showing: $showingProfile) } }
        .sheet(isPresented: $showingProfile) { ProfileSheet() }
        #else
        TabView(selection: $model.screen) {
            ForEach(TactScreen.allCases, id: \.self) { screen in contentFor(screen).tabItem { Label(screen.title, systemImage: screen.symbol) }.tag(screen) }
        }
        .safeAreaInset(edge: .top) { HeaderView(showingProfile: $showingProfile) }
        .sheet(isPresented: $showingProfile) { ProfileSheet() }
        #endif
    }
    @ViewBuilder private var content: some View { contentFor(model.screen) }
    @ViewBuilder private func contentFor(_ screen: TactScreen) -> some View {
        switch screen { case .general: GeneralView(); case .developer: DeveloperView(); case .media: MediaView(); case .events: EventsView(); case .deck: DeckView() }
    }
}

extension TactScreen {
    var title: String { switch self { case .general: "General"; case .developer: "Developer"; case .media: "Media"; case .events: "Events"; case .deck: "Deck" } }
    var symbol: String { switch self { case .general: "rectangle.grid.2x2"; case .developer: "chevron.left.forwardslash.chevron.right"; case .media: "play.circle"; case .events: "bell"; case .deck: "square.grid.2x2" } }
}

struct HeaderView: View {
    @EnvironmentObject private var model: TactAppModel
    @Binding var showingProfile: Bool
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 2) { Text(greeting).font(.title3.weight(.bold)); Text("\(model.selectedDevice?.name ?? "Tact Host") is connected and ready.").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { showingProfile = true } label: { Text("A").font(.headline).frame(width: 38, height: 38).background(Color.tactCyan.opacity(0.18), in: Circle()) } }
            .padding(.horizontal).padding(.vertical, 8).background(.ultraThinMaterial)
    }
    private var greeting: String { let h = Calendar.current.component(.hour, from: .now); return h >= 5 && h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening" }
}

struct ProfileMenu: View { @Binding var showing: Bool; var body: some View { Button { showing = true } label: { Text("A").frame(width: 30, height: 30).background(Color.tactCyan.opacity(0.18), in: Circle()) } } }

struct ProfileSheet: View {
    @EnvironmentObject private var model: TactAppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { List { Section("Account") { Label("Local user", systemImage: "person.crop.circle") }; Section("Tact") { NavigationLink("Settings") { SettingsView() }; NavigationLink("Devices") { DeviceSelectionView() }; Label("Connection · \(model.connection.label)", systemImage: "network") }; Section { Button("Log Out", role: .destructive) { Task { await model.disconnect(); dismiss() } } } }.navigationTitle("Profile") }
    }
}
extension TactConnectionState { var label: String { switch self { case .disconnected: "Disconnected"; case .connecting: "Connecting"; case .connected: "Connected"; case .reconnecting: "Reconnecting" } } }
