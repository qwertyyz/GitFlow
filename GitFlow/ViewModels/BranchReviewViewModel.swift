import Foundation
import SwiftUI

/// View model for reviewing and managing branches.
@MainActor
final class BranchReviewViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var branches: [Branch] = []
    @Published var staleBranches: [BranchStalenessInfo] = []
    @Published var archivedBranches: [ArchivedBranch] = []
    @Published var isLoading = false
    @Published var error: String?

    @Published var selectedTab: ReviewTab = .all
    @Published var stalenessFilter: BranchStalenessInfo.StalenessLevel?
    @Published var showMergedOnly = false

    // Archive sheet
    @Published var showingArchiveSheet = false
    @Published var branchToArchive: Branch?
    @Published var archiveReason = ""

    // MARK: - Types

    enum ReviewTab: String, CaseIterable {
        case all = "All Branches"
        case stale = "Stale"
        case merged = "Merged"
        case archived = "Archived"
    }

    // MARK: - Private Properties

    private let gitService: GitService
    private let archiveStore = ArchivedBranchStore()
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
            await loadData()
        }
    }

    /// Loads all branch data.
    func loadData() async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            // Load branches
            branches = try await gitService.getBranches(in: repository)

            // Load archived branches
            archivedBranches = archiveStore.loadArchivedBranches(for: repository.path)

            // Analyze staleness
            await analyzeStaleness()
        } catch {
            self.error = "Failed to load branches: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Archives a branch.
    func archiveBranch() async {
        guard let repository = repository,
              let branch = branchToArchive else { return }

        isLoading = true
        error = nil

        do {
            // Get the last commit info for the branch
            let commits = try await gitService.getHistory(
                in: repository,
                limit: 1,
                ref: branch.name
            )

            guard let lastCommit = commits.first else {
                error = "Could not get branch commit information"
                isLoading = false
                return
            }

            // Create archived branch record
            let archived = ArchivedBranch(
                name: branch.name,
                lastCommitHash: lastCommit.hash,
                lastCommitMessage: lastCommit.subject,
                lastCommitDate: lastCommit.authorDate,
                reason: archiveReason.isEmpty ? nil : archiveReason
            )

            // Save to archive store
            try archiveStore.archiveBranch(archived, for: repository.path)

            // Delete the branch
            try await gitService.deleteBranch(name: branch.name, force: true, in: repository)

            // Reload data
            await loadData()

            // Reset state
            branchToArchive = nil
            archiveReason = ""
            showingArchiveSheet = false
        } catch {
            self.error = "Failed to archive branch: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Unarchives a branch (recreates it from the stored commit).
    func unarchiveBranch(_ archived: ArchivedBranch) async {
        guard let repository = repository else { return }

        isLoading = true
        error = nil

        do {
            // Create the branch from the archived commit
            try await gitService.createBranch(
                name: archived.name,
                startPoint: archived.lastCommitHash,
                in: repository
            )

            // Remove from archive
            _ = try archiveStore.unarchiveBranch(named: archived.name, for: repository.path)

            // Reload data
            await loadData()
        } catch {
            self.error = "Failed to unarchive branch: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Permanently deletes an archived branch record.
    func deleteArchivedBranch(_ archived: ArchivedBranch) {
        guard let repository = repository else { return }

        do {
            try archiveStore.removeArchivedBranch(named: archived.name, for: repository.path)
            archivedBranches.removeAll { $0.id == archived.id }
        } catch {
            self.error = "Failed to delete archived branch: \(error.localizedDescription)"
        }
    }

    /// Shows the archive sheet for a branch.
    func showArchiveSheet(for branch: Branch) {
        branchToArchive = branch
        archiveReason = ""
        showingArchiveSheet = true
    }

    // MARK: - Filtered Results

    var filteredBranches: [Branch] {
        var result = branches

        if showMergedOnly {
            result = result.filter { $0.isMerged }
        }

        return result
    }

    var filteredStaleBranches: [BranchStalenessInfo] {
        var result = staleBranches

        if let filter = stalenessFilter {
            result = result.filter { $0.stalenessLevel == filter }
        }

        return result.sorted { $0.daysSinceLastCommit > $1.daysSinceLastCommit }
    }

    var mergedBranches: [Branch] {
        branches.filter { $0.isMerged && !$0.isHead }
    }

    // MARK: - Statistics

    var totalBranchCount: Int {
        branches.count
    }

    var staleBranchCount: Int {
        staleBranches.filter { $0.stalenessLevel == .stale || $0.stalenessLevel == .veryStale }.count
    }

    var mergedBranchCount: Int {
        mergedBranches.count
    }

    var archivedBranchCount: Int {
        archivedBranches.count
    }

    // MARK: - Private Methods

    private func analyzeStaleness() async {
        guard let repository = repository else { return }

        var stalenessInfos: [BranchStalenessInfo] = []

        for branch in branches {
            // Skip HEAD branch
            guard !branch.isHead else { continue }

            do {
                let commits = try await gitService.getHistory(
                    in: repository,
                    limit: 1,
                    ref: branch.name
                )

                if let lastCommit = commits.first {
                    let daysSince = Calendar.current.dateComponents(
                        [.day],
                        from: lastCommit.authorDate,
                        to: Date()
                    ).day ?? 0

                    let info = BranchStalenessInfo(
                        id: branch.name,
                        branch: branch,
                        lastCommitDate: lastCommit.authorDate,
                        daysSinceLastCommit: daysSince,
                        isMerged: branch.isMerged
                    )
                    stalenessInfos.append(info)
                }
            } catch {
                // Skip branches we can't analyze
                continue
            }
        }

        staleBranches = stalenessInfos
    }
}
