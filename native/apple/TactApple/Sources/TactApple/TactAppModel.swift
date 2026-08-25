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
    @Published var error: String?
    @Published var isBusy = false
    @Published var demoMode = false
    @AppStorage("tact.appearance") var appearance = "system"

    private var messageTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    let client = TactClient.shared
    let pairing = PairingService.shared

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
        error = "Account sign-in requires the production identity service. Pair with your host using IP + OTP."
    }

    func demoSocialLogin(_ provider: String) async {
        error = "\(provider) sign-in requires its production OAuth configuration. Pair with your host using IP + OTP."
    }

    func connect(device: TactDevice) async {
        isBusy = true; error = nil; selectedDevice = device
        do {
            let token = await pairing.savedToken()
            if let token {
                try await client.connect(host: device.ip, port: 8000, token: token)
            } else {
                // Device selection can be used before pairing; the UI routes to OTP when needed.
                phase = .devices
                error = "This device is not paired yet. Use IP + OTP to pair it."
                isBusy = false
                return
            }
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
