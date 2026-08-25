import SwiftUI
import TactCore

struct RootView: View {
    @EnvironmentObject private var model: TactAppModel
    var body: some View {
        Group {
            switch model.phase {
            case .login: AuthView()
            case .devices: DeviceSelectionView()
            case .connected: MainShellView()
            }
        }
        .preferredColorScheme(nil)
    }
}

struct DeviceSelectionView: View {
    @EnvironmentObject private var model: TactAppModel
    var body: some View {
        NavigationStack {
            List {
                Section("Available computers") {
                    ForEach(model.accountDevices) { device in
                        Button { Task { await model.connect(device: device) } } label: { DeviceRow(device: device, busy: model.isBusy && model.selectedDevice?.id == device.id) }.buttonStyle(.plain)
                            .disabled(!device.canConnect)
                    }
                }
                if model.accountDevices.isEmpty {
                    ContentUnavailableView("No computers yet", systemImage: "desktopcomputer", description: Text("Sign in on another desktop to see it here."))
                }
                Section { Button("Refresh devices") { Task { try? await model.refreshDevices() } } }
                Section { Button("Use IP + OTP") { model.phase = .login } }
            }
            .navigationTitle("Choose a computer")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Sign Out") { Task { await model.signOut() } } } }
        }
    }
}

struct DeviceRow: View {
    let device: TactAccountDevice; let busy: Bool
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.platform == "windows" ? "pc" : device.platform == "linux" ? "server.rack" : device.platform == "android" ? "smartphone" : "laptopcomputer")
                .font(.title2).frame(width: 44, height: 44).tactGlass()
            VStack(alignment: .leading, spacing: 3) { Text(device.label).font(.headline); Text("\(device.model) · \(device.platform)").foregroundStyle(.secondary); Text(device.active ? "Active now" : "Offline").font(.caption).foregroundStyle(device.active ? .green : .secondary) }
            Spacer(); if busy { ProgressView() } else if device.canConnect { Text("Connect").foregroundStyle(Color.tactCyan) } else { Text("This device").foregroundStyle(.secondary) }
        }.padding(.vertical, 8)
    }
}
