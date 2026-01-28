import Foundation

/// Command to list all stashes.
struct ListStashesCommand: GitCommand {
    typealias Result = [Stash]

    var arguments: [String] {
        ["stash", "list", "--format=%gd|%H|%gs|%aI"]
    }

    func parse(output: String) throws -> [Stash] {
        StashParser.parse(output)
    }
}

/// Command to create a new stash.
struct CreateStashCommand: VoidGitCommand {
    let message: String?
    let includeUntracked: Bool

    init(message: String? = nil, includeUntracked: Bool = false) {
        self.message = message
        self.includeUntracked = includeUntracked
    }

    var arguments: [String] {
        var args = ["stash", "push"]
        if includeUntracked {
            args.append("--include-untracked")
        }
        if let message {
            args.append("-m")
            args.append(message)
        }
        return args
    }
}

/// Command to apply a stash without removing it.
struct ApplyStashCommand: VoidGitCommand {
    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "apply", stashRef]
    }
}

/// Command to pop a stash (apply and remove).
struct PopStashCommand: VoidGitCommand {
    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "pop", stashRef]
    }
}

/// Command to drop a stash.
struct DropStashCommand: VoidGitCommand {
    let stashRef: String

    var arguments: [String] {
        ["stash", "drop", stashRef]
    }
}

/// Command to clear all stashes.
struct ClearStashesCommand: VoidGitCommand {
    var arguments: [String] {
        ["stash", "clear"]
    }
}

/// Command to show stash contents.
struct ShowStashCommand: GitCommand {
    typealias Result = [FileDiff]

    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "show", "-p", "--no-color", stashRef]
    }

    func parse(output: String) throws -> [FileDiff] {
        DiffParser.parse(output)
    }
}

/// Command to create a stash branch.
struct StashBranchCommand: VoidGitCommand {
    let branchName: String
    let stashRef: String

    init(branchName: String, stashRef: String = "stash@{0}") {
        self.branchName = branchName
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "branch", branchName, stashRef]
    }
}

// MARK: - Prune Commands

/// Command to prune remote-tracking branches that no longer exist.
struct PruneRemoteCommand: VoidGitCommand {
    let remoteName: String

    init(remoteName: String = "origin") {
        self.remoteName = remoteName
    }

    var arguments: [String] {
        ["remote", "prune", remoteName]
    }
}

/// Command to list stale remote-tracking branches.
struct ListStaleBranchesCommand: GitCommand {
    typealias Result = [String]

    let remoteName: String

    init(remoteName: String = "origin") {
        self.remoteName = remoteName
    }

    var arguments: [String] {
        ["remote", "prune", "--dry-run", remoteName]
    }

    func parse(output: String) throws -> [String] {
        // Output format: " * [would prune] origin/branch-name"
        var branches: [String] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("[would prune]") {
                // Extract branch name
                if let lastSpace = trimmed.lastIndex(of: " ") {
                    let branch = String(trimmed[trimmed.index(after: lastSpace)...])
                    branches.append(branch)
                }
            }
        }

        return branches
    }
}

/// Command to delete multiple local branches.
struct DeleteBranchesCommand: VoidGitCommand {
    let branches: [String]
    let force: Bool

    init(branches: [String], force: Bool = false) {
        self.branches = branches
        self.force = force
    }

    var arguments: [String] {
        var args = ["branch", force ? "-D" : "-d"]
        args.append(contentsOf: branches)
        return args
    }
}

/// Command to gc (garbage collect) the repository.
struct GarbageCollectCommand: VoidGitCommand {
    let aggressive: Bool
    let prune: String?

    init(aggressive: Bool = false, prune: String? = nil) {
        self.aggressive = aggressive
        self.prune = prune
    }

    var arguments: [String] {
        var args = ["gc"]
        if aggressive {
            args.append("--aggressive")
        }
        if let prune = prune {
            args.append("--prune=\(prune)")
        }
        return args
    }
}

/// Command to fsck (file system check) the repository.
struct FsckCommand: GitCommand {
    typealias Result = [String]

    let full: Bool

    init(full: Bool = false) {
        self.full = full
    }

    var arguments: [String] {
        var args = ["fsck"]
        if full {
            args.append("--full")
        }
        return args
    }

    func parse(output: String) throws -> [String] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Remote Testing

/// Command to test if a remote is reachable.
struct TestRemoteConnectionCommand: GitCommand {
    typealias Result = Bool

    let remoteUrl: String

    var arguments: [String] {
        ["ls-remote", "--exit-code", "--heads", remoteUrl]
    }

    func parse(output: String) throws -> Bool {
        // If we got here without an error, connection is successful
        true
    }
}
