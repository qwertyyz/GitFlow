import SwiftUI
import AppKit

/// Global application state container.
/// Manages the currently open repository and application-wide settings.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    /// The currently open repository, if any.
    @Published private(set) var currentRepository: Repository?

    /// The view model for the current repository.
    @Published private(set) var repositoryViewModel: RepositoryViewModel?

    /// List of recently opened repository paths.
    @Published private(set) var recentRepositories: [URL] = []

    /// Whether the app is currently loading a repository.
    @Published private(set) var isLoading: Bool = false

    /// Current error to display, if any.
    @Published var currentError: GitError?

    // MARK: - UI State for Menu Commands

    /// Whether to show the command palette.
    @Published var showCommandPalette: Bool = false

    /// Whether to focus the commit message input.
    @Published var focusCommitMessage: Bool = false

    /// Whether to show the create stash sheet.
    @Published var showCreateStash: Bool = false

    /// Whether to show the new branch sheet.
    @Published var showNewBranch: Bool = false

    /// Whether to show the switch branch sheet.
    @Published var showSwitchBranch: Bool = false

    /// Whether to show the merge branch sheet.
    @Published var showMergeBranch: Bool = false

    /// Whether to show the rebase branch sheet.
    @Published var showRebaseBranch: Bool = false

    /// Whether to show the diff search.
    @Published var showDiffSearch: Bool = false

    /// Selected sidebar item for navigation.
    @Published var selectedSidebarItem: SidebarSection? = nil

    // MARK: - Stash UI State

    /// Whether to show the apply stash sheet.
    @Published var showApplyStash: Bool = false

    /// Whether to show the create snapshot sheet.
    @Published var showCreateSnapshot: Bool = false

    // MARK: - Git-Flow UI State

    /// Whether git-flow is initialized in the current repository.
    @Published var isGitFlowInitialized: Bool = false

    /// Whether to show the git-flow init sheet.
    @Published var showGitFlowInit: Bool = false

    /// Whether to show the start feature sheet.
    @Published var showGitFlowStartFeature: Bool = false

    /// Whether to show the finish feature sheet.
    @Published var showGitFlowFinishFeature: Bool = false

    /// Whether to show the start release sheet.
    @Published var showGitFlowStartRelease: Bool = false

    /// Whether to show the finish release sheet.
    @Published var showGitFlowFinishRelease: Bool = false

    /// Whether to show the start hotfix sheet.
    @Published var showGitFlowStartHotfix: Bool = false

    /// Whether to show the finish hotfix sheet.
    @Published var showGitFlowFinishHotfix: Bool = false

    // MARK: - Help UI State

    /// Whether to show the documentation view.
    @Published var showDocumentation: Bool = false

    /// Whether to show the keyboard shortcuts view.
    @Published var showKeyboardShortcuts: Bool = false

    /// Whether to show the video tutorials view.
    @Published var showVideoTutorials: Bool = false

    /// Whether to show the learn git view.
    @Published var showLearnGit: Bool = false

    /// Whether to show the what's new dialog.
    @Published var showWhatsNew: Bool = false

    /// Whether to show the getting started guide.
    @Published var showGettingStarted: Bool = false

    // MARK: - Services

    private let recentRepositoriesStore = RecentRepositoriesStore()
    private let gitService = GitService()

    // MARK: - Initialization

    init() {
        loadRecentRepositories()
    }

    // MARK: - Repository Management

    /// Opens a repository at the specified path.
    /// - Parameter url: The URL to the repository root directory.
    func openRepository(at url: URL) {
        Task {
            await performOpenRepository(at: url)
        }
    }

    /// Shows the system open panel to select a repository directory.
    func showOpenRepositoryPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository folder"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openRepository(at: url)
        }
    }

    /// Closes the currently open repository.
    func closeRepository() {
        currentRepository = nil
        repositoryViewModel = nil
    }

    // MARK: - Recent Repositories

    /// Clears the list of recent repositories.
    func clearRecentRepositories() {
        recentRepositories = []
        recentRepositoriesStore.clear()
    }

    // MARK: - Private Methods

    private func performOpenRepository(at url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Validate that this is a Git repository
            let isRepo = try await gitService.isGitRepository(at: url)
            guard isRepo else {
                currentError = .notARepository(path: url.path)
                return
            }

            // Create repository model
            let repository = Repository(rootURL: url)
            currentRepository = repository

            // Create view model and load initial data
            let viewModel = RepositoryViewModel(repository: repository, gitService: gitService)
            repositoryViewModel = viewModel

            // Add to recent repositories
            addToRecentRepositories(url)

            // Perform initial refresh
            await viewModel.refresh()

        } catch let error as GitError {
            currentError = error
        } catch {
            currentError = .unknown(message: error.localizedDescription)
        }
    }

    private func addToRecentRepositories(_ url: URL) {
        // Remove if already exists to move to front
        recentRepositories.removeAll { $0 == url }

        // Add to front
        recentRepositories.insert(url, at: 0)

        // Keep only last 10
        if recentRepositories.count > 10 {
            recentRepositories = Array(recentRepositories.prefix(10))
        }

        // Persist
        recentRepositoriesStore.save(recentRepositories)
    }

    private func loadRecentRepositories() {
        recentRepositories = recentRepositoriesStore.load()
    }
}
