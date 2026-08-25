import SwiftUI
import TactCore
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class TactAppModel: ObservableObject {
    enum Phase { case login, devices, connected }
    @Published var phase: Phase = .login
    @Published var screen: TactScreen = .general
    @Published var connection: TactConnectionState = .disconnected
    @Published var snapshot = TactSnapshot()
    @Published var events: [[String: AnySendable]] = []
    @Published var selectedDevice: TactDevice?
    @Published var accountDevices: [TactAccountDevice] = []
    @Published var account: TactAccount?
    @Published var error: String?
    @Published var isBusy = false
    @Published var demoMode = false
    @AppStorage("tact.appearance") var appearance = "system"

    private var messageTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    let client = TactClient.shared
    let pairing = PairingService.shared
    let accountService = AccountService.shared

    var accountServiceURL: URL? {
        let configured = ProcessInfo.processInfo.environment["TACT_ACCOUNT_SERVICE_URL"]
            ?? UserDefaults.standard.string(forKey: "tact.account.serviceURL")
            ?? "http://127.0.0.1:8000"
        return URL(string: configured)
    }

    init() {
        messageTask = Task {
            for await message in client.messages {
                await MainActor.run { self.consume(message) }
            }
        }
        statusTask = Task {
            for await state in client.status {
                await MainActor.run { self.connection = state }
            }
        }
    }

    deinit { messageTask?.cancel(); statusTask?.cancel() }

    private func consume(_ message: TactMessage) {
        switch message.type {
        case "init", "telemetry": snapshot = TactSnapshot(values: message.payload)
        case "event": events.insert(message.payload, at: 0); if events.count > 100 { events.removeLast() }
        default: break
        }
    }

    func signIn(email: String, password: String) async {
        isBusy = true; error = nil
        defer { isBusy = false }
        guard let accountServiceURL else { error = "Invalid account service address."; return }
        do {
            let session = try await accountService.signIn(
                serviceURL: accountServiceURL,
                email: email,
                password: password
            )
            account = session.account
            try await registerMac()
            try await refreshDevices()
            phase = .devices
        } catch { self.error = error.localizedDescription }
    }

    func signIn(provider: String, identityToken: String) async {
        isBusy = true; error = nil
        defer { isBusy = false }
        guard let accountServiceURL else { error = "Invalid account service address."; return }
        do {
            let session = try await accountService.signIn(
                serviceURL: accountServiceURL,
                provider: provider,
                identityToken: identityToken
            )
            account = session.account
            try await registerMac()
            try await refreshDevices()
            phase = .devices
        } catch { self.error = error.localizedDescription }
    }

    func refreshDevices() async throws {
        guard let accountServiceURL else { throw AccountServiceError.invalidServiceURL }
        accountDevices = try await accountService.devices(serviceURL: accountServiceURL)
    }

    private func registerMac() async throws {
        guard let accountServiceURL else { throw AccountServiceError.invalidServiceURL }
        try await accountService.registerDevice(
            serviceURL: accountServiceURL,
            deviceID: await pairing.deviceID(),
            label: deviceName,
            platform: "macos",
            deviceType: "desktop",
            model: "Mac",
            host: localAddress,
            port: 8000
        )
    }

    private var localAddress: String? {
        Host.current().addresses.first {
            $0.contains(".") && !$0.hasPrefix("127.")
        }
    }

    func connect(device: TactAccountDevice) async {
        isBusy = true; error = nil
        selectedDevice = TactDevice(
            id: device.deviceID,
            name: device.label,
            platform: device.platform,
            model: device.model,
            os: device.platform,
            ip: device.host ?? "",
            connected: device.active
        )
        do {
            guard let accountServiceURL else { throw AccountServiceError.invalidServiceURL }
            let connection = try await accountService.connection(
                serviceURL: accountServiceURL,
                targetDeviceID: device.deviceID,
                clientDeviceID: await pairing.deviceID(),
                clientLabel: deviceName
            )
            await pairing.saveTrustedToken(connection.token)
            try await client.connect(host: connection.host, port: connection.port, token: connection.token)
            phase = .connected
        } catch { self.error = error.localizedDescription }
        isBusy = false
    }

    func pair(host: String, otp: String) async {
        isBusy = true; error = nil
        do {
            let token = try await pairing.pairWithOTP(host: host, port: 8000, otp: otp, label: deviceName)
            demoMode = false
            try await client.connect(host: host, port: 8000, token: token)
            selectedDevice = TactDevice(name: host, platform: "desktop", model: "Tact Host", os: "Desktop", ip: host, connected: true)
            phase = .connected
        } catch { self.error = error.localizedDescription }
        isBusy = false
    }

    func disconnect() async { await client.disconnect(); phase = .devices; connection = .disconnected }

    func signOut() async {
        await client.disconnect()
        await accountService.signOut(serviceURL: accountServiceURL)
        account = nil
        accountDevices = []
        selectedDevice = nil
        phase = .login
        connection = .disconnected
    }

    func action(_ id: String, payload: [String: Any] = [:]) {
        if demoMode { return }
        let sendablePayload = payload.mapValues(AnySendable.init)
        Task {
            do { _ = try await client.sendAction(id, payload: sendablePayload) }
            catch { await MainActor.run { self.error = error.localizedDescription } }
        }
    }

    var deviceName: String {
#if os(iOS)
        UIDevice.current.name
#else
        Host.current().localizedName ?? "Mac"
#endif
    }

    func value(_ path: String) -> Double? {
        let parts = path.split(separator: ".").map(String.init)
        var current: Any = snapshot.values
        for part in parts {
            guard let dict = current as? [String: AnySendable], let next = dict[part]?.value else { return nil }
            current = next
        }
        if let n = current as? NSNumber { return n.doubleValue }
        if let n = current as? Double { return n }
        if let n = current as? Int { return Double(n) }
        return nil
    }

    func string(_ path: String) -> String? {
        let parts = path.split(separator: ".").map(String.init)
        var current: Any = snapshot.values
        for part in parts {
            guard let dict = current as? [String: AnySendable], let next = dict[part]?.value else { return nil }
            current = next
        }
        return current as? String
    }
}
