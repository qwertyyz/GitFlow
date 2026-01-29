import Foundation

/// Service for Azure DevOps integration.
actor AzureDevOpsService {
    static let shared = AzureDevOpsService()

    private var accessToken: String?
    private var organization: String?
    private var baseURL: URL {
        URL(string: "https://dev.azure.com/\(organization ?? "")")!
    }

    private init() {}

    // MARK: - Authentication

    /// Authenticate with Azure DevOps using a Personal Access Token
    func authenticate(organization: String, token: String) async throws -> AzureDevOpsUser {
        self.organization = organization
        self.accessToken = token

        // Verify the token by fetching user profile
        let user = try await getCurrentUser()
        return user
    }

    /// Check if authenticated
    func isAuthenticated() -> Bool {
        accessToken != nil && organization != nil
    }

    /// Sign out from Azure DevOps
    func signOut() {
        accessToken = nil
        organization = nil
    }

    // MARK: - User

    /// Get the current authenticated user
    func getCurrentUser() async throws -> AzureDevOpsUser {
        let url = URL(string: "https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.0")!
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(AzureDevOpsUser.self, from: data)
    }

    // MARK: - Projects

    /// List all projects in the organization
    func listProjects() async throws -> [AzureDevOpsProject] {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/_apis/projects?api-version=7.0")!
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(AzureDevOpsListResponse<AzureDevOpsProject>.self, from: data)
        return response.value
    }

    /// Get a specific project
    func getProject(id: String) async throws -> AzureDevOpsProject {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/_apis/projects/\(id)?api-version=7.0")!
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(AzureDevOpsProject.self, from: data)
    }

    // MARK: - Repositories

    /// List all repositories in a project
    func listRepositories(projectId: String) async throws -> [AzureDevOpsRepository] {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories?api-version=7.0")!
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(AzureDevOpsListResponse<AzureDevOpsRepository>.self, from: data)
        return response.value
    }

    /// List all repositories across all projects
    func listAllRepositories() async throws -> [AzureDevOpsRepository] {
        let projects = try await listProjects()
        var allRepos: [AzureDevOpsRepository] = []

        for project in projects {
            do {
                let repos = try await listRepositories(projectId: project.id)
                allRepos.append(contentsOf: repos)
            } catch {
                // Continue if we can't access a project
                continue
            }
        }

        return allRepos
    }

    /// Get a specific repository
    func getRepository(projectId: String, repositoryId: String) async throws -> AzureDevOpsRepository {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)?api-version=7.0")!
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(AzureDevOpsRepository.self, from: data)
    }

    // MARK: - Pull Requests

    /// List pull requests in a repository
    func listPullRequests(
        projectId: String,
        repositoryId: String,
        status: AzureDevOpsPRStatus = .active
    ) async throws -> [AzureDevOpsPullRequest] {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests?searchCriteria.status=\(status.rawValue)&api-version=7.0")!
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(AzureDevOpsListResponse<AzureDevOpsPullRequest>.self, from: data)
        return response.value
    }

    /// Get a specific pull request
    func getPullRequest(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int
    ) async throws -> AzureDevOpsPullRequest {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests/\(pullRequestId)?api-version=7.0")!
        let data = try await performRequest(url: url)
        return try JSONDecoder().decode(AzureDevOpsPullRequest.self, from: data)
    }

    /// Create a pull request
    func createPullRequest(
        projectId: String,
        repositoryId: String,
        sourceBranch: String,
        targetBranch: String,
        title: String,
        description: String?
    ) async throws -> AzureDevOpsPullRequest {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests?api-version=7.0")!

        let body: [String: Any] = [
            "sourceRefName": "refs/heads/\(sourceBranch)",
            "targetRefName": "refs/heads/\(targetBranch)",
            "title": title,
            "description": description ?? ""
        ]

        let data = try await performRequest(url: url, method: "POST", body: body)
        return try JSONDecoder().decode(AzureDevOpsPullRequest.self, from: data)
    }

    /// Update a pull request (approve, reject, etc.)
    func updatePullRequest(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int,
        status: AzureDevOpsPRStatus? = nil,
        title: String? = nil,
        description: String? = nil
    ) async throws -> AzureDevOpsPullRequest {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests/\(pullRequestId)?api-version=7.0")!

        var body: [String: Any] = [:]
        if let status = status {
            body["status"] = status.rawValue
        }
        if let title = title {
            body["title"] = title
        }
        if let description = description {
            body["description"] = description
        }

        let data = try await performRequest(url: url, method: "PATCH", body: body)
        return try JSONDecoder().decode(AzureDevOpsPullRequest.self, from: data)
    }

    /// Complete (merge) a pull request
    func completePullRequest(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int,
        lastMergeSourceCommit: String,
        deleteSourceBranch: Bool = false,
        squashMerge: Bool = false
    ) async throws -> AzureDevOpsPullRequest {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests/\(pullRequestId)?api-version=7.0")!

        let completionOptions: [String: Any] = [
            "deleteSourceBranch": deleteSourceBranch,
            "squashMerge": squashMerge
        ]

        let body: [String: Any] = [
            "status": "completed",
            "lastMergeSourceCommit": ["commitId": lastMergeSourceCommit],
            "completionOptions": completionOptions
        ]

        let data = try await performRequest(url: url, method: "PATCH", body: body)
        return try JSONDecoder().decode(AzureDevOpsPullRequest.self, from: data)
    }

    /// Abandon a pull request
    func abandonPullRequest(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int
    ) async throws -> AzureDevOpsPullRequest {
        return try await updatePullRequest(
            projectId: projectId,
            repositoryId: repositoryId,
            pullRequestId: pullRequestId,
            status: .abandoned
        )
    }

    /// Add a reviewer to a pull request
    func addReviewer(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int,
        reviewerId: String,
        vote: Int = 0  // 0 = no vote, 5 = waiting, 10 = approved, -5 = waiting, -10 = rejected
    ) async throws {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests/\(pullRequestId)/reviewers/\(reviewerId)?api-version=7.0")!

        let body: [String: Any] = [
            "vote": vote
        ]

        _ = try await performRequest(url: url, method: "PUT", body: body)
    }

    // MARK: - Comments

    /// List comments on a pull request
    func listPullRequestComments(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int
    ) async throws -> [AzureDevOpsPRThread] {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests/\(pullRequestId)/threads?api-version=7.0")!
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(AzureDevOpsListResponse<AzureDevOpsPRThread>.self, from: data)
        return response.value
    }

    /// Add a comment to a pull request
    func addPullRequestComment(
        projectId: String,
        repositoryId: String,
        pullRequestId: Int,
        content: String
    ) async throws -> AzureDevOpsPRThread {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/pullrequests/\(pullRequestId)/threads?api-version=7.0")!

        let body: [String: Any] = [
            "comments": [
                ["content": content, "commentType": 1]  // 1 = text
            ],
            "status": 1  // 1 = active
        ]

        let data = try await performRequest(url: url, method: "POST", body: body)
        return try JSONDecoder().decode(AzureDevOpsPRThread.self, from: data)
    }

    // MARK: - Branches

    /// List branches in a repository
    func listBranches(projectId: String, repositoryId: String) async throws -> [AzureDevOpsBranch] {
        guard let org = organization else {
            throw AzureDevOpsError.notAuthenticated
        }

        let url = URL(string: "https://dev.azure.com/\(org)/\(projectId)/_apis/git/repositories/\(repositoryId)/refs?filter=heads&api-version=7.0")!
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(AzureDevOpsListResponse<AzureDevOpsBranch>.self, from: data)
        return response.value
    }

    // MARK: - Network

    private func performRequest(
        url: URL,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = accessToken else {
            throw AzureDevOpsError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Azure DevOps uses Basic auth with PAT
        let authString = ":\(token)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.addValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureDevOpsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw AzureDevOpsError.unauthorized
        case 403:
            throw AzureDevOpsError.forbidden
        case 404:
            throw AzureDevOpsError.notFound
        default:
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw AzureDevOpsError.apiError(message: errorMessage)
            }
            throw AzureDevOpsError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Data Models

struct AzureDevOpsUser: Codable, Identifiable {
    let id: String
    let displayName: String
    let emailAddress: String?
    let publicAlias: String?
    let coreRevision: Int?

    var avatarURL: URL? {
        // Azure DevOps doesn't provide avatar URL directly in profile
        nil
    }
}

struct AzureDevOpsProject: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let url: String
    let state: String
    let revision: Int?
    let visibility: String?
    let lastUpdateTime: String?
}

struct AzureDevOpsRepository: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let project: AzureDevOpsProjectRef
    let defaultBranch: String?
    let size: Int
    let remoteUrl: String
    let sshUrl: String?
    let webUrl: String?
    let isDisabled: Bool?

    struct AzureDevOpsProjectRef: Codable, Hashable {
        let id: String
        let name: String
        let url: String?
        let state: String?
    }
}

struct AzureDevOpsPullRequest: Codable, Identifiable, Hashable {
    let pullRequestId: Int
    let codeReviewId: Int?
    let status: String
    let createdBy: AzureDevOpsIdentityRef
    let creationDate: String
    let title: String
    let description: String?
    let sourceRefName: String
    let targetRefName: String
    let mergeStatus: String?
    let isDraft: Bool?
    let reviewers: [AzureDevOpsReviewer]?
    let url: String
    let repository: AzureDevOpsRepositoryRef?

    var id: Int { pullRequestId }

    var sourceBranch: String {
        sourceRefName.replacingOccurrences(of: "refs/heads/", with: "")
    }

    var targetBranch: String {
        targetRefName.replacingOccurrences(of: "refs/heads/", with: "")
    }

    struct AzureDevOpsRepositoryRef: Codable, Hashable {
        let id: String
        let name: String
        let url: String?
        let project: AzureDevOpsRepository.AzureDevOpsProjectRef?
    }
}

struct AzureDevOpsIdentityRef: Codable, Hashable {
    let displayName: String
    let url: String?
    let id: String
    let uniqueName: String?
    let imageUrl: String?
}

struct AzureDevOpsReviewer: Codable, Identifiable, Hashable {
    let reviewerUrl: String?
    let vote: Int
    let hasDeclined: Bool?
    let isRequired: Bool?
    let isFlagged: Bool?
    let displayName: String
    let url: String?
    let id: String
    let uniqueName: String?
    let imageUrl: String?

    var voteDescription: String {
        switch vote {
        case 10: return "Approved"
        case 5: return "Approved with suggestions"
        case 0: return "No vote"
        case -5: return "Waiting for author"
        case -10: return "Rejected"
        default: return "Unknown"
        }
    }
}

struct AzureDevOpsBranch: Codable, Identifiable {
    let name: String
    let objectId: String
    let creator: AzureDevOpsIdentityRef?
    let url: String?

    var id: String { name }

    var shortName: String {
        name.replacingOccurrences(of: "refs/heads/", with: "")
    }
}

struct AzureDevOpsPRThread: Codable, Identifiable {
    let id: Int
    let publishedDate: String?
    let lastUpdatedDate: String?
    let comments: [AzureDevOpsPRComment]?
    let status: String?
    let threadContext: ThreadContext?
    let isDeleted: Bool?

    struct ThreadContext: Codable {
        let filePath: String?
        let rightFileStart: FilePosition?
        let rightFileEnd: FilePosition?
        let leftFileStart: FilePosition?
        let leftFileEnd: FilePosition?

        struct FilePosition: Codable {
            let line: Int
            let offset: Int
        }
    }
}

struct AzureDevOpsPRComment: Codable, Identifiable {
    let id: Int
    let parentCommentId: Int?
    let author: AzureDevOpsIdentityRef
    let content: String
    let publishedDate: String
    let lastUpdatedDate: String?
    let commentType: String?
    let isDeleted: Bool?
}

enum AzureDevOpsPRStatus: String, Codable {
    case notSet = "notSet"
    case active = "active"
    case abandoned = "abandoned"
    case completed = "completed"
    case all = "all"
}

struct AzureDevOpsListResponse<T: Codable>: Codable {
    let count: Int
    let value: [T]
}

// MARK: - Errors

enum AzureDevOpsError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case forbidden
    case notFound
    case invalidResponse
    case apiError(message: String)
    case unknown(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Azure DevOps"
        case .unauthorized:
            return "Invalid Personal Access Token"
        case .forbidden:
            return "Access denied. Check your token permissions."
        case .notFound:
            return "Resource not found"
        case .invalidResponse:
            return "Invalid response from Azure DevOps"
        case .apiError(let message):
            return "Azure DevOps API error: \(message)"
        case .unknown(let statusCode):
            return "Unknown error (HTTP \(statusCode))"
        }
    }
}

// MARK: - Account Storage

struct AzureDevOpsAccount: Codable, Identifiable {
    let id: UUID
    let organization: String
    let displayName: String
    let email: String?
    var token: String  // Stored securely in Keychain in production

    init(organization: String, displayName: String, email: String?, token: String) {
        self.id = UUID()
        self.organization = organization
        self.displayName = displayName
        self.email = email
        self.token = token
    }
}

@MainActor
class AzureDevOpsAccountStore: ObservableObject {
    static let shared = AzureDevOpsAccountStore()

    @Published var accounts: [AzureDevOpsAccount] = []
    @Published var currentAccount: AzureDevOpsAccount?

    private let storageKey = "azureDevOpsAccounts"

    private init() {
        loadAccounts()
    }

    func addAccount(_ account: AzureDevOpsAccount) {
        accounts.append(account)
        if currentAccount == nil {
            currentAccount = account
        }
        saveAccounts()
    }

    func removeAccount(_ account: AzureDevOpsAccount) {
        accounts.removeAll { $0.id == account.id }
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
        }
        saveAccounts()
    }

    func switchToAccount(_ account: AzureDevOpsAccount) {
        currentAccount = account
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AzureDevOpsAccount].self, from: data) {
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
