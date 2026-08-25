import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor PairingService {
    public static let shared = PairingService()
    private let defaults = UserDefaults.standard
    private let deviceKey = "tact.native.device.id"
    private let tokenKey = "tact.native.pair.token"

    public func deviceID() -> String {
        if let existing = defaults.string(forKey: deviceKey) { return existing }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: deviceKey)
        return id
    }

    public func savedToken() -> String? { SecureStore.shared.get(tokenKey) }

    public func saveTrustedToken(_ token: String) {
        SecureStore.shared.set(token, for: tokenKey)
    }

    public func pairWithOTP(host: String, port: Int, otp: String, label: String) async throws -> String {
        let id = deviceID()
        var request = URLRequest(url: URL(string: "http://\(host):\(port)/api/pair/request")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["token": otp, "device_id": id, "label": label])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PairingError.requestFailed }

        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline {
            var components = URLComponents(string: "http://\(host):\(port)/api/pair/me")!
            components.queryItems = [URLQueryItem(name: "device_id", value: id)]
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            if (response as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["paired"] as? Bool == true {
                SecureStore.shared.set(id, for: tokenKey)
                return id
            }
            try await Task.sleep(for: .seconds(2))
        }
        throw PairingError.timeout
    }

    public func forget() { SecureStore.shared.remove(tokenKey) }
}

public enum PairingError: LocalizedError {
    case requestFailed, timeout
    public var errorDescription: String? { self == .requestFailed ? "The pairing request was rejected." : "The host did not approve pairing in time." }
}
