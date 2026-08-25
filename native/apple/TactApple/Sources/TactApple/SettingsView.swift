import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: TactAppModel
    var body: some View {
        Form {
            Section("Appearance") { Picker("Theme", selection: $model.appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.pickerStyle(.segmented) }
            Section("Connection") { LabeledContent("Device", value: model.selectedDevice?.name ?? "None"); LabeledContent("Host", value: model.selectedDevice?.ip ?? "—"); LabeledContent("Status", value: model.connection.label) }
            Section("About") { LabeledContent("Tact", value: "Native 2.0"); Text("A native control surface for your development machines.").foregroundStyle(.secondary) }
        }.formStyle(.grouped).navigationTitle("Settings")
    }
}

struct GeneralView: View {
    @EnvironmentObject private var model: TactAppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                #if os(macOS)
                Text(greeting).font(.largeTitle.weight(.bold))
                Text("\(model.selectedDevice?.name ?? "Tact Host") is connected and ready.").foregroundStyle(.secondary)
                #endif
                HStack { Image(systemName: "desktopcomputer").font(.title); VStack(alignment: .leading) { Text(model.selectedDevice?.name ?? "Tact Host").font(.headline); Text("\(model.selectedDevice?.model ?? "Desktop") · \(model.selectedDevice?.os ?? "Connected host")").foregroundStyle(.secondary); Text(model.selectedDevice?.ip ?? "—").font(.caption.monospaced()).foregroundStyle(.secondary) }; Spacer(); Label(model.connection.label, systemImage: "circle.fill").foregroundStyle(model.connection == .connected ? .green : .orange) }.padding(20).tactGlass()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    MetricView(title: "CPU", systemImage: "cpu", value: metric("system.cpu")); MetricView(title: "Memory", systemImage: "memorychip", value: metric("system.memory")); MetricView(title: "Disk", systemImage: "internaldrive", value: metric("system.disk")); MetricView(title: "Battery", systemImage: "battery.100percent", value: metric("system.battery"))
                }
                Text("Quick Controls").font(.title3.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    QuickAction("Lock Screen", "lock.fill", "system.lock_screen"); QuickAction("Terminal", "terminal", "system.open_terminal"); QuickAction("Open URL", "link", "system.open_url"); QuickAction("Project", "folder", "system.open_project"); QuickAction("Screenshot", "camera.viewfinder", "system.screenshot"); QuickAction("Mute", "speaker.slash", "system.mute")
                }
                if let context = model.string("context.summary") { Text(context).font(.callout).foregroundStyle(.secondary).padding(.top, 4) }
            }.padding(24).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }.background(Color.primary.opacity(0.015))
    }
    private func metric(_ key: String) -> Double? { model.value(key) }
    private var greeting: String { let h = Calendar.current.component(.hour, from: .now); return h >= 5 && h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening" }
}
struct QuickAction: View { @EnvironmentObject private var model: TactAppModel; let title: String; let icon: String; let actionID: String; init(_ title: String, _ icon: String, _ actionID: String) { self.title=title; self.icon=icon; self.actionID=actionID }; var body: some View { Button { model.action(actionID) } label: { Label(title, systemImage: icon).frame(maxWidth: .infinity, minHeight: 58) }.buttonStyle(.bordered).tactGlass() } }
