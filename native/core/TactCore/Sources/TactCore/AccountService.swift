import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct TactAccount: Codable, Sendable, Equatable {
    public let accountID: String
    public let email: String
    public let displayName: String
    public let provider: String

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case email
        case displayName = "display_name"
        case provider
    }
}

public struct TactAccountSession: Codable, Sendable, Equatable {
    public let token: String
    public let expiresAt: String
    public let account: TactAccount

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case account
    }
}

public struct TactAccountDevice: Codable, Identifiable, Sendable, Equatable {
    public let deviceID: String
    public let label: String
    public let platform: String
    public let deviceType: String
    public let model: String
    public let host: String?
    public let port: Int?
    public let lastSeen: String
    public let active: Bool
    public let canConnect: Bool

    public var id: String { deviceID }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case label, platform
        case deviceType = "device_type"
        case model, host, port
        case lastSeen = "last_seen"
        case active
        case canConnect = "can_connect"
    }
}

public struct TactAccountConnection: Codable, Sendable, Equatable {
    public let host: String
    public let port: Int
    public let websocketPath: String
    public let token: String
    public let targetDeviceID: String
    public let targetLabel: String

    enum CodingKeys: String, CodingKey {
        case host, port, token
        case websocketPath = "websocket_path"
        case targetDeviceID = "target_device_id"
        case targetLabel = "target_label"
    }
}

public enum AccountServiceError: LocalizedError {
    case invalidServiceURL
    case rejected(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidServiceURL:
            return "The account service address is invalid."
        case .rejected(let message):
            return message.replacingOccurrences(of: "_", with: " ").capitalized
        case .invalidResponse:
            return "The account service returned an invalid response."
        }
    }
}

public actor AccountService {
    public static let shared = AccountService()

    private let tokenKey = "tact.native.account.token"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public func savedToken() -> String? {
        SecureStore.shared.get(tokenKey)
    }

    public func signIn(
        serviceURL: URL,
        email: String,
        password: String
    ) async throws -> TactAccountSession {
        let session: TactAccountSession = try await request(
            serviceURL: serviceURL,
            path: "/api/auth/login",
            method: "POST",
            body: ["email": email, "password": password]
        )
        SecureStore.shared.set(session.token, for: tokenKey)
        return session
    }

    public func signIn(
        serviceURL: URL,
        provider: String,
        identityToken: String
    ) async throws -> TactAccountSession {
        let session: TactAccountSession = try await request(
            serviceURL: serviceURL,
            path: "/api/auth/provider",
            method: "POST",
            body: ["provider": provider, "identity_token": identityToken]
        )
        SecureStore.shared.set(session.token, for: tokenKey)
        return session
    }

    public func devices(serviceURL: URL) async throws -> [TactAccountDevice] {
        let response: DeviceListResponse = try await authenticatedRequest(
            serviceURL: serviceURL,
            path: "/api/account/devices",
            method: "GET",
            body: Optional<[String: String]>.none
        )
        return response.devices
    }

    public func registerDevice(
        serviceURL: URL,
        deviceID: String,
        label: String,
        platform: String,
        deviceType: String,
        model: String
    ) async throws {
        let _: DeviceResponse = try await authenticatedRequest(
            serviceURL: serviceURL,
            path: "/api/account/devices",
            method: "POST",
            body: [
                "device_id": deviceID,
                "label": label,
                "platform": platform,
                "device_type": deviceType,
                "model": model,
            ]
        )
    }

    public func connection(
        serviceURL: URL,
        targetDeviceID: String,
        clientDeviceID: String,
        clientLabel: String
    ) async throws -> TactAccountConnection {
        let response: ConnectionResponse = try await authenticatedRequest(
            serviceURL: serviceURL,
            path: "/api/account/devices/connect",
            method: "POST",
            body: [
                "target_device_id": targetDeviceID,
                "client_device_id": clientDeviceID,
                "client_label": clientLabel,
            ]
        )
        return response.connection
    }

    public func signOut(serviceURL: URL?) async {
        if let serviceURL, savedToken() != nil {
            let _: EmptyResponse? = try? await authenticatedRequest(
                serviceURL: serviceURL,
                path: "/api/auth/logout",
                method: "POST",
                body: Optional<[String: String]>.none
            )
        }
        SecureStore.shared.remove(tokenKey)
    }

    private func authenticatedRequest<Response: Decodable, Body: Encodable>(
        serviceURL: URL,
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        guard let token = savedToken() else {
            throw AccountServiceError.rejected("authentication_required")
        }
        return try await request(
            serviceURL: serviceURL,
            path: path,
            method: method,
            body: body,
            token: token
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        serviceURL: URL,
        path: String,
        method: String,
        body: Body?,
        token: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: serviceURL)?.absoluteURL else {
            throw AccountServiceError.invalidServiceURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AccountServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? decoder.decode(ErrorResponse.self, from: data).detail)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AccountServiceError.rejected(detail)
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct DeviceListResponse: Codable { let devices: [TactAccountDevice] }
private struct DeviceResponse: Codable { let device: TactAccountDevice }
private struct ConnectionResponse: Codable { let connection: TactAccountConnection }
private struct ErrorResponse: Codable { let detail: String }
private struct EmptyResponse: Codable { init() {} }
