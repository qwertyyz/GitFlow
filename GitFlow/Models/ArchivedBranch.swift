import Foundation

/// Represents an archived branch.
struct ArchivedBranch: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let lastCommitHash: String
    let lastCommitMessage: String
    let lastCommitDate: Date
    let archivedDate: Date
    let archivedBy: String?
    let reason: String?

    init(
        id: UUID = UUID(),
        name: String,
        lastCommitHash: String,
        lastCommitMessage: String,
        lastCommitDate: Date,
        archivedDate: Date = Date(),
        archivedBy: String? = nil,
        reason: String? = nil
    ) {
        self.id = id
        self.name = name
        self.lastCommitHash = lastCommitHash
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitDate = lastCommitDate
        self.archivedDate = archivedDate
        self.archivedBy = archivedBy
        self.reason = reason
    }

    /// Short form of the last commit hash.
    var shortHash: String {
        String(lastCommitHash.prefix(7))
    }

    /// Time since the branch was archived.
    var timeSinceArchived: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: archivedDate, relativeTo: Date())
    }

    /// Time since the last commit.
    var timeSinceLastCommit: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastCommitDate, relativeTo: Date())
    }
}

/// Information about a branch's staleness.
struct BranchStalenessInfo: Identifiable {
    let id: String
    let branch: Branch
    let lastCommitDate: Date
    let daysSinceLastCommit: Int
    let isMerged: Bool

    var stalenessLevel: StalenessLevel {
        if daysSinceLastCommit > 180 {
            return .veryStale
        } else if daysSinceLastCommit > 90 {
            return .stale
        } else if daysSinceLastCommit > 30 {
            return .aging
        } else {
            return .active
        }
    }

    enum StalenessLevel: String, CaseIterable {
        case active = "Active"
        case aging = "Aging"
        case stale = "Stale"
        case veryStale = "Very Stale"

        var color: String {
            switch self {
            case .active: return "green"
            case .aging: return "yellow"
            case .stale: return "orange"
            case .veryStale: return "red"
            }
        }

        var description: String {
            switch self {
            case .active: return "Active (< 30 days)"
            case .aging: return "Aging (30-90 days)"
            case .stale: return "Stale (90-180 days)"
            case .veryStale: return "Very Stale (> 180 days)"
            }
        }
    }
}
