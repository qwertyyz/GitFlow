import Foundation
import AppKit
import Security

/// Handles GitHub Device Flow authentication.
/// This is ideal for CLI/desktop apps as it doesn't require a client secret.
/// See: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow
@MainActor
class GitHubDeviceAuth: ObservableObject {
    // MARK: - Published State

    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var userCode: String?
    @Published private(set) var verificationURL: URL?
    @Published private(set) var error: Error?
    @Published private(set) var statusMessage: String = ""

    // MARK: - Configuration

    /// Default client ID for GitFlow - you can register your own at https://github.com/settings/developers
    /// For Device Flow, create an "OAuth App" (not GitHub App)
    private var clientId: String {
        if let customId = UserDefaults.standard.string(forKey: "github_oauth_client_id"), !customId.isEmpty {
            return customId
        }
        // Placeholder - users need to create their own OAuth app
        return ""
    }

    private let keychainService = "com.gitflow.github"
    private let keychainAccount = "oauth_token"

    private var pollingTask: Task<String?, Never>?

    // MARK: - Public Methods

    /// Checks if a client ID is configured.
    var isConfigured: Bool {
        !clientId.isEmpty
    }

    /// Starts the device flow authentication.
    func authenticate() async -> String? {
        guard isConfigured else {
            error = DeviceAuthError.noClientId
            return nil
        }

        isAuthenticating = true
        error = nil
        userCode = nil
        verificationURL = nil
        statusMessage = "Requesting device code..."

        defer {
            isAuthenticating = false
            userCode = nil
            verificationURL = nil
            statusMessage = ""
        }

        do {
            // Step 1: Request device and user codes
            let deviceCode = try await requestDeviceCode()
            userCode = deviceCode.userCode
            verificationURL = URL(string: deviceCode.verificationUri)

            // Open the verification URL in browser
            if let url = verificationURL {
                NSWorkspace.shared.open(url)
            }

            statusMessage = "Waiting for authorization..."

            // Step 2: Poll for the access token
            let token = try await pollForToken(deviceCode: deviceCode)

            // Save token
            saveToken(token)

            statusMessage = "Authentication successful!"
            return token
        } catch {
            self.error = error
            return nil
        }
    }

    /// Cancels the ongoing authentication.
    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        isAuthenticating = false
        userCode = nil
        verificationURL = nil
        statusMessage = ""
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

    /// Removes the saved token (logout).
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

    // MARK: - Private Types

    private struct DeviceCodeResponse: Codable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationUri = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    private struct TokenResponse: Codable {
        let accessToken: String?
        let tokenType: String?
        let scope: String?
        let error: String?
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case scope
            case error
            case errorDescription = "error_description"
        }
    }

    // MARK: - Private Methods

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&scope=repo%20read:org%20read:user"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DeviceAuthError.requestFailed
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForToken(deviceCode: DeviceCodeResponse) async throws -> String {
        let deadline = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))
        let interval = TimeInterval(deviceCode.interval)

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            if Task.isCancelled {
                throw DeviceAuthError.cancelled
            }

            let result = try await checkToken(deviceCode: deviceCode.deviceCode)

            if let token = result.accessToken {
                return token
            }

            // Handle error states
            if let error = result.error {
                switch error {
                case "authorization_pending":
                    // User hasn't authorized yet, keep polling
                    continue
                case "slow_down":
                    // We're polling too fast, wait extra time
                    try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))
                    continue
                case "expired_token":
                    throw DeviceAuthError.expired
                case "access_denied":
                    throw DeviceAuthError.denied
                default:
                    throw DeviceAuthError.unknown(error)
                }
            }
        }

        throw DeviceAuthError.expired
    }

    private func checkToken(deviceCode: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func saveToken(_ token: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

/// Errors for device flow authentication.
enum DeviceAuthError: LocalizedError {
    case noClientId
    case requestFailed
    case expired
    case denied
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noClientId:
            return "No GitHub OAuth Client ID configured. Please set one up in Settings."
        case .requestFailed:
            return "Failed to request device code from GitHub"
        case .expired:
            return "Authentication request expired. Please try again."
        case .denied:
            return "Authentication was denied"
        case .cancelled:
            return "Authentication was cancelled"
        case .unknown(let error):
            return "Authentication error: \(error)"
        }
    }
}
