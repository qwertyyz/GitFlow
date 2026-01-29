import Foundation

/// View model for git-flow workflow management.
@MainActor
final class GitFlowViewModel: ObservableObject {
    // MARK: - Published State

    /// The current git-flow state.
    @Published private(set) var state: GitFlowState = .notInitialized

    /// Whether git-flow operations are loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether an operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the git-flow state.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await gitService.getGitFlowState(in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Initializes git-flow in the repository.
    func initialize(with config: GitFlowConfig) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.initializeGitFlow(config: config, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Feature Operations

    /// Starts a new feature branch.
    func startFeature(name: String) async {
        guard let config = state.config else {
            error = .unknown(message: "Git-flow not initialized")
            return
        }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.startFeature(name: name, config: config, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Finishes a feature branch.
    func finishFeature(name: String, deleteBranch: Bool = true) async {
        guard let config = state.config else {
            error = .unknown(message: "Git-flow not initialized")
            return
        }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.finishFeature(name: name, config: config, shouldDeleteBranch: deleteBranch, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Release Operations

    /// Starts a new release branch.
    func startRelease(version: String) async {
        guard let config = state.config else {
            error = .unknown(message: "Git-flow not initialized")
            return
        }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.startRelease(version: version, config: config, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Finishes a release branch.
    func finishRelease(version: String, tagMessage: String? = nil, deleteBranch: Bool = true) async {
        guard let config = state.config else {
            error = .unknown(message: "Git-flow not initialized")
            return
        }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.finishRelease(version: version, config: config, tagMessage: tagMessage, deleteBranch: deleteBranch, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Hotfix Operations

    /// Starts a new hotfix branch.
    func startHotfix(version: String) async {
        guard let config = state.config else {
            error = .unknown(message: "Git-flow not initialized")
            return
        }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.startHotfix(version: version, config: config, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Finishes a hotfix branch.
    func finishHotfix(version: String, tagMessage: String? = nil, deleteBranch: Bool = true) async {
        guard let config = state.config else {
            error = .unknown(message: "Git-flow not initialized")
            return
        }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.finishHotfix(version: version, config: config, tagMessage: tagMessage, deleteBranch: deleteBranch, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    /// Whether git-flow is initialized.
    var isInitialized: Bool {
        state.isInitialized
    }

    /// The git-flow configuration if initialized.
    var config: GitFlowConfig? {
        state.config
    }

    /// Whether there are any active feature branches.
    var hasActiveFeatures: Bool {
        !state.activeFeatures.isEmpty
    }

    /// Whether there are any active release branches.
    var hasActiveReleases: Bool {
        !state.activeReleases.isEmpty
    }

    /// Whether there are any active hotfix branches.
    var hasActiveHotfixes: Bool {
        !state.activeHotfixes.isEmpty
    }
}
