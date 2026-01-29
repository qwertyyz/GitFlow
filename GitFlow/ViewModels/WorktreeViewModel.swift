import Foundation
import SwiftUI

/// View model for managing Git worktrees.
@MainActor
final class WorktreeViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var worktrees: [Worktree] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedWorktree: Worktree?

    // Create worktree sheet state
    @Published var showingCreateSheet = false
    @Published var newWorktreePath = ""
    @Published var newWorktreeBranch = ""
    @Published var createNewBranch = true
    @Published var baseBranch = ""
    @Published var detachHead = false
    @Published var lockAfterCreate = false
    @Published var lockReason = ""

    // Remove worktree confirmation
    @Published var showingRemoveConfirmation = false
    @Published var worktreeToRemove: Worktree?
    @Published var forceRemove = false

    // Lock/unlock sheet
    @Published var showingLockSheet = false
    @Published var worktreeToLock: Worktree?
    @Published var lockReasonInput = ""

    // Move worktree sheet
    @Published var showingMoveSheet = false
    @Published var worktreeToMove: Worktree?
    @Published var newPath = ""
    @Published var forceMove = false

    // MARK: - Private Properties

    private let gitService: GitService
    private var repository: Repository?

    // MARK: - Initialization

    init(gitService: GitService = GitService()) {
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Sets the repository to work with.
    func setRepository(_ repository: Repository) {
        self.repository = repository
        Task {
            await loadWorktrees()
        }
    }

    /// Loads all worktrees from the repository.
    func loadWorktrees() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            worktrees = try await gitService.getWorktrees(in: repository)
        } catch {
            self.error = "Failed to load worktrees: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Creates a new worktree.
    func createWorktree() async {
        guard let repository = repository else { return }
        guard !newWorktreePath.isEmpty else {
            error = "Please specify a path for the worktree"
            return
        }

        isLoading = true
        error = nil

        do {
            let options = WorktreeCreateOptions(
                path: newWorktreePath,
                branch: newWorktreeBranch.isEmpty ? nil : newWorktreeBranch,
                baseBranch: baseBranch.isEmpty ? nil : baseBranch,
                createBranch: createNewBranch && !newWorktreeBranch.isEmpty,
                force: false,
                detach: detachHead,
                lock: lockAfterCreate,
                lockReason: lockAfterCreate && !lockReason.isEmpty ? lockReason : nil
            )

            try await gitService.addWorktree(options: options, in: repository)
            await loadWorktrees()
            resetCreateForm()
            showingCreateSheet = false
        } catch {
            self.error = "Failed to create worktree: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Removes a worktree.
    func removeWorktree() async {
        guard let repository = repository,
              let worktree = worktreeToRemove else { return }

        isLoading = true
        error = nil

        do {
            let options = WorktreeRemoveOptions(path: worktree.path, force: forceRemove)
            try await gitService.removeWorktree(options: options, in: repository)
            await loadWorktrees()
            worktreeToRemove = nil
            showingRemoveConfirmation = false
            forceRemove = false
        } catch {
            self.error = "Failed to remove worktree: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Locks a worktree.
    func lockWorktree() async {
        guard let repository = repository,
              let worktree = worktreeToLock else { return }

        isLoading = true
        error = nil

        do {
            try await gitService.lockWorktree(
                path: worktree.path,
                reason: lockReasonInput.isEmpty ? nil : lockReasonInput,
                in: repository
            )
            await loadWorktrees()
            worktreeToLock = nil
            lockReasonInput = ""
            showingLockSheet = false
        } catch {
            self.error = "Failed to lock worktree: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Unlocks a worktree.
    func unlockWorktree(_ worktree: Worktree) async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            try await gitService.unlockWorktree(path: worktree.path, in: repository)
            await loadWorktrees()
        } catch {
            self.error = "Failed to unlock worktree: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Moves a worktree to a new location.
    func moveWorktree() async {
        guard let repository = repository,
              let worktree = worktreeToMove else { return }
        guard !newPath.isEmpty else {
            error = "Please specify a new path"
            return
        }

        isLoading = true
        error = nil

        do {
            try await gitService.moveWorktree(
                sourcePath: worktree.path,
                destinationPath: newPath,
                force: forceMove,
                in: repository
            )
            await loadWorktrees()
            worktreeToMove = nil
            newPath = ""
            forceMove = false
            showingMoveSheet = false
        } catch {
            self.error = "Failed to move worktree: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Prunes stale worktree information.
    func pruneWorktrees(dryRun: Bool = false) async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            let result = try await gitService.pruneWorktrees(dryRun: dryRun, verbose: true, in: repository)
            if !dryRun {
                await loadWorktrees()
            }
            if !result.isEmpty {
                // Could display this result in a sheet if needed
                print("Prune result: \(result)")
            }
        } catch {
            self.error = "Failed to prune worktrees: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Repairs worktree administrative files.
    func repairWorktrees() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            _ = try await gitService.repairWorktrees(in: repository)
            await loadWorktrees()
        } catch {
            self.error = "Failed to repair worktrees: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Opens a worktree in Finder.
    func openInFinder(_ worktree: Worktree) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: worktree.path)
    }

    /// Opens a worktree in Terminal.
    func openInTerminal(_ worktree: Worktree) {
        let script = "tell application \"Terminal\" to do script \"cd '\(worktree.path)'\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    // MARK: - Sheet Presentation

    func showCreateSheet() {
        resetCreateForm()
        showingCreateSheet = true
    }

    func showRemoveConfirmation(for worktree: Worktree) {
        worktreeToRemove = worktree
        forceRemove = false
        showingRemoveConfirmation = true
    }

    func showLockSheet(for worktree: Worktree) {
        worktreeToLock = worktree
        lockReasonInput = ""
        showingLockSheet = true
    }

    func showMoveSheet(for worktree: Worktree) {
        worktreeToMove = worktree
        newPath = ""
        forceMove = false
        showingMoveSheet = true
    }

    // MARK: - Private Methods

    private func resetCreateForm() {
        newWorktreePath = ""
        newWorktreeBranch = ""
        createNewBranch = true
        baseBranch = ""
        detachHead = false
        lockAfterCreate = false
        lockReason = ""
    }
}
