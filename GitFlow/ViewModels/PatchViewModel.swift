import Foundation
import SwiftUI

/// View model for managing Git patches.
@MainActor
final class PatchViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var error: String?
    @Published var successMessage: String?

    // Create patch state
    @Published var showingCreateSheet = false
    @Published var patchSource: PatchSource = .staged
    @Published var selectedCommits: [Commit] = []
    @Published var generatedPatch: String = ""

    // Apply patch state
    @Published var showingApplySheet = false
    @Published var patchContent: String = ""
    @Published var patchFilePath: String = ""
    @Published var useThreeWay = false
    @Published var applyAsEmail = false

    // Patch in progress state
    @Published var isPatchInProgress = false

    // MARK: - Types

    enum PatchSource {
        case staged
        case unstaged
        case commit
        case commitRange
    }

    // MARK: - Private Properties

    private let gitService: GitService
    private var repository: Repository?

    // MARK: - Initialization

    init(gitService: GitService = GitService()) {
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Sets the repository to work with.
    func setRepository(_ repository: Repository) {
        self.repository = repository
        Task {
            await checkPatchState()
        }
    }

    /// Checks if there's a patch operation in progress.
    func checkPatchState() async {
        guard let repository = repository else { return }
        isPatchInProgress = await gitService.isPatchInProgress(in: repository)
    }

    // MARK: - Create Patch

    /// Generates a patch from staged changes.
    func createPatchFromStaged() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            generatedPatch = try await gitService.getStagedPatch(in: repository)
            if generatedPatch.isEmpty {
                error = "No staged changes to create a patch from"
            }
        } catch {
            self.error = "Failed to create patch: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Generates a patch from unstaged changes.
    func createPatchFromUnstaged() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            generatedPatch = try await gitService.getUnstagedPatch(in: repository)
            if generatedPatch.isEmpty {
                error = "No unstaged changes to create a patch from"
            }
        } catch {
            self.error = "Failed to create patch: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Generates a patch from a commit.
    func createPatchFromCommit(_ commit: Commit) async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            generatedPatch = try await gitService.getCommitPatch(commitHash: commit.hash, in: repository)
        } catch {
            self.error = "Failed to create patch: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Generates a patch from a commit range.
    func createPatchFromCommitRange(from fromCommit: String, to toCommit: String) async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            generatedPatch = try await gitService.getCommitRangePatch(fromCommit: fromCommit, toCommit: toCommit, in: repository)
        } catch {
            self.error = "Failed to create patch: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Saves the generated patch to a file.
    func savePatch(to url: URL) async {
        guard !generatedPatch.isEmpty else {
            error = "No patch to save"
            return
        }

        do {
            try await gitService.savePatch(content: generatedPatch, to: url)
            successMessage = "Patch saved successfully"
        } catch {
            self.error = "Failed to save patch: \(error.localizedDescription)"
        }
    }

    // MARK: - Apply Patch

    /// Applies a patch from the patchContent property.
    func applyPatchFromContent() async {
        guard let repository = repository else { return }
        guard !patchContent.isEmpty else {
            error = "No patch content to apply"
            return
        }

        isLoading = true
        error = nil

        do {
            try await gitService.applyPatch(content: patchContent, check: false, threeWay: useThreeWay, in: repository)
            successMessage = "Patch applied successfully"
            showingApplySheet = false
            patchContent = ""
        } catch {
            self.error = "Failed to apply patch: \(error.localizedDescription)"
        }

        isLoading = false
        await checkPatchState()
    }

    /// Applies a patch from a file.
    func applyPatchFromFile() async {
        guard let repository = repository else { return }
        guard !patchFilePath.isEmpty else {
            error = "No patch file selected"
            return
        }

        isLoading = true
        error = nil

        do {
            if applyAsEmail {
                try await gitService.applyMailPatch(from: patchFilePath, threeWay: useThreeWay, in: repository)
            } else {
                try await gitService.applyPatch(from: patchFilePath, check: false, threeWay: useThreeWay, in: repository)
            }
            successMessage = "Patch applied successfully"
            showingApplySheet = false
            patchFilePath = ""
        } catch {
            self.error = "Failed to apply patch: \(error.localizedDescription)"
        }

        isLoading = false
        await checkPatchState()
    }

    /// Checks if a patch can be applied cleanly.
    func checkPatch() async -> Bool {
        guard let repository = repository else { return false }

        isLoading = true
        error = nil

        do {
            if !patchContent.isEmpty {
                try await gitService.applyPatch(content: patchContent, check: true, threeWay: false, in: repository)
            } else if !patchFilePath.isEmpty {
                try await gitService.applyPatch(from: patchFilePath, check: true, threeWay: false, in: repository)
            } else {
                error = "No patch to check"
                isLoading = false
                return false
            }
            successMessage = "Patch can be applied cleanly"
            isLoading = false
            return true
        } catch {
            self.error = "Patch cannot be applied cleanly"
            isLoading = false
            return false
        }
    }

    // MARK: - Patch Operations In Progress

    /// Aborts a patch application in progress.
    func abortPatch() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            try await gitService.abortPatch(in: repository)
            successMessage = "Patch application aborted"
        } catch {
            self.error = "Failed to abort patch: \(error.localizedDescription)"
        }

        isLoading = false
        await checkPatchState()
    }

    /// Continues applying patches after resolving conflicts.
    func continuePatch() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            try await gitService.continuePatch(in: repository)
            successMessage = "Patch application continued"
        } catch {
            self.error = "Failed to continue patch: \(error.localizedDescription)"
        }

        isLoading = false
        await checkPatchState()
    }

    /// Skips the current patch and continues with the next.
    func skipPatch() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            try await gitService.skipPatch(in: repository)
            successMessage = "Patch skipped"
        } catch {
            self.error = "Failed to skip patch: \(error.localizedDescription)"
        }

        isLoading = false
        await checkPatchState()
    }

    // MARK: - Sheet Presentation

    func showCreateSheet() {
        generatedPatch = ""
        patchSource = .staged
        selectedCommits = []
        showingCreateSheet = true
    }

    func showApplySheet() {
        patchContent = ""
        patchFilePath = ""
        useThreeWay = false
        applyAsEmail = false
        showingApplySheet = true
    }

    func clearMessages() {
        error = nil
        successMessage = nil
    }
}
