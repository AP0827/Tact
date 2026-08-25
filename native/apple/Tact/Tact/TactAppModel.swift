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

    enum Phase {
        case login
        case devices
        case connected
    }

    @Published var phase: Phase = .login
    @Published var screen: TactScreen = .general
    @Published var connection: TactConnectionState = .disconnected
    @Published var snapshot = TactSnapshot()
    @Published var events: [[String: AnySendable]] = []
    @Published var selectedDevice: TactDevice?
    @Published var error: String?
    @Published var isBusy = false
    @Published var demoMode = false
    @Published var authMode = 0

    @AppStorage("tact.appearance")
    var appearance = "system"

    private var messageTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    let client = TactClient.shared
    let pairing = PairingService.shared

    init() {
        messageTask = Task {
            for await message in client.messages {
                await MainActor.run {
                    self.consume(message)
                }
            }
        }

        statusTask = Task {
            for await state in client.status {
                await MainActor.run {
                    self.connection = state
                }
            }
        }
    }

    deinit {
        messageTask?.cancel()
        statusTask?.cancel()
    }

    private func consume(_ message: TactMessage) {
        switch message.type {
        case "init", "telemetry":
            snapshot = TactSnapshot(values: message.payload)

        case "event":
            events.insert(message.payload, at: 0)

            if events.count > 100 {
                events.removeLast()
            }

        default:
            break
        }
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async {
        error = "Account sign-in requires the production identity service. Pair with your host using IP + OTP."
    }

    func demoSocialLogin(_ provider: String) async {
        error = "\(provider) sign-in requires its production OAuth configuration. Pair with your host using IP + OTP."
    }

    // MARK: - Device Connection

    func connect(device: TactDevice) async {
        error = nil
        isBusy = true
        selectedDevice = device

        guard let token = await pairing.savedToken() else {
            error = "This host is not paired. Use IP + OTP to pair it first."
            isBusy = false
            return
        }

        do {
            try await client.connect(
                host: device.ip,
                port: 8000,
                token: token
            )
            demoMode = false
            connection = .connected
            phase = .connected
        } catch {
            self.error = error.localizedDescription
        }
        isBusy = false
    }

    func pair(host: String, otp: String) async {
        error = nil
        isBusy = true

        defer {
            isBusy = false
        }

        let cleanHost = host.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanHost.isEmpty else {
            error = "Enter the host IP address."
            return
        }

        guard otp.count == 6 else {
            error = "Enter the 6-digit OTP."
            return
        }

        do {
            let token = try await pairing.pairWithOTP(
                host: cleanHost,
                port: 8000,
                otp: otp,
                label: deviceName
            )

            demoMode = false

            try await client.connect(
                host: cleanHost,
                port: 8000,
                token: token
            )

            selectedDevice = TactDevice(
                name: cleanHost,
                platform: "desktop",
                model: "Tact Host",
                os: "Desktop",
                ip: cleanHost,
                connected: true
            )

            connection = .connected
            phase = .connected

        } catch {
            self.error = error.localizedDescription
        }
    }

    func disconnect() async {
        await client.disconnect()

        demoMode = false
        selectedDevice = nil
        connection = .disconnected
        phase = .login
        authMode = 0
    }

    // MARK: - Actions

    func action(
        _ id: String,
        payload: [String: Any] = [:]
    ) {
        if demoMode {
            return
        }

        let sendablePayload = payload.mapValues(AnySendable.init)

        Task {
            do {
                _ = try await client.sendAction(
                    id,
                    payload: sendablePayload
                )
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Device

    var deviceName: String {
#if os(iOS)
        UIDevice.current.name
#else
        Host.current().localizedName ?? "Mac"
#endif
    }

    // MARK: - Snapshot Helpers

    func value(_ path: String) -> Double? {
        let parts = path
            .split(separator: ".")
            .map(String.init)

        var current: Any = snapshot.values

        for part in parts {
            guard
                let dictionary =
                    current as? [String: AnySendable],
                let next = dictionary[part]?.value
            else {
                return nil
            }

            current = next
        }

        if let number = current as? NSNumber {
            return number.doubleValue
        }

        if let number = current as? Double {
            return number
        }

        if let number = current as? Int {
            return Double(number)
        }

        return nil
    }

    func string(_ path: String) -> String? {
        let parts = path
            .split(separator: ".")
            .map(String.init)

        var current: Any = snapshot.values

        for part in parts {
            guard
                let dictionary =
                    current as? [String: AnySendable],
                let next = dictionary[part]?.value
            else {
                return nil
            }

            current = next
        }

        return current as? String
    }
}
