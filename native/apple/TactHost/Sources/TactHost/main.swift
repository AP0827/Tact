import AppKit
import Foundation
import SwiftUI

@main
struct TactHostApp: App {
    @StateObject private var model = HostModel()

    var body: some Scene {
        MenuBarExtra("Tact", systemImage: "bolt.horizontal.circle.fill") {
            HostMenu()
                .environmentObject(model)
        }

        Window("Tact Host Settings", id: "settings") {
            HostSettings()
                .environmentObject(model)
                .frame(width: 760, height: 620)
        }
    }
}

@MainActor
final class HostModel: ObservableObject {
    @Published var host = "127.0.0.1"
    @Published var port = "8000"
    @Published var otp = "—"
    @Published var expires = ""
    @Published var paired = 0
    @Published var pending: [[String: Any]] = []
    @Published var error: String?
    @Published var isRefreshing = false

    func refresh() async {
        guard let url = endpoint("/api/debug/config") else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try validate(response)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            paired = (json["paired_devices"] as? [[String: Any]])?.count ?? 0
            pending = json["pending_pairings"] as? [[String: Any]] ?? []
            otp = json["pairing_token"] as? String ?? "—"
            updateExpiration(json["pairing_token_expires"])
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func regenerate() async {
        guard let url = endpoint("/api/debug/regenerate-otp") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            otp = json["pairing_token"] as? String ?? "—"
            updateExpiration(json["pairing_token_expires"])
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func approve(_ id: String) async {
        await post("/api/pair/approve", pendingID: id)
        await refresh()
    }

    func reject(_ id: String) async {
        await post("/api/pair/reject", pendingID: id)
        await refresh()
    }

    private func post(_ path: String, pendingID: String) async {
        guard !pendingID.isEmpty, let url = endpoint(path) else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["pending_id": pendingID])
            let (_, response) = try await URLSession.shared.data(for: request)
            try validate(response)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func endpoint(_ path: String) -> URL? {
        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            error = "Enter a valid agent port."
            return nil
        }
        return URL(string: "http://\(host):\(portNumber)\(path)")
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    private func updateExpiration(_ value: Any?) {
        guard let timestamp = value as? Double else {
            expires = ""
            return
        }
        expires = "Expires \(Date(timeIntervalSince1970: timestamp).formatted(date: .omitted, time: .shortened))"
    }
}

struct HostMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: HostModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tact Host")
                .font(.headline)
            Text("OTP \(model.otp)")
                .font(.title3.monospaced())
            Text(model.expires)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Regenerate OTP") {
                Task { await model.regenerate() }
            }
            Button("Review approvals…") {
                openWindow(id: "settings")
                Task { await model.refresh() }
            }
            Divider()
            Button("Open settings…") {
                openWindow(id: "settings")
            }
            Button("Quit Tact Host") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .task { await model.refresh() }
    }
}

struct HostSettings: View {
    @EnvironmentObject private var model: HostModel

    var body: some View {
        NavigationSplitView {
            List {
                Section("Agent") {
                    TextField("Host", text: $model.host)
                    TextField("Port", text: $model.port)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tact Host")
                        .font(.largeTitle.weight(.bold))

                    hostGroup
                    approvalsGroup
                    connectionGroup

                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(28)
                .frame(maxWidth: 760)
            }
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await model.refresh() }
                }
                .disabled(model.isRefreshing)
            }
        }
    }

    private var hostGroup: some View {
        GroupBox("This host") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Hostname", value: Host.current().localizedName ?? "Mac")
                HStack {
                    Text("OTP")
                    Spacer()
                    Text(model.otp)
                        .font(.title2.monospaced())
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.otp, forType: .string)
                    }
                    Button("Regenerate") {
                        Task { await model.regenerate() }
                    }
                }
                LabeledContent("Paired devices", value: "\(model.paired)")
            }
            .padding(10)
        }
    }

    private var approvalsGroup: some View {
        GroupBox("Pending approvals") {
            VStack(alignment: .leading, spacing: 12) {
                if model.pending.isEmpty {
                    Text("No devices waiting for approval.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.pending.enumerated()), id: \.offset) { _, item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item["label"] as? String ?? "Device")
                                    .font(.headline)
                                Text(item["device_id"] as? String ?? "")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Approve") {
                                Task { await model.approve(item["pending_id"] as? String ?? "") }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Reject") {
                                Task { await model.reject(item["pending_id"] as? String ?? "") }
                            }
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    private var connectionGroup: some View {
        GroupBox("Agent connection") {
            VStack(spacing: 12) {
                TextField("Agent host", text: $model.host)
                TextField("Agent port", text: $model.port)
                Button("Save and refresh") {
                    Task { await model.refresh() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
        }
    }
}
