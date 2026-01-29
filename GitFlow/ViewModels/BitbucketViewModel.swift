import Foundation
import AppKit

/// View model for Bitbucket integration features.
@MainActor
final class BitbucketViewModel: ObservableObject {
    // MARK: - Published State

    /// Bitbucket repository info extracted from remotes.
    @Published private(set) var bitbucketInfo: BitbucketRemoteInfo?

    /// Whether this repository is connected to Bitbucket.
    @Published private(set) var isBitbucketRepository: Bool = false

    /// The authenticated Bitbucket user.
    @Published private(set) var authenticatedUser: BitbucketUser?

    /// Whether we're authenticated.
    @Published var isAuthenticated: Bool = false

    /// Current issues.
    @Published private(set) var issues: [BitbucketIssue] = []

    /// Current pull requests.
    @Published private(set) var pullRequests: [BitbucketPullRequest] = []

    /// Selected pull request for detailed view.
    @Published var selectedPullRequest: BitbucketPullRequest?

    /// Comments for the selected PR.
    @Published private(set) var selectedPRComments: [BitbucketComment] = []

    /// The repository details.
    @Published private(set) var bitbucketRepository: BitbucketRepository?

    /// Available branches for the repository.
    @Published private(set) var branches: [BitbucketBranch] = []

    /// Whether data is loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: BitbucketError?

    /// Filter for issues/PRs state.
    @Published var stateFilter: StateFilter = .open

    /// The Bitbucket username.
    @Published var bitbucketUsername: String = "" {
        didSet {
            saveCredentialsToKeychain()
            Task {
                await bitbucketService.setCredentials(
                    username: bitbucketUsername.isEmpty ? nil : bitbucketUsername,
                    appPassword: bitbucketAppPassword.isEmpty ? nil : bitbucketAppPassword
                )
                if !bitbucketUsername.isEmpty && !bitbucketAppPassword.isEmpty {
                    await validateAndLoadUser()
                }
            }
        }
    }

    /// The Bitbucket app password.
    @Published var bitbucketAppPassword: String = "" {
        didSet {
            saveCredentialsToKeychain()
            Task {
                await bitbucketService.setCredentials(
                    username: bitbucketUsername.isEmpty ? nil : bitbucketUsername,
                    appPassword: bitbucketAppPassword.isEmpty ? nil : bitbucketAppPassword
                )
                if !bitbucketUsername.isEmpty && !bitbucketAppPassword.isEmpty {
                    await validateAndLoadUser()
                }
            }
        }
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService
    private let bitbucketService: BitbucketService
    private let keychainService: KeychainService

    // MARK: - Types

    enum StateFilter: String, CaseIterable, Identifiable {
        case open = "OPEN"
        case merged = "MERGED"
        case declined = "DECLINED"
        case all = "all"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .open: return "Open"
            case .merged: return "Merged"
            case .declined: return "Declined"
            case .all: return "All"
            }
        }
    }

    // MARK: - Initialization

    init(
        repository: Repository,
        gitService: GitService,
        bitbucketService: BitbucketService = BitbucketService(),
        keychainService: KeychainService = .shared
    ) {
        self.repository = repository
        self.gitService = gitService
        self.bitbucketService = bitbucketService
        self.keychainService = keychainService

        // Load saved credentials from Keychain
        loadCredentialsFromKeychain()
    }

    // MARK: - Public Methods

    /// Initializes Bitbucket connection by detecting if this is a Bitbucket repo.
    func initialize() async {
        bitbucketInfo = await bitbucketService.getBitbucketInfo(for: repository, gitService: gitService)
        isBitbucketRepository = bitbucketInfo != nil

        if isBitbucketRepository && !bitbucketUsername.isEmpty && !bitbucketAppPassword.isEmpty {
            await bitbucketService.setCredentials(username: bitbucketUsername, appPassword: bitbucketAppPassword)
            await validateAndLoadUser()
        }
    }

    /// Clears the saved credentials and logs out.
    func logout() {
        bitbucketUsername = ""
        bitbucketAppPassword = ""
        isAuthenticated = false
        authenticatedUser = nil
        issues = []
        pullRequests = []
        bitbucketRepository = nil

        try? keychainService.delete(for: KeychainAccount.bitbucketToken)
    }

    /// Validates the credentials and loads the authenticated user.
    func validateAndLoadUser() async {
        guard !bitbucketUsername.isEmpty && !bitbucketAppPassword.isEmpty else {
            isAuthenticated = false
            authenticatedUser = nil
            return
        }

        do {
            authenticatedUser = try await bitbucketService.getAuthenticatedUser()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            authenticatedUser = nil
        }
    }

    /// Loads repository details.
    func loadRepository() async {
        guard let info = bitbucketInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            bitbucketRepository = try await bitbucketService.getRepository(
                workspace: info.workspace,
                repoSlug: info.repoSlug
            )
            error = nil
        } catch let bitbucketError as BitbucketError {
            error = bitbucketError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads issues from Bitbucket.
    func loadIssues() async {
        guard let info = bitbucketInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let state: String? = stateFilter == .all ? nil : stateFilter.rawValue.lowercased()
            issues = try await bitbucketService.getIssues(
                workspace: info.workspace,
                repoSlug: info.repoSlug,
                state: state
            )
            error = nil
        } catch let bitbucketError as BitbucketError {
            error = bitbucketError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads pull requests from Bitbucket.
    func loadPullRequests() async {
        guard let info = bitbucketInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let state = stateFilter == .all ? "OPEN" : stateFilter.rawValue
            pullRequests = try await bitbucketService.getPullRequests(
                workspace: info.workspace,
                repoSlug: info.repoSlug,
                state: state
            )

            // If showing all, also fetch merged and declined
            if stateFilter == .all {
                let merged = try await bitbucketService.getPullRequests(
                    workspace: info.workspace,
                    repoSlug: info.repoSlug,
                    state: "MERGED"
                )
                let declined = try await bitbucketService.getPullRequests(
                    workspace: info.workspace,
                    repoSlug: info.repoSlug,
                    state: "DECLINED"
                )
                pullRequests = pullRequests + merged + declined
            }

            error = nil
        } catch let bitbucketError as BitbucketError {
            error = bitbucketError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads details for the selected pull request.
    func loadPullRequestDetails() async {
        guard let info = bitbucketInfo,
              let pr = selectedPullRequest else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            selectedPRComments = try await bitbucketService.getPullRequestComments(
                workspace: info.workspace,
                repoSlug: info.repoSlug,
                prId: pr.id
            )
            error = nil
        } catch let bitbucketError as BitbucketError {
            error = bitbucketError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads branches for the repository.
    func loadBranches() async {
        guard let info = bitbucketInfo else { return }

        do {
            branches = try await bitbucketService.getBranches(
                workspace: info.workspace,
                repoSlug: info.repoSlug
            )
            error = nil
        } catch let bitbucketError as BitbucketError {
            error = bitbucketError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Refreshes all data.
    func refresh() async {
        await loadRepository()
        await loadIssues()
        await loadPullRequests()
    }

    // MARK: - Write Operations

    /// Creates a new pull request.
    func createPullRequest(
        title: String,
        description: String?,
        sourceBranch: String,
        destinationBranch: String,
        closeSourceBranch: Bool = false
    ) async throws -> BitbucketPullRequest {
        guard let info = bitbucketInfo else {
            throw BitbucketError.notFound
        }

        let pr = try await bitbucketService.createPullRequest(
            workspace: info.workspace,
            repoSlug: info.repoSlug,
            title: title,
            description: description,
            sourceBranch: sourceBranch,
            destinationBranch: destinationBranch,
            closeSourceBranch: closeSourceBranch
        )

        await loadPullRequests()
        return pr
    }

    /// Merges a pull request.
    func mergePullRequest(
        _ pr: BitbucketPullRequest,
        strategy: String = "merge_commit",
        closeSourceBranch: Bool = false
    ) async throws {
        guard let info = bitbucketInfo else {
            throw BitbucketError.notFound
        }

        _ = try await bitbucketService.mergePullRequest(
            workspace: info.workspace,
            repoSlug: info.repoSlug,
            prId: pr.id,
            mergeStrategy: strategy,
            closeSourceBranch: closeSourceBranch
        )

        await loadPullRequests()
    }

    /// Declines (closes) a pull request.
    func declinePullRequest(_ pr: BitbucketPullRequest) async throws {
        guard let info = bitbucketInfo else {
            throw BitbucketError.notFound
        }

        _ = try await bitbucketService.declinePullRequest(
            workspace: info.workspace,
            repoSlug: info.repoSlug,
            prId: pr.id
        )

        await loadPullRequests()
    }

    /// Approves a pull request.
    func approvePullRequest(_ pr: BitbucketPullRequest) async throws {
        guard let info = bitbucketInfo else {
            throw BitbucketError.notFound
        }

        try await bitbucketService.approvePullRequest(
            workspace: info.workspace,
            repoSlug: info.repoSlug,
            prId: pr.id
        )
    }

    /// Adds a comment to a pull request.
    func addComment(to pr: BitbucketPullRequest, content: String) async throws -> BitbucketComment {
        guard let info = bitbucketInfo else {
            throw BitbucketError.notFound
        }

        let comment = try await bitbucketService.addPullRequestComment(
            workspace: info.workspace,
            repoSlug: info.repoSlug,
            prId: pr.id,
            content: content
        )

        await loadPullRequestDetails()
        return comment
    }

    // MARK: - Browser Actions

    /// Opens the repository in the browser.
    func openRepositoryInBrowser() {
        guard let info = bitbucketInfo else { return }
        Task {
            await bitbucketService.openInBrowser(workspace: info.workspace, repoSlug: info.repoSlug)
        }
    }

    /// Opens a pull request in the browser.
    func openPullRequestInBrowser(_ pr: BitbucketPullRequest) {
        guard let info = bitbucketInfo else { return }
        Task {
            await bitbucketService.openPullRequestInBrowser(
                workspace: info.workspace,
                repoSlug: info.repoSlug,
                prId: pr.id
            )
        }
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(_ issue: BitbucketIssue) {
        guard let info = bitbucketInfo else { return }
        Task {
            await bitbucketService.openIssueInBrowser(
                workspace: info.workspace,
                repoSlug: info.repoSlug,
                issueId: issue.id
            )
        }
    }

    /// Opens the create PR view for a branch.
    func openCreatePullRequest(from branch: String, to destinationBranch: String? = nil) {
        guard let info = bitbucketInfo else { return }
        Task {
            let url = await bitbucketService.newPullRequestURL(
                workspace: info.workspace,
                repoSlug: info.repoSlug,
                sourceBranch: branch,
                destinationBranch: destinationBranch
            )
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the pipelines page in browser.
    func openPipelinesInBrowser() {
        guard let info = bitbucketInfo else { return }
        Task {
            await bitbucketService.openPipelinesInBrowser(workspace: info.workspace, repoSlug: info.repoSlug)
        }
    }

    // MARK: - Computed Properties

    /// Number of open issues.
    var openIssueCount: Int {
        issues.filter { $0.isOpen }.count
    }

    /// Number of open pull requests.
    var openPRCount: Int {
        pullRequests.filter { $0.isOpen }.count
    }

    /// Summary text for the current state.
    var statusSummary: String {
        guard isBitbucketRepository else {
            return "Not a Bitbucket repository"
        }

        if !isAuthenticated {
            return "Not authenticated"
        }

        var parts: [String] = []
        if openIssueCount > 0 {
            parts.append("\(openIssueCount) open issues")
        }
        if openPRCount > 0 {
            parts.append("\(openPRCount) open PRs")
        }

        return parts.isEmpty ? "No open items" : parts.joined(separator: ", ")
    }

    // MARK: - Private Keychain Methods

    private func loadCredentialsFromKeychain() {
        // Bitbucket credentials are stored as "username:appPassword"
        if let savedCredentials = keychainService.retrieve(for: KeychainAccount.bitbucketToken) {
            let parts = savedCredentials.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                bitbucketUsername = String(parts[0])
                bitbucketAppPassword = String(parts[1])
            }
        }
    }

    private func saveCredentialsToKeychain() {
        if bitbucketUsername.isEmpty || bitbucketAppPassword.isEmpty {
            try? keychainService.delete(for: KeychainAccount.bitbucketToken)
        } else {
            let credentials = "\(bitbucketUsername):\(bitbucketAppPassword)"
            do {
                try keychainService.save(credentials, for: KeychainAccount.bitbucketToken)
            } catch {
                print("Failed to save Bitbucket credentials to Keychain: \(error.localizedDescription)")
            }
        }
    }
}
