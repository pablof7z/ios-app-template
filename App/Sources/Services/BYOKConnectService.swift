import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class BYOKConnectService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let authorizationBaseURL = URL(string: "https://byok.f7z.io/authorize")!
    private let tokenURL = URL(string: "https://byok.f7z.io/api/token")!
    private let redirectScheme = "apptemplate"
    private let redirectHost = "byok"
    private var currentSession: ASWebAuthenticationSession?

    func connectOpenRouter() async throws -> BYOKTokenResponse {
        let pending = try makeAuthorization(provider: "openrouter", scope: "key:openrouter")
        let callbackURL = try await authenticate(url: pending.authorizationURL)
        let code = try authorizationCode(from: callbackURL, expectedState: pending.state)
        let token = try await exchangeCode(code, pending: pending)

        guard token.provider == "openrouter" else {
            throw BYOKConnectError.unexpectedProvider
        }
        guard token.tokenType == "raw_api_key", !token.apiKey.isEmpty else {
            throw BYOKConnectError.invalidTokenResponse
        }

        return token
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = activeScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        if let fallbackWindow = scenes.flatMap(\.windows).first {
            return fallbackWindow
        }
        return ASPresentationAnchor()
    }

    private func makeAuthorization(provider: String, scope: String) throws -> BYOKPendingAuthorization {
        let state = try Self.randomBase64URL(byteCount: 32)
        let codeVerifier = try Self.randomBase64URL(byteCount: 64)
        let codeChallenge = Self.sha256Base64URL(codeVerifier)
        let redirectURI = "\(redirectScheme)://\(redirectHost)"

        var components = URLComponents(url: authorizationBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "app_name", value: appName),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authorizationURL = components.url else {
            throw BYOKConnectError.invalidAuthorizationURL
        }

        return BYOKPendingAuthorization(
            provider: provider,
            authorizationURL: authorizationURL,
            redirectURI: redirectURI,
            clientID: clientID,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.currentSession = nil

                    if let error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            continuation.resume(throwing: BYOKConnectError.cancelled)
                            return
                        }
                        continuation.resume(throwing: BYOKConnectError.authenticationFailed)
                        return
                    }

                    guard let callbackURL else {
                        continuation.resume(throwing: BYOKConnectError.invalidCallback)
                        return
                    }
                    continuation.resume(returning: callbackURL)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            currentSession = session

            guard session.start() else {
                currentSession = nil
                continuation.resume(throwing: BYOKConnectError.authenticationFailed)
                return
            }
        }
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard callbackURL.scheme == redirectScheme,
              callbackURL.host == redirectHost,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw BYOKConnectError.invalidCallback
        }

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if query["state"] != expectedState {
            throw BYOKConnectError.stateMismatch
        }
        if query["error"] == "access_denied" {
            throw BYOKConnectError.accessDenied
        }
        guard let code = query["code"], !code.isEmpty else {
            throw BYOKConnectError.missingCode
        }
        return code
    }

    private func exchangeCode(_ code: String, pending: BYOKPendingAuthorization) async throws -> BYOKTokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body = BYOKTokenRequest(
            code: code,
            codeVerifier: pending.codeVerifier,
            clientID: pending.clientID,
            redirectURI: pending.redirectURI
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BYOKConnectError.tokenExchangeFailed
        }
        if !(200..<300).contains(http.statusCode) {
            let tokenError = try? JSONDecoder().decode(BYOKTokenErrorResponse.self, from: data)
            throw BYOKConnectError.serverRejectedToken(error: tokenError?.error)
        }

        do {
            return try JSONDecoder().decode(BYOKTokenResponse.self, from: data)
        } catch {
            throw BYOKConnectError.invalidTokenResponse
        }
    }

    private var clientID: String {
        Bundle.main.bundleIdentifier ?? "com.yourcompany.apptemplate"
    }

    private var appName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App Template"
    }

    private static func randomBase64URL(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw BYOKConnectError.randomGenerationFailed
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func sha256Base64URL(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private struct BYOKPendingAuthorization {
    let provider: String
    let authorizationURL: URL
    let redirectURI: String
    let clientID: String
    let state: String
    let codeVerifier: String
}

private struct BYOKTokenRequest: Encodable {
    let grantType = "authorization_code"
    let code: String
    let codeVerifier: String
    let clientID: String
    let redirectURI: String

    private enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case codeVerifier = "code_verifier"
        case clientID = "client_id"
        case redirectURI = "redirect_uri"
    }
}

struct BYOKTokenResponse: Decodable, Sendable {
    let tokenType: String
    let provider: String
    let apiKey: String
    let keyID: String?
    let keyLabel: String?
    let appName: String?
    let issuedAt: Int?

    private enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case provider
        case apiKey = "api_key"
        case keyID = "key_id"
        case keyLabel = "key_label"
        case appName = "app_name"
        case issuedAt = "issued_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        provider = try container.decode(String.self, forKey: .provider).lowercased()
        apiKey = try container.decode(String.self, forKey: .apiKey)
        keyID = try container.decodeIfPresent(String.self, forKey: .keyID)
        keyLabel = try container.decodeIfPresent(String.self, forKey: .keyLabel)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        issuedAt = try container.decodeIfPresent(Int.self, forKey: .issuedAt)
    }
}

private struct BYOKTokenErrorResponse: Decodable {
    let error: String?
}

enum BYOKConnectError: LocalizedError {
    case accessDenied
    case authenticationFailed
    case cancelled
    case invalidAuthorizationURL
    case invalidCallback
    case invalidTokenResponse
    case missingCode
    case randomGenerationFailed
    case serverRejectedToken(error: String?)
    case stateMismatch
    case tokenExchangeFailed
    case unexpectedProvider

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Access was denied in BYOK."
        case .authenticationFailed:
            "BYOK authentication could not be completed."
        case .cancelled:
            "BYOK connection was cancelled."
        case .invalidAuthorizationURL:
            "BYOK authorization URL could not be created."
        case .invalidCallback:
            "BYOK returned an unexpected callback."
        case .invalidTokenResponse:
            "BYOK returned an invalid token response."
        case .missingCode:
            "BYOK did not return an authorization code."
        case .randomGenerationFailed:
            "Secure random generation failed."
        case .serverRejectedToken(let error):
            if let error, !error.isEmpty {
                "BYOK rejected the token exchange: \(error)"
            } else {
                "BYOK rejected the token exchange."
            }
        case .stateMismatch:
            "BYOK returned an invalid state."
        case .tokenExchangeFailed:
            "BYOK token exchange failed."
        case .unexpectedProvider:
            "BYOK returned a credential for the wrong provider."
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
