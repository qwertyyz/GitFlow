import Foundation

/// Represents a single entry in the Git reflog.
/// The reflog records when the tips of branches and other references were updated.
struct ReflogEntry: Identifiable, Equatable, Hashable {
    /// The full commit hash this entry points to.
    let hash: String

    /// The abbreviated commit hash (typically 7 characters).
    let shortHash: String

    /// The reflog selector (e.g., "HEAD@{0}", "main@{1}").
    let selector: String

    /// The action that caused this reflog entry (e.g., "commit", "checkout", "rebase").
    let action: ReflogAction

    /// The raw action string from git.
    let actionRaw: String

    /// The message describing the action.
    let message: String

    /// The timestamp when this action occurred.
    let date: Date

    /// The author/committer name.
    let authorName: String

    /// The author/committer email.
    let authorEmail: String

    // MARK: - Identifiable

    var id: String { selector }

    // MARK: - Computed Properties

    /// A human-readable description of the action.
    var actionDescription: String {
        action.description
    }

    /// A short summary suitable for display in a list.
    var shortSummary: String {
        message.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? message
    }

    /// Creates a reflog entry with the given properties.
    init(
        hash: String,
        shortHash: String? = nil,
        selector: String,
        action: ReflogAction,
        actionRaw: String,
        message: String,
        date: Date,
        authorName: String,
        authorEmail: String
    ) {
        self.hash = hash
        self.shortHash = shortHash ?? String(hash.prefix(7))
        self.selector = selector
        self.action = action
        self.actionRaw = actionRaw
        self.message = message
        self.date = date
        self.authorName = authorName
        self.authorEmail = authorEmail
    }
}

// MARK: - Reflog Action Types

/// The type of action that created a reflog entry.
enum ReflogAction: String, CaseIterable, Hashable {
    case commit
    case commitInitial = "commit (initial)"
    case commitAmend = "commit (amend)"
    case commitMerge = "commit (merge)"
    case checkout
    case pull
    case push
    case merge
    case rebase
    case rebaseInteractive = "rebase -i"
    case rebaseFinish = "rebase (finish)"
    case rebaseAbort = "rebase (abort)"
    case reset
    case cherryPick = "cherry-pick"
    case revert
    case branch
    case clone
    case fetch
    case stash
    case other

    /// Parses an action string from git reflog output.
    static func parse(_ string: String) -> ReflogAction {
        let normalized = string.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for exact matches first
        for action in ReflogAction.allCases {
            if normalized == action.rawValue.lowercased() {
                return action
            }
        }

        // Check for prefix matches
        if normalized.hasPrefix("commit") {
            if normalized.contains("initial") { return .commitInitial }
            if normalized.contains("amend") { return .commitAmend }
            if normalized.contains("merge") { return .commitMerge }
            return .commit
        }

        if normalized.hasPrefix("checkout") { return .checkout }
        if normalized.hasPrefix("pull") { return .pull }
        if normalized.hasPrefix("push") { return .push }
        if normalized.hasPrefix("merge") { return .merge }
        if normalized.hasPrefix("rebase") {
            if normalized.contains("finish") { return .rebaseFinish }
            if normalized.contains("abort") { return .rebaseAbort }
            if normalized.contains("-i") { return .rebaseInteractive }
            return .rebase
        }
        if normalized.hasPrefix("reset") { return .reset }
        if normalized.hasPrefix("cherry-pick") { return .cherryPick }
        if normalized.hasPrefix("revert") { return .revert }
        if normalized.hasPrefix("branch") { return .branch }
        if normalized.hasPrefix("clone") { return .clone }
        if normalized.hasPrefix("fetch") { return .fetch }
        if normalized.hasPrefix("stash") { return .stash }

        return .other
    }

    /// Human-readable description of the action.
    var description: String {
        switch self {
        case .commit: return "Commit"
        case .commitInitial: return "Initial commit"
        case .commitAmend: return "Amend commit"
        case .commitMerge: return "Merge commit"
        case .checkout: return "Checkout"
        case .pull: return "Pull"
        case .push: return "Push"
        case .merge: return "Merge"
        case .rebase: return "Rebase"
        case .rebaseInteractive: return "Interactive rebase"
        case .rebaseFinish: return "Rebase finished"
        case .rebaseAbort: return "Rebase aborted"
        case .reset: return "Reset"
        case .cherryPick: return "Cherry-pick"
        case .revert: return "Revert"
        case .branch: return "Branch"
        case .clone: return "Clone"
        case .fetch: return "Fetch"
        case .stash: return "Stash"
        case .other: return "Other"
        }
    }

    /// SF Symbol icon name for the action.
    var iconName: String {
        switch self {
        case .commit, .commitInitial, .commitAmend, .commitMerge:
            return "checkmark.circle"
        case .checkout:
            return "arrow.uturn.right"
        case .pull:
            return "arrow.down.circle"
        case .push:
            return "arrow.up.circle"
        case .merge:
            return "arrow.triangle.merge"
        case .rebase, .rebaseInteractive, .rebaseFinish, .rebaseAbort:
            return "arrow.triangle.branch"
        case .reset:
            return "arrow.counterclockwise"
        case .cherryPick:
            return "arrow.right.doc.on.clipboard"
        case .revert:
            return "arrow.uturn.backward"
        case .branch:
            return "arrow.triangle.branch"
        case .clone:
            return "doc.on.doc"
        case .fetch:
            return "arrow.down.to.line"
        case .stash:
            return "tray.and.arrow.down"
        case .other:
            return "questionmark.circle"
        }
    }
}
