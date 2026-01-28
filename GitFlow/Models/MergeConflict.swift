import Foundation

/// Represents a file with merge conflicts.
struct ConflictedFile: Identifiable, Equatable, Hashable {
    let id = UUID()

    /// The file path.
    let path: String

    /// The type of conflict.
    let conflictType: ConflictType

    /// Whether the conflict has been marked as resolved.
    var isResolved: Bool = false

    /// The file name without directory.
    var fileName: String {
        (path as NSString).lastPathComponent
    }

    /// The directory containing the file.
    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir
    }
}

/// Type of merge conflict.
enum ConflictType: String, CaseIterable {
    /// Both sides modified the same lines.
    case bothModified = "both modified"

    /// One side deleted, other modified.
    case deletedModified = "deleted/modified"

    /// One side modified, other deleted.
    case modifiedDeleted = "modified/deleted"

    /// Both sides added with different content.
    case bothAdded = "both added"

    /// Rename/rename conflict.
    case renameRename = "rename/rename"

    /// Rename/delete conflict.
    case renameDelete = "rename/delete"

    case unknown = "unknown"

    var description: String {
        switch self {
        case .bothModified:
            return "Both sides modified"
        case .deletedModified:
            return "Deleted on one side, modified on other"
        case .modifiedDeleted:
            return "Modified on one side, deleted on other"
        case .bothAdded:
            return "Both sides added"
        case .renameRename:
            return "Renamed differently on both sides"
        case .renameDelete:
            return "Renamed on one side, deleted on other"
        case .unknown:
            return "Unknown conflict type"
        }
    }
}

/// A section of conflicting content in a file.
struct ConflictSection: Identifiable, Equatable {
    let id = UUID()

    /// Line number where the conflict starts in the file.
    let startLine: Int

    /// Line number where the conflict ends.
    let endLine: Int

    /// Content from "our" side (current branch).
    let oursContent: String

    /// Content from "their" side (merging branch).
    let theirsContent: String

    /// Content from the base (common ancestor).
    let baseContent: String?

    /// Label for "our" side (e.g., "HEAD" or branch name).
    let oursLabel: String

    /// Label for "their" side (e.g., branch name being merged).
    let theirsLabel: String

    /// The resolution chosen for this section.
    var resolution: ConflictResolution?
}

/// How a conflict section was resolved.
enum ConflictResolution: Equatable {
    /// Accept content from "our" side.
    case ours

    /// Accept content from "their" side.
    case theirs

    /// Accept content from both sides.
    case both

    /// Custom edited content.
    case custom(content: String)

    var displayName: String {
        switch self {
        case .ours:
            return "Ours"
        case .theirs:
            return "Theirs"
        case .both:
            return "Both"
        case .custom:
            return "Custom"
        }
    }
}

/// Represents the overall merge state.
struct MergeState: Equatable {
    /// The branch being merged into current.
    let mergingBranch: String?

    /// The current branch (target of merge).
    let currentBranch: String?

    /// List of conflicted files.
    var conflictedFiles: [ConflictedFile]

    /// Whether all conflicts have been resolved.
    var allResolved: Bool {
        conflictedFiles.allSatisfy { $0.isResolved }
    }

    /// Number of unresolved conflicts.
    var unresolvedCount: Int {
        conflictedFiles.filter { !$0.isResolved }.count
    }

    /// Number of resolved conflicts.
    var resolvedCount: Int {
        conflictedFiles.filter { $0.isResolved }.count
    }

    init(mergingBranch: String? = nil, currentBranch: String? = nil, conflictedFiles: [ConflictedFile] = []) {
        self.mergingBranch = mergingBranch
        self.currentBranch = currentBranch
        self.conflictedFiles = conflictedFiles
    }
}
