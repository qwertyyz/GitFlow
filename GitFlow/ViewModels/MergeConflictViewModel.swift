import Foundation

/// View model for merge conflict resolution.
@MainActor
final class MergeConflictViewModel: ObservableObject {
    // MARK: - Published State

    /// The current merge state.
    @Published private(set) var mergeState: MergeState = MergeState()

    /// The currently selected conflicted file.
    @Published var selectedFile: ConflictedFile?

    /// Conflict sections in the selected file.
    @Published private(set) var conflictSections: [ConflictSection] = []

    /// Content from "our" side.
    @Published private(set) var oursContent: String = ""

    /// Content from "their" side.
    @Published private(set) var theirsContent: String = ""

    /// Content from the base (common ancestor).
    @Published private(set) var baseContent: String = ""

    /// The merged result content.
    @Published var mergedContent: String = ""

    /// Whether conflict data is loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether a conflict operation is in progress.
    @Published private(set) var isOperationInProgress: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Whether we're currently in a merge state.
    @Published private(set) var isMerging: Bool = false

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the merge state.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        isMerging = await gitService.isMerging(in: repository)

        guard isMerging else {
            mergeState = MergeState()
            selectedFile = nil
            clearFileContent()
            return
        }

        do {
            mergeState = try await gitService.getMergeState(in: repository)
            error = nil

            // If selected file is no longer in conflict list, clear selection
            if let selected = selectedFile,
               !mergeState.conflictedFiles.contains(where: { $0.path == selected.path }) {
                selectedFile = nil
                clearFileContent()
            }

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Loads content for a conflicted file.
    func loadFileContent(for file: ConflictedFile) async {
        selectedFile = file
        isLoading = true
        defer { isLoading = false }

        do {
            // Load content from all three stages
            async let ours = gitService.getMergeStageContent(stage: 2, filePath: file.path, in: repository)
            async let theirs = gitService.getMergeStageContent(stage: 3, filePath: file.path, in: repository)

            oursContent = try await ours
            theirsContent = try await theirs

            // Base content may not exist for new files
            if let base = try? await gitService.getMergeStageContent(stage: 1, filePath: file.path, in: repository) {
                baseContent = base
            } else {
                baseContent = ""
            }

            // Load current file content (with conflict markers)
            let currentContent = try await gitService.readFileContent(at: file.path, in: repository)
            mergedContent = currentContent

            // Parse conflict sections
            conflictSections = ConflictMarkerParser.parseConflictSections(from: currentContent)

            error = nil

        } catch let gitError as GitError {
            error = gitError
            clearFileContent()
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            clearFileContent()
        }
    }

    /// Uses "ours" version for the selected file.
    func useOurs() async {
        guard let file = selectedFile else { return }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.useOursVersion(for: file.path, in: repository)
            try await gitService.markConflictResolved(filePath: file.path, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Uses "theirs" version for the selected file.
    func useTheirs() async {
        guard let file = selectedFile else { return }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.useTheirsVersion(for: file.path, in: repository)
            try await gitService.markConflictResolved(filePath: file.path, in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Saves the merged content and marks the file as resolved.
    func saveMergedContent() async {
        guard let file = selectedFile else { return }

        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            // Write the merged content
            try await gitService.writeFileContent(mergedContent, to: file.path, in: repository)

            // Mark as resolved
            try await gitService.markConflictResolved(filePath: file.path, in: repository)

            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Applies a resolution to a specific conflict section.
    func resolveSection(_ section: ConflictSection, with resolution: ConflictResolution) {
        let resolvedContent = ConflictMarkerParser.resolveSection(section, with: resolution)

        // Find and replace the conflict markers in mergedContent
        let lines = mergedContent.components(separatedBy: "\n")
        var newLines: [String] = []
        var skipUntilEnd = false

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            if lineNumber == section.startLine && line.hasPrefix("<<<<<<<") {
                skipUntilEnd = true
                // Insert the resolved content
                newLines.append(contentsOf: resolvedContent.components(separatedBy: "\n"))
            } else if skipUntilEnd && line.hasPrefix(">>>>>>>") && lineNumber == section.endLine {
                skipUntilEnd = false
            } else if !skipUntilEnd {
                newLines.append(line)
            }
        }

        mergedContent = newLines.joined(separator: "\n")

        // Update conflict sections
        conflictSections = ConflictMarkerParser.parseConflictSections(from: mergedContent)
    }

    /// Aborts the merge.
    func abortMerge() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.abortMerge(in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Continues the merge after all conflicts are resolved.
    func continueMerge() async {
        isOperationInProgress = true
        defer { isOperationInProgress = false }

        do {
            try await gitService.continueMerge(in: repository)
            await refresh()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func clearFileContent() {
        oursContent = ""
        theirsContent = ""
        baseContent = ""
        mergedContent = ""
        conflictSections = []
    }

    // MARK: - Computed Properties

    /// Whether there are any conflicts.
    var hasConflicts: Bool {
        !mergeState.conflictedFiles.isEmpty
    }

    /// Whether all conflicts have been resolved.
    var allResolved: Bool {
        mergeState.allResolved
    }

    /// Whether the merged content has no conflict markers.
    var mergedContentHasNoConflicts: Bool {
        !mergedContent.contains("<<<<<<<") &&
        !mergedContent.contains("=======") &&
        !mergedContent.contains(">>>>>>>")
    }

    /// Progress string (e.g., "2/5 resolved").
    var progressString: String {
        "\(mergeState.resolvedCount)/\(mergeState.conflictedFiles.count) resolved"
    }
}
