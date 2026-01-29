import Foundation

/// View model for branch operations.
@MainActor
final class BranchViewModel: ObservableObject {
    // MARK: - Published State

    /// All branches (local and remote).
    @Published private(set) var branches: [Branch] = []

    /// Local branches only.
    @Published private(set) var localBranches: [Branch] = []

    /// Remote branches only.
    @Published private(set) var remoteBranches: [Branch] = []

    /// The current branch.
    @Published private(set) var currentBranch: Branch?

    /// The currently selected branch for viewing.
    @Published var selectedBranch: Branch?

    /// Whether branches are currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether a branch operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Whether to show remote branches.
    @Published var showRemoteBranches: Bool = true

    /// Current repository state (merge/rebase in progress).
    @Published private(set) var repositoryState: RepositoryState = RepositoryState()

    /// Commits unique to the compare branch (for branch comparison).
    @Published private(set) var comparisonCommits: [Commit] = []

    /// File diffs between compared branches.
    @Published private(set) var comparisonDiffs: [FileDiff] = []

    // MARK: - Dependencies

    let repository: Repository
    let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the branch list.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            branches = try await gitService.getBranches(in: repository, includeRemote: true)
            localBranches = branches.filter { !$0.isRemote }
            remoteBranches = branches.filter { $0.isRemote }
            currentBranch = branches.first { $0.isCurrent }
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Checks out the specified branch.
    func checkout(branchName: String) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.checkout(branch: branchName, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Checks out the specified branch object.
    func checkout(branch: Branch) async {
        await checkout(branchName: branch.name)
    }

    /// Creates a new branch and checks it out.
    func createBranch(name: String, startPoint: String? = nil) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.createBranch(name: name, startPoint: startPoint, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Deletes a branch.
    func deleteBranch(name: String, force: Bool = false) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.deleteBranch(name: name, force: force, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Selects a branch for viewing.
    func selectBranch(_ branch: Branch) {
        selectedBranch = branch
    }

    // MARK: - Branch Rename Operations

    /// Renames a local branch.
    func renameBranch(oldName: String, newName: String) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.renameBranch(oldName: oldName, newName: newName, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Renames a branch on both local and remote.
    func renameBranchOnRemote(oldName: String, newName: String, remoteName: String = "origin") async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.renameBranchOnRemote(
                oldName: oldName,
                newName: newName,
                remoteName: remoteName,
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

    // MARK: - Upstream Operations

    /// Sets the upstream tracking branch.
    func setUpstream(branchName: String, upstreamRef: String) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.setUpstream(branchName: branchName, upstreamRef: upstreamRef, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unsets the upstream tracking branch.
    func unsetUpstream(branchName: String) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.unsetUpstream(branchName: branchName, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Merge Operations

    /// Merges a branch into the current branch.
    func merge(branchName: String, mergeType: MergeType = .normal, message: String? = nil) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.merge(branchName: branchName, mergeType: mergeType, message: message, in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
            await refreshRepositoryState()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            await refreshRepositoryState()
        }
    }

    /// Aborts a merge in progress.
    func abortMerge() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.abortMerge(in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Continues a merge after conflicts have been resolved.
    func continueMerge() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.continueMerge(in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Rebase Operations

    /// Rebases the current branch onto another branch.
    func rebase(ontoBranch: String) async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.rebase(ontoBranch: ontoBranch, in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
            await refreshRepositoryState()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            await refreshRepositoryState()
        }
    }

    /// Aborts a rebase in progress.
    func abortRebase() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.abortRebase(in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Continues a rebase after conflicts have been resolved.
    func continueRebase() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.continueRebase(in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Skips the current commit during rebase.
    func skipRebase() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.skipRebase(in: repository)
            await refresh()
            await refreshRepositoryState()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Branch Comparison

    /// Compares two branches and loads the commit and file diffs.
    func compareBranches(base: String, compare: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let commits = gitService.getBranchCommitDiff(
                baseBranch: base,
                compareBranch: compare,
                in: repository
            )
            async let diffs = gitService.getBranchDiff(
                baseBranch: base,
                compareBranch: compare,
                in: repository
            )

            comparisonCommits = try await commits
            comparisonDiffs = try await diffs
            error = nil
        } catch let gitError as GitError {
            error = gitError
            comparisonCommits = []
            comparisonDiffs = []
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            comparisonCommits = []
            comparisonDiffs = []
        }
    }

    /// Clears the branch comparison results.
    func clearComparison() {
        comparisonCommits = []
        comparisonDiffs = []
    }

    // MARK: - Repository State

    /// Refreshes the repository state (merge/rebase status).
    func refreshRepositoryState() async {
        do {
            repositoryState = try await gitService.getRepositoryState(in: repository)
        } catch {
            // Silently fail, keep previous state
        }
    }

    // MARK: - Computed Properties

    /// Branches to display based on filter settings.
    var displayBranches: [Branch] {
        if showRemoteBranches {
            return branches
        }
        return localBranches
    }

    /// Local branch count.
    var localBranchCount: Int {
        localBranches.count
    }

    /// Remote branch count.
    var remoteBranchCount: Int {
        remoteBranches.count
    }

    /// The current branch name.
    var currentBranchName: String? {
        currentBranch?.name
    }

    /// Whether the current branch is ahead of upstream.
    var isAhead: Bool {
        (currentBranch?.ahead ?? 0) > 0
    }

    /// Whether the current branch is behind upstream.
    var isBehind: Bool {
        (currentBranch?.behind ?? 0) > 0
    }

    /// Summary of ahead/behind status.
    var syncStatus: String? {
        guard let branch = currentBranch, branch.upstream != nil else { return nil }

        if branch.ahead > 0 && branch.behind > 0 {
            return "↑\(branch.ahead) ↓\(branch.behind)"
        } else if branch.ahead > 0 {
            return "↑\(branch.ahead)"
        } else if branch.behind > 0 {
            return "↓\(branch.behind)"
        }
        return nil
    }

    /// Number of commits the current branch is ahead of upstream.
    var currentBranchAhead: Int {
        currentBranch?.ahead ?? 0
    }

    /// Number of commits the current branch is behind upstream.
    var currentBranchBehind: Int {
        currentBranch?.behind ?? 0
    }

    // MARK: - Branch Review Properties

    /// Branches that haven't been updated recently (stale).
    var staleBranches: [Branch] {
        let staleDays: TimeInterval = 30 * 24 * 60 * 60 // 30 days
        let staleDate = Date().addingTimeInterval(-staleDays)

        return localBranches.filter { branch in
            guard let lastCommitDate = branch.lastCommitDate else { return false }
            return lastCommitDate < staleDate && !branch.isCurrent
        }
    }

    /// Branches that have been merged into the main branch.
    var mergedBranches: [Branch] {
        // This would require checking merge status
        // For now, return empty - would be populated after checking git branch --merged
        return localBranches.filter { $0.isMerged && !$0.isCurrent }
    }

    /// Archived branches (stored locally, hidden from main list).
    @Published private(set) var archivedBranches: [Branch] = []

    // MARK: - Archive Operations

    /// Archives a branch (hides it from the main list).
    func archiveBranch(_ branchName: String) async {
        guard let branch = localBranches.first(where: { $0.name == branchName }) else { return }

        // Store in archived list
        archivedBranches.append(branch)

        // Persist to UserDefaults
        saveArchivedBranches()
    }

    /// Unarchives a branch (restores it to the main list).
    func unarchiveBranch(_ branchName: String) async {
        archivedBranches.removeAll { $0.name == branchName }

        // Persist to UserDefaults
        saveArchivedBranches()
    }

    /// Loads archived branches from UserDefaults.
    func loadArchivedBranches() {
        if let data = UserDefaults.standard.data(forKey: "archivedBranches.\(repository.path)"),
           let names = try? JSONDecoder().decode([String].self, from: data) {
            archivedBranches = localBranches.filter { names.contains($0.name) }
        }
    }

    /// Saves archived branches to UserDefaults.
    private func saveArchivedBranches() {
        let names = archivedBranches.map { $0.name }
        if let data = try? JSONEncoder().encode(names) {
            UserDefaults.standard.set(data, forKey: "archivedBranches.\(repository.path)")
        }
    }

    /// Branches excluding archived ones.
    var visibleLocalBranches: [Branch] {
        let archivedNames = Set(archivedBranches.map { $0.name })
        return localBranches.filter { !archivedNames.contains($0.name) }
    }
}
