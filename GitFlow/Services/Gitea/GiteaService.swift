import Foundation

/// Service for Gitea/Forgejo integration.
actor GiteaService {
    static let shared = GiteaService()

    private var accessToken: String?
    private var baseURL: URL?

    private init() {}

    // MARK: - Authentication

    /// Authenticate with Gitea using a Personal Access Token
    func authenticate(serverURL: String, token: String) async throws -> GiteaUser {
        guard let url = URL(string: serverURL) else {
            throw GiteaError.invalidServerURL
        }

        self.baseURL = url
        self.accessToken = token

        // Verify the token by fetching user profile
        let user = try await getCurrentUser()
        return user
    }

    /// Check if authenticated
    func isAuthenticated() -> Bool {
        accessToken != nil && baseURL != nil
    }

    /// Sign out from Gitea
    func signOut() {
        accessToken = nil
        baseURL = nil
    }

    // MARK: - User

    /// Get the current authenticated user
    func getCurrentUser() async throws -> GiteaUser {
        let data = try await performRequest(endpoint: "/api/v1/user")
        return try JSONDecoder().decode(GiteaUser.self, from: data)
    }

    // MARK: - Repositories

    /// List repositories for the current user
    func listUserRepositories(page: Int = 1, limit: Int = 50) async throws -> [GiteaRepository] {
        let data = try await performRequest(endpoint: "/api/v1/user/repos?page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode([GiteaRepository].self, from: data)
    }

    /// List starred repositories
    func listStarredRepositories(page: Int = 1, limit: Int = 50) async throws -> [GiteaRepository] {
        let data = try await performRequest(endpoint: "/api/v1/user/starred?page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode([GiteaRepository].self, from: data)
    }

    /// Search repositories
    func searchRepositories(query: String, page: Int = 1, limit: Int = 50) async throws -> GiteaSearchResult<GiteaRepository> {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await performRequest(endpoint: "/api/v1/repos/search?q=\(encodedQuery)&page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode(GiteaSearchResult<GiteaRepository>.self, from: data)
    }

    /// Get a specific repository
    func getRepository(owner: String, name: String) async throws -> GiteaRepository {
        let data = try await performRequest(endpoint: "/api/v1/repos/\(owner)/\(name)")
        return try JSONDecoder().decode(GiteaRepository.self, from: data)
    }

    /// Fork a repository
    func forkRepository(owner: String, name: String, organization: String? = nil) async throws -> GiteaRepository {
        var body: [String: Any] = [:]
        if let org = organization {
            body["organization"] = org
        }

        let data = try await performRequest(
            endpoint: "/api/v1/repos/\(owner)/\(name)/forks",
            method: "POST",
            body: body.isEmpty ? nil : body
        )
        return try JSONDecoder().decode(GiteaRepository.self, from: data)
    }

    // MARK: - Branches

    /// List branches in a repository
    func listBranches(owner: String, repo: String, page: Int = 1, limit: Int = 50) async throws -> [GiteaBranch] {
        let data = try await performRequest(endpoint: "/api/v1/repos/\(owner)/\(repo)/branches?page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode([GiteaBranch].self, from: data)
    }

    /// Get a specific branch
    func getBranch(owner: String, repo: String, branch: String) async throws -> GiteaBranch {
        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? branch
        let data = try await performRequest(endpoint: "/api/v1/repos/\(owner)/\(repo)/branches/\(encodedBranch)")
        return try JSONDecoder().decode(GiteaBranch.self, from: data)
    }

    // MARK: - Pull Requests

    /// List pull requests in a repository
    func listPullRequests(
        owner: String,
        repo: String,
        state: GiteaPRState = .open,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> [GiteaPullRequest] {
        let data = try await performRequest(endpoint: "/api/v1/repos/\(owner)/\(repo)/pulls?state=\(state.rawValue)&page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode([GiteaPullRequest].self, from: data)
    }

    /// Get a specific pull request
    func getPullRequest(owner: String, repo: String, index: Int) async throws -> GiteaPullRequest {
        let data = try await performRequest(endpoint: "/api/v1/repos/\(owner)/\(repo)/pulls/\(index)")
        return try JSONDecoder().decode(GiteaPullRequest.self, from: data)
    }

    /// Create a pull request
    func createPullRequest(
        owner: String,
        repo: String,
        title: String,
        head: String,
        base: String,
        body: String?
    ) async throws -> GiteaPullRequest {
        var requestBody: [String: Any] = [
            "title": title,
            "head": head,
            "base": base
        ]
        if let body = body {
            requestBody["body"] = body
        }

        let data = try await performRequest(
            endpoint: "/api/v1/repos/\(owner)/\(repo)/pulls",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GiteaPullRequest.self, from: data)
    }

    /// Merge a pull request
    func mergePullRequest(
        owner: String,
        repo: String,
        index: Int,
        mergeStyle: GiteaMergeStyle = .merge,
        title: String? = nil,
        message: String? = nil
    ) async throws {
        var body: [String: Any] = [
            "Do": mergeStyle.rawValue
        ]
        if let title = title {
            body["MergeTitleField"] = title
        }
        if let message = message {
            body["MergeMessageField"] = message
        }

        _ = try await performRequest(
            endpoint: "/api/v1/repos/\(owner)/\(repo)/pulls/\(index)/merge",
            method: "POST",
            body: body
        )
    }

    /// Add a review to a pull request
    func addReview(
        owner: String,
        repo: String,
        index: Int,
        event: GiteaReviewEvent,
        body: String?
    ) async throws -> GiteaReview {
        var requestBody: [String: Any] = [
            "event": event.rawValue
        ]
        if let body = body {
            requestBody["body"] = body
        }

        let data = try await performRequest(
            endpoint: "/api/v1/repos/\(owner)/\(repo)/pulls/\(index)/reviews",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GiteaReview.self, from: data)
    }

    // MARK: - Issues (PRs are also issues in Gitea)

    /// Add a comment to an issue/PR
    func addComment(owner: String, repo: String, index: Int, body: String) async throws -> GiteaComment {
        let requestBody: [String: Any] = ["body": body]

        let data = try await performRequest(
            endpoint: "/api/v1/repos/\(owner)/\(repo)/issues/\(index)/comments",
            method: "POST",
            body: requestBody
        )
        return try JSONDecoder().decode(GiteaComment.self, from: data)
    }

    /// List comments on an issue/PR
    func listComments(owner: String, repo: String, index: Int) async throws -> [GiteaComment] {
        let data = try await performRequest(endpoint: "/api/v1/repos/\(owner)/\(repo)/issues/\(index)/comments")
        return try JSONDecoder().decode([GiteaComment].self, from: data)
    }

    // MARK: - Organizations

    /// List organizations for the current user
    func listOrganizations() async throws -> [GiteaOrganization] {
        let data = try await performRequest(endpoint: "/api/v1/user/orgs")
        return try JSONDecoder().decode([GiteaOrganization].self, from: data)
    }

    /// List repositories in an organization
    func listOrganizationRepositories(org: String, page: Int = 1, limit: Int = 50) async throws -> [GiteaRepository] {
        let data = try await performRequest(endpoint: "/api/v1/orgs/\(org)/repos?page=\(page)&limit=\(limit)")
        return try JSONDecoder().decode([GiteaRepository].self, from: data)
    }

    // MARK: - Network

    private func performRequest(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let baseURL = baseURL else {
            throw GiteaError.notAuthenticated
        }

        guard let token = accessToken else {
            throw GiteaError.notAuthenticated
        }

        guard let url = URL(string: baseURL.absoluteString + endpoint) else {
            throw GiteaError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GiteaError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw GiteaError.unauthorized
        case 403:
            throw GiteaError.forbidden
        case 404:
            throw GiteaError.notFound
        case 409:
            throw GiteaError.conflict
        default:
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw GiteaError.apiError(message: errorMessage)
            }
            throw GiteaError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Data Models

struct GiteaUser: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let fullName: String?
    let email: String?
    let avatarUrl: String?
    let language: String?
    let isAdmin: Bool?
    let lastLogin: String?
    let created: String?

    enum CodingKeys: String, CodingKey {
        case id, login, email, language, created
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
        case lastLogin = "last_login"
    }

    var displayName: String {
        fullName ?? login
    }
}

struct GiteaRepository: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String?
    let description: String?
    let empty: Bool?
    let isPrivate: Bool?
    let isFork: Bool?
    let isTemplate: Bool?
    let htmlUrl: String?
    let sshUrl: String?
    let cloneUrl: String?
    let defaultBranch: String?
    let starsCount: Int?
    let forksCount: Int?
    let watchersCount: Int?
    let openIssuesCount: Int?
    let size: Int?
    let owner: GiteaUser?
    let createdAt: String?
    let updatedAt: String?
    let archived: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, empty, size, owner, archived
        case fullName = "full_name"
        case isPrivate = "private"
        case isFork = "fork"
        case isTemplate = "template"
        case htmlUrl = "html_url"
        case sshUrl = "ssh_url"
        case cloneUrl = "clone_url"
        case defaultBranch = "default_branch"
        case starsCount = "stars_count"
        case forksCount = "forks_count"
        case watchersCount = "watchers_count"
        case openIssuesCount = "open_issues_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GiteaBranch: Codable, Identifiable {
    let name: String
    let commit: GiteaCommitRef?
    let protected: Bool?
    let requiredApprovals: Int?
    let enableStatusCheck: Bool?
    let statusCheckContexts: [String]?
    let userCanPush: Bool?
    let userCanMerge: Bool?
    let effectiveBranchProtectionName: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, commit, protected
        case requiredApprovals = "required_approvals"
        case enableStatusCheck = "enable_status_check"
        case statusCheckContexts = "status_check_contexts"
        case userCanPush = "user_can_push"
        case userCanMerge = "user_can_merge"
        case effectiveBranchProtectionName = "effective_branch_protection_name"
    }

    struct GiteaCommitRef: Codable {
        let id: String?
        let message: String?
        let url: String?
        let author: GiteaCommitAuthor?
        let committer: GiteaCommitAuthor?
        let timestamp: String?
    }

    struct GiteaCommitAuthor: Codable {
        let name: String?
        let email: String?
        let date: String?
    }
}

struct GiteaPullRequest: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let state: String
    let title: String
    let body: String?
    let user: GiteaUser?
    let head: GiteaPRRef?
    let base: GiteaPRRef?
    let htmlUrl: String?
    let diffUrl: String?
    let patchUrl: String?
    let mergeable: Bool?
    let merged: Bool?
    let mergedAt: String?
    let mergedBy: GiteaUser?
    let createdAt: String?
    let updatedAt: String?
    let closedAt: String?
    let comments: Int?
    let isDraft: Bool?

    enum CodingKeys: String, CodingKey {
        case id, number, state, title, body, user, head, base, mergeable, merged, comments
        case htmlUrl = "html_url"
        case diffUrl = "diff_url"
        case patchUrl = "patch_url"
        case mergedAt = "merged_at"
        case mergedBy = "merged_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case isDraft = "draft"
    }

    struct GiteaPRRef: Codable, Hashable {
        let ref: String
        let sha: String
        let repo: GiteaRepository?
        let label: String?
    }
}

struct GiteaReview: Codable, Identifiable {
    let id: Int
    let user: GiteaUser?
    let body: String?
    let state: String
    let htmlUrl: String?
    let pullRequestUrl: String?
    let submittedAt: String?
    let commitId: String?
    let stale: Bool?
    let official: Bool?

    enum CodingKeys: String, CodingKey {
        case id, user, body, state, stale, official
        case htmlUrl = "html_url"
        case pullRequestUrl = "pull_request_url"
        case submittedAt = "submitted_at"
        case commitId = "commit_id"
    }
}

struct GiteaComment: Codable, Identifiable {
    let id: Int
    let user: GiteaUser?
    let body: String
    let htmlUrl: String?
    let pullRequestUrl: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, user, body
        case htmlUrl = "html_url"
        case pullRequestUrl = "pull_request_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GiteaOrganization: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String?
    let avatarUrl: String?
    let description: String?
    let website: String?
    let location: String?
    let visibility: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, website, location, visibility
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }

    var displayName: String {
        fullName ?? name
    }
}

struct GiteaSearchResult<T: Codable>: Codable {
    let ok: Bool?
    let data: [T]?
}

enum GiteaPRState: String, Codable {
    case open
    case closed
    case all
}

enum GiteaMergeStyle: String, Codable {
    case merge
    case rebase
    case rebaseMerge = "rebase-merge"
    case squash
    case manuallyMerged = "manually-merged"
}

enum GiteaReviewEvent: String, Codable {
    case approve = "APPROVE"
    case requestChanges = "REQUEST_CHANGES"
    case comment = "COMMENT"
}

// MARK: - Errors

enum GiteaError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case invalidResponse
    case invalidServerURL
    case invalidEndpoint
    case apiError(message: String)
    case unknown(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Gitea"
        case .unauthorized:
            return "Invalid access token"
        case .forbidden:
            return "Access denied. Check your token permissions."
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Conflict - the operation cannot be completed"
        case .invalidResponse:
            return "Invalid response from Gitea"
        case .invalidServerURL:
            return "Invalid Gitea server URL"
        case .invalidEndpoint:
            return "Invalid API endpoint"
        case .apiError(let message):
            return "Gitea API error: \(message)"
        case .unknown(let statusCode):
            return "Unknown error (HTTP \(statusCode))"
        }
    }
}

// MARK: - Account Storage

struct GiteaAccount: Codable, Identifiable {
    let id: UUID
    let serverURL: String
    let username: String
    let displayName: String
    let email: String?
    var token: String

    init(serverURL: String, username: String, displayName: String, email: String?, token: String) {
        self.id = UUID()
        self.serverURL = serverURL
        self.username = username
        self.displayName = displayName
        self.email = email
        self.token = token
    }

    var serverDisplayName: String {
        URL(string: serverURL)?.host ?? serverURL
    }
}

@MainActor
class GiteaAccountStore: ObservableObject {
    static let shared = GiteaAccountStore()

    @Published var accounts: [GiteaAccount] = []
    @Published var currentAccount: GiteaAccount?

    private let storageKey = "giteaAccounts"

    private init() {
        loadAccounts()
    }

    func addAccount(_ account: GiteaAccount) {
        accounts.append(account)
        if currentAccount == nil {
            currentAccount = account
        }
        saveAccounts()
    }

    func removeAccount(_ account: GiteaAccount) {
        accounts.removeAll { $0.id == account.id }
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
        }
        saveAccounts()
    }

    func switchToAccount(_ account: GiteaAccount) {
        currentAccount = account
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([GiteaAccount].self, from: data) {
            accounts = decoded
            currentAccount = accounts.first
        }
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
