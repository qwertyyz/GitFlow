import Foundation

/// Command to check if Git LFS is installed.
struct LFSVersionCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["lfs", "version"]
    }

    func parse(output: String) throws -> String? {
        // Output: "git-lfs/3.4.0 (GitHub; darwin arm64; go 1.21.0)"
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// Command to initialize Git LFS in a repository.
struct LFSInstallCommand: GitCommand {
    typealias Result = Bool

    var arguments: [String] {
        ["lfs", "install"]
    }

    func parse(output: String) throws -> Bool {
        // Success output contains "Updated" or "Git LFS initialized"
        output.contains("Updated") || output.contains("initialized")
    }
}

/// Command to track files with Git LFS.
struct LFSTrackCommand: GitCommand {
    typealias Result = Bool
    let pattern: String

    var arguments: [String] {
        ["lfs", "track", pattern]
    }

    func parse(output: String) throws -> Bool {
        // Success: "Tracking \"*.psd\""
        output.contains("Tracking")
    }
}

/// Command to untrack files from Git LFS.
struct LFSUntrackCommand: GitCommand {
    typealias Result = Bool
    let pattern: String

    var arguments: [String] {
        ["lfs", "untrack", pattern]
    }

    func parse(output: String) throws -> Bool {
        // Success: "Untracking \"*.psd\""
        output.contains("Untracking")
    }
}

/// Command to list LFS tracking patterns.
struct LFSTrackListCommand: GitCommand {
    typealias Result = [LFSTrackingPattern]

    var arguments: [String] {
        ["lfs", "track"]
    }

    func parse(output: String) throws -> [LFSTrackingPattern] {
        // Output format:
        // Listing tracked patterns
        //     *.psd (.gitattributes)
        //     *.png (.gitattributes)

        var patterns: [LFSTrackingPattern] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip header line
            if trimmed.starts(with: "Listing") || trimmed.isEmpty {
                continue
            }

            // Parse pattern: "*.psd (.gitattributes)"
            if let parenIndex = trimmed.firstIndex(of: "(") {
                let pattern = String(trimmed[..<parenIndex]).trimmingCharacters(in: .whitespaces)
                if !pattern.isEmpty {
                    patterns.append(LFSTrackingPattern(
                        pattern: pattern,
                        filter: "lfs",
                        diffDisabled: true,
                        mergeDisabled: true
                    ))
                }
            }
        }

        return patterns
    }
}

/// Command to get LFS file status.
struct LFSStatusCommand: GitCommand {
    typealias Result = [LFSFile]

    var arguments: [String] {
        ["lfs", "status"]
    }

    func parse(output: String) throws -> [LFSFile] {
        // Output format:
        // On branch main
        // Objects to be committed:
        //
        //     assets/image.png (LFS: abcdef1)
        //
        // Objects not staged for commit:
        //
        //     assets/modified.png (File: 1234567)

        var files: [LFSFile] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip headers and empty lines
            if trimmed.isEmpty ||
               trimmed.starts(with: "On branch") ||
               trimmed.starts(with: "Objects") ||
               trimmed.starts(with: "Git LFS") {
                continue
            }

            // Parse file entry
            if let file = parseLFSFileLine(trimmed) {
                files.append(file)
            }
        }

        return files
    }

    private func parseLFSFileLine(_ line: String) -> LFSFile? {
        // Format: "path/to/file.ext (LFS: abc123)" or "path/to/file.ext (File: abc123)"
        guard let parenStart = line.firstIndex(of: "("),
              let parenEnd = line.lastIndex(of: ")") else {
            return nil
        }

        let path = String(line[..<parenStart]).trimmingCharacters(in: .whitespaces)
        let info = String(line[line.index(after: parenStart)..<parenEnd])

        let isLFS = info.starts(with: "LFS:")
        let oid = info.split(separator: ":").last.map { String($0).trimmingCharacters(in: .whitespaces) }

        return LFSFile(
            path: path,
            oid: oid,
            size: nil,
            status: isLFS ? .tracked : .modified,
            isDownloaded: isLFS
        )
    }
}

/// Command to list LFS files in the repository.
struct LFSLsFilesCommand: GitCommand {
    typealias Result = [LFSFile]
    let includeSize: Bool

    init(includeSize: Bool = false) {
        self.includeSize = includeSize
    }

    var arguments: [String] {
        var args = ["lfs", "ls-files"]
        if includeSize {
            args.append("--size")
        }
        return args
    }

    func parse(output: String) throws -> [LFSFile] {
        // Output format without --size:
        // abc123def4 * path/to/file.ext
        // abc123def4 - path/to/other.ext

        // Output format with --size:
        // abc123def4 * path/to/file.ext (1.2 MB)
        // abc123def4 - path/to/other.ext (500 KB)

        var files: [LFSFile] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let file = parseLsFileLine(String(trimmed)) {
                files.append(file)
            }
        }

        return files
    }

    private func parseLsFileLine(_ line: String) -> LFSFile? {
        // Format: "abc123def4 * path/to/file.ext" or "abc123def4 - path/to/file.ext (1.2 MB)"
        let parts = line.split(separator: " ", maxSplits: 2)
        guard parts.count >= 3 else { return nil }

        let oid = String(parts[0])
        let downloadIndicator = String(parts[1])
        var pathAndSize = String(parts[2])

        let isDownloaded = downloadIndicator == "*"

        // Extract size if present
        var size: Int64?
        if let sizeStart = pathAndSize.lastIndex(of: "("),
           let sizeEnd = pathAndSize.lastIndex(of: ")") {
            let sizeStr = String(pathAndSize[pathAndSize.index(after: sizeStart)..<sizeEnd])
            size = parseSize(sizeStr)
            pathAndSize = String(pathAndSize[..<sizeStart]).trimmingCharacters(in: .whitespaces)
        }

        return LFSFile(
            path: pathAndSize,
            oid: oid,
            size: size,
            status: isDownloaded ? .tracked : .pointer,
            isDownloaded: isDownloaded
        )
    }

    private func parseSize(_ sizeStr: String) -> Int64? {
        let parts = sizeStr.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard parts.count == 2,
              let value = Double(parts[0]) else {
            return nil
        }

        let unit = String(parts[1]).uppercased()
        let multiplier: Int64
        switch unit {
        case "B": multiplier = 1
        case "KB": multiplier = 1024
        case "MB": multiplier = 1024 * 1024
        case "GB": multiplier = 1024 * 1024 * 1024
        case "TB": multiplier = 1024 * 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return Int64(value * Double(multiplier))
    }
}

/// Command to fetch LFS objects.
struct LFSFetchCommand: GitCommand {
    typealias Result = Bool
    let all: Bool
    let recent: Bool

    init(all: Bool = false, recent: Bool = false) {
        self.all = all
        self.recent = recent
    }

    var arguments: [String] {
        var args = ["lfs", "fetch"]
        if all {
            args.append("--all")
        }
        if recent {
            args.append("--recent")
        }
        return args
    }

    func parse(output: String) throws -> Bool {
        // Fetch typically outputs progress, consider success if no error
        true
    }
}

/// Command to pull LFS objects.
struct LFSPullCommand: GitCommand {
    typealias Result = Bool

    var arguments: [String] {
        ["lfs", "pull"]
    }

    func parse(output: String) throws -> Bool {
        true
    }
}

/// Command to push LFS objects.
struct LFSPushCommand: GitCommand {
    typealias Result = Bool
    let remote: String
    let all: Bool

    init(remote: String = "origin", all: Bool = false) {
        self.remote = remote
        self.all = all
    }

    var arguments: [String] {
        var args = ["lfs", "push", remote]
        if all {
            args.append("--all")
        }
        return args
    }

    func parse(output: String) throws -> Bool {
        true
    }
}

/// Command to prune old LFS objects.
struct LFSPruneCommand: GitCommand {
    typealias Result = String
    let dryRun: Bool
    let verifyRemote: Bool

    init(dryRun: Bool = false, verifyRemote: Bool = true) {
        self.dryRun = dryRun
        self.verifyRemote = verifyRemote
    }

    var arguments: [String] {
        var args = ["lfs", "prune"]
        if dryRun {
            args.append("--dry-run")
        }
        if verifyRemote {
            args.append("--verify-remote")
        }
        return args
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to migrate files to LFS.
struct LFSMigrateCommand: GitCommand {
    typealias Result = Bool
    let pattern: String
    let everything: Bool

    init(pattern: String, everything: Bool = false) {
        self.pattern = pattern
        self.everything = everything
    }

    var arguments: [String] {
        var args = ["lfs", "migrate", "import", "--include=\(pattern)"]
        if everything {
            args.append("--everything")
        }
        return args
    }

    func parse(output: String) throws -> Bool {
        // Migration rewrites history, success if no fatal error
        !output.contains("fatal:")
    }
}

/// Command to check LFS environment.
struct LFSEnvCommand: GitCommand {
    typealias Result = [String: String]

    var arguments: [String] {
        ["lfs", "env"]
    }

    func parse(output: String) throws -> [String: String] {
        // Output format:
        // git-lfs/3.4.0 (GitHub; darwin arm64; go 1.21.0)
        // git version 2.43.0
        //
        // Endpoint=https://github.com/owner/repo.git/info/lfs (auth=none)
        //   SSH=git@github.com:owner/repo.git
        // ...

        var env: [String: String] = [:]
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "git-lfs/") {
                env["version"] = trimmed
            } else if trimmed.starts(with: "Endpoint=") {
                let value = String(trimmed.dropFirst("Endpoint=".count))
                env["endpoint"] = value
            } else if trimmed.contains("=") && !trimmed.starts(with: " ") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    env[String(parts[0])] = String(parts[1])
                }
            }
        }

        return env
    }
}
