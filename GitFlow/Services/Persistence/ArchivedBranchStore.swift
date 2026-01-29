import Foundation

/// Service for persisting archived branch data.
/// Archived branches are stored per-repository in a JSON file.
final class ArchivedBranchStore {
    private let fileManager = FileManager.default

    /// Gets the archive file URL for a repository.
    private func archiveFileURL(for repositoryPath: String) -> URL {
        let repoHash = repositoryPath.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(32) ?? "default"

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let archivesDir = appSupport.appendingPathComponent("GitFlow/ArchivedBranches", isDirectory: true)

        // Ensure directory exists
        try? fileManager.createDirectory(at: archivesDir, withIntermediateDirectories: true)

        return archivesDir.appendingPathComponent("\(repoHash).json")
    }

    /// Loads all archived branches for a repository.
    func loadArchivedBranches(for repositoryPath: String) -> [ArchivedBranch] {
        let fileURL = archiveFileURL(for: repositoryPath)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ArchivedBranch].self, from: data)
        } catch {
            print("Failed to load archived branches: \(error)")
            return []
        }
    }

    /// Saves archived branches for a repository.
    func saveArchivedBranches(_ branches: [ArchivedBranch], for repositoryPath: String) throws {
        let fileURL = archiveFileURL(for: repositoryPath)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(branches)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Archives a branch.
    func archiveBranch(_ branch: ArchivedBranch, for repositoryPath: String) throws {
        var branches = loadArchivedBranches(for: repositoryPath)

        // Remove existing archive with same name if present
        branches.removeAll { $0.name == branch.name }

        branches.append(branch)
        try saveArchivedBranches(branches, for: repositoryPath)
    }

    /// Unarchives a branch by name.
    func unarchiveBranch(named name: String, for repositoryPath: String) throws -> ArchivedBranch? {
        var branches = loadArchivedBranches(for: repositoryPath)

        guard let index = branches.firstIndex(where: { $0.name == name }) else {
            return nil
        }

        let branch = branches.remove(at: index)
        try saveArchivedBranches(branches, for: repositoryPath)
        return branch
    }

    /// Removes an archived branch permanently.
    func removeArchivedBranch(named name: String, for repositoryPath: String) throws {
        var branches = loadArchivedBranches(for: repositoryPath)
        branches.removeAll { $0.name == name }
        try saveArchivedBranches(branches, for: repositoryPath)
    }

    /// Checks if a branch is archived.
    func isArchived(branchName: String, for repositoryPath: String) -> Bool {
        loadArchivedBranches(for: repositoryPath).contains { $0.name == branchName }
    }
}
