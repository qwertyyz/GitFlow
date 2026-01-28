import Foundation

/// Represents an action to perform on a commit during interactive rebase.
enum RebaseAction: String, CaseIterable, Identifiable {
    case pick = "pick"
    case reword = "reword"
    case edit = "edit"
    case squash = "squash"
    case fixup = "fixup"
    case drop = "drop"

    var id: String { rawValue }

    /// Display name for the action.
    var displayName: String {
        switch self {
        case .pick: return "Pick"
        case .reword: return "Reword"
        case .edit: return "Edit"
        case .squash: return "Squash"
        case .fixup: return "Fixup"
        case .drop: return "Drop"
        }
    }

    /// Description of what the action does.
    var description: String {
        switch self {
        case .pick:
            return "Use commit as-is"
        case .reword:
            return "Use commit, but edit the commit message"
        case .edit:
            return "Use commit, but stop for amending"
        case .squash:
            return "Meld into previous commit, keeping message"
        case .fixup:
            return "Meld into previous commit, discarding message"
        case .drop:
            return "Remove commit"
        }
    }

    /// Short code for the action.
    var shortCode: String {
        switch self {
        case .pick: return "p"
        case .reword: return "r"
        case .edit: return "e"
        case .squash: return "s"
        case .fixup: return "f"
        case .drop: return "d"
        }
    }

    /// Icon name for the action.
    var iconName: String {
        switch self {
        case .pick: return "checkmark.circle"
        case .reword: return "pencil.circle"
        case .edit: return "stop.circle"
        case .squash: return "arrow.up.left.circle"
        case .fixup: return "arrow.up.left.circle.fill"
        case .drop: return "xmark.circle"
        }
    }
}

/// A commit entry in the interactive rebase sequence.
struct RebaseEntry: Identifiable, Equatable, Hashable {
    let id = UUID()

    /// The commit hash.
    let commitHash: String

    /// Short commit hash.
    var shortHash: String {
        String(commitHash.prefix(7))
    }

    /// The original commit message (first line).
    let message: String

    /// The action to perform on this commit.
    var action: RebaseAction

    /// The author of the commit.
    let author: String?

    /// The date of the commit.
    let date: Date?

    /// Whether this entry has been modified from its original state.
    var isModified: Bool = false

    /// New message for reword action.
    var newMessage: String?

    init(
        commitHash: String,
        message: String,
        action: RebaseAction = .pick,
        author: String? = nil,
        date: Date? = nil
    ) {
        self.commitHash = commitHash
        self.message = message
        self.action = action
        self.author = author
        self.date = date
    }

    static func == (lhs: RebaseEntry, rhs: RebaseEntry) -> Bool {
        lhs.commitHash == rhs.commitHash &&
        lhs.action == rhs.action &&
        lhs.newMessage == rhs.newMessage
    }
}

/// State of an interactive rebase operation.
enum InteractiveRebaseState: Equatable {
    case idle
    case preparing
    case inProgress(currentStep: Int, totalSteps: Int)
    case paused(reason: PauseReason)
    case completed
    case failed(error: String)

    enum PauseReason: Equatable {
        case edit(commitHash: String)
        case reword(commitHash: String)
        case conflict
    }
}

/// The full interactive rebase configuration.
struct InteractiveRebaseConfig {
    /// The base commit/branch to rebase onto.
    let onto: String

    /// The entries to rebase.
    var entries: [RebaseEntry]

    /// Whether to preserve merge commits.
    var preserveMerges: Bool = false

    /// Whether to autosquash.
    var autosquash: Bool = false

    /// The number of commits being rebased.
    var commitCount: Int {
        entries.count
    }

    /// Generate the rebase todo file content.
    func generateTodoContent() -> String {
        entries.map { entry in
            "\(entry.action.rawValue) \(entry.shortHash) \(entry.newMessage ?? entry.message)"
        }.joined(separator: "\n")
    }
}
