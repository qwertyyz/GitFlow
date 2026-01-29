import Foundation

/// Command to get reflog entries.
struct ReflogCommand: GitCommand {
    typealias Result = [ReflogEntry]

    /// Maximum number of entries to retrieve.
    let limit: Int

    /// Optional ref to get reflog for (e.g., "HEAD", "main").
    let ref: String?

    init(limit: Int = 100, ref: String? = nil) {
        self.limit = limit
        self.ref = ref
    }

    var arguments: [String] {
        var args = [
            "reflog",
            "--format=\(ReflogParser.formatString)",
            "-n", String(limit)
        ]

        if let ref {
            args.append(ref)
        }

        return args
    }

    func parse(output: String) throws -> [ReflogEntry] {
        try ReflogParser.parse(output)
    }
}

/// Command to get reflog entries for a specific branch.
struct BranchReflogCommand: GitCommand {
    typealias Result = [ReflogEntry]

    /// The branch name to get reflog for.
    let branchName: String

    /// Maximum number of entries to retrieve.
    let limit: Int

    init(branchName: String, limit: Int = 100) {
        self.branchName = branchName
        self.limit = limit
    }

    var arguments: [String] {
        [
            "reflog",
            "--format=\(ReflogParser.formatString)",
            "-n", String(limit),
            branchName
        ]
    }

    func parse(output: String) throws -> [ReflogEntry] {
        try ReflogParser.parse(output)
    }
}

/// Command to show a specific reflog entry.
struct ReflogShowCommand: GitCommand {
    typealias Result = ReflogEntry

    /// The reflog selector (e.g., "HEAD@{0}", "main@{1}").
    let selector: String

    var arguments: [String] {
        [
            "reflog",
            "--format=\(ReflogParser.formatString)",
            "-n", "1",
            selector
        ]
    }

    func parse(output: String) throws -> ReflogEntry {
        let entries = try ReflogParser.parse(output)
        guard let entry = entries.first else {
            throw GitError.unknown(message: "Reflog entry not found: \(selector)")
        }
        return entry
    }
}

/// Command to expire old reflog entries.
struct ReflogExpireCommand: VoidGitCommand {
    /// Whether to expire all entries (not just unreachable ones).
    let all: Bool

    /// Whether to run in dry-run mode.
    let dryRun: Bool

    init(all: Bool = false, dryRun: Bool = false) {
        self.all = all
        self.dryRun = dryRun
    }

    var arguments: [String] {
        var args = ["reflog", "expire"]

        if all {
            args.append("--all")
        }

        if dryRun {
            args.append("--dry-run")
        }

        args.append("--expire=now")

        return args
    }

    func parse(output: String) throws {
        // No output to parse for void command
    }
}
