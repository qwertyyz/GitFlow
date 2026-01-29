import Foundation

/// Service for Beanstalk integration.
actor BeanstalkService {
    static let shared = BeanstalkService()

    private var accessToken: String?
    private var accountDomain: String?
    private var username: String?

    private var baseURL: URL? {
        guard let domain = accountDomain else { return nil }
        return URL(string: "https://\(domain).beanstalkapp.com/api")
    }

    private init() {}

    // MARK: - Authentication

    /// Authenticate with Beanstalk using username and access token
    func authenticate(domain: String, username: String, token: String) async throws -> BeanstalkUser {
        self.accountDomain = domain
        self.username = username
        self.accessToken = token

        // Verify credentials by fetching user profile
        let user = try await getCurrentUser()
        return user
    }

    /// Check if authenticated
    func isAuthenticated() -> Bool {
        accessToken != nil && accountDomain != nil && username != nil
    }

    /// Sign out from Beanstalk
    func signOut() {
        accessToken = nil
        accountDomain = nil
        username = nil
    }

    // MARK: - User

    /// Get the current authenticated user
    func getCurrentUser() async throws -> BeanstalkUser {
        let data = try await performRequest(endpoint: "/users/current.json")
        let response = try JSONDecoder().decode(BeanstalkUserResponse.self, from: data)
        return response.user
    }

    // MARK: - Repositories

    /// List all repositories
    func listRepositories(page: Int = 1, perPage: Int = 50) async throws -> [BeanstalkRepository] {
        let data = try await performRequest(endpoint: "/repositories.json?page=\(page)&per_page=\(perPage)")
        return try JSONDecoder().decode([BeanstalkRepositoryWrapper].self, from: data).map { $0.repository }
    }

    /// Get a specific repository
    func getRepository(id: Int) async throws -> BeanstalkRepository {
        let data = try await performRequest(endpoint: "/repositories/\(id).json")
        let response = try JSONDecoder().decode(BeanstalkRepositoryWrapper.self, from: data)
        return response.repository
    }

    /// Get repository by name
    func getRepository(name: String) async throws -> BeanstalkRepository {
        let data = try await performRequest(endpoint: "/repositories/\(name).json")
        let response = try JSONDecoder().decode(BeanstalkRepositoryWrapper.self, from: data)
        return response.repository
    }

    // MARK: - Branches

    /// List branches in a repository
    func listBranches(repositoryId: Int) async throws -> [BeanstalkBranch] {
        let data = try await performRequest(endpoint: "/\(repositoryId)/branches.json")
        return try JSONDecoder().decode([BeanstalkBranchWrapper].self, from: data).map { $0.branch }
    }

    // MARK: - Changesets (Commits)

    /// List changesets in a repository
    func listChangesets(repositoryId: Int, page: Int = 1, perPage: Int = 30) async throws -> [BeanstalkChangeset] {
        let data = try await performRequest(endpoint: "/\(repositoryId)/changesets.json?page=\(page)&per_page=\(perPage)")
        return try JSONDecoder().decode([BeanstalkChangesetWrapper].self, from: data).map { $0.revision_cache }
    }

    /// Get a specific changeset
    func getChangeset(repositoryId: Int, revision: String) async throws -> BeanstalkChangeset {
        let data = try await performRequest(endpoint: "/\(repositoryId)/changesets/\(revision).json")
        let response = try JSONDecoder().decode(BeanstalkChangesetWrapper.self, from: data)
        return response.revision_cache
    }

    // MARK: - Code Reviews

    /// List code reviews in a repository
    func listCodeReviews(repositoryId: Int, state: BeanstalkCodeReviewState = .pending) async throws -> [BeanstalkCodeReview] {
        let data = try await performRequest(endpoint: "/\(repositoryId)/code_reviews.json?state=\(state.rawValue)")
        return try JSONDecoder().decode([BeanstalkCodeReviewWrapper].self, from: data).map { $0.code_review }
    }

    /// Get a specific code review
    func getCodeReview(repositoryId: Int, id: Int) async throws -> BeanstalkCodeReview {
        let data = try await performRequest(endpoint: "/\(repositoryId)/code_reviews/\(id).json")
        let response = try JSONDecoder().decode(BeanstalkCodeReviewWrapper.self, from: data)
        return response.code_review
    }

    /// Create a code review
    func createCodeReview(
        repositoryId: Int,
        description: String,
        revisions: [String]
    ) async throws -> BeanstalkCodeReview {
        let body: [String: Any] = [
            "code_review": [
                "description": description,
                "revisions": revisions.joined(separator: ",")
            ]
        ]

        let data = try await performRequest(
            endpoint: "/\(repositoryId)/code_reviews.json",
            method: "POST",
            body: body
        )
        let response = try JSONDecoder().decode(BeanstalkCodeReviewWrapper.self, from: data)
        return response.code_review
    }

    /// Add a comment to a code review
    func addCodeReviewComment(
        repositoryId: Int,
        codeReviewId: Int,
        body: String
    ) async throws -> BeanstalkComment {
        let requestBody: [String: Any] = [
            "comment": [
                "body": body
            ]
        ]

        let data = try await performRequest(
            endpoint: "/\(repositoryId)/code_reviews/\(codeReviewId)/comments.json",
            method: "POST",
            body: requestBody
        )
        let response = try JSONDecoder().decode(BeanstalkCommentWrapper.self, from: data)
        return response.comment
    }

    /// Approve a code review
    func approveCodeReview(repositoryId: Int, codeReviewId: Int) async throws {
        _ = try await performRequest(
            endpoint: "/\(repositoryId)/code_reviews/\(codeReviewId)/approve.json",
            method: "PUT"
        )
    }

    /// Reject a code review
    func rejectCodeReview(repositoryId: Int, codeReviewId: Int) async throws {
        _ = try await performRequest(
            endpoint: "/\(repositoryId)/code_reviews/\(codeReviewId)/reject.json",
            method: "PUT"
        )
    }

    // MARK: - Users

    /// List all users in the account
    func listUsers() async throws -> [BeanstalkUser] {
        let data = try await performRequest(endpoint: "/users.json")
        return try JSONDecoder().decode([BeanstalkUserWrapper].self, from: data).map { $0.user }
    }

    // MARK: - Network

    private func performRequest(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let baseURL = baseURL else {
            throw BeanstalkError.notAuthenticated
        }

        guard let token = accessToken, let user = username else {
            throw BeanstalkError.notAuthenticated
        }

        guard let url = URL(string: baseURL.absoluteString + endpoint) else {
            throw BeanstalkError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        // Beanstalk uses HTTP Basic Auth with username and token
        let authString = "\(user):\(token)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.addValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BeanstalkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw BeanstalkError.unauthorized
        case 403:
            throw BeanstalkError.forbidden
        case 404:
            throw BeanstalkError.notFound
        case 422:
            throw BeanstalkError.validationError
        default:
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw BeanstalkError.apiError(message: errorMessage)
            }
            throw BeanstalkError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Data Models

struct BeanstalkUser: Codable, Identifiable {
    let id: Int
    let login: String
    let email: String?
    let name: String?
    let firstName: String?
    let lastName: String?
    let accountId: Int?
    let timezone: String?
    let admin: Bool?
    let owner: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, login, email, name, timezone, admin, owner
        case firstName = "first_name"
        case lastName = "last_name"
        case accountId = "account_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return name ?? login
    }
}

struct BeanstalkRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let title: String?
    let colorLabel: String?
    let type: String // "git" or "subversion"
    let vcs: String? // "git" or "svn"
    let repositoryUrl: String?
    let storageUsedBytes: Int?
    let lastCommitAt: String?
    let createdAt: String?
    let updatedAt: String?
    let accountId: Int?
    let defaultBranch: String?

    enum CodingKeys: String, CodingKey {
        case id, name, title, type, vcs
        case colorLabel = "color_label"
        case repositoryUrl = "repository_url"
        case storageUsedBytes = "storage_used_bytes"
        case lastCommitAt = "last_commit_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case accountId = "account_id"
        case defaultBranch = "default_branch"
    }

    var isGit: Bool {
        type == "git" || vcs == "git"
    }

    var cloneUrl: String? {
        repositoryUrl
    }
}

struct BeanstalkBranch: Codable, Identifiable {
    let name: String
    let revision: String?
    let isMerged: Bool?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, revision
        case isMerged = "is_merged"
    }
}

struct BeanstalkChangeset: Codable, Identifiable {
    let id: Int?
    let revision: String
    let message: String?
    let author: String?
    let email: String?
    let time: String?
    let accountId: Int?
    let repositoryId: Int?
    let userId: Int?
    let tooLarge: Bool?

    enum CodingKeys: String, CodingKey {
        case id, revision, message, author, email, time
        case accountId = "account_id"
        case repositoryId = "repository_id"
        case userId = "user_id"
        case tooLarge = "too_large"
    }

    var shortRevision: String {
        String(revision.prefix(7))
    }
}

struct BeanstalkCodeReview: Codable, Identifiable {
    let id: Int
    let description: String?
    let state: String
    let revisions: String?
    let creatorId: Int?
    let assigneeId: Int?
    let repositoryId: Int?
    let createdAt: String?
    let updatedAt: String?
    let approvedAt: String?
    let rejectedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, description, state, revisions
        case creatorId = "creator_id"
        case assigneeId = "assignee_id"
        case repositoryId = "repository_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case approvedAt = "approved_at"
        case rejectedAt = "rejected_at"
    }

    var revisionList: [String] {
        revisions?.split(separator: ",").map { String($0) } ?? []
    }
}

struct BeanstalkComment: Codable, Identifiable {
    let id: Int
    let body: String?
    let authorId: Int?
    let authorLogin: String?
    let authorName: String?
    let authorEmail: String?
    let createdAt: String?
    let updatedAt: String?
    let renderedBody: String?

    enum CodingKeys: String, CodingKey {
        case id, body
        case authorId = "author_id"
        case authorLogin = "author_login"
        case authorName = "author_name"
        case authorEmail = "author_email"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case renderedBody = "rendered_body"
    }
}

enum BeanstalkCodeReviewState: String {
    case pending
    case approved
    case rejected
    case all
}

// MARK: - Wrapper Types (Beanstalk wraps responses in type keys)

struct BeanstalkUserResponse: Codable {
    let user: BeanstalkUser
}

struct BeanstalkUserWrapper: Codable {
    let user: BeanstalkUser
}

struct BeanstalkRepositoryWrapper: Codable {
    let repository: BeanstalkRepository
}

struct BeanstalkBranchWrapper: Codable {
    let branch: BeanstalkBranch
}

struct BeanstalkChangesetWrapper: Codable {
    let revision_cache: BeanstalkChangeset
}

struct BeanstalkCodeReviewWrapper: Codable {
    let code_review: BeanstalkCodeReview
}

struct BeanstalkCommentWrapper: Codable {
    let comment: BeanstalkComment
}

// MARK: - Errors

enum BeanstalkError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case forbidden
    case notFound
    case validationError
    case invalidResponse
    case invalidEndpoint
    case apiError(message: String)
    case unknown(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Beanstalk"
        case .unauthorized:
            return "Invalid username or access token"
        case .forbidden:
            return "Access denied. Check your permissions."
        case .notFound:
            return "Resource not found"
        case .validationError:
            return "Validation error"
        case .invalidResponse:
            return "Invalid response from Beanstalk"
        case .invalidEndpoint:
            return "Invalid API endpoint"
        case .apiError(let message):
            return "Beanstalk API error: \(message)"
        case .unknown(let statusCode):
            return "Unknown error (HTTP \(statusCode))"
        }
    }
}

// MARK: - Account Storage

struct BeanstalkAccount: Codable, Identifiable {
    let id: UUID
    let domain: String
    let username: String
    let displayName: String
    let email: String?
    var token: String

    init(domain: String, username: String, displayName: String, email: String?, token: String) {
        self.id = UUID()
        self.domain = domain
        self.username = username
        self.displayName = displayName
        self.email = email
        self.token = token
    }

    var accountURL: String {
        "https://\(domain).beanstalkapp.com"
    }
}

@MainActor
class BeanstalkAccountStore: ObservableObject {
    static let shared = BeanstalkAccountStore()

    @Published var accounts: [BeanstalkAccount] = []
    @Published var currentAccount: BeanstalkAccount?

    private let storageKey = "beanstalkAccounts"

    private init() {
        loadAccounts()
    }

    func addAccount(_ account: BeanstalkAccount) {
        accounts.append(account)
        if currentAccount == nil {
            currentAccount = account
        }
        saveAccounts()
    }

    func removeAccount(_ account: BeanstalkAccount) {
        accounts.removeAll { $0.id == account.id }
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
        }
        saveAccounts()
    }

    func switchToAccount(_ account: BeanstalkAccount) {
        currentAccount = account
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BeanstalkAccount].self, from: data) {
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
