import Foundation

/// Service for automatically stashing changes before Git operations.
actor AutoStashService {
    static let shared = AutoStashService()

    private let gitService = GitService()

    private init() {}

    // MARK: - Settings

    struct AutoStashSettings: Codable {
        var enableAutoStash: Bool = false
        var autoStashBeforePull: Bool = true
        var autoStashBeforeCheckout: Bool = true
        var autoStashBeforeMerge: Bool = true
        var autoStashBeforeRebase: Bool = true
        var autoRestoreAfterOperation: Bool = true
        var includeUntrackedFiles: Bool = false
        var showNotificationOnAutoStash: Bool = true

        static var `default`: AutoStashSettings { AutoStashSettings() }

        private static let key = "autoStashSettings"

        static func load() -> AutoStashSettings {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let settings = try? JSONDecoder().decode(AutoStashSettings.self, from: data) else {
                return .default
            }
            return settings
        }

        func save() {
            if let data = try? JSONEncoder().encode(self) {
                UserDefaults.standard.set(data, forKey: AutoStashSettings.key)
            }
        }
    }

    // MARK: - Auto Stash Operations

    /// Result of an auto-stash operation.
    struct AutoStashResult {
        let wasStashed: Bool
        let stashMessage: String?
        let error: Error?

        static let noChanges = AutoStashResult(wasStashed: false, stashMessage: nil, error: nil)
    }

    /// Automatically stashes changes if needed before an operation.
    /// Returns the stash reference if changes were stashed.
    func autoStashIfNeeded(
        in repository: Repository,
        operation: String,
        settings: AutoStashSettings? = nil
    ) async -> AutoStashResult {
        let config = settings ?? AutoStashSettings.load()

        guard config.enableAutoStash else {
            return .noChanges
        }

        // Check if there are uncommitted changes
        do {
            let status = try await gitService.getStatus(in: repository)

            let hasChanges = !status.stagedFiles.isEmpty ||
                             !status.unstagedFiles.isEmpty ||
                             (config.includeUntrackedFiles && !status.untrackedFiles.isEmpty)

            guard hasChanges else {
                return .noChanges
            }

            // Create the auto-stash
            let message = "GitFlow auto-stash before \(operation) at \(Date().formatted())"

            try await gitService.createStash(
                message: message,
                includeUntracked: config.includeUntrackedFiles,
                in: repository
            )

            // Notify if enabled
            if config.showNotificationOnAutoStash {
                await notifyAutoStash(operation: operation, repository: repository.name)
            }

            return AutoStashResult(wasStashed: true, stashMessage: message, error: nil)
        } catch {
            return AutoStashResult(wasStashed: false, stashMessage: nil, error: error)
        }
    }

    /// Restores an auto-stashed state after an operation.
    func autoRestoreIfNeeded(
        in repository: Repository,
        wasStashed: Bool,
        settings: AutoStashSettings? = nil
    ) async throws {
        let config = settings ?? AutoStashSettings.load()

        guard config.autoRestoreAfterOperation && wasStashed else {
            return
        }

        // Pop the most recent stash (which should be our auto-stash)
        try await gitService.popStash("stash@{0}", in: repository)

        if config.showNotificationOnAutoStash {
            await notifyAutoRestore(repository: repository.name)
        }
    }

    /// Performs an operation with auto-stash handling.
    func withAutoStash<T>(
        in repository: Repository,
        operation: String,
        settings: AutoStashSettings? = nil,
        action: () async throws -> T
    ) async throws -> T {
        let stashResult = await autoStashIfNeeded(
            in: repository,
            operation: operation,
            settings: settings
        )

        if let error = stashResult.error {
            throw error
        }

        do {
            let result = try await action()

            // Restore stash if needed
            try await autoRestoreIfNeeded(
                in: repository,
                wasStashed: stashResult.wasStashed,
                settings: settings
            )

            return result
        } catch {
            // Try to restore stash even on failure
            try? await autoRestoreIfNeeded(
                in: repository,
                wasStashed: stashResult.wasStashed,
                settings: settings
            )
            throw error
        }
    }

    // MARK: - Notifications

    private func notifyAutoStash(operation: String, repository: String) async {
        await NotificationService.shared.notifyOperationComplete(
            operation: "Auto-Stash",
            repository: repository,
            success: true,
            details: "Changes automatically stashed before \(operation)"
        )
    }

    private func notifyAutoRestore(repository: String) async {
        await NotificationService.shared.notifyOperationComplete(
            operation: "Auto-Restore",
            repository: repository,
            success: true,
            details: "Auto-stashed changes have been restored"
        )
    }
}

// MARK: - Stash Options (if not already defined)

struct StashOptions {
    var message: String?
    var includeUntracked: Bool = false
    var keepIndex: Bool = false
}
