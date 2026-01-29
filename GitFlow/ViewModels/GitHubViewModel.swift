import Foundation
import AppKit

/// View model for GitHub integration features.
@MainActor
final class GitHubViewModel: ObservableObject {
    // MARK: - Published State

    /// GitHub repository info extracted from remotes.
    @Published private(set) var githubInfo: GitHubRemoteInfo?

    /// Alias for githubInfo for API compatibility.
    var remoteInfo: GitHubRemoteInfo? { githubInfo }

    /// Whether this repository is connected to GitHub.
    @Published private(set) var isGitHubRepository: Bool = false

    /// The authenticated GitHub user.
    @Published private(set) var authenticatedUser: GitHubUser?

    /// Whether we're authenticated.
    @Published var isAuthenticated: Bool = false

    /// Current issues (excluding PRs).
    @Published private(set) var issues: [GitHubIssue] = []

    /// Current pull requests.
    @Published private(set) var pullRequests: [GitHubPullRequest] = []

    /// Selected pull request for detailed view.
    @Published var selectedPullRequest: GitHubPullRequest?

    /// Reviews for the selected PR.
    @Published private(set) var selectedPRReviews: [GitHubReview] = []

    /// Comments for the selected PR.
    @Published private(set) var selectedPRComments: [GitHubComment] = []

    /// Check runs for the selected PR.
    @Published private(set) var selectedPRChecks: [GitHubCheckRun] = []

    /// Whether data is loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitHubError?

    /// Filter for issues/PRs state.
    @Published var stateFilter: StateFilter = .open

    /// The GitHub token, securely stored in Keychain.
    /// Setting this value automatically persists it to the Keychain.
    @Published var githubToken: String = "" {
        didSet {
            // Persist token to Keychain whenever it changes
            saveTokenToKeychain(githubToken)

            Task {
                await githubService.setAuthToken(githubToken.isEmpty ? nil : githubToken)
                await validateAndLoadUser()
            }
        }
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService
    /// The GitHub service for API calls.
    let githubService: GitHubService
    private let keychainService: KeychainService

    // MARK: - Types

    enum StateFilter: String, CaseIterable, Identifiable {
        case open = "open"
        case closed = "closed"
        case all = "all"

        var id: String { rawValue }

        var displayName: String {
            rawValue.capitalized
        }
    }

    // MARK: - Initialization

    init(
        repository: Repository,
        gitService: GitService,
        githubService: GitHubService = GitHubService(),
        keychainService: KeychainService = .shared
    ) {
        self.repository = repository
        self.gitService = gitService
        self.githubService = githubService
        self.keychainService = keychainService

        // Load saved token from Keychain on initialization
        loadTokenFromKeychain()
    }

    // MARK: - Public Methods

    /// Initializes GitHub connection by detecting if this is a GitHub repo.
    func initialize() async {
        githubInfo = await githubService.getGitHubInfo(for: repository, gitService: gitService)
        isGitHubRepository = githubInfo != nil

        if isGitHubRepository && !githubToken.isEmpty {
            // Set the token on the service (it was loaded from Keychain in init)
            await githubService.setAuthToken(githubToken)
            await validateAndLoadUser()
        }
    }

    /// Clears the saved token and logs out.
    /// Removes the token from both memory and Keychain.
    func logout() {
        githubToken = ""
        isAuthenticated = false
        authenticatedUser = nil
        issues = []
        pullRequests = []

        // Clear from Keychain
        try? keychainService.delete(for: KeychainAccount.githubToken)
    }

    /// Validates the token and loads the authenticated user.
    func validateAndLoadUser() async {
        guard !githubToken.isEmpty else {
            isAuthenticated = false
            authenticatedUser = nil
            return
        }

        do {
            authenticatedUser = try await githubService.getAuthenticatedUser()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            authenticatedUser = nil
        }
    }

    /// Loads issues from GitHub.
    func loadIssues() async {
        guard let info = githubInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let allIssues = try await githubService.getIssues(
                owner: info.owner,
                repo: info.repo,
                state: stateFilter.rawValue
            )
            // Filter out PRs (GitHub API returns both)
            issues = allIssues.filter { !$0.isPullRequest }
            error = nil
        } catch let gitHubError as GitHubError {
            error = gitHubError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads pull requests from GitHub.
    func loadPullRequests() async {
        guard let info = githubInfo else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            pullRequests = try await githubService.getPullRequests(
                owner: info.owner,
                repo: info.repo,
                state: stateFilter.rawValue
            )
            error = nil
        } catch let gitHubError as GitHubError {
            error = gitHubError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Loads details for the selected pull request.
    func loadPullRequestDetails() async {
        guard let info = githubInfo,
              let pr = selectedPullRequest else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load reviews, comments, and checks in parallel
            async let reviews = githubService.getReviews(owner: info.owner, repo: info.repo, pullNumber: pr.number)
            async let comments = githubService.getComments(owner: info.owner, repo: info.repo, pullNumber: pr.number)
            async let checks = githubService.getCheckRuns(owner: info.owner, repo: info.repo, ref: pr.head.sha)

            selectedPRReviews = try await reviews
            selectedPRComments = try await comments
            selectedPRChecks = try await checks
            error = nil
        } catch let gitHubError as GitHubError {
            error = gitHubError
        } catch {
            self.error = .invalidResponse
        }
    }

    /// Refreshes all data.
    func refresh() async {
        await loadIssues()
        await loadPullRequests()
    }

    // MARK: - Browser Actions

    /// Opens the repository in the browser.
    func openRepositoryInBrowser() {
        guard let info = githubInfo else { return }
        Task {
            await githubService.openInBrowser(owner: info.owner, repo: info.repo)
        }
    }

    /// Opens a pull request in the browser.
    func openPullRequestInBrowser(_ pr: GitHubPullRequest) {
        guard let info = githubInfo else { return }
        Task {
            await githubService.openPullRequestInBrowser(owner: info.owner, repo: info.repo, number: pr.number)
        }
    }

    /// Opens an issue in the browser.
    func openIssueInBrowser(_ issue: GitHubIssue) {
        guard let info = githubInfo else { return }
        Task {
            await githubService.openIssueInBrowser(owner: info.owner, repo: info.repo, number: issue.number)
        }
    }

    /// Opens the compare view for creating a new PR.
    func openCreatePullRequest(from branch: String, to baseBranch: String? = nil) {
        guard let info = githubInfo else { return }
        Task {
            if let base = baseBranch {
                await githubService.openCompareInBrowser(owner: info.owner, repo: info.repo, base: base, head: branch)
            } else {
                let url = await githubService.newPullRequestURL(owner: info.owner, repo: info.repo, head: branch)
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Opens the Actions page in browser.
    func openActionsInBrowser() {
        guard let info = githubInfo else { return }
        Task {
            await githubService.openActionsInBrowser(owner: info.owner, repo: info.repo)
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
        guard isGitHubRepository else {
            return "Not a GitHub repository"
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

    /// Loads the GitHub token from Keychain.
    /// Called during initialization to restore the saved token.
    private func loadTokenFromKeychain() {
        if let savedToken = keychainService.retrieve(for: KeychainAccount.githubToken) {
            // Set without triggering didSet to avoid double-saving
            // We'll set the service token in initialize()
            githubToken = savedToken
        }
    }

    /// Saves the GitHub token to Keychain.
    /// Called whenever the token changes.
    ///
    /// - Parameter token: The token to save. If empty, deletes the stored token.
    private func saveTokenToKeychain(_ token: String) {
        if token.isEmpty {
            // Remove token from Keychain when cleared
            try? keychainService.delete(for: KeychainAccount.githubToken)
        } else {
            // Save or update token in Keychain
            do {
                try keychainService.save(token, for: KeychainAccount.githubToken)
            } catch {
                // Log error but don't fail - token still works in memory
                print("Failed to save GitHub token to Keychain: \(error.localizedDescription)")
            }
        }
    }
}
