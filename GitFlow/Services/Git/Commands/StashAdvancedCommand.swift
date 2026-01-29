import Foundation

/// Command to show stash contents as a patch.
struct StashShowPatchCommand: GitCommand {
    typealias Result = String

    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "show", "-p", stashRef]
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to show only specific files from a stash.
struct StashShowFilesCommand: GitCommand {
    typealias Result = [String]

    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "show", "--name-only", stashRef]
    }

    func parse(output: String) throws -> [String] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Command to stash only specific paths.
struct StashPushPathsCommand: VoidGitCommand {
    let paths: [String]
    let message: String?
    let keepIndex: Bool

    init(paths: [String], message: String? = nil, keepIndex: Bool = false) {
        self.paths = paths
        self.message = message
        self.keepIndex = keepIndex
    }

    var arguments: [String] {
        var args = ["stash", "push"]

        if let message = message {
            args.append("-m")
            args.append(message)
        }

        if keepIndex {
            args.append("--keep-index")
        }

        args.append("--")
        args.append(contentsOf: paths)

        return args
    }
}

/// Command to stash only staged changes.
struct StashStagedCommand: VoidGitCommand {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var arguments: [String] {
        var args = ["stash", "push", "--staged"]

        if let message = message {
            args.append("-m")
            args.append(message)
        }

        return args
    }
}

/// Command to apply stash and keep index.
struct ApplyStashKeepIndexCommand: VoidGitCommand {
    let stashRef: String

    init(stashRef: String = "stash@{0}") {
        self.stashRef = stashRef
    }

    var arguments: [String] {
        ["stash", "apply", "--index", stashRef]
    }
}
