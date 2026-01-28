import Foundation

/// Options for filtering commit history.
struct LogFilterOptions {
    /// Search in commit messages (grep).
    var messageSearch: String?

    /// Filter by author name or email.
    var author: String?

    /// Filter by committer name or email.
    var committer: String?

    /// Start date for date range filter.
    var since: Date?

    /// End date for date range filter.
    var until: Date?

    /// Optional branch or ref.
    var ref: String?

    /// Optional file path.
    var filePath: String?

    /// Number of commits to skip (for pagination).
    var skip: Int = 0

    /// Whether to use case-insensitive matching.
    var caseInsensitive: Bool = true

    /// Whether to use extended regex.
    var extendedRegex: Bool = false

    /// Whether to search all refs (including remotes).
    var allRefs: Bool = false

    init() {}

    /// Returns true if any filter is active.
    var hasActiveFilters: Bool {
        messageSearch != nil || author != nil || committer != nil ||
        since != nil || until != nil || filePath != nil
    }
}

/// Command to get commit history.
struct LogCommand: GitCommand {
    typealias Result = [Commit]

    /// Maximum number of commits to retrieve.
    let limit: Int

    /// Optional branch or ref to get history for.
    let ref: String?

    /// Optional file path to get history for.
    let filePath: String?

    init(limit: Int = 100, ref: String? = nil, filePath: String? = nil) {
        self.limit = limit
        self.ref = ref
        self.filePath = filePath
    }

    var arguments: [String] {
        var args = [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", String(limit)
        ]

        if let ref {
            args.append(ref)
        }

        if let filePath {
            args.append("--")
            args.append(filePath)
        }

        return args
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to get commit history with full filter options.
struct LogWithFiltersCommand: GitCommand {
    typealias Result = [Commit]

    /// Maximum number of commits to retrieve.
    let limit: Int

    /// Filter options.
    let filters: LogFilterOptions

    init(limit: Int = 100, filters: LogFilterOptions = LogFilterOptions()) {
        self.limit = limit
        self.filters = filters
    }

    var arguments: [String] {
        var args = [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", String(limit)
        ]

        // Skip for pagination
        if filters.skip > 0 {
            args.append("--skip=\(filters.skip)")
        }

        // Message search (grep)
        if let messageSearch = filters.messageSearch, !messageSearch.isEmpty {
            args.append("--grep=\(messageSearch)")

            if filters.caseInsensitive {
                args.append("-i")
            }

            if filters.extendedRegex {
                args.append("-E")
            }
        }

        // Author filter
        if let author = filters.author, !author.isEmpty {
            args.append("--author=\(author)")
        }

        // Committer filter
        if let committer = filters.committer, !committer.isEmpty {
            args.append("--committer=\(committer)")
        }

        // Date range filters
        let dateFormatter = ISO8601DateFormatter()

        if let since = filters.since {
            args.append("--since=\(dateFormatter.string(from: since))")
        }

        if let until = filters.until {
            args.append("--until=\(dateFormatter.string(from: until))")
        }

        // All refs
        if filters.allRefs {
            args.append("--all")
        }

        // Ref
        if let ref = filters.ref {
            args.append(ref)
        }

        // File path
        if let filePath = filters.filePath {
            args.append("--")
            args.append(filePath)
        }

        return args
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to search commits by message.
struct SearchCommitsCommand: GitCommand {
    typealias Result = [Commit]

    let searchQuery: String
    let limit: Int
    let caseInsensitive: Bool

    init(searchQuery: String, limit: Int = 100, caseInsensitive: Bool = true) {
        self.searchQuery = searchQuery
        self.limit = limit
        self.caseInsensitive = caseInsensitive
    }

    var arguments: [String] {
        var args = [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", String(limit),
            "--grep=\(searchQuery)"
        ]

        if caseInsensitive {
            args.append("-i")
        }

        return args
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to get commits by a specific author.
struct AuthorCommitsCommand: GitCommand {
    typealias Result = [Commit]

    let author: String
    let limit: Int

    init(author: String, limit: Int = 100) {
        self.author = author
        self.limit = limit
    }

    var arguments: [String] {
        [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", String(limit),
            "--author=\(author)"
        ]
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to get commits in a date range.
struct DateRangeCommitsCommand: GitCommand {
    typealias Result = [Commit]

    let since: Date?
    let until: Date?
    let limit: Int

    init(since: Date? = nil, until: Date? = nil, limit: Int = 100) {
        self.since = since
        self.until = until
        self.limit = limit
    }

    var arguments: [String] {
        var args = [
            "log",
            "--format=\(LogParser.formatString)",
            "-n", String(limit)
        ]

        let dateFormatter = ISO8601DateFormatter()

        if let since = since {
            args.append("--since=\(dateFormatter.string(from: since))")
        }

        if let until = until {
            args.append("--until=\(dateFormatter.string(from: until))")
        }

        return args
    }

    func parse(output: String) throws -> [Commit] {
        try LogParser.parse(output)
    }
}

/// Command to get a single commit by hash.
struct ShowCommitCommand: GitCommand {
    typealias Result = Commit

    let commitHash: String

    var arguments: [String] {
        ["show", "--format=\(LogParser.formatString)", "-s", commitHash]
    }

    func parse(output: String) throws -> Commit {
        let commits = try LogParser.parse(output)
        guard let commit = commits.first else {
            throw GitError.commitNotFound(hash: commitHash)
        }
        return commit
    }
}

/// Command to get the current HEAD commit hash.
struct HeadCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["rev-parse", "HEAD"]
    }

    func parse(output: String) throws -> String? {
        let hash = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? nil : hash
    }
}
