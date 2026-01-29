import Foundation

/// Stores and retrieves commit templates.
final class CommitTemplateStore {
    /// The file name for storing templates.
    private let fileName = "commit_templates.json"

    /// The file manager instance.
    private let fileManager: FileManager

    /// Cached templates for performance.
    private var cachedTemplates: [CommitTemplate]?

    /// Creates a CommitTemplateStore.
    /// - Parameter fileManager: The FileManager instance to use. Defaults to default.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - File Management

    /// The URL for the templates storage file.
    private var storageURL: URL? {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let gitFlowURL = appSupportURL.appendingPathComponent("GitFlow", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: gitFlowURL.path) {
            try? fileManager.createDirectory(at: gitFlowURL, withIntermediateDirectories: true)
        }

        return gitFlowURL.appendingPathComponent(fileName)
    }

    // MARK: - CRUD Operations

    /// Loads all templates from storage.
    /// - Returns: Array of commit templates including built-in templates.
    func loadAll() -> [CommitTemplate] {
        if let cached = cachedTemplates {
            return cached
        }

        var templates = loadUserTemplates()

        // Add built-in templates if not already present
        let userTemplateNames = Set(templates.map(\.name))
        for builtIn in CommitTemplate.builtInTemplates {
            if !userTemplateNames.contains(builtIn.name) {
                templates.append(builtIn)
            }
        }

        cachedTemplates = templates
        return templates
    }

    /// Loads only user-created templates.
    /// - Returns: Array of user-created templates.
    func loadUserTemplates() -> [CommitTemplate] {
        guard let url = storageURL,
              fileManager.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([CommitTemplate].self, from: data)
        } catch {
            print("Error loading commit templates: \(error)")
            return []
        }
    }

    /// Saves a new template.
    /// - Parameter template: The template to save.
    /// - Throws: Error if saving fails.
    func save(_ template: CommitTemplate) throws {
        var templates = loadUserTemplates()

        // Check for duplicate names
        if templates.contains(where: { $0.name == template.name && $0.id != template.id }) {
            throw CommitTemplateStoreError.duplicateName
        }

        templates.append(template)
        try persist(templates)
        cachedTemplates = nil
    }

    /// Updates an existing template.
    /// - Parameter template: The template with updated values.
    /// - Throws: Error if updating fails.
    func update(_ template: CommitTemplate) throws {
        var templates = loadUserTemplates()

        guard let index = templates.firstIndex(where: { $0.id == template.id }) else {
            throw CommitTemplateStoreError.notFound
        }

        // Check for duplicate names (excluding self)
        if templates.contains(where: { $0.name == template.name && $0.id != template.id }) {
            throw CommitTemplateStoreError.duplicateName
        }

        var updatedTemplate = template
        updatedTemplate.modifiedAt = Date()
        templates[index] = updatedTemplate
        try persist(templates)
        cachedTemplates = nil
    }

    /// Deletes a template.
    /// - Parameter template: The template to delete.
    /// - Throws: Error if deletion fails.
    func delete(_ template: CommitTemplate) throws {
        if template.isBuiltIn {
            throw CommitTemplateStoreError.cannotDeleteBuiltIn
        }

        var templates = loadUserTemplates()
        templates.removeAll { $0.id == template.id }
        try persist(templates)
        cachedTemplates = nil
    }

    /// Deletes a template by ID.
    /// - Parameter id: The ID of the template to delete.
    /// - Throws: Error if deletion fails.
    func delete(id: UUID) throws {
        var templates = loadUserTemplates()

        guard let template = templates.first(where: { $0.id == id }) else {
            throw CommitTemplateStoreError.notFound
        }

        if template.isBuiltIn {
            throw CommitTemplateStoreError.cannotDeleteBuiltIn
        }

        templates.removeAll { $0.id == id }
        try persist(templates)
        cachedTemplates = nil
    }

    // MARK: - Import/Export

    /// Imports a template from a file.
    /// - Parameter url: The URL of the file to import.
    /// - Returns: The imported template.
    /// - Throws: Error if import fails.
    func importTemplate(from url: URL) throws -> CommitTemplate {
        let data = try Data(contentsOf: url)
        let template = try CommitTemplate.importFromJSON(data)

        // Check for duplicate names
        let existingTemplates = loadAll()
        if existingTemplates.contains(where: { $0.name == template.name }) {
            // Rename with suffix
            var newTemplate = template
            var counter = 1
            var newName = "\(template.name) (\(counter))"
            while existingTemplates.contains(where: { $0.name == newName }) {
                counter += 1
                newName = "\(template.name) (\(counter))"
            }
            newTemplate = CommitTemplate(
                id: newTemplate.id,
                name: newName,
                content: newTemplate.content,
                category: newTemplate.category,
                createdAt: newTemplate.createdAt,
                modifiedAt: newTemplate.modifiedAt,
                isBuiltIn: newTemplate.isBuiltIn
            )
            try save(newTemplate)
            return newTemplate
        }

        try save(template)
        return template
    }

    /// Exports a template to a file.
    /// - Parameters:
    ///   - template: The template to export.
    ///   - url: The destination URL.
    /// - Throws: Error if export fails.
    func exportTemplate(_ template: CommitTemplate, to url: URL) throws {
        let data = try template.exportToJSON()
        try data.write(to: url)
    }

    // MARK: - Filtering

    /// Returns templates filtered by category.
    /// - Parameter category: The category to filter by.
    /// - Returns: Templates matching the category.
    func templates(for category: CommitTemplate.Category) -> [CommitTemplate] {
        loadAll().filter { $0.category == category }
    }

    /// Returns templates matching a search query.
    /// - Parameter query: The search query.
    /// - Returns: Templates matching the query.
    func search(_ query: String) -> [CommitTemplate] {
        guard !query.isEmpty else {
            return loadAll()
        }

        let lowercased = query.lowercased()
        return loadAll().filter { template in
            template.name.lowercased().contains(lowercased) ||
            template.content.lowercased().contains(lowercased)
        }
    }

    // MARK: - Private Methods

    /// Persists templates to disk.
    /// - Parameter templates: The templates to persist.
    /// - Throws: Error if persistence fails.
    private func persist(_ templates: [CommitTemplate]) throws {
        guard let url = storageURL else {
            throw CommitTemplateStoreError.storageUnavailable
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(templates)
        try data.write(to: url, options: .atomic)
    }

    /// Clears the cache.
    func clearCache() {
        cachedTemplates = nil
    }

    /// Clears all user templates.
    func clearAll() throws {
        try persist([])
        cachedTemplates = nil
    }
}

// MARK: - Errors

/// Errors that can occur during commit template operations.
enum CommitTemplateStoreError: LocalizedError {
    case duplicateName
    case notFound
    case cannotDeleteBuiltIn
    case storageUnavailable
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "A template with this name already exists."
        case .notFound:
            return "The template was not found."
        case .cannotDeleteBuiltIn:
            return "Built-in templates cannot be deleted."
        case .storageUnavailable:
            return "Unable to access template storage."
        case .invalidFormat:
            return "The template file format is invalid."
        }
    }
}
