import Foundation
import AppKit

/// View model for GitLab integration features.
@MainActor
final class GitLabViewModel: ObservableObject {
    // MARK: - Published State

    /// GitLab project info extracted from remotes.
    @Published private(set) var gitlabInfo: GitLabRemoteInfo?

    /// Whether this repository is connected to GitLab.
    @Published private(set) var isGitLabRepository: Bool = false

    /// The authenticated GitLab user.
    @Published private(set) var authenticatedUser: GitLabUser?

    /// Whether we're authenticated.
    @Published var isAuthenticated: Bool = false

    /// Current issues.
    @Published private(set) var issues: [GitLabIssue] = []

    /// Current merge requests.
    @Published private(set) var mergeRequests: [GitLabMergeRequest] = []

    /// Selected merge request for detailed view.
    @Published var selectedMergeRequest: GitLabMergeRequest?

    /// Notes (comments) for the selected MR.
    @Published private(set) var selectedMRNotes: [GitLabNote] = []

    /// Pipelines for the selected MR.
    @Published private(set) var selectedMRPipelines: [GitLabPipeline] = []

    /// The project details.
    @Published private(set) var project: GitLabProject?

    /// Available branches for the project.
    @Published private(set) var branches: [GitLabBranch] = []

    /// Whether data is loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitLabError?

    /// Filter for issues/MRs state.
    @Published var stateFilter: StateFilter = .open

    /// The GitLab token, securely stored in Keychain.
    @Published var gitlabToken: String = "" {
        didSet {
            saveTokenToKeychain(gitlabToken)

            Task {
                await gitLabService.setAuthToken(gitlabToken.isEmpty ? nil : gitlabToken)
                await validateAndLoadUser()
            }
        }
    }

    /// The GitLab host (for self-hosted instances).
    @Published var gitlabHost: String = "gitlab.com" {
        didSet {
            saveHostToKeychain(gitlabHost)

            Task {
                await gitLabService.setHost(gitlabHost)
                if !gitlabToken.isEmpty {
                    await validateAndLoadUser()
                }
            }
        }
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService
    private let gitLabService: GitLabService
    private let keychainService: KeychainService

    // MARK: - Types

    enum StateFilter: String, CaseIterable, Identifiable {
        case open = "opened"
        case closed = "closed"
        case merged = "merged"
        case all = "all"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .open: return "Open"
            case .closed: return "Closed"
            case .merged: return "Merged"
            case .all: return "All"
            }
        }
    }

    // MARK: - Initialization

    init(
        repository: Repository,
        gitService: GitService,
        gitLabService: GitLabService = GitLabService(),
        keychainService: KeychainService = .shared
    ) {
        self.repository = repository
        self.gitService = gitService
        self.gitLabService = gitLabService
        self.keychainService = keychainService

        // Load saved token and host from Keychain
        loadFromKeychain()
    }

    // MARK: - Public Methods

    /// Initializes GitLab connection by detecting if this is a GitLab repo.
    func initialize() async {
        gitlabInfo = await gitLabService.getGitLabInfo(for: repository, gitService: gitService)
        isGitLabRepository = gitlabInfo != nil

        if let info = gitlabInfo, info.host != "gitlab.com" {
            // Update host for self-hosted GitLab
            gitlabHost = info.host
        }

        if isGitLabRepository && !gitlabToken.isEmpty {
            await gitLabService.setAuthToken(gitlabToken)
            await validateAndLoadUser()
        }
    }

    /// Clears the saved token and logs out.
    func logout() {
        gitlabToken = ""
        isAuthenticated = false
        authenticatedUser = nil
        issues = []
        mergeRequests = []
        project = nil

        try? keychainService.delete(for: KeychainAccount.gitlabToken)
    }

    /// Validates the token and loads the authenticated user.
    func validateAndLoadUser() async {
        guard !gitlabToken.isEmpty else {
            isAuthenticated = false
            authenticatedUser = nil
            return
        }

        do {
            authenticatedUser = try await gitLabService.getAuthenticatedUser()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            authenticatedUser = nil
        }
    }

    /// Loads project details.
    func loadProject() async {
        guard let info = gitlabInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            project = try await gitLabService.getProject(path: info.projectPath)
            error = nil
        } catch let gitLabError as GitLabError {
            error = gitLabError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads issues from GitLab.
    func loadIssues() async {
        guard let projectId = project?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let state = stateFilter == .all ? "all" : stateFilter.rawValue
            issues = try await gitLabService.getIssues(
                projectId: projectId,
                state: state
            )
            error = nil
        } catch let gitLabError as GitLabError {
            error = gitLabError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads merge requests from GitLab.
    func loadMergeRequests() async {
        guard let projectId = project?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let state = stateFilter == .all ? "all" : stateFilter.rawValue
            mergeRequests = try await gitLabService.getMergeRequests(
                projectId: projectId,
                state: state
            )
            error = nil
        } catch let gitLabError as GitLabError {
            error = gitLabError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads details for the selected merge request.
    func loadMergeRequestDetails() async {
        guard let projectId = project?.id,
              let mr = selectedMergeRequest else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load notes and pipelines in parallel
            async let notes = gitLabService.getMergeRequestNotes(projectId: projectId, mrIid: mr.iid)
            async let pipelines = gitLabService.getMergeRequestPipelines(projectId: projectId, mrIid: mr.iid)

            selectedMRNotes = try await notes.filter { $0.isUserComment }
            selectedMRPipelines = try await pipelines
            error = nil
        } catch let gitLabError as GitLabError {
            error = gitLabError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads branches for the project.
    func loadBranches() async {
        guard let projectId = project?.id else { return }

        do {
            branches = try await gitLabService.getBranches(projectId: projectId)
            error = nil
        } catch let gitLabError as GitLabError {
            error = gitLabError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Refreshes all data.
    func refresh() async {
        await loadProject()
        await loadIssues()
        await loadMergeRequests()
    }

    // MARK: - Write Operations

    /// Creates a new merge request.
    func createMergeRequest(
        title: String,
        description: String?,
        sourceBranch: String,
        targetBranch: String,
        isDraft: Bool = false
    ) async throws -> GitLabMergeRequest {
        guard let projectId = project?.id else {
            throw GitLabError.notFound
        }

        let mr = try await gitLabService.createMergeRequest(
            projectId: projectId,
            title: title,
            description: description,
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            isDraft: isDraft
        )

        await loadMergeRequests()
        return mr
    }

    /// Merges a merge request.
    func mergeMergeRequest(
        _ mr: GitLabMergeRequest,
        squash: Bool = false,
        removeSourceBranch: Bool = false
    ) async throws {
        guard let projectId = project?.id else {
            throw GitLabError.notFound
        }

        _ = try await gitLabService.mergeMergeRequest(
            projectId: projectId,
            mrIid: mr.iid,
            squash: squash,
            shouldRemoveSourceBranch: removeSourceBranch
        )

        await loadMergeRequests()
    }

    /// Closes a merge request.
    func closeMergeRequest(_ mr: GitLabMergeRequest) async throws {
        guard let projectId = project?.id else {
            throw GitLabError.notFound
        }

        _ = try await gitLabService.closeMergeRequest(projectId: projectId, mrIid: mr.iid)
        await loadMergeRequests()
    }

    /// Adds a comment to a merge request.
    func addComment(to mr: GitLabMergeRequest, body: String) async throws -> GitLabNote {
        guard let projectId = project?.id else {
            throw GitLabError.notFound
        }

        let note = try await gitLabService.addMergeRequestNote(
            projectId: projectId,
            mrIid: mr.iid,
            body: body
        )

        await loadMergeRequestDetails()
        return note
    }

    // MARK: - Browser Actions

    /// Opens the project in the browser.
    func openProjectInBrowser() {
        guard let info = gitlabInfo else { return }
        Task {
            await gitLabService.openInBrowser(projectPath: info.projectPath, host: info.host)
        }
    }

    /// Opens a merge request in the browser.
    func openMergeRequestInBrowser(_ mr: GitLabMergeRequest) {
        guard let info = gitlabInfo else { return }
        Task {
            await gitLabService.openMergeRequestInBrowser(
                projectPath: info.projectPath,
                mrIid: mr.iid,
                host: info.host
            )
        }
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(_ issue: GitLabIssue) {
        guard let info = gitlabInfo else { return }
        Task {
            await gitLabService.openIssueInBrowser(
                projectPath: info.projectPath,
                issueIid: issue.iid,
                host: info.host
            )
        }
    }

    /// Opens the create MR view for a branch.
    func openCreateMergeRequest(from branch: String, to targetBranch: String? = nil) {
        guard let info = gitlabInfo else { return }
        Task {
            let url = await gitLabService.newMergeRequestURL(
                projectPath: info.projectPath,
                sourceBranch: branch,
                targetBranch: targetBranch,
                host: info.host
            )
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the pipelines page in browser.
    func openPipelinesInBrowser() {
        guard let info = gitlabInfo else { return }
        Task {
            await gitLabService.openPipelinesInBrowser(projectPath: info.projectPath, host: info.host)
        }
    }

    // MARK: - Computed Properties

    /// Number of open issues.
    var openIssueCount: Int {
        issues.filter { $0.isOpen }.count
    }

    /// Number of open merge requests.
    var openMRCount: Int {
        mergeRequests.filter { $0.isOpen }.count
    }

    /// Summary text for the current state.
    var statusSummary: String {
        guard isGitLabRepository else {
            return "Not a GitLab repository"
        }

        if !isAuthenticated {
            return "Not authenticated"
        }

        var parts: [String] = []
        if openIssueCount > 0 {
            parts.append("\(openIssueCount) open issues")
        }
        if openMRCount > 0 {
            parts.append("\(openMRCount) open MRs")
        }

        return parts.isEmpty ? "No open items" : parts.joined(separator: ", ")
    }

    // MARK: - Private Keychain Methods

    private func loadFromKeychain() {
        if let savedToken = keychainService.retrieve(for: KeychainAccount.gitlabToken) {
            gitlabToken = savedToken
        }
        if let savedHost = keychainService.retrieve(for: KeychainAccount.gitlabHost) {
            gitlabHost = savedHost
        }
    }

    private func saveTokenToKeychain(_ token: String) {
        if token.isEmpty {
            try? keychainService.delete(for: KeychainAccount.gitlabToken)
        } else {
            do {
                try keychainService.save(token, for: KeychainAccount.gitlabToken)
            } catch {
                print("Failed to save GitLab token to Keychain: \(error.localizedDescription)")
            }
        }
    }

    private func saveHostToKeychain(_ host: String) {
        if host == "gitlab.com" {
            try? keychainService.delete(for: KeychainAccount.gitlabHost)
        } else {
            do {
                try keychainService.save(host, for: KeychainAccount.gitlabHost)
            } catch {
                print("Failed to save GitLab host to Keychain: \(error.localizedDescription)")
            }
        }
    }
}
