import Foundation
import AppKit

/// View model for interactive rebase operations.
@MainActor
final class InteractiveRebaseViewModel: ObservableObject {
    // MARK: - Published State

    /// The commits available for rebase.
    @Published private(set) var entries: [RebaseEntry] = []

    /// The target branch/commit to rebase onto.
    @Published var ontoBranch: String = ""

    /// Current state of the rebase operation.
    @Published private(set) var state: InteractiveRebaseState = .idle

    /// Whether we're loading commits.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// The currently selected entry.
    @Published var selectedEntry: RebaseEntry?

    /// Whether the editor has unsaved changes.
    @Published private(set) var hasChanges: Bool = false

    /// Message for reword operation.
    @Published var rewordMessage: String = ""

    /// Whether to show the reword sheet.
    @Published var showRewordSheet: Bool = false

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Loads commits that would be rebased onto the target branch.
    func loadCommits(onto branch: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            ontoBranch = branch
            entries = try await gitService.getRebaseCommits(onto: branch, in: repository)
            hasChanges = false
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Changes the action for a specific entry.
    func setAction(_ action: RebaseAction, for entry: RebaseEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        var updatedEntry = entries[index]
        updatedEntry.action = action
        updatedEntry.isModified = true
        entries[index] = updatedEntry
        hasChanges = true

        // If reword, show the message editor
        if action == .reword {
            selectedEntry = entries[index]
            rewordMessage = entries[index].message
            showRewordSheet = true
        }
    }

    /// Updates the message for a reword action.
    func updateRewordMessage(_ message: String, for entry: RebaseEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        var updatedEntry = entries[index]
        updatedEntry.newMessage = message
        updatedEntry.isModified = true
        entries[index] = updatedEntry
        hasChanges = true
    }

    /// Applies the reword message from the sheet.
    func applyRewordMessage() {
        guard let entry = selectedEntry else { return }
        updateRewordMessage(rewordMessage, for: entry)
        showRewordSheet = false
        selectedEntry = nil
        rewordMessage = ""
    }

    /// Moves an entry up in the list.
    func moveUp(_ entry: RebaseEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              index > 0 else { return }

        entries.swapAt(index, index - 1)
        hasChanges = true
    }

    /// Moves an entry down in the list.
    func moveDown(_ entry: RebaseEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              index < entries.count - 1 else { return }

        entries.swapAt(index, index + 1)
        hasChanges = true
    }

    /// Moves entries from one set of indices to another.
    func moveEntries(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        hasChanges = true
    }

    /// Resets all entries to their original state.
    func resetAll() {
        for index in entries.indices {
            entries[index].action = .pick
            entries[index].newMessage = nil
            entries[index].isModified = false
        }
        hasChanges = false
    }

    /// Squashes all selected commits after the first one.
    func squashSelected(_ selectedEntries: Set<RebaseEntry>) {
        let sortedIndices = selectedEntries
            .compactMap { entry in entries.firstIndex(where: { $0.id == entry.id }) }
            .sorted()

        guard sortedIndices.count > 1 else { return }

        // First commit keeps pick, rest become squash
        for (offset, index) in sortedIndices.enumerated() {
            if offset > 0 {
                entries[index].action = .squash
                entries[index].isModified = true
            }
        }
        hasChanges = true
    }

    /// Starts the interactive rebase with the current configuration.
    func startRebase() async {
        state = .preparing

        do {
            try await gitService.performInteractiveRebase(
                entries: entries,
                onto: ontoBranch,
                in: repository
            )
            state = .completed
            error = nil
        } catch let gitError as GitError {
            error = gitError
            state = .failed(error: gitError.localizedDescription)
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            state = .failed(error: error.localizedDescription)
        }
    }

    /// Continues the rebase after resolving conflicts or editing.
    func continueRebase() async {
        do {
            try await gitService.continueRebase(in: repository)
            await checkRebaseState()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Aborts the current rebase.
    func abortRebase() async {
        do {
            try await gitService.abortRebase(in: repository)
            state = .idle
            entries = []
            hasChanges = false
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Skips the current commit in rebase.
    func skipCommit() async {
        do {
            try await gitService.skipRebase(in: repository)
            await checkRebaseState()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Edits the current commit message during rebase.
    func editCommitMessage(_ message: String) async {
        do {
            try await gitService.editRebaseCommitMessage(message, in: repository)
            await checkRebaseState()
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Checks the current rebase state.
    func checkRebaseState() async {
        do {
            let progress = try await gitService.getRebaseProgress(in: repository)
            if let progress = progress {
                state = .inProgress(currentStep: progress.current, totalSteps: progress.total)
            } else {
                state = .idle
            }
        } catch {
            state = .idle
        }
    }

    // MARK: - Computed Properties

    /// Whether the rebase can be started.
    var canStartRebase: Bool {
        !entries.isEmpty && !ontoBranch.isEmpty && state == .idle
    }

    /// Number of commits that will be picked.
    var pickCount: Int {
        entries.filter { $0.action == .pick }.count
    }

    /// Number of commits that will be reworded.
    var rewordCount: Int {
        entries.filter { $0.action == .reword }.count
    }

    /// Number of commits that will be squashed.
    var squashCount: Int {
        entries.filter { $0.action == .squash || $0.action == .fixup }.count
    }

    /// Number of commits that will be dropped.
    var dropCount: Int {
        entries.filter { $0.action == .drop }.count
    }

    /// Summary of the rebase operation.
    var summary: String {
        var parts: [String] = []

        if pickCount > 0 { parts.append("\(pickCount) pick") }
        if rewordCount > 0 { parts.append("\(rewordCount) reword") }
        if squashCount > 0 { parts.append("\(squashCount) squash") }
        if dropCount > 0 { parts.append("\(dropCount) drop") }

        return parts.isEmpty ? "No commits" : parts.joined(separator: ", ")
    }
}
