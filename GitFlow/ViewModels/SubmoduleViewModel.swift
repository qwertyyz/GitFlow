import Foundation

/// View model for submodule operations.
@MainActor
final class SubmoduleViewModel: ObservableObject {
    // MARK: - Published State

    /// All submodules in the repository.
    @Published private(set) var submodules: [Submodule] = []

    /// The currently selected submodule.
    @Published var selectedSubmodule: Submodule?

    /// Whether submodules are currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether an operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Diff content for the selected submodule.
    @Published private(set) var selectedSubmoduleDiff: String = ""

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the submodule list.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            submodules = try await gitService.getSubmodules(in: repository)
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Initializes all submodules.
    func initializeAll() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.initSubmodules(recursive: true, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Updates all submodules.
    func updateAll(remote: Bool = false) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.updateSubmodules(recursive: true, init_: true, remote: remote, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Updates a specific submodule.
    func updateSubmodule(_ submodule: Submodule, remote: Bool = false) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.updateSubmodules(
                recursive: true,
                init_: true,
                remote: remote,
                paths: [submodule.path],
                in: repository
            )
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Deinitializes a submodule.
    func deinitSubmodule(_ submodule: Submodule, force: Bool = false) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.deinitSubmodule(path: submodule.path, force: force, in: repository)
            await refresh()
            if selectedSubmodule?.path == submodule.path {
                selectedSubmodule = nil
            }
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Syncs submodule URLs.
    func syncAll() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.syncSubmodules(recursive: true, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Loads the diff for a submodule.
    func loadSubmoduleDiff(_ submodule: Submodule) async {
        do {
            selectedSubmoduleDiff = try await gitService.getSubmoduleDiff(path: submodule.path, in: repository)
        } catch {
            selectedSubmoduleDiff = ""
        }
    }

    /// Checks out a specific commit in a submodule.
    func checkoutCommit(_ commit: String, in submodule: Submodule) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.checkoutSubmoduleCommit(commit, path: submodule.path, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Adds a new submodule.
    func addSubmodule(url: String, path: String, branch: String?) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.addSubmodule(url: url, path: path, branch: branch, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    /// Whether there are any submodules.
    var hasSubmodules: Bool {
        !submodules.isEmpty
    }

    /// Number of uninitialized submodules.
    var uninitializedCount: Int {
        submodules.filter { !$0.isInitialized }.count
    }

    /// Number of out-of-date submodules.
    var outOfDateCount: Int {
        submodules.filter { $0.status == .outOfDate }.count
    }

    /// Number of modified submodules.
    var modifiedCount: Int {
        submodules.filter { $0.status == .modified }.count
    }

    /// Summary string for submodule status.
    var statusSummary: String {
        var parts: [String] = []

        if uninitializedCount > 0 {
            parts.append("\(uninitializedCount) uninitialized")
        }
        if outOfDateCount > 0 {
            parts.append("\(outOfDateCount) out of date")
        }
        if modifiedCount > 0 {
            parts.append("\(modifiedCount) modified")
        }

        if parts.isEmpty {
            return "All up to date"
        }

        return parts.joined(separator: ", ")
    }
}
