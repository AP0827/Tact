import AppKit
import SwiftUI

@main
struct TactApp: App {
    @StateObject private var model = HostModel()

    init() { NSApplication.shared.setActivationPolicy(.accessory) }

    var body: some Scene {
        MenuBarExtra("Tact Host", systemImage: model.approvals.isEmpty ? "bolt.horizontal.circle" : "bolt.horizontal.circle.fill") {
            HostPanel().environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            HostSettingsView().environmentObject(model).frame(width: 680, height: 620)
        }
    }
}

struct HostPanel: View {
    @EnvironmentObject private var model: HostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bolt.horizontal.fill").font(.title2).foregroundStyle(Color.tactCyan)
                VStack(alignment: .leading) { Text("Tact Host").font(.headline); Text("\(model.host):\(model.port)").font(.caption.monospaced()).foregroundStyle(.secondary) }
                Spacer()
                Circle().fill(model.error == nil ? .green : .orange).frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PAIRING CODE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                HStack {
                    Text(model.otp).font(.system(size: 30, weight: .semibold, design: .monospaced)).tracking(5)
                    Spacer()
                    Button { model.copy(model.otp) } label: { Image(systemName: "doc.on.doc") }
                    Button { Task { await model.regenerateOTP() } } label: { Image(systemName: "arrow.clockwise") }
                }
                if let expiry = model.expiresAt { Text("Expires \(expiry.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(14).tactGlass(prominent: true)

            if !model.approvals.isEmpty {
                Text("Waiting for approval").font(.headline)
                ForEach(model.approvals) { approval in
                    VStack(alignment: .leading, spacing: 9) {
                        Label(approval.label, systemImage: "iphone.gen3")
                        Text(approval.deviceID).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        HStack {
                            Button("Reject", role: .destructive) { Task { await model.reject(approval) } }
                            Spacer()
                            Button("Allow") { Task { await model.approve(approval) } }.buttonStyle(.borderedProminent).tint(Color.tactCyan)
                        }
                    }.padding(12).tactGlass()
                }
            }

            Divider()
            SettingsLink { Label("Host Settings…", systemImage: "gearshape") }
            Button { Task { await model.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Divider()
            Button("Quit Tact Host") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .task { await model.refresh() }
    }
}

struct HostSettingsView: View {
    @EnvironmentObject private var model: HostModel

    var body: some View {
        NavigationStack {
            Form {
                Section("This host") {
                    LabeledContent("Host IP", value: model.host)
                    LabeledContent("Port", value: "\(model.port)")
                    HStack { LabeledContent("Current OTP", value: model.otp); Button("Copy") { model.copy(model.otp) }; Button("Regenerate") { Task { await model.regenerateOTP() } } }
                    TextField("Agent service URL", text: $model.agentURL)
                    Button("Refresh host status") { Task { await model.refresh() } }
                }
                Section("Pending approvals") {
                    if model.approvals.isEmpty { Text("No controllers are waiting for approval.").foregroundStyle(.secondary) }
                    ForEach(model.approvals) { approval in
                        HStack { Label(approval.label, systemImage: "person.badge.clock"); Spacer(); Button("Reject", role: .destructive) { Task { await model.reject(approval) } }; Button("Allow") { Task { await model.approve(approval) } }.buttonStyle(.borderedProminent) }
                    }
                }
                Section("Authorized controllers") {
                    if model.devices.isEmpty { Text("No controllers are authorized.").foregroundStyle(.secondary) }
                    ForEach(model.devices) { device in
                        HStack {
                            Image(systemName: device.active ? "dot.radiowaves.left.and.right" : "iphone")
                                .foregroundStyle(device.active ? .green : .secondary)
                            VStack(alignment: .leading) { Text(device.label); Text(device.active ? "Connected now" : "Last seen \(device.lastSeen)").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button("Terminate", role: .destructive) { Task { await model.terminate(device) } }
                        }
                    }
                    if !model.devices.isEmpty { Button("Terminate all connections", role: .destructive) { Task { await model.terminateAll() } } }
                }
                if let error = model.error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
            }
            .formStyle(.grouped)
            .navigationTitle("Tact Host Settings")
        }
    }
}
