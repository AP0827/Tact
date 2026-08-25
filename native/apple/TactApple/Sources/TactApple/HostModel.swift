import AppKit
import Foundation
import SwiftUI

struct HostDevice: Identifiable {
    let id: String
    let label: String
    let lastSeen: String
    let active: Bool
}

struct HostApproval: Identifiable {
    let id: String
    let deviceID: String
    let label: String
    let createdAt: String
}

@MainActor
final class HostModel: ObservableObject {
    @Published var host = "127.0.0.1"
    @Published var port = 8000
    @Published var otp = "—"
    @Published var expiresAt: Date?
    @Published var devices: [HostDevice] = []
    @Published var approvals: [HostApproval] = []
    @Published var error: String?
    @Published var refreshing = false
    @AppStorage("tact.host.agentURL") var agentURL = "http://127.0.0.1:8000"

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func refresh() async {
        refreshing = true
        defer { refreshing = false }
        do {
            let json = try await request("/api/host/status")
            host = json["host"] as? String ?? host
            port = json["port"] as? Int ?? port
            otp = json["pairing_token"] as? String ?? "—"
            if let timestamp = json["pairing_token_expires"] as? Double { expiresAt = Date(timeIntervalSince1970: timestamp) }
            devices = (json["paired_devices"] as? [[String: Any]] ?? []).map {
                HostDevice(id: $0["device_id"] as? String ?? UUID().uuidString,
                           label: $0["label"] as? String ?? "Controller",
                           lastSeen: $0["last_seen"] as? String ?? "Never",
                           active: $0["active"] as? Bool ?? false)
            }
            approvals = (json["pending_pairings"] as? [[String: Any]] ?? []).map {
                HostApproval(id: $0["pending_id"] as? String ?? UUID().uuidString,
                             deviceID: $0["device_id"] as? String ?? "",
                             label: $0["label"] as? String ?? "New controller",
                             createdAt: $0["created_at"] as? String ?? "")
            }
            error = nil
        } catch { self.error = "Start the Tact agent to manage this host. \(error.localizedDescription)" }
    }

    func regenerateOTP() async { _ = try? await request("/api/debug/regenerate-otp", method: "POST"); await refresh() }
    func approve(_ approval: HostApproval) async { _ = try? await request("/api/pair/approve", method: "POST", body: ["pending_id": approval.id]); await refresh() }
    func reject(_ approval: HostApproval) async { _ = try? await request("/api/pair/reject", method: "POST", body: ["pending_id": approval.id]); await refresh() }
    func terminate(_ device: HostDevice) async { _ = try? await request("/api/pair/reset", method: "POST", body: ["device_id": device.id]); await refresh() }
    func terminateAll() async { _ = try? await request("/api/pair/reset_all", method: "POST"); await refresh() }

    func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let base = URL(string: agentURL), let url = URL(string: path, relativeTo: base)?.absoluteURL else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
