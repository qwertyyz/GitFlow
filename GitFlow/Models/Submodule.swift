import Foundation

/// Represents a Git submodule.
struct Submodule: Identifiable, Equatable, Hashable {
    let id = UUID()

    /// The submodule name (usually the path).
    let name: String

    /// The path to the submodule relative to repository root.
    let path: String

    /// The URL of the submodule repository.
    let url: String

    /// The currently checked out commit hash.
    let currentCommit: String?

    /// The commit hash expected by the parent repository.
    let expectedCommit: String?

    /// The branch the submodule tracks (if any).
    let branch: String?

    /// Whether the submodule has been initialized.
    let isInitialized: Bool

    /// Whether the submodule is up to date.
    var isUpToDate: Bool {
        guard let current = currentCommit, let expected = expectedCommit else { return false }
        return current == expected
    }

    /// Whether the submodule has local changes.
    var hasLocalChanges: Bool = false

    /// The status of the submodule.
    var status: SubmoduleStatus {
        if !isInitialized {
            return .uninitialized
        } else if currentCommit == nil {
            return .uninitialized
        } else if hasLocalChanges {
            return .modified
        } else if !isUpToDate {
            return .outOfDate
        } else {
            return .upToDate
        }
    }

    /// Short form of the current commit hash.
    var shortCommit: String? {
        currentCommit.map { String($0.prefix(7)) }
    }

    /// Short form of the expected commit hash.
    var shortExpectedCommit: String? {
        expectedCommit.map { String($0.prefix(7)) }
    }
}

/// Status of a submodule.
enum SubmoduleStatus: String, CaseIterable {
    case upToDate = "Up to date"
    case outOfDate = "Out of date"
    case modified = "Modified"
    case uninitialized = "Not initialized"

    var iconName: String {
        switch self {
        case .upToDate:
            return "checkmark.circle.fill"
        case .outOfDate:
            return "arrow.down.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .uninitialized:
            return "circle.dashed"
        }
    }

    var color: String {
        switch self {
        case .upToDate:
            return "green"
        case .outOfDate:
            return "orange"
        case .modified:
            return "blue"
        case .uninitialized:
            return "gray"
        }
    }
}

/// Configuration for a submodule from .gitmodules.
struct SubmoduleConfig: Equatable {
    let name: String
    let path: String
    let url: String
    let branch: String?
}
