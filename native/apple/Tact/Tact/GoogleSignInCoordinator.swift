import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class GoogleSignInCoordinator: NSObject, ObservableObject,
    ASWebAuthenticationPresentationContextProviding {

    @Published var isAuthenticating = false
    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> String {
        guard
            let clientID = Bundle.main.object(
                forInfoDictionaryKey: "TACTGoogleClientID"
            ) as? String,
            !clientID.isEmpty,
            let redirectValue = Bundle.main.object(
                forInfoDictionaryKey: "TACTGoogleRedirectURI"
            ) as? String,
            let redirectURI = URL(string: redirectValue),
            let callbackScheme = redirectURI.scheme
        else {
            throw GoogleSignInError.notConfigured
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let verifier = Self.randomURLSafeString()
        let challenge = Self.base64URL(
            Data(SHA256.hash(data: Data(verifier.utf8)))
        )
        var components = URLComponents(
            string: "https://accounts.google.com/o/oauth2/v2/auth"
        )!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectValue),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation {
            continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: callbackScheme
            ) { callback, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: GoogleSignInError.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            guard session.start() else {
                continuation.resume(throwing: GoogleSignInError.couldNotStart)
                return
            }
        }

        guard
            let code = URLComponents(
                url: callbackURL,
                resolvingAgainstBaseURL: false
            )?.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw GoogleSignInError.missingAuthorizationCode
        }

        var tokenRequest = URLRequest(
            url: URL(string: "https://oauth2.googleapis.com/token")!
        )
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        tokenRequest.httpBody = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectValue,
        ]
        .map { key, value in
            "\(Self.formEncode(key))=\(Self.formEncode(value))"
        }
        .joined(separator: "&")
        .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: tokenRequest)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let identityToken = payload["id_token"] as? String
        else {
            throw GoogleSignInError.tokenExchangeFailed
        }
        return identityToken
    }

    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        return scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private static func randomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) ?? value
    }
}

enum GoogleSignInError: LocalizedError {
    case notConfigured
    case cancelled
    case couldNotStart
    case missingAuthorizationCode
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sign-In is not configured for this build."
        case .cancelled:
            return "Google Sign-In was cancelled."
        case .couldNotStart:
            return "Google Sign-In could not start."
        case .missingAuthorizationCode:
            return "Google did not return an authorization code."
        case .tokenExchangeFailed:
            return "Google could not complete authentication."
        }
    }
}
