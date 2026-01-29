import Foundation

/// Service for managing repository groups.
actor RepositoryGroupStore {
    static let shared = RepositoryGroupStore()

    private let fileManager = FileManager.default
    private let groupsKey = "repositoryGroups"

    private init() {}

    // MARK: - Group Model

    struct RepositoryGroup: Identifiable, Equatable, Hashable, Codable {
        let id: UUID
        var name: String
        var icon: String
        var color: String?
        var repositoryPaths: [String]
        var sortOrder: Int

        init(
            id: UUID = UUID(),
            name: String,
            icon: String = "folder",
            color: String? = nil,
            repositoryPaths: [String] = [],
            sortOrder: Int = 0
        ) {
            self.id = id
            self.name = name
            self.icon = icon
            self.color = color
            self.repositoryPaths = repositoryPaths
            self.sortOrder = sortOrder
        }
    }

    // MARK: - Load & Save

    func loadGroups() -> [RepositoryGroup] {
        guard let data = UserDefaults.standard.data(forKey: groupsKey),
              let groups = try? JSONDecoder().decode([RepositoryGroup].self, from: data) else {
            return []
        }
        return groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    func saveGroups(_ groups: [RepositoryGroup]) {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    // MARK: - CRUD Operations

    func createGroup(name: String, icon: String = "folder", color: String? = nil) -> RepositoryGroup {
        var groups = loadGroups()
        let maxOrder = groups.map { $0.sortOrder }.max() ?? -1
        let group = RepositoryGroup(
            name: name,
            icon: icon,
            color: color,
            sortOrder: maxOrder + 1
        )
        groups.append(group)
        saveGroups(groups)
        return group
    }

    func updateGroup(_ group: RepositoryGroup) {
        var groups = loadGroups()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups(groups)
        }
    }

    func deleteGroup(id: UUID) {
        var groups = loadGroups()
        groups.removeAll { $0.id == id }
        saveGroups(groups)
    }

    // MARK: - Repository Assignment

    func addRepositoryToGroup(repositoryPath: String, groupId: UUID) {
        var groups = loadGroups()
        // Remove from all groups first
        for i in 0..<groups.count {
            groups[i].repositoryPaths.removeAll { $0 == repositoryPath }
        }
        // Add to target group
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].repositoryPaths.append(repositoryPath)
        }
        saveGroups(groups)
    }

    func removeRepositoryFromGroup(repositoryPath: String, groupId: UUID) {
        var groups = loadGroups()
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].repositoryPaths.removeAll { $0 == repositoryPath }
            saveGroups(groups)
        }
    }

    func removeRepositoryFromAllGroups(repositoryPath: String) {
        var groups = loadGroups()
        for i in 0..<groups.count {
            groups[i].repositoryPaths.removeAll { $0 == repositoryPath }
        }
        saveGroups(groups)
    }

    func getGroupForRepository(path: String) -> RepositoryGroup? {
        loadGroups().first { $0.repositoryPaths.contains(path) }
    }

    // MARK: - Reordering

    func reorderGroups(fromIndex: Int, toIndex: Int) {
        var groups = loadGroups()
        guard fromIndex < groups.count, toIndex < groups.count else { return }

        let group = groups.remove(at: fromIndex)
        groups.insert(group, at: toIndex)

        // Update sort orders
        for (index, _) in groups.enumerated() {
            groups[index].sortOrder = index
        }

        saveGroups(groups)
    }
}

// MARK: - Repository Filter

enum RepositoryFilterOption: String, CaseIterable, Identifiable {
    case all = "All Repositories"
    case local = "Local Only"
    case withRemote = "With Remote"
    case withUncommitted = "With Uncommitted Changes"
    case favorites = "Favorites"
    case recent = "Recently Opened"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "folder"
        case .local: return "laptopcomputer"
        case .withRemote: return "network"
        case .withUncommitted: return "pencil.circle"
        case .favorites: return "star"
        case .recent: return "clock"
        }
    }
}

// MARK: - Repository Sort

enum RepositorySortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case lastOpened = "Last Opened"
    case lastModified = "Last Modified"
    case path = "Path"
    case size = "Size"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .name: return "textformat.abc"
        case .lastOpened: return "clock"
        case .lastModified: return "calendar"
        case .path: return "folder"
        case .size: return "externaldrive"
        }
    }
}

// MARK: - Repository List Manager

@MainActor
class RepositoryListManager: ObservableObject {
    @Published var groups: [RepositoryGroupStore.RepositoryGroup] = []
    @Published var selectedGroupId: UUID?
    @Published var filterOption: RepositoryFilterOption = .all
    @Published var sortOption: RepositorySortOption = .name
    @Published var sortAscending = true
    @Published var searchText = ""

    private let groupStore = RepositoryGroupStore.shared

    init() {
        Task {
            await loadGroups()
        }
    }

    func loadGroups() async {
        groups = await groupStore.loadGroups()
    }

    func createGroup(name: String, icon: String, color: String?) async {
        _ = await groupStore.createGroup(name: name, icon: icon, color: color)
        await loadGroups()
    }

    func updateGroup(_ group: RepositoryGroupStore.RepositoryGroup) async {
        await groupStore.updateGroup(group)
        await loadGroups()
    }

    func deleteGroup(id: UUID) async {
        await groupStore.deleteGroup(id: id)
        if selectedGroupId == id {
            selectedGroupId = nil
        }
        await loadGroups()
    }

    func addRepositoryToGroup(path: String, groupId: UUID) async {
        await groupStore.addRepositoryToGroup(repositoryPath: path, groupId: groupId)
        await loadGroups()
    }

    func removeRepositoryFromGroup(path: String, groupId: UUID) async {
        await groupStore.removeRepositoryFromGroup(repositoryPath: path, groupId: groupId)
        await loadGroups()
    }

    func getGroupForRepository(path: String) async -> RepositoryGroupStore.RepositoryGroup? {
        await groupStore.getGroupForRepository(path: path)
    }

    // MARK: - Filtering

    func filterRepositories(_ repositories: [RepositoryInfo]) -> [RepositoryInfo] {
        var result = repositories

        // Filter by group
        if let groupId = selectedGroupId,
           let group = groups.first(where: { $0.id == groupId }) {
            result = result.filter { group.repositoryPaths.contains($0.path) }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply filter option
        switch filterOption {
        case .all:
            break
        case .local:
            // Would filter by repos without remote
            break
        case .withRemote:
            // Would filter by repos with remote
            break
        case .withUncommitted:
            // Would filter by repos with uncommitted changes
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .recent:
            // Would sort by last opened and take top N
            break
        }

        // Sort
        result.sort { repo1, repo2 in
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = repo1.name.localizedCaseInsensitiveCompare(repo2.name) == .orderedAscending
            case .lastOpened:
                // Would use actual dates
                comparison = repo1.name < repo2.name
            case .lastModified:
                // Would use file system dates
                comparison = repo1.name < repo2.name
            case .path:
                comparison = repo1.path < repo2.path
            case .size:
                // Would use actual size
                comparison = repo1.name < repo2.name
            }
            return sortAscending ? comparison : !comparison
        }

        return result
    }
}
