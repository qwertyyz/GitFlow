import Foundation

/// View model for git configuration management.
@MainActor
final class ConfigViewModel: ObservableObject {
    // MARK: - Published State

    /// All configuration entries.
    @Published private(set) var entries: [GitConfigEntry] = []

    /// Filtered entries based on search.
    @Published private(set) var filteredEntries: [GitConfigEntry] = []

    /// Search query.
    @Published var searchQuery: String = "" {
        didSet { filterEntries() }
    }

    /// Selected scope filter.
    @Published var scopeFilter: ConfigScope? = nil {
        didSet { filterEntries() }
    }

    /// Selected section filter.
    @Published var sectionFilter: String? = nil {
        didSet { filterEntries() }
    }

    /// Whether config is loading.
    @Published private(set) var isLoading: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Application preferences.
    @Published var appPreferences: AppPreferences = AppPreferences()

    /// User name (quick access).
    @Published var userName: String = ""

    /// User email (quick access).
    @Published var userEmail: String = ""

    // MARK: - Dependencies

    private let repository: Repository?
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository?, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
        loadAppPreferences()
    }

    // MARK: - Public Methods

    /// Loads all configuration.
    func loadConfig() async {
        isLoading = true
        defer { isLoading = false }

        do {
            entries = try await gitService.listConfig(scope: nil, in: repository)
            filterEntries()

            // Load user info
            userName = try await gitService.getConfig(key: "user.name", scope: .global, in: repository) ?? ""
            userEmail = try await gitService.getConfig(key: "user.email", scope: .global, in: repository) ?? ""

            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Gets a config value.
    func getValue(for key: String, scope: ConfigScope? = nil) async -> String? {
        do {
            return try await gitService.getConfig(key: key, scope: scope, in: repository)
        } catch {
            return nil
        }
    }

    /// Sets a config value.
    func setValue(_ value: String, for key: String, scope: ConfigScope) async {
        do {
            try await gitService.setConfig(key: key, value: value, scope: scope, in: repository)
            await loadConfig()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Unsets a config value.
    func unsetValue(for key: String, scope: ConfigScope) async {
        do {
            try await gitService.unsetConfig(key: key, scope: scope, in: repository)
            await loadConfig()
            error = nil
        } catch let gitError as GitError {
            error = gitError
        } catch {
            self.error = .unknown(message: error.localizedDescription)
        }
    }

    /// Saves user identity settings.
    func saveUserIdentity() async {
        if !userName.isEmpty {
            await setValue(userName, for: "user.name", scope: .global)
        }
        if !userEmail.isEmpty {
            await setValue(userEmail, for: "user.email", scope: .global)
        }
    }

    /// Saves application preferences.
    func saveAppPreferences() {
        if let data = try? JSONEncoder().encode(appPreferences) {
            UserDefaults.standard.set(data, forKey: "appPreferences")
        }
    }

    /// Loads application preferences.
    func loadAppPreferences() {
        if let data = UserDefaults.standard.data(forKey: "appPreferences"),
           let prefs = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            appPreferences = prefs
        }
    }

    // MARK: - Computed Properties

    /// All unique sections in the config.
    var sections: [String] {
        Array(Set(entries.map { $0.section })).sorted()
    }

    /// Entries grouped by section.
    var entriesBySection: [(section: String, entries: [GitConfigEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.section }
        return grouped.keys.sorted().map { section in
            (section, grouped[section]!.sorted { $0.name < $1.name })
        }
    }

    /// Entries grouped by scope.
    var entriesByScope: [(scope: ConfigScope, entries: [GitConfigEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.scope }
        return ConfigScope.allCases.compactMap { scope in
            guard let entries = grouped[scope], !entries.isEmpty else { return nil }
            return (scope, entries.sorted { $0.key < $1.key })
        }
    }

    // MARK: - Private Methods

    private func filterEntries() {
        var result = entries

        // Filter by scope
        if let scope = scopeFilter {
            result = result.filter { $0.scope == scope }
        }

        // Filter by section
        if let section = sectionFilter {
            result = result.filter { $0.section == section }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.key.lowercased().contains(query) ||
                $0.value.lowercased().contains(query)
            }
        }

        filteredEntries = result
    }
}

// MARK: - GitService Extensions

extension GitService {
    /// Gets a config value.
    func getConfig(key: String, scope: ConfigScope?, in repository: Repository?) async throws -> String? {
        let command = GetConfigCommand(key: key, scope: scope)
        let workingDir = repository?.rootURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let result = try await executor.execute(
            arguments: command.arguments,
            workingDirectory: workingDir
        )

        // Config not found is not an error
        if !result.succeeded && result.exitCode == 1 {
            return nil
        }

        return try command.parse(output: result.stdout)
    }

    /// Sets a config value.
    func setConfig(key: String, value: String, scope: ConfigScope, in repository: Repository?) async throws {
        let command = SetConfigCommand(key: key, value: value, scope: scope)
        let workingDir = repository?.rootURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: workingDir
        )
    }

    /// Unsets a config value.
    func unsetConfig(key: String, scope: ConfigScope, in repository: Repository?) async throws {
        let command = UnsetConfigCommand(key: key, scope: scope)
        let workingDir = repository?.rootURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        _ = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: workingDir
        )
    }

    /// Lists all config values.
    func listConfig(scope: ConfigScope?, in repository: Repository?) async throws -> [GitConfigEntry] {
        let command = ListConfigCommand(scope: scope, showOrigin: true)
        let workingDir = repository?.rootURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let output = try await executor.executeOrThrow(
            arguments: command.arguments,
            workingDirectory: workingDir
        )

        return try command.parse(output: output)
    }
}
