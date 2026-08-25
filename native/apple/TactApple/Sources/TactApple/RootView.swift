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
    private let devices = [
        TactDevice(name: "Studio-Mac", platform: "macOS", model: "MacBook Pro", os: "macOS 27", ip: "192.168.1.42"),
        TactDevice(name: "Workstation", platform: "Windows", model: "Windows PC", os: "Windows 11", ip: "192.168.1.38"),
        TactDevice(name: "Linux-Dev", platform: "Linux", model: "Linux Workstation", os: "Ubuntu 24.04", ip: "192.168.1.51"),
        TactDevice(name: "Mac Mini", platform: "macOS", model: "Mac mini", os: "macOS 27", ip: "192.168.1.44")
    ]
    var body: some View {
        NavigationStack {
            List {
                Section("Available computers") {
                    ForEach(devices) { device in
                        Button { Task { await model.connect(device: device) } } label: { DeviceRow(device: device, busy: model.isBusy && model.selectedDevice?.id == device.id) }.buttonStyle(.plain)
                    }
                }
                Section { Button("Use IP + OTP") { model.phase = .login } }
            }
            .navigationTitle("Choose a computer")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Sign Out") { model.phase = .login } } }
        }
    }
}

struct DeviceRow: View {
    let device: TactDevice; let busy: Bool
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.platform == "Windows" ? "pc" : device.platform == "Linux" ? "server.rack" : "laptopcomputer")
                .font(.title2).frame(width: 44, height: 44).tactGlass()
            VStack(alignment: .leading, spacing: 3) { Text(device.name).font(.headline); Text("\(device.model) · \(device.os)").foregroundStyle(.secondary); Text(device.ip).font(.caption.monospaced()).foregroundStyle(.secondary) }
            Spacer(); if busy { ProgressView() } else { Text("Connect").foregroundStyle(Color.tactCyan) }
        }.padding(.vertical, 8)
    }
}
