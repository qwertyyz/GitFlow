import Foundation

/// Main facade for Git operations.
/// Provides a high-level interface for all Git commands.
actor GitService {
    let executor: GitExecutor

    init(executor: GitExecutor = GitExecutor()) {
        self.executor = executor
    }

    // MARK: - Repository Operations

    /// Checks if the specified path is inside a Git repository.
    func isGitRepository(at url: URL) async throws -> Bool {
        let command = IsRepositoryCommand()
        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: url
        )
        return result.succeeded && (try? command.parse(output: result.stdout)) == true
    }

    /// Gets the root directory of the repository.
    func getRepositoryRoot(at url: URL) async throws -> URL {
        let command = GetRootCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: url
        )
        let path = try command.parse(output: output)
        return URL(fileURLWithPath: path)
    }

    // MARK: - Status Operations

    /// Gets the current working tree status.
    func getStatus(in repository: Repository) async throws -> WorkingTreeStatus {
        let command = StatusCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        let files = try command.parse(output: output)
        return WorkingTreeStatus.from(files: files)
    }

    // MARK: - Staging Operations

    /// Stages the specified files.
    func stage(files: [String], in repository: Repository) async throws {
        guard !files.isEmpty else { return }
        let command = StageCommand(paths: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Stages all changes.
    func stageAll(in repository: Repository) async throws {
        let command = StageAllCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Unstages the specified files.
    func unstage(files: [String], in repository: Repository) async throws {
        guard !files.isEmpty else { return }
        let command = UnstageCommand(paths: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Unstages all files.
    func unstageAll(in repository: Repository) async throws {
        let command = UnstageAllCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Discards changes in the specified files.
    func discardChanges(files: [String], in repository: Repository) async throws {
        guard !files.isEmpty else { return }
        let command = DiscardChangesCommand(paths: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Stages a specific hunk from a file.
    /// - Parameters:
    ///   - hunk: The hunk to stage.
    ///   - filePath: The path of the file containing the hunk.
    ///   - repository: The repository.
    func stageHunk(_ hunk: DiffHunk, filePath: String, in repository: Repository) async throws {
        let patchContent = hunk.toPatchString(filePath: filePath)
        let command = StageHunkCommand()
        _ = try await executor.executeWithStdinOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            stdinContent: patchContent
        )
    }

    /// Unstages a specific hunk from a file.
    /// - Parameters:
    ///   - hunk: The hunk to unstage.
    ///   - filePath: The path of the file containing the hunk.
    ///   - repository: The repository.
    func unstageHunk(_ hunk: DiffHunk, filePath: String, in repository: Repository) async throws {
        let patchContent = hunk.toPatchString(filePath: filePath)
        let command = UnstageHunkCommand()
        _ = try await executor.executeWithStdinOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            stdinContent: patchContent
        )
    }

    /// Stages specific lines from a hunk.
    /// - Parameters:
    ///   - hunk: The hunk containing the lines.
    ///   - lineIds: The IDs of lines to stage.
    ///   - filePath: The path of the file containing the hunk.
    ///   - repository: The repository.
    func stageLines(_ hunk: DiffHunk, lineIds: Set<String>, filePath: String, in repository: Repository) async throws {
        guard let patchContent = hunk.toPatchString(filePath: filePath, selectedLineIds: lineIds, forStaging: true) else {
            throw GitError.unknown(message: "No valid lines to stage")
        }
        let command = StageHunkCommand()
        _ = try await executor.executeWithStdinOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            stdinContent: patchContent
        )
    }

    /// Unstages specific lines from a hunk.
    /// - Parameters:
    ///   - hunk: The hunk containing the lines.
    ///   - lineIds: The IDs of lines to unstage.
    ///   - filePath: The path of the file containing the hunk.
    ///   - repository: The repository.
    func unstageLines(_ hunk: DiffHunk, lineIds: Set<String>, filePath: String, in repository: Repository) async throws {
        guard let patchContent = hunk.toPatchString(filePath: filePath, selectedLineIds: lineIds, forStaging: false) else {
            throw GitError.unknown(message: "No valid lines to unstage")
        }
        let command = UnstageHunkCommand()
        _ = try await executor.executeWithStdinOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            stdinContent: patchContent
        )
    }

    // MARK: - Diff Operations

    /// Gets the diff for staged changes.
    func getStagedDiff(in repository: Repository, filePath: String? = nil, options: DiffOptions = DiffOptions()) async throws -> [FileDiff] {
        let command = StagedDiffCommand(filePath: filePath, options: options)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the diff for unstaged changes.
    func getUnstagedDiff(in repository: Repository, filePath: String? = nil, options: DiffOptions = DiffOptions()) async throws -> [FileDiff] {
        let command = UnstagedDiffCommand(filePath: filePath, options: options)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the diff for a specific commit.
    func getCommitDiff(commitHash: String, in repository: Repository, options: DiffOptions = DiffOptions()) async throws -> [FileDiff] {
        let command = ShowCommitDiffCommand(commitHash: commitHash, options: options)
        // Use longer timeout for commit diffs as they can be large
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL,
            timeout: 120.0
        )
        return try command.parse(output: output)
    }

    // MARK: - Blame Operations

    /// Gets blame information for a file.
    /// - Parameters:
    ///   - filePath: The path to the file.
    ///   - startLine: Optional start line for range.
    ///   - endLine: Optional end line for range.
    ///   - repository: The repository.
    /// - Returns: Array of blame lines.
    func getBlame(for filePath: String, startLine: Int? = nil, endLine: Int? = nil, in repository: Repository) async throws -> [BlameLine] {
        let command = BlameCommand(filePath: filePath, startLine: startLine, endLine: endLine)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    // MARK: - Patch Operations

    /// Generates a patch for staged changes.
    func getStagedPatch(in repository: Repository, filePath: String? = nil) async throws -> String {
        let command = GenerateStagedPatchCommand(filePath: filePath)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Generates a patch for unstaged changes.
    func getUnstagedPatch(in repository: Repository, filePath: String? = nil) async throws -> String {
        let command = GenerateUnstagedPatchCommand(filePath: filePath)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Generates a patch for a commit.
    func getCommitPatch(commitHash: String, in repository: Repository) async throws -> String {
        let command = GenerateCommitPatchCommand(commitHash: commitHash)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Reverts changes in specified files.
    func revertFiles(_ files: [String], in repository: Repository) async throws {
        let command = RevertFilesCommand(files: files)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Merge Conflict Operations

    /// Checks if the repository is currently in a merge state.
    func isMerging(in repository: Repository) async -> Bool {
        let mergeHeadURL = repository.rootURL.appendingPathComponent(".git/MERGE_HEAD")
        return FileManager.default.fileExists(atPath: mergeHeadURL.path)
    }

    /// Gets the list of conflicted files.
    func getConflictedFiles(in repository: Repository) async throws -> [ConflictedFile] {
        let command = GetUnmergedStatusCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the current merge state.
    func getMergeState(in repository: Repository) async throws -> MergeState {
        let currentBranch = try await getCurrentBranch(in: repository)
        let conflictedFiles = try await getConflictedFiles(in: repository)

        // Try to get the branch being merged
        var mergingBranch: String?
        let mergeCommand = GetMergingBranchCommand()
        if let output = try? await executor.executeOrThrow(
            arguments: mergeCommand.arguments,
            workingDirectory: repository.rootURL
        ) {
            mergingBranch = try? mergeCommand.parse(output: output)
        }

        return MergeState(
            mergingBranch: mergingBranch,
            currentBranch: currentBranch,
            conflictedFiles: conflictedFiles
        )
    }

    /// Gets the content of a file at a specific merge stage.
    /// - Parameters:
    ///   - stage: 1 = base (common ancestor), 2 = ours, 3 = theirs
    ///   - filePath: The file path.
    ///   - repository: The repository.
    /// - Returns: The file content at that stage.
    func getMergeStageContent(stage: Int, filePath: String, in repository: Repository) async throws -> String {
        let command = GetMergeStageContentCommand(stage: stage, filePath: filePath)
        return try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Uses "ours" version to resolve a conflict.
    func useOursVersion(for filePath: String, in repository: Repository) async throws {
        let command = UseOursVersionCommand(filePath: filePath)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Uses "theirs" version to resolve a conflict.
    func useTheirsVersion(for filePath: String, in repository: Repository) async throws {
        let command = UseTheirsVersionCommand(filePath: filePath)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Marks a file as resolved by staging it.
    func markConflictResolved(filePath: String, in repository: Repository) async throws {
        let command = MarkConflictResolvedCommand(filePath: filePath)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Reads the current content of a file (with conflict markers).
    func readFileContent(at filePath: String, in repository: Repository) async throws -> String {
        let fileURL = repository.rootURL.appendingPathComponent(filePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    /// Writes resolved content to a file.
    func writeFileContent(_ content: String, to filePath: String, in repository: Repository) async throws {
        let fileURL = repository.rootURL.appendingPathComponent(filePath)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Commit Operations

    /// Creates a new commit with the specified message.
    func commit(message: String, in repository: Repository) async throws {
        let command = CreateCommitCommand(message: message)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Creates a commit with full options.
    /// - Parameters:
    ///   - options: The commit options.
    ///   - repository: The repository.
    func commitWithOptions(_ options: CommitOptions, in repository: Repository) async throws {
        let command = CreateCommitWithOptionsCommand(options: options)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Amends the last commit with a new message.
    /// - Parameters:
    ///   - message: The new commit message.
    ///   - repository: The repository.
    func amendCommit(message: String, in repository: Repository) async throws {
        var options = CommitOptions(message: message)
        options.amend = true
        try await commitWithOptions(options, in: repository)
    }

    /// Amends the last commit without changing the message.
    /// - Parameter repository: The repository.
    func amendCommitNoEdit(in repository: Repository) async throws {
        var options = CommitOptions()
        options.amend = true
        options.noEdit = true
        try await commitWithOptions(options, in: repository)
    }

    /// Gets the last commit message.
    /// - Parameter repository: The repository.
    /// - Returns: The last commit message.
    func getLastCommitMessage(in repository: Repository) async throws -> String {
        let command = GetLastCommitMessageCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Checks if GPG signing is configured.
    /// - Parameter repository: The repository.
    /// - Returns: True if GPG signing is configured.
    func isGPGSigningConfigured(in repository: Repository) async -> Bool {
        let command = CheckGPGSigningCommand()
        let result = try? await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard let result = result, result.succeeded else { return false }
        return (try? command.parse(output: result.stdout)) ?? false
    }

    /// Gets the configured GPG key ID.
    /// - Parameter repository: The repository.
    /// - Returns: The GPG key ID or nil.
    func getGPGKeyId(in repository: Repository) async -> String? {
        let command = GetGPGKeyIdCommand()
        let result = try? await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard let result = result, result.succeeded else { return nil }
        return try? command.parse(output: result.stdout)
    }

    /// Gets the configured commit template.
    /// - Parameter repository: The repository.
    /// - Returns: The template content or nil.
    func getCommitTemplate(in repository: Repository) async -> String? {
        let command = GetCommitTemplateCommand()
        let result = try? await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard let result = result, result.succeeded else { return nil }
        return try? command.parse(output: result.stdout)
    }

    /// Gets the commit history.
    func getHistory(in repository: Repository, limit: Int = 100, ref: String? = nil) async throws -> [Commit] {
        let command = LogCommand(limit: limit, ref: ref)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the commit history with filter options.
    /// - Parameters:
    ///   - repository: The repository.
    ///   - limit: Maximum number of commits.
    ///   - filters: Filter options.
    /// - Returns: Array of commits matching the filters.
    func getHistoryWithFilters(
        in repository: Repository,
        limit: Int = 100,
        filters: LogFilterOptions
    ) async throws -> [Commit] {
        let command = LogWithFiltersCommand(limit: limit, filters: filters)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Searches commits by message.
    /// - Parameters:
    ///   - query: The search query.
    ///   - limit: Maximum number of results.
    ///   - repository: The repository.
    /// - Returns: Array of matching commits.
    func searchCommits(
        query: String,
        limit: Int = 100,
        in repository: Repository
    ) async throws -> [Commit] {
        let command = SearchCommitsCommand(searchQuery: query, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets commits by a specific author.
    /// - Parameters:
    ///   - author: The author name or email.
    ///   - limit: Maximum number of results.
    ///   - repository: The repository.
    /// - Returns: Array of commits by the author.
    func getCommitsByAuthor(
        author: String,
        limit: Int = 100,
        in repository: Repository
    ) async throws -> [Commit] {
        let command = AuthorCommitsCommand(author: author, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets commits in a date range.
    /// - Parameters:
    ///   - since: Start date (optional).
    ///   - until: End date (optional).
    ///   - limit: Maximum number of results.
    ///   - repository: The repository.
    /// - Returns: Array of commits in the date range.
    func getCommitsInDateRange(
        since: Date? = nil,
        until: Date? = nil,
        limit: Int = 100,
        in repository: Repository
    ) async throws -> [Commit] {
        let command = DateRangeCommitsCommand(since: since, until: until, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets a specific commit by hash.
    func getCommit(hash: String, in repository: Repository) async throws -> Commit {
        let command = ShowCommitCommand(commitHash: hash)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the current HEAD commit hash.
    func getHead(in repository: Repository) async throws -> String? {
        let command = HeadCommand()
        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard result.succeeded else { return nil }
        return try command.parse(output: result.stdout)
    }

    // MARK: - Branch Operations

    /// Gets all branches.
    func getBranches(in repository: Repository, includeRemote: Bool = true) async throws -> [Branch] {
        let command = ListBranchesCommand(includeRemote: includeRemote)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the current branch name.
    func getCurrentBranch(in repository: Repository) async throws -> String? {
        let command = CurrentBranchCommand()
        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        guard result.succeeded else { return nil }
        return try command.parse(output: result.stdout)
    }

    /// Checks out the specified branch.
    func checkout(branch: String, in repository: Repository) async throws {
        let command = CheckoutCommand(branchName: branch)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Creates a new branch.
    func createBranch(name: String, startPoint: String? = nil, in repository: Repository) async throws {
        let command = CreateBranchCommand(branchName: name, startPoint: startPoint)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Deletes a branch.
    func deleteBranch(name: String, force: Bool = false, in repository: Repository) async throws {
        let command = DeleteBranchCommand(branchName: name, force: force)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Renames a local branch.
    /// - Parameters:
    ///   - oldName: The current name of the branch.
    ///   - newName: The new name for the branch.
    ///   - repository: The repository.
    func renameBranch(oldName: String, newName: String, in repository: Repository) async throws {
        let command = RenameBranchCommand(oldName: oldName, newName: newName)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Renames a branch on the remote (deletes old, pushes new).
    /// - Parameters:
    ///   - oldName: The current name of the branch on remote.
    ///   - newName: The new name for the branch.
    ///   - remoteName: The remote name (defaults to "origin").
    ///   - repository: The repository.
    func renameBranchOnRemote(oldName: String, newName: String, remoteName: String = "origin", in repository: Repository) async throws {
        // First rename locally
        try await renameBranch(oldName: oldName, newName: newName, in: repository)

        // Delete old branch on remote
        let deleteCommand = DeleteRemoteBranchCommand(remoteName: remoteName, branchName: oldName)
        _ = try await executor.executeOrThrow(
            arguments: deleteCommand.arguments,
            workingDirectory: repository.rootURL
        )

        // Push new branch to remote
        let pushCommand = PushBranchToRemoteCommand(
            localBranch: newName,
            remoteName: remoteName,
            remoteBranch: newName,
            setUpstream: true
        )
        _ = try await executor.executeOrThrow(
            arguments: pushCommand.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Sets the upstream tracking branch.
    /// - Parameters:
    ///   - branchName: The local branch name.
    ///   - upstreamRef: The upstream reference (e.g., "origin/main").
    ///   - repository: The repository.
    func setUpstream(branchName: String, upstreamRef: String, in repository: Repository) async throws {
        let command = SetUpstreamCommand(branchName: branchName, upstreamRef: upstreamRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Unsets the upstream tracking branch.
    /// - Parameters:
    ///   - branchName: The local branch name.
    ///   - repository: The repository.
    func unsetUpstream(branchName: String, in repository: Repository) async throws {
        let command = UnsetUpstreamCommand(branchName: branchName)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Merge Operations

    /// Merges a branch into the current branch.
    /// - Parameters:
    ///   - branchName: The branch to merge.
    ///   - mergeType: The type of merge to perform.
    ///   - message: Optional commit message for the merge.
    ///   - repository: The repository.
    func merge(branchName: String, mergeType: MergeType = .normal, message: String? = nil, in repository: Repository) async throws {
        let command = MergeCommand(branchName: branchName, mergeType: mergeType, message: message)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Aborts a merge in progress.
    func abortMerge(in repository: Repository) async throws {
        let command = AbortMergeCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Continues a merge after conflicts have been resolved.
    func continueMerge(in repository: Repository) async throws {
        let command = ContinueMergeCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Previews a merge without actually performing it.
    /// - Parameters:
    ///   - sourceBranch: The branch to merge from.
    ///   - targetBranch: The branch to merge into (current branch).
    ///   - repository: The repository.
    /// - Returns: A preview of what the merge would do.
    func previewMerge(sourceBranch: String, targetBranch: String, in repository: Repository) async throws -> MergePreviewResult {
        // Get merge base
        let mergeBaseCommand = MergeBaseCommand(branch1: targetBranch, branch2: sourceBranch)
        let mergeBase = try? await executor.executeOrThrow(
            arguments: mergeBaseCommand.arguments,
            workingDirectory: repository.rootURL
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Get commits that would be merged
        let logCommand = LogCommand(limit: 100, ref: "\(targetBranch)..\(sourceBranch)")
        let logOutput = try await executor.executeOrThrow(
            arguments: logCommand.arguments,
            workingDirectory: repository.rootURL
        )
        let commits = (try? logCommand.parse(output: logOutput)) ?? []

        // Get file changes
        var fileChanges: [MergePreviewChange] = []
        if let base = mergeBase {
            let diffCommand = DiffTreeSummaryCommand(base: base, target: sourceBranch)
            let diffOutput = try await executor.executeOrThrow(
                arguments: diffCommand.arguments,
                workingDirectory: repository.rootURL
            )
            fileChanges = (try? diffCommand.parse(output: diffOutput)) ?? []
        }

        // Try a dry-run merge to detect conflicts
        var hasConflicts = false
        var conflictedFiles: [ConflictedFile] = []

        do {
            // Attempt merge without commit
            let previewCommand = MergePreviewCommand(branchName: sourceBranch)
            _ = try await executor.executeOrThrow(
                arguments: previewCommand.arguments,
                workingDirectory: repository.rootURL
            )

            // Check for conflicts
            let unmergedCommand = GetUnmergedStatusCommand()
            let unmergedOutput = try await executor.executeOrThrow(
                arguments: unmergedCommand.arguments,
                workingDirectory: repository.rootURL
            )
            conflictedFiles = (try? unmergedCommand.parse(output: unmergedOutput)) ?? []
            hasConflicts = !conflictedFiles.isEmpty

            // Abort the preview merge
            try? await abortMerge(in: repository)
        } catch {
            // Merge failed - likely has conflicts
            hasConflicts = true

            // Try to get conflict info
            let unmergedCommand = GetUnmergedStatusCommand()
            if let unmergedOutput = try? await executor.executeOrThrow(
                arguments: unmergedCommand.arguments,
                workingDirectory: repository.rootURL
            ) {
                conflictedFiles = (try? unmergedCommand.parse(output: unmergedOutput)) ?? []
            }

            // Abort the preview merge
            try? await abortMerge(in: repository)
        }

        return MergePreviewResult(
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            mergeBase: mergeBase,
            commitCount: commits.count,
            commits: commits,
            fileChanges: fileChanges,
            hasConflicts: hasConflicts,
            conflictedFiles: conflictedFiles
        )
    }

    // MARK: - Rebase Operations

    /// Rebases the current branch onto another branch.
    /// - Parameters:
    ///   - ontoBranch: The branch to rebase onto.
    ///   - repository: The repository.
    func rebase(ontoBranch: String, in repository: Repository) async throws {
        let command = RebaseCommand(ontoBranch: ontoBranch, interactive: false)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Aborts a rebase in progress.
    func abortRebase(in repository: Repository) async throws {
        let command = AbortRebaseCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Continues a rebase after conflicts have been resolved.
    func continueRebase(in repository: Repository) async throws {
        let command = ContinueRebaseCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Skips the current commit during a rebase.
    func skipRebase(in repository: Repository) async throws {
        let command = SkipRebaseCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Interactive Rebase Operations

    /// Gets the commits that would be rebased onto the target branch.
    func getRebaseCommits(onto branch: String, in repository: Repository) async throws -> [RebaseEntry] {
        let command = GetRebaseCommitsCommand(ontoBranch: branch)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Performs an interactive rebase with the specified entries.
    func performInteractiveRebase(entries: [RebaseEntry], onto branch: String, in repository: Repository) async throws {
        // Create a temporary script that will be used as the sequence editor
        let tempDir = FileManager.default.temporaryDirectory
        let todoFile = tempDir.appendingPathComponent("git-rebase-todo-\(UUID().uuidString)")
        let editorScript = tempDir.appendingPathComponent("git-rebase-editor-\(UUID().uuidString).sh")

        // Generate the todo content
        let todoContent = entries.map { entry in
            let message = entry.newMessage ?? entry.message
            return "\(entry.action.rawValue) \(entry.shortHash) \(message)"
        }.joined(separator: "\n")

        // Write the todo content
        try todoContent.write(to: todoFile, atomically: true, encoding: .utf8)

        // Create editor script that replaces the rebase todo file
        let editorContent = """
        #!/bin/bash
        cat "\(todoFile.path)" > "$1"
        """
        try editorContent.write(to: editorScript, atomically: true, encoding: .utf8)

        // Make script executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: editorScript.path)

        defer {
            try? FileManager.default.removeItem(at: todoFile)
            try? FileManager.default.removeItem(at: editorScript)
        }

        // Run the interactive rebase with our custom editor
        let result = try await executor.execute(
            arguments: ["rebase", "-i", branch],
            workingDirectory: repository.rootURL,
            environment: ["GIT_SEQUENCE_EDITOR": editorScript.path]
        )

        if !result.succeeded {
            throw GitError.commandFailed(
                command: "git rebase -i \(branch)",
                exitCode: result.exitCode,
                message: result.stderr
            )
        }
    }

    /// Gets the current progress of an interactive rebase.
    func getRebaseProgress(in repository: Repository) async throws -> (current: Int, total: Int)? {
        let rebaseMergeDir = repository.rootURL.appendingPathComponent(".git/rebase-merge")

        guard FileManager.default.fileExists(atPath: rebaseMergeDir.path) else {
            return nil
        }

        let msgNumFile = rebaseMergeDir.appendingPathComponent("msgnum")
        let endFile = rebaseMergeDir.appendingPathComponent("end")

        guard let msgNumData = FileManager.default.contents(atPath: msgNumFile.path),
              let endData = FileManager.default.contents(atPath: endFile.path),
              let msgNumStr = String(data: msgNumData, encoding: .utf8),
              let endStr = String(data: endData, encoding: .utf8),
              let current = Int(msgNumStr.trimmingCharacters(in: .whitespacesAndNewlines)),
              let total = Int(endStr.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return (current, total)
    }

    /// Edits the commit message during an interactive rebase.
    func editRebaseCommitMessage(_ message: String, in repository: Repository) async throws {
        let command = RebaseEditMessageCommand(message: message)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Checks if an interactive rebase is in progress.
    func isRebaseInProgress(in repository: Repository) -> Bool {
        let rebaseMergeDir = repository.rootURL.appendingPathComponent(".git/rebase-merge")
        let rebaseApplyDir = repository.rootURL.appendingPathComponent(".git/rebase-apply")

        return FileManager.default.fileExists(atPath: rebaseMergeDir.path)
            || FileManager.default.fileExists(atPath: rebaseApplyDir.path)
    }

    /// Gets information about the current rebase state.
    func getRebaseInfo(in repository: Repository) async throws -> (headName: String?, onto: String?)? {
        let rebaseMergeDir = repository.rootURL.appendingPathComponent(".git/rebase-merge")

        guard FileManager.default.fileExists(atPath: rebaseMergeDir.path) else {
            return nil
        }

        let headNameFile = rebaseMergeDir.appendingPathComponent("head-name")
        let ontoFile = rebaseMergeDir.appendingPathComponent("onto")

        let headName: String?
        if let data = FileManager.default.contents(atPath: headNameFile.path),
           let str = String(data: data, encoding: .utf8) {
            headName = str.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "refs/heads/", with: "")
        } else {
            headName = nil
        }

        let onto: String?
        if let data = FileManager.default.contents(atPath: ontoFile.path),
           let str = String(data: data, encoding: .utf8) {
            onto = String(str.trimmingCharacters(in: .whitespacesAndNewlines).prefix(7))
        } else {
            onto = nil
        }

        return (headName, onto)
    }

    // MARK: - Branch Comparison Operations

    /// Gets the diff between two branches.
    /// - Parameters:
    ///   - baseBranch: The base branch for comparison.
    ///   - compareBranch: The branch to compare against.
    ///   - repository: The repository.
    /// - Returns: Array of file diffs between the branches.
    func getBranchDiff(baseBranch: String, compareBranch: String, in repository: Repository) async throws -> [FileDiff] {
        let command = BranchDiffCommand(baseBranch: baseBranch, compareBranch: compareBranch)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Gets the commits that exist in compareBranch but not in baseBranch.
    /// - Parameters:
    ///   - baseBranch: The base branch for comparison.
    ///   - compareBranch: The branch to compare against.
    ///   - limit: Maximum number of commits to return.
    ///   - repository: The repository.
    /// - Returns: Array of commits unique to compareBranch.
    func getBranchCommitDiff(baseBranch: String, compareBranch: String, limit: Int = 100, in repository: Repository) async throws -> [Commit] {
        let command = BranchLogDiffCommand(baseBranch: baseBranch, compareBranch: compareBranch, limit: limit)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Checks if the repository is in a merging or rebasing state.
    func getRepositoryState(in repository: Repository) async throws -> RepositoryState {
        var state = RepositoryState()

        // Check for current branch
        if let currentBranch = try await getCurrentBranch(in: repository) {
            state.currentBranch = currentBranch
        } else {
            state.isDetachedHead = true
        }

        // Check for merge state by looking for MERGE_HEAD file
        let mergeHeadURL = repository.rootURL.appendingPathComponent(".git/MERGE_HEAD")
        state.isMerging = FileManager.default.fileExists(atPath: mergeHeadURL.path)

        // Check for rebase state by looking for rebase directory
        let rebaseApplyURL = repository.rootURL.appendingPathComponent(".git/rebase-apply")
        let rebaseMergeURL = repository.rootURL.appendingPathComponent(".git/rebase-merge")
        state.isRebasing = FileManager.default.fileExists(atPath: rebaseApplyURL.path)
            || FileManager.default.fileExists(atPath: rebaseMergeURL.path)

        return state
    }

    // MARK: - Stash Operations

    /// Gets all stashes.
    func getStashes(in repository: Repository) async throws -> [Stash] {
        let command = ListStashesCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Creates a new stash.
    /// - Parameters:
    ///   - message: Optional stash message.
    ///   - includeUntracked: Whether to include untracked files.
    ///   - includeIgnored: Whether to include ignored files (implies includeUntracked).
    ///   - repository: The repository.
    func createStash(message: String? = nil, includeUntracked: Bool = false, includeIgnored: Bool = false, in repository: Repository) async throws {
        let command = CreateStashCommand(message: message, includeUntracked: includeUntracked, includeIgnored: includeIgnored)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Applies a stash without removing it.
    func applyStash(_ stashRef: String = "stash@{0}", in repository: Repository) async throws {
        let command = ApplyStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pops a stash (apply and remove).
    func popStash(_ stashRef: String = "stash@{0}", in repository: Repository) async throws {
        let command = PopStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Drops a stash.
    func dropStash(_ stashRef: String, in repository: Repository) async throws {
        let command = DropStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Clears all stashes.
    func clearStashes(in repository: Repository) async throws {
        let command = ClearStashesCommand()
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Shows the diff for a stash.
    func getStashDiff(_ stashRef: String = "stash@{0}", in repository: Repository) async throws -> [FileDiff] {
        let command = ShowStashCommand(stashRef: stashRef)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Renames a stash by storing it with a new message.
    /// This uses `git stash store` to create a new stash entry with the same commit but new message.
    /// - Parameters:
    ///   - stashRef: The stash reference to rename.
    ///   - newMessage: The new message for the stash.
    ///   - repository: The repository.
    func renameStash(_ stashRef: String, to newMessage: String, in repository: Repository) async throws {
        // Get the commit hash of the stash
        let revParseArgs = ["rev-parse", stashRef]
        let stashCommit = try await executor.executeOrThrow(
            arguments: revParseArgs,
            workingDirectory: repository.rootURL
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Drop the old stash
        let dropCommand = DropStashCommand(stashRef: stashRef)
        _ = try await executor.executeOrThrow(
            arguments: dropCommand.arguments,
            workingDirectory: repository.rootURL
        )

        // Store the stash with the new message
        let storeArgs = ["stash", "store", "-m", newMessage, stashCommit]
        _ = try await executor.executeOrThrow(
            arguments: storeArgs,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Remote Operations

    /// Fetches from all remotes.
    func fetch(in repository: Repository, remote: String? = nil, prune: Bool = false) async throws {
        let command = FetchCommand(remote: remote, prune: prune)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pulls changes from remote.
    func pull(in repository: Repository, remote: String? = nil, branch: String? = nil, rebase: Bool = false) async throws {
        let command = PullCommand(remote: remote, branch: branch, rebase: rebase)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pushes changes to remote.
    func push(in repository: Repository, remote: String? = nil, branch: String? = nil, setUpstream: Bool = false, force: Bool = false) async throws {
        let command = PushCommand(remote: remote, branch: branch, setUpstream: setUpstream, force: force)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Gets list of remotes.
    func getRemotes(in repository: Repository) async throws -> [Remote] {
        let command = ListRemotesCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Adds a new remote.
    func addRemote(name: String, url: String, in repository: Repository) async throws {
        let command = AddRemoteCommand(name: name, url: url)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Removes a remote.
    func removeRemote(name: String, in repository: Repository) async throws {
        let command = RemoveRemoteCommand(name: name)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Renames a remote.
    func renameRemote(oldName: String, newName: String, in repository: Repository) async throws {
        let command = RenameRemoteCommand(oldName: oldName, newName: newName)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Sets the URL of a remote.
    func setRemoteURL(name: String, url: String, pushURL: Bool = false, in repository: Repository) async throws {
        let command = SetRemoteURLCommand(name: name, url: url, pushURL: pushURL)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Tag Operations

    /// Gets all tags.
    func getTags(in repository: Repository) async throws -> [Tag] {
        let command = ListTagsCommand()
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Creates a new tag.
    func createTag(name: String, message: String? = nil, commitHash: String? = nil, in repository: Repository) async throws {
        let command = CreateTagCommand(name: name, message: message, commitHash: commitHash)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Deletes a tag.
    func deleteTag(name: String, in repository: Repository) async throws {
        let command = DeleteTagCommand(name: name)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Pushes a tag to remote.
    func pushTag(name: String, remote: String = "origin", in repository: Repository) async throws {
        let command = PushTagCommand(name: name, remote: remote)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    // MARK: - Clone Operations

    /// Clones a repository to the specified destination.
    /// - Parameters:
    ///   - url: The URL of the repository to clone.
    ///   - destination: The local directory to clone into (the repository folder will be created inside).
    ///   - branch: Optional specific branch to clone.
    /// - Returns: The URL of the cloned repository.
    func clone(url: String, to destination: URL, branch: String? = nil) async throws -> URL {
        let command = CloneCommand(url: url, branch: branch)

        // Append the folder name derived from the URL to the destination
        var args = command.arguments
        let repoName = Self.extractRepoName(from: url)
        let repoPath = destination.appendingPathComponent(repoName)
        args.append(repoPath.path)

        _ = try await executor.executeOrThrow(
            arguments: args,
            workingDirectory: destination
        )

        return repoPath
    }

    /// Extracts the repository name from a Git URL.
    private static func extractRepoName(from url: String) -> String {
        // Handle various URL formats:
        // https://github.com/user/repo.git -> repo
        // git@github.com:user/repo.git -> repo
        // /path/to/repo.git -> repo
        // /path/to/repo -> repo

        var name = url

        // Remove trailing slash
        if name.hasSuffix("/") {
            name = String(name.dropLast())
        }

        // Remove .git suffix
        if name.hasSuffix(".git") {
            name = String(name.dropLast(4))
        }

        // Get the last path component
        if let lastSlash = name.lastIndex(of: "/") {
            name = String(name[name.index(after: lastSlash)...])
        } else if let lastColon = name.lastIndex(of: ":") {
            name = String(name[name.index(after: lastColon)...])
        }

        return name.isEmpty ? "repository" : name
    }

    // MARK: - Submodule Operations

    /// Gets all submodules in the repository.
    func getSubmodules(in repository: Repository) async throws -> [Submodule] {
        // Get status
        let statusCommand = ListSubmodulesCommand()
        let statusOutput = try await executor.executeOrThrow(
            arguments: statusCommand.arguments,
            workingDirectory: repository.rootURL
        )
        let submodules = try statusCommand.parse(output: statusOutput)

        // Get config
        let configCommand = GetSubmoduleConfigCommand()
        if let configOutput = try? await executor.executeOrThrow(
            arguments: configCommand.arguments,
            workingDirectory: repository.rootURL
        ) {
            let configs = try configCommand.parse(output: configOutput)
            return SubmoduleParser.merge(status: submodules, configs: configs)
        }

        return submodules
    }

    /// Initializes submodules.
    func initSubmodules(recursive: Bool = true, in repository: Repository) async throws {
        let command = InitSubmodulesCommand(recursive: recursive)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Updates submodules.
    func updateSubmodules(
        recursive: Bool = true,
        init_: Bool = true,
        remote: Bool = false,
        paths: [String]? = nil,
        in repository: Repository
    ) async throws {
        let command = UpdateSubmodulesCommand(recursive: recursive, init_: init_, remote: remote, paths: paths)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Adds a new submodule.
    func addSubmodule(url: String, path: String, branch: String? = nil, in repository: Repository) async throws {
        let command = AddSubmoduleCommand(url: url, path: path, branch: branch)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Deinitializes a submodule (removes from working tree).
    func deinitSubmodule(path: String, force: Bool = false, in repository: Repository) async throws {
        let command = DeinitSubmoduleCommand(path: path, force: force)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Syncs submodule URLs.
    func syncSubmodules(recursive: Bool = true, in repository: Repository) async throws {
        let command = SyncSubmodulesCommand(recursive: recursive)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }

    /// Gets the diff for a submodule.
    func getSubmoduleDiff(path: String, in repository: Repository) async throws -> String {
        let command = SubmoduleDiffCommand(path: path)
        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
        return try command.parse(output: output)
    }

    /// Checks out a specific commit in a submodule.
    func checkoutSubmoduleCommit(_ commit: String, path: String, in repository: Repository) async throws {
        let command = CheckoutSubmoduleCommitCommand(submodulePath: path, commit: commit)
        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: repository.rootURL
        )
    }
}
