import Foundation

/// Command to list all branches.
struct ListBranchesCommand: GitCommand {
    typealias Result = [Branch]

    /// Whether to include remote branches.
    let includeRemote: Bool

    init(includeRemote: Bool = true) {
        self.includeRemote = includeRemote
    }

    var arguments: [String] {
        var args = [
            "branch",
            "--format=%(HEAD)|%(refname)|%(refname:short)|%(objectname)|%(upstream:short)|%(upstream:track,nobracket)"
        ]

        if includeRemote {
            args.append("-a")
        }

        return args
    }

    func parse(output: String) throws -> [Branch] {
        BranchParser.parse(output)
    }
}

/// Command to get the current branch name.
struct CurrentBranchCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["rev-parse", "--abbrev-ref", "HEAD"]
    }

    func parse(output: String) throws -> String? {
        let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
        // Returns "HEAD" when in detached state
        return name == "HEAD" ? nil : name
    }
}

/// Command to checkout a branch.
struct CheckoutCommand: VoidGitCommand {
    let branchName: String

    var arguments: [String] {
        ["checkout", branchName]
    }
}

/// Command to create a new branch.
struct CreateBranchCommand: VoidGitCommand {
    let branchName: String
    let startPoint: String?

    init(branchName: String, startPoint: String? = nil) {
        self.branchName = branchName
        self.startPoint = startPoint
    }

    var arguments: [String] {
        var args = ["checkout", "-b", branchName]
        if let startPoint {
            args.append(startPoint)
        }
        return args
    }
}

/// Command to delete a branch.
struct DeleteBranchCommand: VoidGitCommand {
    let branchName: String
    let force: Bool

    init(branchName: String, force: Bool = false) {
        self.branchName = branchName
        self.force = force
    }

    var arguments: [String] {
        ["branch", force ? "-D" : "-d", branchName]
    }
}

// MARK: - Branch Rename Commands

/// Command to rename a local branch.
struct RenameBranchCommand: VoidGitCommand {
    let oldName: String
    let newName: String

    var arguments: [String] {
        ["branch", "-m", oldName, newName]
    }
}

/// Command to delete a remote branch (used for remote rename).
struct DeleteRemoteBranchCommand: VoidGitCommand {
    let remoteName: String
    let branchName: String

    var arguments: [String] {
        ["push", remoteName, "--delete", branchName]
    }
}

/// Command to push a branch to remote with a specific name.
struct PushBranchToRemoteCommand: VoidGitCommand {
    let localBranch: String
    let remoteName: String
    let remoteBranch: String
    let setUpstream: Bool

    init(localBranch: String, remoteName: String, remoteBranch: String, setUpstream: Bool = true) {
        self.localBranch = localBranch
        self.remoteName = remoteName
        self.remoteBranch = remoteBranch
        self.setUpstream = setUpstream
    }

    var arguments: [String] {
        var args = ["push", remoteName, "\(localBranch):\(remoteBranch)"]
        if setUpstream {
            args.insert("-u", at: 1)
        }
        return args
    }
}

// MARK: - Upstream Commands

/// Command to set upstream tracking branch.
struct SetUpstreamCommand: VoidGitCommand {
    let branchName: String
    let upstreamRef: String

    var arguments: [String] {
        ["branch", "--set-upstream-to=\(upstreamRef)", branchName]
    }
}

/// Command to unset upstream tracking branch.
struct UnsetUpstreamCommand: VoidGitCommand {
    let branchName: String

    var arguments: [String] {
        ["branch", "--unset-upstream", branchName]
    }
}

// MARK: - Merge Commands

/// The type of merge to perform.
enum MergeType {
    case normal
    case squash
    case fastForwardOnly
    case noFastForward
}

/// Command to merge a branch into the current branch.
struct MergeCommand: VoidGitCommand {
    let branchName: String
    let mergeType: MergeType
    let message: String?

    init(branchName: String, mergeType: MergeType = .normal, message: String? = nil) {
        self.branchName = branchName
        self.mergeType = mergeType
        self.message = message
    }

    var arguments: [String] {
        var args = ["merge"]

        switch mergeType {
        case .normal:
            break
        case .squash:
            args.append("--squash")
        case .fastForwardOnly:
            args.append("--ff-only")
        case .noFastForward:
            args.append("--no-ff")
        }

        if let message = message {
            args.append("-m")
            args.append(message)
        }

        args.append(branchName)
        return args
    }
}

/// Command to abort a merge in progress.
struct AbortMergeCommand: VoidGitCommand {
    var arguments: [String] {
        ["merge", "--abort"]
    }
}

/// Command to continue a merge after resolving conflicts.
struct ContinueMergeCommand: VoidGitCommand {
    var arguments: [String] {
        ["merge", "--continue"]
    }
}

// MARK: - Rebase Commands

/// Command to rebase the current branch onto another branch.
struct RebaseCommand: VoidGitCommand {
    let ontoBranch: String
    let interactive: Bool

    init(ontoBranch: String, interactive: Bool = false) {
        self.ontoBranch = ontoBranch
        self.interactive = interactive
    }

    var arguments: [String] {
        var args = ["rebase"]
        if interactive {
            args.append("-i")
        }
        args.append(ontoBranch)
        return args
    }
}

/// Command to abort a rebase in progress.
struct AbortRebaseCommand: VoidGitCommand {
    var arguments: [String] {
        ["rebase", "--abort"]
    }
}

/// Command to continue a rebase after resolving conflicts.
struct ContinueRebaseCommand: VoidGitCommand {
    var arguments: [String] {
        ["rebase", "--continue"]
    }
}

/// Command to skip the current commit during rebase.
struct SkipRebaseCommand: VoidGitCommand {
    var arguments: [String] {
        ["rebase", "--skip"]
    }
}

// MARK: - Interactive Rebase Commands

/// Command to get commits for interactive rebase planning.
struct GetRebaseCommitsCommand: GitCommand {
    typealias Result = [RebaseEntry]

    let ontoBranch: String
    let limit: Int

    init(ontoBranch: String, limit: Int = 100) {
        self.ontoBranch = ontoBranch
        self.limit = limit
    }

    var arguments: [String] {
        [
            "log",
            "--format=%H|%s|%an|%aI",
            "--reverse",
            "-n", "\(limit)",
            "\(ontoBranch)..HEAD"
        ]
    }

    func parse(output: String) throws -> [RebaseEntry] {
        var entries: [RebaseEntry] = []
        let dateFormatter = ISO8601DateFormatter()

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: "|", maxSplits: 3)
            guard parts.count >= 2 else { continue }

            let hash = String(parts[0])
            let message = String(parts[1])
            let author = parts.count > 2 ? String(parts[2]) : nil
            let date = parts.count > 3 ? dateFormatter.date(from: String(parts[3])) : nil

            entries.append(RebaseEntry(
                commitHash: hash,
                message: message,
                action: .pick,
                author: author,
                date: date
            ))
        }

        return entries
    }
}

/// Command to check the current rebase state.
struct GetRebaseStateCommand: GitCommand {
    typealias Result = InteractiveRebaseState

    let repositoryPath: String

    var arguments: [String] {
        // We check if rebase-merge or rebase-apply exists
        ["rev-parse", "--git-dir"]
    }

    func parse(output: String) throws -> InteractiveRebaseState {
        // This is a placeholder - actual state detection is done by checking files
        return .idle
    }
}

/// Command to get the current step in an interactive rebase.
struct GetRebaseProgressCommand: GitCommand {
    typealias Result = (current: Int, total: Int)?

    var arguments: [String] {
        ["rev-parse", "--git-dir"]
    }

    func parse(output: String) throws -> (current: Int, total: Int)? {
        // The actual parsing is handled in GitService by reading the files
        return nil
    }
}

/// Command to edit the commit message during rebase.
struct RebaseEditMessageCommand: VoidGitCommand {
    let message: String

    var arguments: [String] {
        ["commit", "--amend", "-m", message]
    }
}

/// Command to get the rebase todo file path.
struct GetRebaseTodoPathCommand: GitCommand {
    typealias Result = String

    var arguments: [String] {
        ["rev-parse", "--git-path", "rebase-merge/git-rebase-todo"]
    }

    func parse(output: String) throws -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Command to get the original commit being rebased.
struct GetRebaseCurrentCommitCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["rev-parse", "--git-path", "rebase-merge/stopped-sha"]
    }

    func parse(output: String) throws -> String? {
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return path
    }
}

// MARK: - Branch Comparison Commands

/// Command to get the diff between two branches.
struct BranchDiffCommand: GitCommand {
    typealias Result = [FileDiff]

    let baseBranch: String
    let compareBranch: String

    var arguments: [String] {
        ["diff", "\(baseBranch)...\(compareBranch)"]
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}

/// Command to get the list of commits between two branches.
struct BranchLogDiffCommand: GitCommand {
    typealias Result = [Commit]

    let baseBranch: String
    let compareBranch: String
    let limit: Int

    init(baseBranch: String, compareBranch: String, limit: Int = 100) {
        self.baseBranch = baseBranch
        self.compareBranch = compareBranch
        self.limit = limit
    }

    var arguments: [String] {
        [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", "\(limit)",
            "\(baseBranch)..\(compareBranch)"
        ]
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to check if a rebase or merge is in progress.
struct GetRepositoryStateCommand: GitCommand {
    typealias Result = RepositoryState

    var arguments: [String] {
        ["status", "--porcelain=v2", "--branch"]
    }

    func parse(output: String) throws -> RepositoryState {
        // Check for merge/rebase state indicators
        var state = RepositoryState()

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("# branch.head") {
                let parts = line.split(separator: " ")
                if parts.count >= 2 {
                    state.currentBranch = String(parts[2])
                }
            }
        }

        return state
    }
}

/// Represents the current state of the repository.
struct RepositoryState {
    var currentBranch: String?
    var isMerging: Bool = false
    var isRebasing: Bool = false
    var isDetachedHead: Bool = false
    var conflictedFiles: [String] = []
}
