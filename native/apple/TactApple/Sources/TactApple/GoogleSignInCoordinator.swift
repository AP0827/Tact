import AppKit
import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security

@MainActor
final class GoogleSignInCoordinator: NSObject, ObservableObject,
    ASWebAuthenticationPresentationContextProviding {
    @Published var isAuthenticating = false
    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> String {
        let environment = ProcessInfo.processInfo.environment
        guard let clientID = environment["TACT_GOOGLE_CLIENT_ID"], !clientID.isEmpty,
              let redirectValue = environment["TACT_GOOGLE_REDIRECT_URI"],
              let redirectURI = URL(string: redirectValue),
              let callbackScheme = redirectURI.scheme else {
            throw GoogleSignInError.notConfigured
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let verifier = Self.randomURLSafeString()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectValue),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: GoogleSignInError.cancelled) }
            }
            session.presentationContextProvider = self
            self.session = session
            guard session.start() else {
                continuation.resume(throwing: GoogleSignInError.couldNotStart)
                return
            }
        }
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleSignInError.missingAuthorizationCode
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectValue,
        ].map { "\(Self.formEncode($0.key))=\(Self.formEncode($0.value))" }
            .joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["id_token"] as? String else {
            throw GoogleSignInError.tokenExchangeFailed
        }
        return token
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSWindow()
    }

    private static func randomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }
}

enum GoogleSignInError: LocalizedError {
    case notConfigured, cancelled, couldNotStart, missingAuthorizationCode, tokenExchangeFailed
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Google Sign-In is not configured for this build."
        case .cancelled: "Google Sign-In was cancelled."
        case .couldNotStart: "Google Sign-In could not start."
        case .missingAuthorizationCode: "Google did not return an authorization code."
        case .tokenExchangeFailed: "Google could not complete authentication."
        }
    }
}
