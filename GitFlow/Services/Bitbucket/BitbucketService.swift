import Foundation
import AppKit

/// Service for Bitbucket API interactions.
/// Uses Basic Authentication with app passwords.
actor BitbucketService {
    /// The base URL for the Bitbucket API.
    private let apiBaseURL = "https://api.bitbucket.org/2.0"

    /// The username for authentication.
    private var username: String?

    /// The app password for authentication.
    private var appPassword: String?

    /// JSON decoder configured for Bitbucket API responses.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Sets the authentication credentials.
    func setCredentials(username: String?, appPassword: String?) {
        self.username = username
        self.appPassword = appPassword
    }

    /// Checks if the service is authenticated.
    var isAuthenticated: Bool {
        username != nil && !username!.isEmpty &&
        appPassword != nil && !appPassword!.isEmpty
    }

    // MARK: - Authentication

    /// Gets the authenticated user.
    func getAuthenticatedUser() async throws -> BitbucketUser {
        let data = try await makeRequest(path: "/user")
        return try decoder.decode(BitbucketUser.self, from: data)
    }

    /// Validates the current credentials.
    func validateCredentials() async -> Bool {
        do {
            _ = try await getAuthenticatedUser()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Workspaces

    /// Gets workspaces the user has access to.
    func getWorkspaces(page: Int = 1, pageLen: Int = 25) async throws -> [BitbucketWorkspace] {
        let query = "page=\(page)&pagelen=\(pageLen)"
        let data = try await makeRequest(path: "/workspaces", query: query)
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketWorkspace>.self, from: data)
        return response.values
    }

    // MARK: - Repositories

    /// Gets a repository by workspace and slug.
    func getRepository(workspace: String, repoSlug: String) async throws -> BitbucketRepository {
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)")
        return try decoder.decode(BitbucketRepository.self, from: data)
    }

    /// Gets repositories for a workspace.
    func getRepositories(
        workspace: String,
        page: Int = 1,
        pageLen: Int = 25
    ) async throws -> [BitbucketRepository] {
        let query = "page=\(page)&pagelen=\(pageLen)"
        let data = try await makeRequest(path: "/repositories/\(workspace)", query: query)
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketRepository>.self, from: data)
        return response.values
    }

    /// Gets repositories the user has access to.
    func getUserRepositories(
        role: String = "member",
        page: Int = 1,
        pageLen: Int = 25
    ) async throws -> [BitbucketRepository] {
        let query = "role=\(role)&page=\(page)&pagelen=\(pageLen)"
        let data = try await makeRequest(path: "/user/permissions/repositories", query: query)

        // Response contains repository objects in a different structure
        struct PermissionResponse: Codable {
            let repository: BitbucketRepository
        }
        let response = try decoder.decode(BitbucketPaginatedResponse<PermissionResponse>.self, from: data)
        return response.values.map(\.repository)
    }

    /// Extracts Bitbucket info from a repository's remotes.
    func getBitbucketInfo(for repository: Repository, gitService: GitService) async -> BitbucketRemoteInfo? {
        do {
            let remotes = try await gitService.getRemotes(in: repository)
            // Prefer origin
            if let origin = remotes.first(where: { $0.name == "origin" }),
               let info = BitbucketRemoteInfo.parse(from: origin.fetchURL) {
                return info
            }
            // Fall back to first Bitbucket remote
            for remote in remotes {
                if let info = BitbucketRemoteInfo.parse(from: remote.fetchURL) {
                    return info
                }
            }
        } catch {
            // Ignore errors
        }
        return nil
    }

    // MARK: - Issues

    /// Gets issues for a repository.
    func getIssues(
        workspace: String,
        repoSlug: String,
        state: String? = nil,
        page: Int = 1,
        pageLen: Int = 25
    ) async throws -> [BitbucketIssue] {
        var query = "page=\(page)&pagelen=\(pageLen)"
        if let state = state {
            query += "&q=state=\"\(state)\""
        }
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/issues", query: query)
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketIssue>.self, from: data)
        return response.values
    }

    /// Gets a specific issue.
    func getIssue(workspace: String, repoSlug: String, issueId: Int) async throws -> BitbucketIssue {
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/issues/\(issueId)")
        return try decoder.decode(BitbucketIssue.self, from: data)
    }

    // MARK: - Pull Requests

    /// Gets pull requests for a repository.
    func getPullRequests(
        workspace: String,
        repoSlug: String,
        state: String = "OPEN",
        page: Int = 1,
        pageLen: Int = 25
    ) async throws -> [BitbucketPullRequest] {
        let query = "state=\(state)&page=\(page)&pagelen=\(pageLen)"
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/pullrequests", query: query)
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketPullRequest>.self, from: data)
        return response.values
    }

    /// Gets a specific pull request.
    func getPullRequest(workspace: String, repoSlug: String, prId: Int) async throws -> BitbucketPullRequest {
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)")
        return try decoder.decode(BitbucketPullRequest.self, from: data)
    }

    /// Gets comments for a pull request.
    func getPullRequestComments(
        workspace: String,
        repoSlug: String,
        prId: Int
    ) async throws -> [BitbucketComment] {
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/comments")
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketComment>.self, from: data)
        return response.values.filter { !$0.deleted }
    }

    /// Gets the diff for a pull request.
    func getPullRequestDiff(workspace: String, repoSlug: String, prId: Int) async throws -> String {
        var request = URLRequest(url: URL(string: "\(apiBaseURL)/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/diff")!)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        if let credentials = authorizationHeader {
            request.setValue(credentials, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BitbucketError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw BitbucketError.httpError(statusCode: httpResponse.statusCode)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Pull Request Write Operations

    /// Creates a new pull request.
    func createPullRequest(
        workspace: String,
        repoSlug: String,
        title: String,
        description: String?,
        sourceBranch: String,
        destinationBranch: String,
        closeSourceBranch: Bool = false
    ) async throws -> BitbucketPullRequest {
        var payload: [String: Any] = [
            "title": title,
            "source": ["branch": ["name": sourceBranch]],
            "destination": ["branch": ["name": destinationBranch]],
            "close_source_branch": closeSourceBranch
        ]
        if let description = description {
            payload["description"] = description
        }

        let data = try await makePostRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests",
            body: payload
        )
        return try decoder.decode(BitbucketPullRequest.self, from: data)
    }

    /// Updates an existing pull request.
    func updatePullRequest(
        workspace: String,
        repoSlug: String,
        prId: Int,
        title: String? = nil,
        description: String? = nil,
        destinationBranch: String? = nil
    ) async throws -> BitbucketPullRequest {
        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = title }
        if let description = description { payload["description"] = description }
        if let destinationBranch = destinationBranch {
            payload["destination"] = ["branch": ["name": destinationBranch]]
        }

        let data = try await makePutRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)",
            body: payload
        )
        return try decoder.decode(BitbucketPullRequest.self, from: data)
    }

    /// Declines (closes) a pull request.
    func declinePullRequest(workspace: String, repoSlug: String, prId: Int) async throws -> BitbucketPullRequest {
        let data = try await makePostRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/decline",
            body: [:]
        )
        return try decoder.decode(BitbucketPullRequest.self, from: data)
    }

    /// Merges a pull request.
    func mergePullRequest(
        workspace: String,
        repoSlug: String,
        prId: Int,
        mergeStrategy: String = "merge_commit",
        closeSourceBranch: Bool = false,
        message: String? = nil
    ) async throws -> BitbucketPullRequest {
        var payload: [String: Any] = [
            "merge_strategy": mergeStrategy,
            "close_source_branch": closeSourceBranch
        ]
        if let message = message {
            payload["message"] = message
        }

        let data = try await makePostRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/merge",
            body: payload
        )
        return try decoder.decode(BitbucketPullRequest.self, from: data)
    }

    // MARK: - Comment Operations

    /// Adds a comment to a pull request.
    func addPullRequestComment(
        workspace: String,
        repoSlug: String,
        prId: Int,
        content: String
    ) async throws -> BitbucketComment {
        let payload: [String: Any] = [
            "content": ["raw": content]
        ]
        let data = try await makePostRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/comments",
            body: payload
        )
        return try decoder.decode(BitbucketComment.self, from: data)
    }

    /// Updates a comment.
    func updateComment(
        workspace: String,
        repoSlug: String,
        prId: Int,
        commentId: Int,
        content: String
    ) async throws -> BitbucketComment {
        let payload: [String: Any] = [
            "content": ["raw": content]
        ]
        let data = try await makePutRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/comments/\(commentId)",
            body: payload
        )
        return try decoder.decode(BitbucketComment.self, from: data)
    }

    /// Deletes a comment.
    func deleteComment(workspace: String, repoSlug: String, prId: Int, commentId: Int) async throws {
        try await makeDeleteRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/comments/\(commentId)"
        )
    }

    // MARK: - Approve/Unapprove

    /// Approves a pull request.
    func approvePullRequest(workspace: String, repoSlug: String, prId: Int) async throws {
        _ = try await makePostRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/approve",
            body: [:]
        )
    }

    /// Removes approval from a pull request.
    func unapprovePullRequest(workspace: String, repoSlug: String, prId: Int) async throws {
        try await makeDeleteRequest(
            path: "/repositories/\(workspace)/\(repoSlug)/pullrequests/\(prId)/approve"
        )
    }

    // MARK: - Branch Operations

    /// Gets branches for a repository.
    func getBranches(
        workspace: String,
        repoSlug: String,
        page: Int = 1,
        pageLen: Int = 25
    ) async throws -> [BitbucketBranch] {
        let query = "page=\(page)&pagelen=\(pageLen)"
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/refs/branches", query: query)
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketBranch>.self, from: data)
        return response.values
    }

    // MARK: - Pipeline Operations

    /// Gets pipelines for a repository.
    func getPipelines(
        workspace: String,
        repoSlug: String,
        page: Int = 1,
        pageLen: Int = 25
    ) async throws -> [BitbucketPipeline] {
        let query = "page=\(page)&pagelen=\(pageLen)&sort=-created_on"
        let data = try await makeRequest(path: "/repositories/\(workspace)/\(repoSlug)/pipelines", query: query)
        let response = try decoder.decode(BitbucketPaginatedResponse<BitbucketPipeline>.self, from: data)
        return response.values
    }

    // MARK: - URL Generation

    /// Opens the repository in the browser.
    func openInBrowser(workspace: String, repoSlug: String) {
        let url = URL(string: "https://bitbucket.org/\(workspace)/\(repoSlug)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens a pull request in the browser.
    func openPullRequestInBrowser(workspace: String, repoSlug: String, prId: Int) {
        let url = URL(string: "https://bitbucket.org/\(workspace)/\(repoSlug)/pull-requests/\(prId)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(workspace: String, repoSlug: String, issueId: Int) {
        let url = URL(string: "https://bitbucket.org/\(workspace)/\(repoSlug)/issues/\(issueId)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the pipelines page in browser.
    func openPipelinesInBrowser(workspace: String, repoSlug: String) {
        let url = URL(string: "https://bitbucket.org/\(workspace)/\(repoSlug)/pipelines")!
        NSWorkspace.shared.open(url)
    }

    /// Generates a URL for creating a new pull request.
    func newPullRequestURL(workspace: String, repoSlug: String, sourceBranch: String, destinationBranch: String? = nil) -> URL {
        var urlString = "https://bitbucket.org/\(workspace)/\(repoSlug)/pull-requests/new?source=\(sourceBranch)"
        if let dest = destinationBranch {
            urlString += "&dest=\(dest)"
        }
        return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)!
    }

    // MARK: - Private Helpers

    private var authorizationHeader: String? {
        guard let username = username, let appPassword = appPassword else { return nil }
        let credentials = "\(username):\(appPassword)"
        guard let data = credentials.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    private func makeRequest(path: String, query: String? = nil) async throws -> Data {
        try await makeHTTPRequest(method: "GET", path: path, query: query, body: nil)
    }

    private func makePostRequest(path: String, body: [String: Any]) async throws -> Data {
        try await makeHTTPRequest(method: "POST", path: path, query: nil, body: body)
    }

    private func makePutRequest(path: String, body: [String: Any]) async throws -> Data {
        try await makeHTTPRequest(method: "PUT", path: path, query: nil, body: body)
    }

    private func makeDeleteRequest(path: String) async throws {
        _ = try await makeHTTPRequest(method: "DELETE", path: path, query: nil, body: nil)
    }

    private func makeHTTPRequest(
        method: String,
        path: String,
        query: String?,
        body: [String: Any]?
    ) async throws -> Data {
        var urlString = apiBaseURL + path
        if let query = query {
            urlString += "?" + query
        }

        guard let url = URL(string: urlString) else {
            throw BitbucketError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let credentials = authorizationHeader {
            request.setValue(credentials, forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BitbucketError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw BitbucketError.unauthorized
        case 403:
            throw BitbucketError.forbidden
        case 404:
            throw BitbucketError.notFound
        case 400:
            throw BitbucketError.badRequest
        default:
            throw BitbucketError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

/// Errors that can occur when interacting with the Bitbucket API.
enum BitbucketError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case badRequest
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Bitbucket URL"
        case .invalidResponse:
            return "Invalid response from Bitbucket"
        case .unauthorized:
            return "Authentication required. Please add your Bitbucket credentials."
        case .forbidden:
            return "Access forbidden. Check your app password permissions."
        case .notFound:
            return "Resource not found"
        case .badRequest:
            return "Invalid request"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
