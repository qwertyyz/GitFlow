import Foundation

/// A git configuration entry.
struct GitConfigEntry: Identifiable, Equatable {
    let id = UUID()

    /// The configuration key (e.g., "user.name").
    let key: String

    /// The current value.
    var value: String

    /// The scope of this configuration.
    let scope: ConfigScope

    /// Whether this is a system default.
    let isDefault: Bool

    /// The section this key belongs to (e.g., "user").
    var section: String {
        key.components(separatedBy: ".").first ?? key
    }

    /// The name within the section (e.g., "name").
    var name: String {
        let parts = key.components(separatedBy: ".")
        return parts.dropFirst().joined(separator: ".")
    }
}

/// The scope of a git configuration.
enum ConfigScope: String, CaseIterable, Identifiable {
    case system = "System"
    case global = "Global"
    case local = "Local"
    case worktree = "Worktree"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .system:
            return "System-wide configuration (all users)"
        case .global:
            return "User-specific configuration (~/.gitconfig)"
        case .local:
            return "Repository-specific configuration (.git/config)"
        case .worktree:
            return "Worktree-specific configuration"
        }
    }

    var flag: String {
        switch self {
        case .system: return "--system"
        case .global: return "--global"
        case .local: return "--local"
        case .worktree: return "--worktree"
        }
    }

    var priority: Int {
        switch self {
        case .system: return 0
        case .global: return 1
        case .local: return 2
        case .worktree: return 3
        }
    }
}

/// Common git configuration sections.
enum ConfigSection: String, CaseIterable, Identifiable {
    case user = "user"
    case core = "core"
    case commit = "commit"
    case push = "push"
    case pull = "pull"
    case merge = "merge"
    case diff = "diff"
    case alias = "alias"
    case color = "color"
    case remote = "remote"
    case branch = "branch"

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .user: return "User identity settings"
        case .core: return "Core git settings"
        case .commit: return "Commit behavior settings"
        case .push: return "Push behavior settings"
        case .pull: return "Pull behavior settings"
        case .merge: return "Merge behavior settings"
        case .diff: return "Diff display settings"
        case .alias: return "Command aliases"
        case .color: return "Color output settings"
        case .remote: return "Remote repository settings"
        case .branch: return "Branch-specific settings"
        }
    }
}

/// Common configuration keys with descriptions.
enum CommonConfigKey: String, CaseIterable {
    // User
    case userName = "user.name"
    case userEmail = "user.email"
    case userSigningKey = "user.signingkey"

    // Core
    case coreEditor = "core.editor"
    case coreAutocrlf = "core.autocrlf"
    case corePager = "core.pager"
    case coreExcludesFile = "core.excludesfile"

    // Commit
    case commitGpgSign = "commit.gpgsign"
    case commitTemplate = "commit.template"

    // Push
    case pushDefault = "push.default"
    case pushAutoSetupRemote = "push.autosetupremote"

    // Pull
    case pullRebase = "pull.rebase"
    case pullFf = "pull.ff"

    // Merge
    case mergeTool = "merge.tool"
    case mergeConflictStyle = "merge.conflictstyle"
    case mergeFf = "merge.ff"

    // Diff
    case diffTool = "diff.tool"
    case diffColorMoved = "diff.colorMoved"

    var description: String {
        switch self {
        case .userName: return "Your name for commit authorship"
        case .userEmail: return "Your email for commit authorship"
        case .userSigningKey: return "GPG key ID for signing commits"
        case .coreEditor: return "Default text editor for commit messages"
        case .coreAutocrlf: return "Line ending conversion (true/false/input)"
        case .corePager: return "Pager program for output (e.g., less)"
        case .coreExcludesFile: return "Path to global gitignore file"
        case .commitGpgSign: return "Sign commits with GPG by default"
        case .commitTemplate: return "Path to commit message template"
        case .pushDefault: return "Default push behavior (simple/current/matching)"
        case .pushAutoSetupRemote: return "Auto-setup remote tracking on push"
        case .pullRebase: return "Rebase instead of merge on pull"
        case .pullFf: return "Fast-forward only on pull (true/false/only)"
        case .mergeTool: return "Default merge tool"
        case .mergeConflictStyle: return "Conflict marker style (merge/diff3)"
        case .mergeFf: return "Fast-forward behavior (true/false/only)"
        case .diffTool: return "Default diff tool"
        case .diffColorMoved: return "Color moved lines in diff"
        }
    }

    var possibleValues: [String]? {
        switch self {
        case .coreAutocrlf: return ["true", "false", "input"]
        case .pushDefault: return ["simple", "current", "matching", "upstream", "nothing"]
        case .pullRebase: return ["true", "false", "merges", "interactive"]
        case .pullFf: return ["true", "false", "only"]
        case .commitGpgSign: return ["true", "false"]
        case .pushAutoSetupRemote: return ["true", "false"]
        case .mergeConflictStyle: return ["merge", "diff3"]
        case .mergeFf: return ["true", "false", "only"]
        case .diffColorMoved: return ["no", "default", "plain", "blocks", "zebra", "dimmed-zebra"]
        default: return nil
        }
    }
}

/// Application preferences (not git config).
struct AppPreferences: Codable {
    /// External editor path.
    var externalEditor: String = "/Applications/Visual Studio Code.app"

    /// External diff tool path.
    var externalDiffTool: String?

    /// External merge tool path.
    var externalMergeTool: String?

    /// Default clone directory.
    var defaultCloneDirectory: String = "~/Developer"

    /// Show hidden files in file browser.
    var showHiddenFiles: Bool = false

    /// Confirm before destructive operations.
    var confirmDestructiveOperations: Bool = true

    /// Auto-fetch interval in seconds (0 = disabled).
    var autoFetchInterval: Int = 300

    /// Theme preference.
    var theme: ThemePreference = .system

    enum ThemePreference: String, Codable, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
    }
}
