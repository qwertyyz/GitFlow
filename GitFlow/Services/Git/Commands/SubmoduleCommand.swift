import Foundation

/// Command to list all submodules with their status.
struct ListSubmodulesCommand: GitCommand {
    typealias Result = [Submodule]

    var arguments: [String] {
        ["submodule", "status", "--recursive"]
    }

    func parse(output: String) throws -> [Submodule] {
        SubmoduleParser.parseStatus(output)
    }
}

/// Command to get submodule configuration from .gitmodules.
struct GetSubmoduleConfigCommand: GitCommand {
    typealias Result = [SubmoduleConfig]

    var arguments: [String] {
        ["config", "--file", ".gitmodules", "--list"]
    }

    func parse(output: String) throws -> [SubmoduleConfig] {
        SubmoduleParser.parseConfig(output)
    }
}

/// Command to initialize submodules.
struct InitSubmodulesCommand: VoidGitCommand {
    let recursive: Bool

    init(recursive: Bool = true) {
        self.recursive = recursive
    }

    var arguments: [String] {
        var args = ["submodule", "init"]
        if recursive {
            args.insert("--recursive", at: 2)
        }
        return args
    }
}

/// Command to update submodules.
struct UpdateSubmodulesCommand: VoidGitCommand {
    let recursive: Bool
    let init_: Bool
    let remote: Bool
    let paths: [String]?

    init(recursive: Bool = true, init_: Bool = true, remote: Bool = false, paths: [String]? = nil) {
        self.recursive = recursive
        self.init_ = init_
        self.remote = remote
        self.paths = paths
    }

    var arguments: [String] {
        var args = ["submodule", "update"]

        if init_ {
            args.append("--init")
        }

        if recursive {
            args.append("--recursive")
        }

        if remote {
            args.append("--remote")
        }

        if let paths = paths, !paths.isEmpty {
            args.append("--")
            args.append(contentsOf: paths)
        }

        return args
    }
}

/// Command to add a new submodule.
struct AddSubmoduleCommand: VoidGitCommand {
    let url: String
    let path: String
    let branch: String?

    init(url: String, path: String, branch: String? = nil) {
        self.url = url
        self.path = path
        self.branch = branch
    }

    var arguments: [String] {
        var args = ["submodule", "add"]

        if let branch = branch {
            args.append("-b")
            args.append(branch)
        }

        args.append(url)
        args.append(path)

        return args
    }
}

/// Command to deinitialize (remove from working tree) a submodule.
struct DeinitSubmoduleCommand: VoidGitCommand {
    let path: String
    let force: Bool

    init(path: String, force: Bool = false) {
        self.path = path
        self.force = force
    }

    var arguments: [String] {
        var args = ["submodule", "deinit"]

        if force {
            args.append("--force")
        }

        args.append(path)

        return args
    }
}

/// Command to sync submodule URLs.
struct SyncSubmodulesCommand: VoidGitCommand {
    let recursive: Bool

    init(recursive: Bool = true) {
        self.recursive = recursive
    }

    var arguments: [String] {
        var args = ["submodule", "sync"]
        if recursive {
            args.append("--recursive")
        }
        return args
    }
}

/// Command to get the diff for submodule changes.
struct SubmoduleDiffCommand: GitCommand {
    typealias Result = String

    let path: String

    var arguments: [String] {
        ["diff", "--submodule=diff", "--", path]
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to checkout a specific commit in a submodule.
struct CheckoutSubmoduleCommitCommand: VoidGitCommand {
    let submodulePath: String
    let commit: String

    var arguments: [String] {
        // This runs inside the submodule
        ["-C", submodulePath, "checkout", commit]
    }
}

// MARK: - Parser

/// Parser for submodule-related git output.
enum SubmoduleParser {
    /// Parses `git submodule status` output.
    static func parseStatus(_ output: String) -> [Submodule] {
        var submodules: [Submodule] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: [ +-U]<sha1> <path> [(<describe>)]
            // First character indicates status:
            // ' ' = initialized and matches
            // '-' = not initialized
            // '+' = checked out commit doesn't match
            // 'U' = has merge conflicts

            let statusChar = trimmed.first ?? " "
            let rest = String(trimmed.dropFirst())
            let parts = rest.split(separator: " ", maxSplits: 1)

            guard parts.count >= 2 else { continue }

            let commitHash = String(parts[0])
            var pathAndDescribe = String(parts[1])

            // Extract describe if present
            var path = pathAndDescribe
            if let parenStart = pathAndDescribe.firstIndex(of: "(") {
                path = String(pathAndDescribe[..<parenStart]).trimmingCharacters(in: .whitespaces)
            }

            let isInitialized = statusChar != "-"
            let hasChanges = statusChar == "+" || statusChar == "U"

            var submodule = Submodule(
                name: path,
                path: path,
                url: "", // Will be filled from config
                currentCommit: isInitialized ? commitHash : nil,
                expectedCommit: nil, // Would need separate command
                branch: nil,
                isInitialized: isInitialized
            )
            submodule.hasLocalChanges = hasChanges

            submodules.append(submodule)
        }

        return submodules
    }

    /// Parses `git config --file .gitmodules --list` output.
    static func parseConfig(_ output: String) -> [SubmoduleConfig] {
        var configs: [String: (path: String?, url: String?, branch: String?)] = [:]

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: submodule.<name>.<key>=<value>
            guard trimmed.hasPrefix("submodule.") else { continue }

            let withoutPrefix = String(trimmed.dropFirst(10)) // "submodule."

            // Find the key=value separator
            guard let equalsIndex = withoutPrefix.firstIndex(of: "=") else { continue }

            let keyPath = String(withoutPrefix[..<equalsIndex])
            let value = String(withoutPrefix[withoutPrefix.index(after: equalsIndex)...])

            // Parse key path: <name>.<key>
            if let lastDotIndex = keyPath.lastIndex(of: ".") {
                let name = String(keyPath[..<lastDotIndex])
                let key = String(keyPath[keyPath.index(after: lastDotIndex)...])

                var config = configs[name] ?? (path: nil, url: nil, branch: nil)

                switch key {
                case "path":
                    config.path = value
                case "url":
                    config.url = value
                case "branch":
                    config.branch = value
                default:
                    break
                }

                configs[name] = config
            }
        }

        return configs.compactMap { name, config in
            guard let path = config.path, let url = config.url else { return nil }
            return SubmoduleConfig(
                name: name,
                path: path,
                url: url,
                branch: config.branch
            )
        }
    }

    /// Merges status and config information into complete Submodule objects.
    static func merge(status: [Submodule], configs: [SubmoduleConfig]) -> [Submodule] {
        var result: [Submodule] = []

        for submodule in status {
            if let config = configs.first(where: { $0.path == submodule.path }) {
                var merged = Submodule(
                    name: config.name,
                    path: submodule.path,
                    url: config.url,
                    currentCommit: submodule.currentCommit,
                    expectedCommit: submodule.expectedCommit,
                    branch: config.branch,
                    isInitialized: submodule.isInitialized
                )
                merged.hasLocalChanges = submodule.hasLocalChanges
                result.append(merged)
            } else {
                result.append(submodule)
            }
        }

        return result
    }
}
