import Foundation
import Combine

/// View model for managing multiple repositories.
@MainActor
final class RepositoryManagerViewModel: ObservableObject {
    // MARK: - Published State

    /// All known repositories.
    @Published private(set) var repositories: [RepositoryInfo] = []

    /// Open repository tabs.
    @Published private(set) var tabs: [RepositoryTab] = []

    /// Currently active tab.
    @Published var activeTabId: UUID?

    /// Whether scanning is in progress.
    @Published private(set) var isScanning: Bool = false

    /// Scan progress (0.0 - 1.0).
    @Published private(set) var scanProgress: Double = 0

    /// Recent repositories (sorted by last opened).
    @Published private(set) var recentRepositories: [RepositoryInfo] = []

    /// Favorite repositories.
    @Published private(set) var favoriteRepositories: [RepositoryInfo] = []

    /// Current error, if any.
    @Published var error: Error?

    // MARK: - Private Properties

    private let storageKey = "knownRepositories"
    private let maxRecent = 10
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadRepositories()
        updateComputedLists()
    }

    // MARK: - Repository Management

    /// Adds a repository to the known list.
    func addRepository(at path: String) {
        guard !repositories.contains(where: { $0.path == path }) else {
            // Update last opened if it already exists
            updateLastOpened(path: path)
            return
        }

        let info = RepositoryInfo(path: path)
        repositories.append(info)
        saveRepositories()
        updateComputedLists()
    }

    /// Removes a repository from the known list.
    func removeRepository(_ repository: RepositoryInfo) {
        repositories.removeAll { $0.id == repository.id }
        closeTab(for: repository)
        saveRepositories()
        updateComputedLists()
    }

    /// Updates the last opened time for a repository.
    func updateLastOpened(path: String) {
        if let index = repositories.firstIndex(where: { $0.path == path }) {
            repositories[index].lastOpened = Date()
            saveRepositories()
            updateComputedLists()
        }
    }

    /// Toggles favorite status.
    func toggleFavorite(_ repository: RepositoryInfo) {
        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index].isFavorite.toggle()
            saveRepositories()
            updateComputedLists()
        }
    }

    /// Renames a repository (display name only).
    func renameRepository(_ repository: RepositoryInfo, to newName: String) {
        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index].name = newName
            saveRepositories()
        }
    }

    /// Sets the color for a repository.
    func setColor(_ color: String?, for repository: RepositoryInfo) {
        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index].color = color
            saveRepositories()
        }
    }

    // MARK: - Tab Management

    /// Opens a repository in a new tab.
    func openInTab(_ repository: RepositoryInfo) {
        // Check if already open
        if let existingTab = tabs.first(where: { $0.repositoryInfo.id == repository.id }) {
            activateTab(existingTab.id)
            return
        }

        // Close active state on current tab
        if let activeId = activeTabId,
           let index = tabs.firstIndex(where: { $0.id == activeId }) {
            tabs[index].isActive = false
        }

        // Create new tab
        let tab = RepositoryTab(repositoryInfo: repository, isActive: true)
        tabs.append(tab)
        activeTabId = tab.id
        updateLastOpened(path: repository.path)
    }

    /// Closes a tab.
    func closeTab(_ tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

        let wasActive = tabs[index].isActive
        tabs.remove(at: index)

        if wasActive && !tabs.isEmpty {
            // Activate the previous tab or the first one
            let newIndex = max(0, min(index, tabs.count - 1))
            tabs[newIndex].isActive = true
            activeTabId = tabs[newIndex].id
        } else if tabs.isEmpty {
            activeTabId = nil
        }
    }

    /// Closes a tab for a specific repository.
    func closeTab(for repository: RepositoryInfo) {
        if let tab = tabs.first(where: { $0.repositoryInfo.id == repository.id }) {
            closeTab(tab.id)
        }
    }

    /// Activates a tab.
    func activateTab(_ tabId: UUID) {
        for index in tabs.indices {
            tabs[index].isActive = tabs[index].id == tabId
        }
        activeTabId = tabId
    }

    /// Moves a tab to a new position.
    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    /// Gets the active repository.
    var activeRepository: RepositoryInfo? {
        tabs.first { $0.isActive }?.repositoryInfo
    }

    // MARK: - Repository Discovery

    /// Scans a directory for git repositories.
    func discoverRepositories(in directory: URL, options: DiscoveryOptions = DiscoveryOptions()) async -> RepositoryScanResult {
        isScanning = true
        scanProgress = 0

        let startTime = Date()
        var foundPaths: [String] = []
        var scannedCount = 0

        func scan(_ url: URL, depth: Int) {
            guard depth <= options.maxDepth else { return }

            let fileManager = FileManager.default

            // Check if this is a git repository
            let gitPath = url.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitPath.path) {
                foundPaths.append(url.path)
                return // Don't scan inside git repos
            }

            // Scan subdirectories
            guard let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for item in contents {
                let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                let isSymlink = resourceValues?.isSymbolicLink ?? false

                if !isDirectory { continue }
                if isSymlink && !options.followSymlinks { continue }
                if options.excludedDirectories.contains(item.lastPathComponent) { continue }

                scannedCount += 1
                scan(item, depth: depth + 1)
            }
        }

        // Run on background thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                scan(directory, depth: 0)
                continuation.resume()
            }
        }

        // Add found repositories
        for path in foundPaths {
            addRepository(at: path)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        isScanning = false
        scanProgress = 1.0

        return RepositoryScanResult(
            foundRepositories: foundPaths,
            scannedDirectories: scannedCount,
            elapsedTime: elapsed
        )
    }

    /// Cleans up repositories that no longer exist.
    func cleanupInvalidRepositories() {
        let validRepos = repositories.filter { $0.exists && $0.isGitRepository }
        if validRepos.count != repositories.count {
            repositories = validRepos
            saveRepositories()
            updateComputedLists()
        }
    }

    // MARK: - Private Methods

    private func loadRepositories() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let repos = try? JSONDecoder().decode([RepositoryInfo].self, from: data) {
            repositories = repos
        }
    }

    private func saveRepositories() {
        if let data = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func updateComputedLists() {
        // Update recent (sorted by last opened, limited)
        recentRepositories = repositories
            .sorted { $0.lastOpened > $1.lastOpened }
            .prefix(maxRecent)
            .map { $0 }

        // Update favorites
        favoriteRepositories = repositories
            .filter { $0.isFavorite }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
