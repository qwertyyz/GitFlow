import Foundation

/// Service for git-svn operations, enabling Git to work with Subversion repositories.
actor GitSVNService {
    static let shared = GitSVNService()

    private init() {}

    // MARK: - Clone from SVN

    /// Clone a Subversion repository using git-svn
    func clone(
        svnURL: String,
        destination: URL,
        options: SVNCloneOptions = SVNCloneOptions()
    ) async throws -> SVNCloneResult {
        var arguments = ["svn", "clone"]

        // Standard layout (trunk, branches, tags)
        if options.useStandardLayout {
            arguments.append("--stdlayout")
        } else {
            if let trunk = options.trunkPath {
                arguments.append(contentsOf: ["--trunk=\(trunk)"])
            }
            if let branches = options.branchesPath {
                arguments.append(contentsOf: ["--branches=\(branches)"])
            }
            if let tags = options.tagsPath {
                arguments.append(contentsOf: ["--tags=\(tags)"])
            }
        }

        // Revision range
        if let startRevision = options.startRevision {
            if let endRevision = options.endRevision {
                arguments.append(contentsOf: ["-r", "\(startRevision):\(endRevision)"])
            } else {
                arguments.append(contentsOf: ["-r", "\(startRevision):HEAD"])
            }
        }

        // Username
        if let username = options.username {
            arguments.append(contentsOf: ["--username=\(username)"])
        }

        // Prefix for remote refs
        if let prefix = options.prefix {
            arguments.append(contentsOf: ["--prefix=\(prefix)"])
        }

        // Include metadata
        if options.includeMetadata {
            arguments.append("--metadata")
        }

        // No minimize URL
        if options.noMinimizeURL {
            arguments.append("--no-minimize-url")
        }

        arguments.append(svnURL)
        arguments.append(destination.path)

        let result = try await runGitCommand(arguments: arguments, at: destination.deletingLastPathComponent())

        return SVNCloneResult(
            success: result.exitCode == 0,
            repositoryPath: destination,
            output: result.output,
            error: result.error
        )
    }

    // MARK: - SVN Fetch

    /// Fetch new revisions from Subversion
    func fetch(
        in repository: URL,
        options: SVNFetchOptions = SVNFetchOptions()
    ) async throws -> SVNFetchResult {
        var arguments = ["svn", "fetch"]

        // Fetch from all remotes
        if options.fetchAll {
            arguments.append("--all")
        }

        // Specific remote
        if let remote = options.remote {
            arguments.append(remote)
        }

        // Parent fetch (for multi-branch)
        if options.parent {
            arguments.append("--parent")
        }

        // Revision range
        if let revision = options.revision {
            arguments.append(contentsOf: ["-r", revision])
        }

        // Ignore paths
        for ignorePath in options.ignorePaths {
            arguments.append(contentsOf: ["--ignore-paths=\(ignorePath)"])
        }

        let result = try await runGitCommand(arguments: arguments, at: repository)

        // Parse fetched revisions from output
        let fetchedRevisions = parseFetchedRevisions(from: result.output)

        return SVNFetchResult(
            success: result.exitCode == 0,
            fetchedRevisions: fetchedRevisions,
            output: result.output,
            error: result.error
        )
    }

    /// Fetch and rebase in one operation
    func rebase(
        in repository: URL,
        options: SVNRebaseOptions = SVNRebaseOptions()
    ) async throws -> SVNRebaseResult {
        var arguments = ["svn", "rebase"]

        // Local branch
        if options.local {
            arguments.append("--local")
        }

        // Fetch before rebase
        if options.fetch {
            arguments.append("--fetch")
        }

        // Dry run
        if options.dryRun {
            arguments.append("--dry-run")
        }

        let result = try await runGitCommand(arguments: arguments, at: repository)

        return SVNRebaseResult(
            success: result.exitCode == 0,
            updatedRevisions: parseFetchedRevisions(from: result.output),
            output: result.output,
            error: result.error,
            hasConflicts: result.output.contains("CONFLICT") || result.error.contains("CONFLICT")
        )
    }

    // MARK: - SVN DCommit

    /// Push commits to Subversion
    func dcommit(
        in repository: URL,
        options: SVNDCommitOptions = SVNDCommitOptions()
    ) async throws -> SVNDCommitResult {
        var arguments = ["svn", "dcommit"]

        // Dry run
        if options.dryRun {
            arguments.append("--dry-run")
        }

        // No rebase after commit
        if options.noRebase {
            arguments.append("--no-rebase")
        }

        // Commit URL (for non-standard layouts)
        if let commitURL = options.commitURL {
            arguments.append(contentsOf: ["--commit-url=\(commitURL)"])
        }

        // Edit commit message
        if options.edit {
            arguments.append("--edit")
        }

        // Interactive
        if options.interactive {
            arguments.append("--interactive")
        }

        // Specific revision range
        if let revision = options.revision {
            arguments.append(revision)
        }

        let result = try await runGitCommand(arguments: arguments, at: repository)

        // Parse committed revisions
        let committedRevisions = parseCommittedRevisions(from: result.output)

        return SVNDCommitResult(
            success: result.exitCode == 0,
            committedRevisions: committedRevisions,
            output: result.output,
            error: result.error
        )
    }

    // MARK: - SVN Info

    /// Get SVN repository information
    func info(in repository: URL) async throws -> SVNInfo? {
        let arguments = ["svn", "info"]
        let result = try await runGitCommand(arguments: arguments, at: repository)

        guard result.exitCode == 0 else {
            return nil
        }

        return parseSVNInfo(from: result.output)
    }

    /// Get SVN log
    func log(
        in repository: URL,
        limit: Int = 25,
        revision: String? = nil
    ) async throws -> [SVNLogEntry] {
        var arguments = ["svn", "log", "--oneline", "-\(limit)"]

        if let rev = revision {
            arguments.append(contentsOf: ["-r", rev])
        }

        let result = try await runGitCommand(arguments: arguments, at: repository)

        guard result.exitCode == 0 else {
            return []
        }

        return parseSVNLog(from: result.output)
    }

    // MARK: - Branch Management

    /// Create a new SVN branch
    func createBranch(
        name: String,
        message: String,
        in repository: URL
    ) async throws -> Bool {
        let arguments = ["svn", "branch", "-m", message, name]
        let result = try await runGitCommand(arguments: arguments, at: repository)
        return result.exitCode == 0
    }

    /// Create a new SVN tag
    func createTag(
        name: String,
        message: String,
        in repository: URL
    ) async throws -> Bool {
        let arguments = ["svn", "tag", "-m", message, name]
        let result = try await runGitCommand(arguments: arguments, at: repository)
        return result.exitCode == 0
    }

    /// List SVN remotes
    func listRemotes(in repository: URL) async throws -> [String] {
        let arguments = ["svn", "show-externals"]
        let result = try await runGitCommand(arguments: arguments, at: repository)

        guard result.exitCode == 0 else {
            return []
        }

        return result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // MARK: - Utilities

    /// Check if repository is a git-svn clone
    func isSVNRepository(at path: URL) async -> Bool {
        let svnDir = path.appendingPathComponent(".git/svn")
        return FileManager.default.fileExists(atPath: svnDir.path)
    }

    /// Reset to specific SVN revision
    func reset(
        to revision: String,
        in repository: URL
    ) async throws -> Bool {
        let arguments = ["svn", "reset", "-r", revision]
        let result = try await runGitCommand(arguments: arguments, at: repository)
        return result.exitCode == 0
    }

    // MARK: - Private Helpers

    private func runGitCommand(arguments: [String], at directory: URL) async throws -> GitCommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = directory

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                continuation.resume(returning: GitCommandResult(
                    exitCode: Int(process.terminationStatus),
                    output: output,
                    error: error
                ))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseFetchedRevisions(from output: String) -> [Int] {
        // Parse revision numbers from git svn fetch output
        // Example: "r123 = abc123def..."
        let pattern = #"r(\d+)\s*="#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..., in: output)

        var revisions: [Int] = []
        regex?.enumerateMatches(in: output, range: range) { match, _, _ in
            if let match = match,
               let revRange = Range(match.range(at: 1), in: output),
               let revision = Int(output[revRange]) {
                revisions.append(revision)
            }
        }

        return revisions
    }

    private func parseCommittedRevisions(from output: String) -> [Int] {
        // Parse committed revisions from dcommit output
        // Example: "Committed r456"
        let pattern = #"Committed r(\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..., in: output)

        var revisions: [Int] = []
        regex?.enumerateMatches(in: output, range: range) { match, _, _ in
            if let match = match,
               let revRange = Range(match.range(at: 1), in: output),
               let revision = Int(output[revRange]) {
                revisions.append(revision)
            }
        }

        return revisions
    }

    private func parseSVNInfo(from output: String) -> SVNInfo? {
        var url: String?
        var repositoryRoot: String?
        var repositoryUUID: String?
        var revision: Int?
        var lastChangedAuthor: String?
        var lastChangedRevision: Int?
        var lastChangedDate: String?

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }

            switch parts[0] {
            case "URL":
                url = parts[1]
            case "Repository Root":
                repositoryRoot = parts[1]
            case "Repository UUID":
                repositoryUUID = parts[1]
            case "Revision":
                revision = Int(parts[1])
            case "Last Changed Author":
                lastChangedAuthor = parts[1]
            case "Last Changed Rev":
                lastChangedRevision = Int(parts[1])
            case "Last Changed Date":
                lastChangedDate = parts[1]
            default:
                break
            }
        }

        guard let url = url else { return nil }

        return SVNInfo(
            url: url,
            repositoryRoot: repositoryRoot,
            repositoryUUID: repositoryUUID,
            revision: revision ?? 0,
            lastChangedAuthor: lastChangedAuthor,
            lastChangedRevision: lastChangedRevision,
            lastChangedDate: lastChangedDate
        )
    }

    private func parseSVNLog(from output: String) -> [SVNLogEntry] {
        var entries: [SVNLogEntry] = []

        for line in output.components(separatedBy: "\n") {
            // Parse format: "r123 | author | message"
            let parts = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                let revString = parts[0].replacingOccurrences(of: "r", with: "")
                if let revision = Int(revString) {
                    entries.append(SVNLogEntry(
                        revision: revision,
                        author: parts.count > 1 ? parts[1] : nil,
                        message: parts.count > 2 ? parts[2] : nil,
                        date: nil
                    ))
                }
            }
        }

        return entries
    }
}

// MARK: - Data Models

struct SVNCloneOptions {
    var useStandardLayout: Bool = true
    var trunkPath: String?
    var branchesPath: String?
    var tagsPath: String?
    var startRevision: Int?
    var endRevision: Int?
    var username: String?
    var prefix: String?
    var includeMetadata: Bool = true
    var noMinimizeURL: Bool = false
}

struct SVNCloneResult {
    let success: Bool
    let repositoryPath: URL
    let output: String
    let error: String
}

struct SVNFetchOptions {
    var fetchAll: Bool = false
    var remote: String?
    var parent: Bool = false
    var revision: String?
    var ignorePaths: [String] = []
}

struct SVNFetchResult {
    let success: Bool
    let fetchedRevisions: [Int]
    let output: String
    let error: String

    var newRevisionCount: Int {
        fetchedRevisions.count
    }
}

struct SVNRebaseOptions {
    var local: Bool = false
    var fetch: Bool = true
    var dryRun: Bool = false
}

struct SVNRebaseResult {
    let success: Bool
    let updatedRevisions: [Int]
    let output: String
    let error: String
    let hasConflicts: Bool
}

struct SVNDCommitOptions {
    var dryRun: Bool = false
    var noRebase: Bool = false
    var commitURL: String?
    var edit: Bool = false
    var interactive: Bool = false
    var revision: String?
}

struct SVNDCommitResult {
    let success: Bool
    let committedRevisions: [Int]
    let output: String
    let error: String

    var commitCount: Int {
        committedRevisions.count
    }
}

struct SVNInfo {
    let url: String
    let repositoryRoot: String?
    let repositoryUUID: String?
    let revision: Int
    let lastChangedAuthor: String?
    let lastChangedRevision: Int?
    let lastChangedDate: String?
}

struct SVNLogEntry: Identifiable {
    var id: Int { revision }
    let revision: Int
    let author: String?
    let message: String?
    let date: String?
}

struct GitCommandResult {
    let exitCode: Int
    let output: String
    let error: String
}

// MARK: - SVN Clone Dialog

import SwiftUI

struct SVNCloneView: View {
    @StateObject private var viewModel = SVNCloneViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Clone from Subversion")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section("Repository") {
                    TextField("SVN URL", text: $viewModel.svnURL)
                        .textFieldStyle(.roundedBorder)

                    Text("Example: https://svn.example.com/repo/trunk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Clone Location") {
                    HStack {
                        TextField("Destination", text: $viewModel.destinationPath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        Button("Browse...") {
                            viewModel.selectDestination()
                        }
                    }
                }

                Section("Layout") {
                    Picker("Repository layout", selection: $viewModel.useStandardLayout) {
                        Text("Standard (trunk/branches/tags)").tag(true)
                        Text("Custom").tag(false)
                    }
                    .pickerStyle(.radioGroup)

                    if !viewModel.useStandardLayout {
                        TextField("Trunk path", text: $viewModel.trunkPath)
                            .textFieldStyle(.roundedBorder)
                        TextField("Branches path", text: $viewModel.branchesPath)
                            .textFieldStyle(.roundedBorder)
                        TextField("Tags path", text: $viewModel.tagsPath)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Options") {
                    Toggle("Fetch full history", isOn: $viewModel.fetchFullHistory)

                    if !viewModel.fetchFullHistory {
                        HStack {
                            Text("Start from revision:")
                            TextField("Revision", value: $viewModel.startRevision, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    TextField("Username (optional)", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = viewModel.error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                if viewModel.isCloning {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Cloning repository...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !viewModel.cloneOutput.isEmpty {
                            Text(viewModel.cloneOutput)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(5)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Clone") {
                    viewModel.clone {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canClone)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
    }
}

@MainActor
class SVNCloneViewModel: ObservableObject {
    @Published var svnURL: String = ""
    @Published var destinationPath: String = ""
    @Published var useStandardLayout: Bool = true
    @Published var trunkPath: String = "trunk"
    @Published var branchesPath: String = "branches"
    @Published var tagsPath: String = "tags"
    @Published var fetchFullHistory: Bool = false
    @Published var startRevision: Int = 1
    @Published var username: String = ""
    @Published var isCloning: Bool = false
    @Published var cloneOutput: String = ""
    @Published var error: String?

    private let svnService = GitSVNService.shared

    var canClone: Bool {
        !svnURL.isEmpty &&
        !destinationPath.isEmpty &&
        !isCloning
    }

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        destinationPath = documentsPath.appendingPathComponent("SVNClone").path
    }

    func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
        }
    }

    func clone(completion: @escaping () -> Void) {
        isCloning = true
        error = nil
        cloneOutput = ""

        Task {
            do {
                var options = SVNCloneOptions()
                options.useStandardLayout = useStandardLayout

                if !useStandardLayout {
                    options.trunkPath = trunkPath.isEmpty ? nil : trunkPath
                    options.branchesPath = branchesPath.isEmpty ? nil : branchesPath
                    options.tagsPath = tagsPath.isEmpty ? nil : tagsPath
                }

                if !fetchFullHistory {
                    options.startRevision = startRevision
                }

                if !username.isEmpty {
                    options.username = username
                }

                let result = try await svnService.clone(
                    svnURL: svnURL,
                    destination: URL(fileURLWithPath: destinationPath),
                    options: options
                )

                await MainActor.run {
                    if result.success {
                        completion()
                    } else {
                        error = result.error.isEmpty ? "Clone failed" : result.error
                    }
                    isCloning = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCloning = false
                }
            }
        }
    }
}

#Preview {
    SVNCloneView()
}
