import Foundation
import AuthenticationServices
import Security

/// Handles GitHub OAuth authentication flow.
@MainActor
class GitHubOAuth: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    // MARK: - Published State

    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var error: Error?

    // MARK: - OAuth Configuration

    /// GitHub OAuth client ID - Users can set their own or use the default
    /// To create your own: https://github.com/settings/developers
    private var clientId: String {
        // Check for user-configured client ID first
        if let customId = UserDefaults.standard.string(forKey: "github_oauth_client_id"), !customId.isEmpty {
            return customId
        }
        // Default client ID for GitFlow (users should create their own for production)
        return "Ov23liYourClientIdHere"
    }

    /// The callback URL scheme - must match what's registered in GitHub OAuth app
    private let callbackURLScheme = "gitflow"

    /// Keychain service identifier
    private let keychainService = "com.gitflow.github"
    private let keychainAccount = "oauth_token"

    // MARK: - Public Methods

    /// Starts the GitHub OAuth flow.
    /// - Parameter completion: Called with the access token on success, or nil on failure.
    func authenticate() async -> String? {
        isAuthenticating = true
        error = nil

        defer { isAuthenticating = false }

        // Generate state for CSRF protection
        let state = UUID().uuidString

        // Build authorization URL
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: "\(callbackURLScheme)://oauth/callback"),
            URLQueryItem(name: "scope", value: "repo read:org read:user"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authURL = components.url else {
            error = GitHubOAuthError.invalidURL
            return nil
        }

        // Perform OAuth flow
        do {
            let callbackURL = try await performOAuthFlow(authURL: authURL)

            // Parse the callback URL
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                  let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                throw GitHubOAuthError.invalidCallback
            }

            // Verify state
            guard returnedState == state else {
                throw GitHubOAuthError.stateMismatch
            }

            // Exchange code for token
            let token = try await exchangeCodeForToken(code: code)

            // Save token to keychain
            saveToken(token)

            return token
        } catch {
            self.error = error
            return nil
        }
    }

    /// Loads the saved token from keychain.
    func loadSavedToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Removes the saved token from keychain.
    func logout() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Sets a custom OAuth client ID.
    func setClientId(_ clientId: String) {
        UserDefaults.standard.set(clientId, forKey: "github_oauth_client_id")
    }

    /// Sets a custom OAuth client secret (required for token exchange).
    func setClientSecret(_ secret: String) {
        // Store in keychain for security
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "client_secret"
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "client_secret",
            kSecValueData as String: secret.data(using: .utf8)!
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }

    // MARK: - Private Methods

    private func performOAuthFlow(authURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GitHubOAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: GitHubOAuthError.invalidCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: GitHubOAuthError.sessionStartFailed)
            }
        }
    }

    private func exchangeCodeForToken(code: String) async throws -> String {
        // Get client secret from keychain
        let secretQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "client_secret",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var secretResult: AnyObject?
        let secretStatus = SecItemCopyMatching(secretQuery as CFDictionary, &secretResult)

        guard secretStatus == errSecSuccess,
              let secretData = secretResult as? Data,
              let clientSecret = String(data: secretData, encoding: .utf8) else {
            throw GitHubOAuthError.missingClientSecret
        }

        // Exchange code for token
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": "\(callbackURLScheme)://oauth/callback"
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubOAuthError.tokenExchangeFailed
        }

        struct TokenResponse: Codable {
            let accessToken: String
            let tokenType: String
            let scope: String

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case tokenType = "token_type"
                case scope
            }
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    private func saveToken(_ token: String) {
        // Delete any existing token
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Save new token
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: token.data(using: .utf8)!
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }
}

/// Errors that can occur during GitHub OAuth.
enum GitHubOAuthError: LocalizedError {
    case invalidURL
    case invalidCallback
    case stateMismatch
    case userCancelled
    case sessionStartFailed
    case tokenExchangeFailed
    case missingClientSecret

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to create authorization URL"
        case .invalidCallback:
            return "Invalid callback from GitHub"
        case .stateMismatch:
            return "Security state mismatch - possible CSRF attack"
        case .userCancelled:
            return "Authentication was cancelled"
        case .sessionStartFailed:
            return "Failed to start authentication session"
        case .tokenExchangeFailed:
            return "Failed to exchange code for access token"
        case .missingClientSecret:
            return "OAuth client secret not configured. Please set up your GitHub OAuth app credentials."
        }
    }
}
