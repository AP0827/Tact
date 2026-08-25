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
    @Published var accountDevices: [TactAccountDevice] = []
    @Published var account: TactAccount?
    @Published var error: String?
    @Published var isBusy = false
    @Published var demoMode = false
    @Published var authMode = 0
    @Published var lastActionResult: String?

    @AppStorage("tact.appearance")
    var appearance = "system"

    private var messageTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    let client = TactClient.shared
    let pairing = PairingService.shared
    let accountService = AccountService.shared

    var accountServiceURL: URL? {
        if let configured = Bundle.main.object(
            forInfoDictionaryKey: "TACTAccountServiceURL"
        ) as? String,
           !configured.isEmpty {
            return URL(string: configured)
        }
        return URL(string: "http://127.0.0.1:8000")
    }

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
        error = nil
        isBusy = true
        defer { isBusy = false }
        guard let accountServiceURL else {
            error = "The account service is not configured."
            return
        }
        do {
            let session = try await accountService.signIn(
                serviceURL: accountServiceURL,
                email: email,
                password: password
            )
            account = session.account
            try await registerCurrentDevice()
            try await refreshDevices()
            phase = .devices
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signIn(provider: String, identityToken: String) async {
        error = nil
        isBusy = true
        defer { isBusy = false }
        guard let accountServiceURL else {
            error = "The account service is not configured."
            return
        }
        do {
            let session = try await accountService.signIn(
                serviceURL: accountServiceURL,
                provider: provider.lowercased(),
                identityToken: identityToken
            )
            account = session.account
            try await registerCurrentDevice()
            try await refreshDevices()
            phase = .devices
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshDevices() async throws {
        guard let accountServiceURL else {
            throw AccountServiceError.invalidServiceURL
        }
        accountDevices = try await accountService.devices(
            serviceURL: accountServiceURL
        )
    }

    private func registerCurrentDevice() async throws {
        guard let accountServiceURL else {
            throw AccountServiceError.invalidServiceURL
        }
        let id = await pairing.deviceID()
        #if os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        let type = idiom == .pad ? "tablet" : "phone"
        let platform = idiom == .pad ? "ipados" : "ios"
        let modelName = UIDevice.current.model
        #else
        let type = "desktop"
        let platform = "macos"
        let modelName = "Mac"
        #endif
        try await accountService.registerDevice(
            serviceURL: accountServiceURL,
            deviceID: id,
            label: deviceName,
            platform: platform,
            deviceType: type,
            model: modelName
        )
    }

    // MARK: - Device Connection

    func connect(device: TactAccountDevice) async {
        error = nil
        isBusy = true
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
            guard let accountServiceURL else {
                throw AccountServiceError.invalidServiceURL
            }
            let deviceID = await pairing.deviceID()
            let accountConnection = try await accountService.connection(
                serviceURL: accountServiceURL,
                targetDeviceID: device.deviceID,
                clientDeviceID: deviceID,
                clientLabel: deviceName
            )
            await pairing.saveTrustedToken(accountConnection.token)
            try await client.connect(
                host: accountConnection.host,
                port: accountConnection.port,
                token: accountConnection.token
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

    func signOut() async {
        await client.disconnect()
        await accountService.signOut(serviceURL: accountServiceURL)
        await pairing.forget()
        account = nil
        accountDevices = []
        selectedDevice = nil
        connection = .disconnected
        phase = .login
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
                let result = try await client.sendAction(
                    id,
                    payload: sendablePayload
                )
                await MainActor.run {
                    self.lastActionResult = "\(id): \(String(describing: result.value))"
                }
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

    var availableActions: [String] {
        let value = snapshot.values["actions"]?.value
        if let actions = value as? [String] { return actions }
        if let actions = value as? [Any] { return actions.compactMap { $0 as? String } }
        return []
    }
}
