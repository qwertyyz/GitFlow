import Foundation

/// View model for commit history.
@MainActor
final class HistoryViewModel: ObservableObject {
    // MARK: - Published State

    /// The commit history.
    @Published private(set) var commits: [Commit] = []

    /// The currently selected commit.
    @Published var selectedCommit: Commit?

    /// Whether history is currently loading.
    @Published private(set) var isLoading: Bool = false

    /// Whether more commits can be loaded.
    @Published private(set) var hasMore: Bool = true

    /// Current error, if any.
    @Published var error: GitError?

    /// Optional file path filter.
    @Published var filePathFilter: String?

    /// Optional branch/ref filter.
    @Published var refFilter: String?

    /// Message search query.
    @Published var messageSearch: String = ""

    /// Author filter.
    @Published var authorFilter: String = ""

    /// Start date for date range filter.
    @Published var sinceDate: Date?

    /// End date for date range filter.
    @Published var untilDate: Date?

    /// Whether any filter is currently active.
    @Published private(set) var hasActiveFilters: Bool = false

    // MARK: - Configuration

    /// Number of commits to load per page.
    let pageSize: Int = 50

    // MARK: - Private State

    private var currentSkip: Int = 0

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Refreshes the commit history.
    func refresh() async {
        currentSkip = 0
        isLoading = true
        defer { isLoading = false }

        updateHasActiveFilters()

        do {
            commits = try await fetchCommits(skip: 0)
            hasMore = commits.count == pageSize
            error = nil

            // Clear selection if commit no longer in list
            if let selected = selectedCommit,
               !commits.contains(where: { $0.hash == selected.hash }) {
                selectedCommit = nil
            }

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Loads more commits (pagination).
    func loadMore() async {
        guard hasMore, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            currentSkip += pageSize
            let newCommits = try await fetchCommits(skip: currentSkip)

            if newCommits.isEmpty {
                hasMore = false
            } else {
                // Skip commits we already have
                let existingHashes = Set(commits.map(\.hash))
                let uniqueNewCommits = newCommits.filter { !existingHashes.contains($0.hash) }
                commits.append(contentsOf: uniqueNewCommits)
                hasMore = newCommits.count == pageSize
            }

            error = nil

        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Selects a commit for viewing details.
    func selectCommit(_ commit: Commit) {
        selectedCommit = commit
    }

    /// Clears the current selection.
    func clearSelection() {
        selectedCommit = nil
    }

    /// Sets a file path filter and refreshes.
    func filterByFile(_ path: String?) async {
        filePathFilter = path
        await refresh()
    }

    /// Sets a ref filter and refreshes.
    func filterByRef(_ ref: String?) async {
        refFilter = ref
        await refresh()
    }

    /// Searches commits by message.
    func searchByMessage(_ query: String) async {
        messageSearch = query
        await refresh()
    }

    /// Filters commits by author.
    func filterByAuthor(_ author: String) async {
        authorFilter = author
        await refresh()
    }

    /// Filters commits by date range.
    func filterByDateRange(since: Date?, until: Date?) async {
        sinceDate = since
        untilDate = until
        await refresh()
    }

    /// Clears all filters and refreshes.
    func clearAllFilters() async {
        messageSearch = ""
        authorFilter = ""
        sinceDate = nil
        untilDate = nil
        filePathFilter = nil
        refFilter = nil
        await refresh()
    }

    /// Applies the current filter settings (call after changing filter properties).
    func applyFilters() async {
        await refresh()
    }

    // MARK: - Private Methods

    private func fetchCommits(skip: Int) async throws -> [Commit] {
        // Build filter options
        var filters = LogFilterOptions()
        filters.skip = skip
        filters.ref = refFilter
        filters.filePath = filePathFilter

        if !messageSearch.isEmpty {
            filters.messageSearch = messageSearch
        }

        if !authorFilter.isEmpty {
            filters.author = authorFilter
        }

        filters.since = sinceDate
        filters.until = untilDate

        return try await gitService.getHistoryWithFilters(
            in: repository,
            limit: pageSize,
            filters: filters
        )
    }

    private func updateHasActiveFilters() {
        hasActiveFilters = !messageSearch.isEmpty ||
            !authorFilter.isEmpty ||
            sinceDate != nil ||
            untilDate != nil ||
            filePathFilter != nil
    }

    // MARK: - Computed Properties

    /// Whether there are any commits.
    var hasCommits: Bool {
        !commits.isEmpty
    }

    /// The count of loaded commits.
    var commitCount: Int {
        commits.count
    }

    /// A summary of active filters for display.
    var filterSummary: String? {
        var parts: [String] = []

        if !messageSearch.isEmpty {
            parts.append("message: \"\(messageSearch)\"")
        }

        if !authorFilter.isEmpty {
            parts.append("author: \(authorFilter)")
        }

        if let since = sinceDate {
            parts.append("since: \(since.formatted(date: .abbreviated, time: .omitted))")
        }

        if let until = untilDate {
            parts.append("until: \(until.formatted(date: .abbreviated, time: .omitted))")
        }

        if let path = filePathFilter {
            parts.append("file: \(path)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
