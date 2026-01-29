import Foundation

/// Configuration for git-flow workflow.
/// Stores branch naming conventions and main branch names.
struct GitFlowConfig: Codable, Equatable {
    /// The main/production branch name (default: "main" or "master").
    var mainBranch: String

    /// The development branch name (default: "develop").
    var developBranch: String

    /// Prefix for feature branches (default: "feature/").
    var featurePrefix: String

    /// Prefix for release branches (default: "release/").
    var releasePrefix: String

    /// Prefix for hotfix branches (default: "hotfix/").
    var hotfixPrefix: String

    /// Prefix for support branches (default: "support/").
    var supportPrefix: String

    /// Prefix for version tags (default: "v").
    var versionTagPrefix: String

    /// Default configuration with common conventions.
    static let `default` = GitFlowConfig(
        mainBranch: "main",
        developBranch: "develop",
        featurePrefix: "feature/",
        releasePrefix: "release/",
        hotfixPrefix: "hotfix/",
        supportPrefix: "support/",
        versionTagPrefix: "v"
    )

    /// Alternative configuration using "master" as main branch.
    static let masterBased = GitFlowConfig(
        mainBranch: "master",
        developBranch: "develop",
        featurePrefix: "feature/",
        releasePrefix: "release/",
        hotfixPrefix: "hotfix/",
        supportPrefix: "support/",
        versionTagPrefix: "v"
    )

    /// Returns the full branch name for a feature.
    func featureBranchName(_ name: String) -> String {
        "\(featurePrefix)\(name)"
    }

    /// Returns the full branch name for a release.
    func releaseBranchName(_ version: String) -> String {
        "\(releasePrefix)\(version)"
    }

    /// Returns the full branch name for a hotfix.
    func hotfixBranchName(_ version: String) -> String {
        "\(hotfixPrefix)\(version)"
    }

    /// Returns the tag name for a version.
    func tagName(_ version: String) -> String {
        "\(versionTagPrefix)\(version)"
    }

    /// Extracts the feature name from a branch name.
    func featureName(from branchName: String) -> String? {
        guard branchName.hasPrefix(featurePrefix) else { return nil }
        return String(branchName.dropFirst(featurePrefix.count))
    }

    /// Extracts the release version from a branch name.
    func releaseVersion(from branchName: String) -> String? {
        guard branchName.hasPrefix(releasePrefix) else { return nil }
        return String(branchName.dropFirst(releasePrefix.count))
    }

    /// Extracts the hotfix version from a branch name.
    func hotfixVersion(from branchName: String) -> String? {
        guard branchName.hasPrefix(hotfixPrefix) else { return nil }
        return String(branchName.dropFirst(hotfixPrefix.count))
    }

    /// Checks if a branch is a feature branch.
    func isFeatureBranch(_ branchName: String) -> Bool {
        branchName.hasPrefix(featurePrefix)
    }

    /// Checks if a branch is a release branch.
    func isReleaseBranch(_ branchName: String) -> Bool {
        branchName.hasPrefix(releasePrefix)
    }

    /// Checks if a branch is a hotfix branch.
    func isHotfixBranch(_ branchName: String) -> Bool {
        branchName.hasPrefix(hotfixPrefix)
    }
}

/// Represents the current git-flow state of a repository.
struct GitFlowState: Equatable {
    /// Whether git-flow is initialized in the repository.
    var isInitialized: Bool

    /// The current git-flow configuration.
    var config: GitFlowConfig?

    /// Active feature branches.
    var activeFeatures: [String]

    /// Active release branches.
    var activeReleases: [String]

    /// Active hotfix branches.
    var activeHotfixes: [String]

    /// Creates an uninitialized state.
    static let notInitialized = GitFlowState(
        isInitialized: false,
        config: nil,
        activeFeatures: [],
        activeReleases: [],
        activeHotfixes: []
    )
}

/// Types of git-flow branches.
enum GitFlowBranchType: String, CaseIterable, Identifiable {
    case feature
    case release
    case hotfix
    case support

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .feature:
            return "Feature branches are used for developing new features"
        case .release:
            return "Release branches support preparation of a new production release"
        case .hotfix:
            return "Hotfix branches are used to quickly patch production releases"
        case .support:
            return "Support branches are used to maintain older versions"
        }
    }

    var icon: String {
        switch self {
        case .feature: return "sparkles"
        case .release: return "tag"
        case .hotfix: return "flame"
        case .support: return "lifepreserver"
        }
    }
}
