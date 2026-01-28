import Foundation

/// Information about a repository in the manager.
struct RepositoryInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let path: String
    var name: String
    var isFavorite: Bool
    var lastOpened: Date
    var color: String?

    init(
        id: UUID = UUID(),
        path: String,
        name: String? = nil,
        isFavorite: Bool = false,
        lastOpened: Date = Date(),
        color: String? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
        self.isFavorite = isFavorite
        self.lastOpened = lastOpened
        self.color = color
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var isGitRepository: Bool {
        let gitPath = url.appendingPathComponent(".git").path
        return FileManager.default.fileExists(atPath: gitPath)
    }
}

/// A tab representing an open repository.
struct RepositoryTab: Identifiable, Equatable {
    let id: UUID
    let repositoryInfo: RepositoryInfo
    var isActive: Bool

    init(repositoryInfo: RepositoryInfo, isActive: Bool = false) {
        self.id = UUID()
        self.repositoryInfo = repositoryInfo
        self.isActive = isActive
    }
}

/// Result of scanning for repositories.
struct RepositoryScanResult {
    let foundRepositories: [String]
    let scannedDirectories: Int
    let elapsedTime: TimeInterval
}

/// Options for repository discovery.
struct DiscoveryOptions {
    /// Maximum depth to scan.
    var maxDepth: Int = 3

    /// Directories to skip.
    var excludedDirectories: [String] = [
        "node_modules",
        ".git",
        "build",
        "dist",
        "Pods",
        "Carthage",
        "DerivedData",
        ".build",
        "vendor",
        "__pycache__",
        "venv",
        ".venv"
    ]

    /// Whether to follow symlinks.
    var followSymlinks: Bool = false
}
