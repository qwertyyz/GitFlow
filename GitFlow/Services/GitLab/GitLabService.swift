import Foundation
import AppKit

/// Service for GitLab API interactions.
actor GitLabService {
    /// The base URL for the GitLab API (default: gitlab.com).
    private var apiBaseURL: String

    /// The current authentication token.
    private var authToken: String?

    /// JSON decoder configured for GitLab API responses.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Creates a GitLabService for gitlab.com.
    init() {
        self.apiBaseURL = "https://gitlab.com/api/v4"
    }

    /// Creates a GitLabService for a self-hosted GitLab instance.
    init(host: String) {
        self.apiBaseURL = "https://\(host)/api/v4"
    }

    /// Sets the base URL for self-hosted GitLab.
    func setHost(_ host: String) {
        self.apiBaseURL = "https://\(host)/api/v4"
    }

    /// Sets the authentication token for API requests.
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// Checks if the service is authenticated.
    var isAuthenticated: Bool {
        authToken != nil && !authToken!.isEmpty
    }

    // MARK: - Authentication

    /// Gets the authenticated user.
    func getAuthenticatedUser() async throws -> GitLabUser {
        let data = try await makeRequest(path: "/user")
        return try decoder.decode(GitLabUser.self, from: data)
    }

    /// Validates the current token.
    func validateToken() async -> Bool {
        do {
            _ = try await getAuthenticatedUser()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Projects

    /// Gets a project by ID.
    func getProject(id: Int) async throws -> GitLabProject {
        let data = try await makeRequest(path: "/projects/\(id)")
        return try decoder.decode(GitLabProject.self, from: data)
    }

    /// Gets a project by path (e.g., "owner/repo" or "group/subgroup/repo").
    func getProject(path: String) async throws -> GitLabProject {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let data = try await makeRequest(path: "/projects/\(encoded)")
        return try decoder.decode(GitLabProject.self, from: data)
    }

    /// Gets projects the authenticated user has access to.
    func getProjects(
        membership: Bool = true,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GitLabProject] {
        var query = "page=\(page)&per_page=\(perPage)&order_by=last_activity_at"
        if membership {
            query += "&membership=true"
        }
        let data = try await makeRequest(path: "/projects", query: query)
        return try decoder.decode([GitLabProject].self, from: data)
    }

    /// Searches for projects by name.
    func searchProjects(query: String, page: Int = 1, perPage: Int = 20) async throws -> [GitLabProject] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let queryString = "search=\(encoded)&page=\(page)&per_page=\(perPage)"
        let data = try await makeRequest(path: "/projects", query: queryString)
        return try decoder.decode([GitLabProject].self, from: data)
    }

    /// Extracts GitLab info from a repository's remotes.
    func getGitLabInfo(for repository: Repository, gitService: GitService) async -> GitLabRemoteInfo? {
        do {
            let remotes = try await gitService.getRemotes(in: repository)
            // Prefer origin
            if let origin = remotes.first(where: { $0.name == "origin" }),
               let info = GitLabRemoteInfo.parse(from: origin.fetchURL) {
                return info
            }
            // Fall back to first GitLab remote
            for remote in remotes {
                if let info = GitLabRemoteInfo.parse(from: remote.fetchURL) {
                    return info
                }
            }
        } catch {
            // Ignore errors
        }
        return nil
    }

    // MARK: - Issues

    /// Gets issues for a project.
    func getIssues(
        projectId: Int,
        state: String = "opened",
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GitLabIssue] {
        let query = "state=\(state)&page=\(page)&per_page=\(perPage)"
        let data = try await makeRequest(path: "/projects/\(projectId)/issues", query: query)
        return try decoder.decode([GitLabIssue].self, from: data)
    }

    /// Gets a specific issue.
    func getIssue(projectId: Int, issueIid: Int) async throws -> GitLabIssue {
        let data = try await makeRequest(path: "/projects/\(projectId)/issues/\(issueIid)")
        return try decoder.decode(GitLabIssue.self, from: data)
    }

    // MARK: - Merge Requests

    /// Gets merge requests for a project.
    func getMergeRequests(
        projectId: Int,
        state: String = "opened",
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GitLabMergeRequest] {
        let query = "state=\(state)&page=\(page)&per_page=\(perPage)"
        let data = try await makeRequest(path: "/projects/\(projectId)/merge_requests", query: query)
        return try decoder.decode([GitLabMergeRequest].self, from: data)
    }

    /// Gets a specific merge request.
    func getMergeRequest(projectId: Int, mrIid: Int) async throws -> GitLabMergeRequest {
        let data = try await makeRequest(path: "/projects/\(projectId)/merge_requests/\(mrIid)")
        return try decoder.decode(GitLabMergeRequest.self, from: data)
    }

    /// Gets notes (comments) for a merge request.
    func getMergeRequestNotes(projectId: Int, mrIid: Int) async throws -> [GitLabNote] {
        let data = try await makeRequest(path: "/projects/\(projectId)/merge_requests/\(mrIid)/notes")
        return try decoder.decode([GitLabNote].self, from: data)
    }

    /// Gets the diff for a merge request.
    func getMergeRequestDiff(projectId: Int, mrIid: Int) async throws -> String {
        // GitLab returns diff in changes endpoint
        var request = URLRequest(url: URL(string: "\(apiBaseURL)/projects/\(projectId)/merge_requests/\(mrIid)/changes")!)

        if let token = authToken {
            request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitLabError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GitLabError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse the changes and format as diff
        struct ChangesResponse: Codable {
            let changes: [Change]

            struct Change: Codable {
                let diff: String
                let newPath: String
                let oldPath: String

                enum CodingKeys: String, CodingKey {
                    case diff
                    case newPath = "new_path"
                    case oldPath = "old_path"
                }
            }
        }

        let changesResponse = try decoder.decode(ChangesResponse.self, from: data)
        return changesResponse.changes.map { change in
            "diff --git a/\(change.oldPath) b/\(change.newPath)\n\(change.diff)"
        }.joined(separator: "\n")
    }

    // MARK: - Merge Request Write Operations

    /// Creates a new merge request.
    func createMergeRequest(
        projectId: Int,
        title: String,
        description: String?,
        sourceBranch: String,
        targetBranch: String,
        isDraft: Bool = false
    ) async throws -> GitLabMergeRequest {
        var payload: [String: Any] = [
            "title": isDraft ? "Draft: \(title)" : title,
            "source_branch": sourceBranch,
            "target_branch": targetBranch
        ]
        if let description = description {
            payload["description"] = description
        }

        let data = try await makePostRequest(
            path: "/projects/\(projectId)/merge_requests",
            body: payload
        )
        return try decoder.decode(GitLabMergeRequest.self, from: data)
    }

    /// Updates an existing merge request.
    func updateMergeRequest(
        projectId: Int,
        mrIid: Int,
        title: String? = nil,
        description: String? = nil,
        targetBranch: String? = nil,
        stateEvent: String? = nil
    ) async throws -> GitLabMergeRequest {
        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = title }
        if let description = description { payload["description"] = description }
        if let targetBranch = targetBranch { payload["target_branch"] = targetBranch }
        if let stateEvent = stateEvent { payload["state_event"] = stateEvent }

        let data = try await makePutRequest(
            path: "/projects/\(projectId)/merge_requests/\(mrIid)",
            body: payload
        )
        return try decoder.decode(GitLabMergeRequest.self, from: data)
    }

    /// Closes a merge request.
    func closeMergeRequest(projectId: Int, mrIid: Int) async throws -> GitLabMergeRequest {
        try await updateMergeRequest(projectId: projectId, mrIid: mrIid, stateEvent: "close")
    }

    /// Merges a merge request.
    func mergeMergeRequest(
        projectId: Int,
        mrIid: Int,
        mergeCommitMessage: String? = nil,
        squash: Bool = false,
        shouldRemoveSourceBranch: Bool = false
    ) async throws -> GitLabMergeRequest {
        var payload: [String: Any] = [
            "squash": squash,
            "should_remove_source_branch": shouldRemoveSourceBranch
        ]
        if let message = mergeCommitMessage {
            payload["merge_commit_message"] = message
        }

        let data = try await makePutRequest(
            path: "/projects/\(projectId)/merge_requests/\(mrIid)/merge",
            body: payload
        )
        return try decoder.decode(GitLabMergeRequest.self, from: data)
    }

    // MARK: - Note Operations

    /// Adds a note (comment) to a merge request.
    func addMergeRequestNote(
        projectId: Int,
        mrIid: Int,
        body: String
    ) async throws -> GitLabNote {
        let payload: [String: Any] = ["body": body]
        let data = try await makePostRequest(
            path: "/projects/\(projectId)/merge_requests/\(mrIid)/notes",
            body: payload
        )
        return try decoder.decode(GitLabNote.self, from: data)
    }

    /// Updates a note.
    func updateNote(
        projectId: Int,
        mrIid: Int,
        noteId: Int,
        body: String
    ) async throws -> GitLabNote {
        let payload: [String: Any] = ["body": body]
        let data = try await makePutRequest(
            path: "/projects/\(projectId)/merge_requests/\(mrIid)/notes/\(noteId)",
            body: payload
        )
        return try decoder.decode(GitLabNote.self, from: data)
    }

    /// Deletes a note.
    func deleteNote(projectId: Int, mrIid: Int, noteId: Int) async throws {
        try await makeDeleteRequest(
            path: "/projects/\(projectId)/merge_requests/\(mrIid)/notes/\(noteId)"
        )
    }

    // MARK: - Branch Operations

    /// Gets branches for a project.
    func getBranches(projectId: Int, search: String? = nil) async throws -> [GitLabBranch] {
        var query = ""
        if let search = search {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            query = "search=\(encoded)"
        }
        let data = try await makeRequest(path: "/projects/\(projectId)/repository/branches", query: query.isEmpty ? nil : query)
        return try decoder.decode([GitLabBranch].self, from: data)
    }

    // MARK: - Pipeline Operations

    /// Gets pipelines for a project.
    func getPipelines(
        projectId: Int,
        ref: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> [GitLabPipeline] {
        var query = "page=\(page)&per_page=\(perPage)"
        if let ref = ref {
            let encoded = ref.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ref
            query += "&ref=\(encoded)"
        }
        let data = try await makeRequest(path: "/projects/\(projectId)/pipelines", query: query)
        return try decoder.decode([GitLabPipeline].self, from: data)
    }

    /// Gets pipelines for a merge request.
    func getMergeRequestPipelines(projectId: Int, mrIid: Int) async throws -> [GitLabPipeline] {
        let data = try await makeRequest(path: "/projects/\(projectId)/merge_requests/\(mrIid)/pipelines")
        return try decoder.decode([GitLabPipeline].self, from: data)
    }

    // MARK: - URL Generation

    /// Opens the project in the browser.
    func openInBrowser(projectPath: String, host: String = "gitlab.com") {
        let url = URL(string: "https://\(host)/\(projectPath)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens a merge request in the browser.
    func openMergeRequestInBrowser(projectPath: String, mrIid: Int, host: String = "gitlab.com") {
        let url = URL(string: "https://\(host)/\(projectPath)/-/merge_requests/\(mrIid)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(projectPath: String, issueIid: Int, host: String = "gitlab.com") {
        let url = URL(string: "https://\(host)/\(projectPath)/-/issues/\(issueIid)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the compare view in browser.
    func openCompareInBrowser(projectPath: String, source: String, target: String, host: String = "gitlab.com") {
        let url = URL(string: "https://\(host)/\(projectPath)/-/compare/\(target)...\(source)")!
        NSWorkspace.shared.open(url)
    }

    /// Opens the pipelines page in browser.
    func openPipelinesInBrowser(projectPath: String, host: String = "gitlab.com") {
        let url = URL(string: "https://\(host)/\(projectPath)/-/pipelines")!
        NSWorkspace.shared.open(url)
    }

    /// Generates a URL for creating a new merge request.
    func newMergeRequestURL(projectPath: String, sourceBranch: String, targetBranch: String? = nil, host: String = "gitlab.com") -> URL {
        var urlString = "https://\(host)/\(projectPath)/-/merge_requests/new?merge_request[source_branch]=\(sourceBranch)"
        if let target = targetBranch {
            urlString += "&merge_request[target_branch]=\(target)"
        }
        return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)!
    }

    // MARK: - Private Helpers

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
            throw GitLabError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitLabError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw GitLabError.unauthorized
        case 403:
            throw GitLabError.forbidden
        case 404:
            throw GitLabError.notFound
        case 422:
            throw GitLabError.validationFailed
        default:
            throw GitLabError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

/// Errors that can occur when interacting with the GitLab API.
enum GitLabError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationFailed
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitLab URL"
        case .invalidResponse:
            return "Invalid response from GitLab"
        case .unauthorized:
            return "Authentication required. Please add a GitLab token."
        case .forbidden:
            return "Access forbidden. Check your token permissions."
        case .notFound:
            return "Resource not found"
        case .validationFailed:
            return "Validation failed"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
