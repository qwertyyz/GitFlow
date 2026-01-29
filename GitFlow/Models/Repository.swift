import Foundation

/// Represents a Git repository.
struct Repository: Identifiable, Equatable {
    /// Unique identifier for this repository instance.
    let id: UUID

    /// The root directory URL of the repository.
    let rootURL: URL

    /// The name of the repository (directory name).
    var name: String {
        rootURL.lastPathComponent
    }

    /// The absolute path to the repository.
    var path: String {
        rootURL.path
    }

    /// The remote URL of the origin remote (if available).
    /// Computed by reading the git config.
    var remoteURL: String? {
        let configPath = rootURL.appendingPathComponent(".git/config")
        guard let configContents = try? String(contentsOf: configPath, encoding: .utf8) else {
            return nil
        }

        // Simple parser to find origin remote URL
        var inOriginSection = false
        for line in configContents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[remote \"origin\"]" {
                inOriginSection = true
            } else if trimmed.hasPrefix("[") {
                inOriginSection = false
            } else if inOriginSection && trimmed.hasPrefix("url = ") {
                return String(trimmed.dropFirst(6))
            }
        }
        return nil
    }

    /// Creates a new repository reference.
    /// - Parameter rootURL: The root directory URL of the Git repository.
    init(rootURL: URL) {
        self.id = UUID()
        self.rootURL = rootURL
    }
}
