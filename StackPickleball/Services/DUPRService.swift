import Foundation
import AuthenticationServices
import Supabase

enum DUPRService {

    // MARK: - Types

    enum DUPRError: LocalizedError {
        case unknownOAuthError
        case missingAuthorizationCode
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
            case .unknownOAuthError:
                return "An unknown error occurred during DUPR authentication."
            case .missingAuthorizationCode:
                return "No authorization code was returned from DUPR."
            case .connectionFailed(let message):
                return "DUPR connection failed: \(message)"
            }
        }
    }

    struct DUPRAuthResult: Codable {
        let userToken: String
        let refreshToken: String
        let duprId: String
    }

    struct DUPRProfile: Codable {
        let dupr_id: String
        let dupr_verified: Bool
        let dupr_rating: Double?
        let dupr_singles_rating: Double?
        let dupr_doubles_rating: Double?
        let full_name: String?
    }

    struct ConnectResponse: Codable {
        let success: Bool
        let profile: DUPRProfile
    }

    struct ExchangeCodeRequest: Encodable {
        let authorization_code: String
    }

    struct ExchangeCodeResponse: Codable {
        let userToken: String
        let refreshToken: String
        let duprId: String
    }

    // MARK: - OAuth Flow

    /// Opens DUPR OAuth login in an in-app browser session and returns the auth result.
    @MainActor
    static func startOAuthFlow() async throws -> DUPRAuthResult {
        let clientId = "7998359216"
        let redirectURI = "stackpickleball://dupr/callback"
        let authURL = URL(string: "https://api.uat.dupr.gg/oauth/authorize?client_id=\(clientId)&redirect_uri=\(redirectURI)&response_type=code")!
        let callbackScheme = "stackpickleball"

        let code: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: DUPRError.missingAuthorizationCode)
                    return
                }
                continuation.resume(returning: code)
            }

            let coordinator = WebAuthCoordinator()
            session.presentationContextProvider = coordinator
            // Keep coordinator alive for the duration of the session
            objc_setAssociatedObject(session, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Exchange the authorization code for tokens via our backend edge function
        return try await exchangeCode(code)
    }

    // MARK: - Exchange Code (via backend)

    /// Exchanges an OAuth authorization code for DUPR tokens server-side.
    static func exchangeCode(_ authorizationCode: String) async throws -> DUPRAuthResult {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]
        let request = ExchangeCodeRequest(authorization_code: authorizationCode)

        let response: ExchangeCodeResponse = try await supabase.functions.invoke(
            "dupr-exchange-code",
            options: .init(headers: headers, body: request)
        )

        return DUPRAuthResult(
            userToken: response.userToken,
            refreshToken: response.refreshToken,
            duprId: response.duprId
        )
    }

    // MARK: - Connect DUPR

    /// Calls the dupr-connect edge function with the user's DUPR tokens.
    static func connectDUPR(authResult: DUPRAuthResult) async throws -> DUPRProfile {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]

        struct ConnectRequest: Encodable {
            let userToken: String
            let refreshToken: String
            let duprId: String
        }

        let request = ConnectRequest(
            userToken: authResult.userToken,
            refreshToken: authResult.refreshToken,
            duprId: authResult.duprId
        )

        let response: ConnectResponse = try await supabase.functions.invoke(
            "dupr-connect",
            options: .init(headers: headers, body: request)
        )

        return response.profile
    }

    // MARK: - Refresh Token

    /// Refreshes the stored DUPR token via the backend edge function.
    static func refreshToken() async throws {
        let session = try await supabase.auth.session
        let headers = ["Authorization": "Bearer \(session.accessToken)"]

        try await supabase.functions.invoke(
            "dupr-refresh-token",
            options: .init(headers: headers)
        )
    }

    // MARK: - Full OAuth + Connect Flow

    /// Runs the complete flow: OAuth login -> exchange code -> connect DUPR.
    @MainActor
    static func fullConnectFlow() async throws -> DUPRProfile {
        let authResult = try await startOAuthFlow()
        return try await connectDUPR(authResult: authResult)
    }
}

// MARK: - ASWebAuthenticationSession Presentation

final class WebAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) else {
            return ASPresentationAnchor()
        }
        return window
        #else
        return ASPresentationAnchor()
        #endif
    }
}
