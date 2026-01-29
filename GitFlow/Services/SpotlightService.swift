import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Service for integrating with macOS Spotlight search.
actor SpotlightService {
    static let shared = SpotlightService()

    private let searchableIndex = CSSearchableIndex.default()
    private let domainIdentifier = "com.gitflow.repositories"

    private init() {}

    // MARK: - Index Management

    /// Indexes a repository for Spotlight search.
    func indexRepository(_ repository: Repository) async {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .folder)

        // Basic info
        attributeSet.title = repository.name
        attributeSet.contentDescription = "Git repository at \(repository.path)"
        attributeSet.path = repository.path

        // Additional metadata
        attributeSet.keywords = ["git", "repository", "source code", repository.name]
        attributeSet.displayName = repository.name

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: repository.path,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // Index doesn't expire
        item.expirationDate = .distantFuture

        do {
            try await searchableIndex.indexSearchableItems([item])
        } catch {
            print("Failed to index repository: \(error)")
        }
    }

    /// Indexes multiple repositories.
    func indexRepositories(_ repositories: [Repository]) async {
        let items = repositories.map { repository -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .folder)
            attributeSet.title = repository.name
            attributeSet.contentDescription = "Git repository at \(repository.path)"
            attributeSet.path = repository.path
            attributeSet.keywords = ["git", "repository", "source code", repository.name]
            attributeSet.displayName = repository.name

            let item = CSSearchableItem(
                uniqueIdentifier: repository.path,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = .distantFuture
            return item
        }

        do {
            try await searchableIndex.indexSearchableItems(items)
        } catch {
            print("Failed to index repositories: \(error)")
        }
    }

    /// Removes a repository from the Spotlight index.
    func removeRepository(_ repository: Repository) async {
        do {
            try await searchableIndex.deleteSearchableItems(withIdentifiers: [repository.path])
        } catch {
            print("Failed to remove repository from index: \(error)")
        }
    }

    /// Removes a repository by path from the Spotlight index.
    func removeRepository(atPath path: String) async {
        do {
            try await searchableIndex.deleteSearchableItems(withIdentifiers: [path])
        } catch {
            print("Failed to remove repository from index: \(error)")
        }
    }

    /// Removes all GitFlow repositories from the Spotlight index.
    func removeAllRepositories() async {
        do {
            try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
        } catch {
            print("Failed to remove all repositories from index: \(error)")
        }
    }

    /// Re-indexes all repositories (removes then adds).
    func reindexAllRepositories(_ repositories: [Repository]) async {
        await removeAllRepositories()
        await indexRepositories(repositories)
    }

    // MARK: - Enhanced Indexing

    /// Indexes a repository with additional Git metadata.
    func indexRepositoryWithMetadata(
        _ repository: Repository,
        branches: [String]? = nil,
        lastCommitMessage: String? = nil,
        lastCommitAuthor: String? = nil,
        remoteURL: String? = nil
    ) async {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .folder)

        // Basic info
        attributeSet.title = repository.name
        attributeSet.displayName = repository.name
        attributeSet.path = repository.path

        // Build description
        var descriptionParts: [String] = ["Git repository"]
        if let remote = remoteURL {
            descriptionParts.append("Remote: \(remote)")
        }
        if let message = lastCommitMessage {
            descriptionParts.append("Last commit: \(message)")
        }
        attributeSet.contentDescription = descriptionParts.joined(separator: "\n")

        // Keywords
        var keywords = ["git", "repository", "source code", repository.name]
        if let branches = branches {
            keywords.append(contentsOf: branches)
        }
        if let author = lastCommitAuthor {
            keywords.append(author)
        }
        attributeSet.keywords = keywords

        // Additional metadata (if supported)
        if let author = lastCommitAuthor {
            attributeSet.creator = author
        }

        let item = CSSearchableItem(
            uniqueIdentifier: repository.path,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = .distantFuture

        do {
            try await searchableIndex.indexSearchableItems([item])
        } catch {
            print("Failed to index repository with metadata: \(error)")
        }
    }

    // MARK: - Settings

    struct SpotlightSettings: Codable {
        var isEnabled: Bool = true
        var indexBranchNames: Bool = false
        var indexCommitAuthors: Bool = false
        var autoUpdateIndex: Bool = true

        private static let key = "spotlightSettings"

        static func load() -> SpotlightSettings {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let settings = try? JSONDecoder().decode(SpotlightSettings.self, from: data) else {
                return SpotlightSettings()
            }
            return settings
        }

        func save() {
            if let data = try? JSONEncoder().encode(self) {
                UserDefaults.standard.set(data, forKey: SpotlightSettings.key)
            }
        }
    }
}

// MARK: - Spotlight Handler

/// Handles Spotlight search result selection.
class SpotlightHandler: NSObject {
    static let shared = SpotlightHandler()

    private override init() {
        super.init()
        registerForSpotlightNotifications()
    }

    private func registerForSpotlightNotifications() {
        // Register for when user selects a Spotlight result
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpotlightSelection(_:)),
            name: NSNotification.Name("NSApplicationSpotlightResultSelected"),
            object: nil
        )
    }

    @objc private func handleSpotlightSelection(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let identifier = userInfo["kMDItemPath"] as? String else {
            return
        }

        // Open the repository
        NotificationCenter.default.post(
            name: .openRepository,
            object: nil,
            userInfo: ["path": identifier]
        )
    }

    /// Call this to handle a Spotlight search continuation.
    func handleSpotlightContinuation(userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return false
        }

        // Open the repository
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openRepository,
                object: nil,
                userInfo: ["path": identifier]
            )
        }

        return true
    }
}

// MARK: - Spotlight Settings View

import SwiftUI

struct SpotlightSettingsView: View {
    @State private var settings = SpotlightService.SpotlightSettings.load()
    @State private var isReindexing = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Spotlight Integration", isOn: $settings.isEnabled)
                    .onChange(of: settings.isEnabled) { _ in
                        settings.save()
                    }

                Text("When enabled, your repositories will appear in Spotlight search results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Index Options") {
                Toggle("Index branch names", isOn: $settings.indexBranchNames)
                    .onChange(of: settings.indexBranchNames) { _ in
                        settings.save()
                    }

                Toggle("Index commit authors", isOn: $settings.indexCommitAuthors)
                    .onChange(of: settings.indexCommitAuthors) { _ in
                        settings.save()
                    }

                Toggle("Auto-update index", isOn: $settings.autoUpdateIndex)
                    .onChange(of: settings.autoUpdateIndex) { _ in
                        settings.save()
                    }
            }
            .disabled(!settings.isEnabled)

            Section("Maintenance") {
                HStack {
                    Button("Rebuild Index") {
                        rebuildIndex()
                    }
                    .disabled(isReindexing || !settings.isEnabled)

                    if isReindexing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.leading, 8)
                    }
                }

                Button("Clear Index", role: .destructive) {
                    clearIndex()
                }
                .disabled(!settings.isEnabled)
            }
        }
        .formStyle(.grouped)
    }

    private func rebuildIndex() {
        isReindexing = true
        Task {
            // Would need to get all repositories from the repository manager
            // await SpotlightService.shared.reindexAllRepositories(repositories)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                isReindexing = false
            }
        }
    }

    private func clearIndex() {
        Task {
            await SpotlightService.shared.removeAllRepositories()
        }
    }
}

#Preview {
    SpotlightSettingsView()
        .frame(width: 400)
}
