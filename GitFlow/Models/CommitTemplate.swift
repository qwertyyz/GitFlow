import Foundation

/// Represents a commit message template.
struct CommitTemplate: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for the template.
    let id: UUID

    /// Display name for the template.
    var name: String

    /// The template content with optional placeholders.
    var content: String

    /// Category for organizing templates.
    var category: Category

    /// Date when the template was created.
    let createdAt: Date

    /// Date when the template was last modified.
    var modifiedAt: Date

    /// Whether this is a built-in template.
    var isBuiltIn: Bool

    /// Available template categories.
    enum Category: String, Codable, CaseIterable, Identifiable {
        case feature = "Feature"
        case bugfix = "Bug Fix"
        case refactor = "Refactor"
        case docs = "Documentation"
        case test = "Test"
        case chore = "Chore"
        case custom = "Custom"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .feature: return "sparkles"
            case .bugfix: return "ladybug"
            case .refactor: return "arrow.triangle.2.circlepath"
            case .docs: return "doc.text"
            case .test: return "checkmark.seal"
            case .chore: return "wrench"
            case .custom: return "square.and.pencil"
            }
        }
    }

    /// Creates a new commit template.
    init(
        id: UUID = UUID(),
        name: String,
        content: String,
        category: Category = .custom,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isBuiltIn = isBuiltIn
    }

    /// Applies the template, replacing placeholders with provided values.
    func apply(placeholders: [String: String] = [:]) -> String {
        var result = content
        for (key, value) in placeholders {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    /// Extracts placeholder names from the template content.
    var placeholderNames: [String] {
        let pattern = #"\{\{(\w+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }

    /// Whether this template has placeholders.
    var hasPlaceholders: Bool {
        !placeholderNames.isEmpty
    }
}

// MARK: - Built-in Templates

extension CommitTemplate {
    /// Default built-in templates following common conventions.
    static let builtInTemplates: [CommitTemplate] = [
        CommitTemplate(
            name: "Feature",
            content: """
            feat: {{summary}}

            {{description}}
            """,
            category: .feature,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Bug Fix",
            content: """
            fix: {{summary}}

            {{description}}

            Fixes #{{issue}}
            """,
            category: .bugfix,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Refactor",
            content: """
            refactor: {{summary}}

            {{description}}
            """,
            category: .refactor,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Documentation",
            content: """
            docs: {{summary}}

            {{description}}
            """,
            category: .docs,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Test",
            content: """
            test: {{summary}}

            {{description}}
            """,
            category: .test,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Chore",
            content: """
            chore: {{summary}}

            {{description}}
            """,
            category: .chore,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Breaking Change",
            content: """
            feat!: {{summary}}

            BREAKING CHANGE: {{breaking_description}}

            {{description}}
            """,
            category: .feature,
            isBuiltIn: true
        ),
        CommitTemplate(
            name: "Conventional Commit",
            content: """
            {{type}}({{scope}}): {{summary}}

            {{description}}

            {{footer}}
            """,
            category: .custom,
            isBuiltIn: true
        )
    ]
}

// MARK: - Template Import/Export

extension CommitTemplate {
    /// File extension for exported templates.
    static let fileExtension = "gftemplate"

    /// Exports the template to JSON data.
    func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Imports a template from JSON data.
    static func importFromJSON(_ data: Data) throws -> CommitTemplate {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var template = try decoder.decode(CommitTemplate.self, from: data)
        // Generate new ID for imported template
        template = CommitTemplate(
            id: UUID(),
            name: template.name,
            content: template.content,
            category: template.category,
            createdAt: Date(),
            modifiedAt: Date(),
            isBuiltIn: false
        )
        return template
    }
}
