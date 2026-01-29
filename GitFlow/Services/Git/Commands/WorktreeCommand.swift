import Foundation

/// Command to list all worktrees.
struct ListWorktreesCommand: GitCommand {
    typealias Result = [Worktree]

    var arguments: [String] {
        ["worktree", "list", "--porcelain"]
    }

    func parse(output: String) throws -> [Worktree] {
        // Porcelain output format:
        // worktree /path/to/main
        // HEAD abc123def456
        // branch refs/heads/main
        //
        // worktree /path/to/feature
        // HEAD def456abc123
        // branch refs/heads/feature
        // locked
        //
        // worktree /path/to/detached
        // HEAD 123456789abc
        // detached
        //
        // worktree /path/to/prunable
        // HEAD 000000000000
        // prunable

        var worktrees: [Worktree] = []
        var currentPath: String?
        var currentHead: String?
        var currentBranch: String?
        var isDetached = false
        var isLocked = false
        var lockReason: String?
        var isPrunable = false
        var isFirst = true

        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // End of worktree entry
                if let path = currentPath {
                    worktrees.append(Worktree(
                        path: path,
                        head: currentHead,
                        branch: currentBranch,
                        isMain: isFirst,
                        isDetached: isDetached,
                        isLocked: isLocked,
                        lockReason: lockReason,
                        isPrunable: isPrunable
                    ))
                    isFirst = false
                }
                // Reset for next entry
                currentPath = nil
                currentHead = nil
                currentBranch = nil
                isDetached = false
                isLocked = false
                lockReason = nil
                isPrunable = false
                continue
            }

            if trimmed.starts(with: "worktree ") {
                currentPath = String(trimmed.dropFirst("worktree ".count))
            } else if trimmed.starts(with: "HEAD ") {
                currentHead = String(trimmed.dropFirst("HEAD ".count))
            } else if trimmed.starts(with: "branch ") {
                let ref = String(trimmed.dropFirst("branch ".count))
                // Remove refs/heads/ prefix
                if ref.starts(with: "refs/heads/") {
                    currentBranch = String(ref.dropFirst("refs/heads/".count))
                } else {
                    currentBranch = ref
                }
            } else if trimmed == "detached" {
                isDetached = true
            } else if trimmed == "locked" {
                isLocked = true
            } else if trimmed.starts(with: "locked ") {
                isLocked = true
                lockReason = String(trimmed.dropFirst("locked ".count))
            } else if trimmed == "prunable" {
                isPrunable = true
            }
        }

        // Handle last entry if no trailing newline
        if let path = currentPath {
            worktrees.append(Worktree(
                path: path,
                head: currentHead,
                branch: currentBranch,
                isMain: isFirst,
                isDetached: isDetached,
                isLocked: isLocked,
                lockReason: lockReason,
                isPrunable: isPrunable
            ))
        }

        return worktrees
    }
}

/// Command to add a new worktree.
struct AddWorktreeCommand: GitCommand {
    typealias Result = Bool
    let options: WorktreeCreateOptions

    var arguments: [String] {
        var args = ["worktree", "add"]

        if options.force {
            args.append("--force")
        }

        if options.detach {
            args.append("--detach")
        }

        if options.lock {
            if let reason = options.lockReason {
                args.append("--lock")
                args.append("--reason=\(reason)")
            } else {
                args.append("--lock")
            }
        }

        if options.createBranch, let branch = options.branch {
            args.append("-b")
            args.append(branch)
        }

        args.append(options.path)

        if let branch = options.branch, !options.createBranch {
            args.append(branch)
        } else if let baseBranch = options.baseBranch {
            args.append(baseBranch)
        }

        return args
    }

    func parse(output: String) throws -> Bool {
        // Success if output contains "Preparing worktree" or similar
        !output.contains("fatal:")
    }
}

/// Command to remove a worktree.
struct RemoveWorktreeCommand: GitCommand {
    typealias Result = Bool
    let options: WorktreeRemoveOptions

    var arguments: [String] {
        var args = ["worktree", "remove"]

        if options.force {
            args.append("--force")
        }

        args.append(options.path)

        return args
    }

    func parse(output: String) throws -> Bool {
        !output.contains("fatal:")
    }
}

/// Command to lock a worktree.
struct LockWorktreeCommand: GitCommand {
    typealias Result = Bool
    let path: String
    let reason: String?

    init(path: String, reason: String? = nil) {
        self.path = path
        self.reason = reason
    }

    var arguments: [String] {
        var args = ["worktree", "lock"]

        if let reason = reason {
            args.append("--reason=\(reason)")
        }

        args.append(path)

        return args
    }

    func parse(output: String) throws -> Bool {
        true
    }
}

/// Command to unlock a worktree.
struct UnlockWorktreeCommand: GitCommand {
    typealias Result = Bool
    let path: String

    var arguments: [String] {
        ["worktree", "unlock", path]
    }

    func parse(output: String) throws -> Bool {
        true
    }
}

/// Command to move a worktree to a new location.
struct MoveWorktreeCommand: GitCommand {
    typealias Result = Bool
    let sourcePath: String
    let destinationPath: String
    let force: Bool

    init(sourcePath: String, destinationPath: String, force: Bool = false) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.force = force
    }

    var arguments: [String] {
        var args = ["worktree", "move"]

        if force {
            args.append("--force")
        }

        args.append(sourcePath)
        args.append(destinationPath)

        return args
    }

    func parse(output: String) throws -> Bool {
        !output.contains("fatal:")
    }
}

/// Command to prune worktree information for worktrees that no longer exist.
struct PruneWorktreesCommand: GitCommand {
    typealias Result = String
    let dryRun: Bool
    let verbose: Bool
    let expire: String?

    init(dryRun: Bool = false, verbose: Bool = false, expire: String? = nil) {
        self.dryRun = dryRun
        self.verbose = verbose
        self.expire = expire
    }

    var arguments: [String] {
        var args = ["worktree", "prune"]

        if dryRun {
            args.append("--dry-run")
        }

        if verbose {
            args.append("--verbose")
        }

        if let expire = expire {
            args.append("--expire=\(expire)")
        }

        return args
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to repair worktree administrative files.
struct RepairWorktreesCommand: GitCommand {
    typealias Result = String
    let paths: [String]?

    init(paths: [String]? = nil) {
        self.paths = paths
    }

    var arguments: [String] {
        var args = ["worktree", "repair"]

        if let paths = paths {
            args.append(contentsOf: paths)
        }

        return args
    }

    func parse(output: String) throws -> String {
        output
    }
}
