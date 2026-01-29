import Foundation

/// Represents a Git worktree.
struct Worktree: Identifiable, Equatable, Hashable {
    /// The absolute path to the worktree directory.
    let path: String

    /// The HEAD commit hash of the worktree.
    let head: String?

    /// The branch name checked out in the worktree (nil if detached HEAD).
    let branch: String?

    /// Whether this is the main worktree.
    let isMain: Bool

    /// Whether the worktree is in detached HEAD state.
    let isDetached: Bool

    /// Whether the worktree is locked.
    let isLocked: Bool

    /// The lock reason if locked.
    let lockReason: String?

    /// Whether the worktree is prunable (missing from disk).
    let isPrunable: Bool

    var id: String { path }

    /// The worktree directory name.
    var name: String {
        (path as NSString).lastPathComponent
    }

    /// Short form of the HEAD commit.
    var shortHead: String? {
        head.map { String($0.prefix(7)) }
    }

    /// Display name for the branch or HEAD state.
    var displayBranch: String {
        if let branch = branch {
            return branch
        } else if isDetached {
            return "HEAD detached at \(shortHead ?? "unknown")"
        }
        return "unknown"
    }

    /// Status description.
    var statusDescription: String {
        var parts: [String] = []

        if isMain {
            parts.append("main")
        }
        if isLocked {
            parts.append("locked")
        }
        if isPrunable {
            parts.append("prunable")
        }

        return parts.isEmpty ? "" : "(\(parts.joined(separator: ", ")))"
    }
}

/// Options for creating a new worktree.
struct WorktreeCreateOptions {
    /// The path where the worktree will be created.
    let path: String

    /// The branch to check out (creates new if doesn't exist).
    let branch: String?

    /// The commit/branch to base the new branch on.
    let baseBranch: String?

    /// Whether to create a new branch.
    let createBranch: Bool

    /// Whether to force creation (allows checking out a branch already checked out elsewhere).
    let force: Bool

    /// Whether to detach HEAD.
    let detach: Bool

    /// Lock the worktree after creation.
    let lock: Bool

    /// Lock reason if locking.
    let lockReason: String?

    init(
        path: String,
        branch: String? = nil,
        baseBranch: String? = nil,
        createBranch: Bool = false,
        force: Bool = false,
        detach: Bool = false,
        lock: Bool = false,
        lockReason: String? = nil
    ) {
        self.path = path
        self.branch = branch
        self.baseBranch = baseBranch
        self.createBranch = createBranch
        self.force = force
        self.detach = detach
        self.lock = lock
        self.lockReason = lockReason
    }
}

/// Options for removing a worktree.
struct WorktreeRemoveOptions {
    /// The path of the worktree to remove.
    let path: String

    /// Whether to force removal even if there are untracked files.
    let force: Bool

    init(path: String, force: Bool = false) {
        self.path = path
        self.force = force
    }
}
