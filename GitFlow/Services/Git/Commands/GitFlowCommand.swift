import Foundation

// MARK: - Git-Flow Detection

/// Command to check if git-flow is initialized by checking for develop branch.
struct CheckGitFlowInitializedCommand: GitCommand {
    typealias Result = Bool

    var arguments: [String] {
        ["config", "--get", "gitflow.branch.develop"]
    }

    func parse(output: String) throws -> Bool {
        !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Command to get git-flow configuration from git config.
struct GetGitFlowConfigCommand: GitCommand {
    typealias Result = GitFlowConfig?

    var arguments: [String] {
        ["config", "--get-regexp", "^gitflow\\."]
    }

    func parse(output: String) throws -> GitFlowConfig? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var mainBranch = "main"
        var developBranch = "develop"
        var featurePrefix = "feature/"
        var releasePrefix = "release/"
        var hotfixPrefix = "hotfix/"
        var supportPrefix = "support/"
        var versionTagPrefix = ""

        for line in trimmed.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0])
            let value = String(parts[1])

            switch key {
            case "gitflow.branch.master", "gitflow.branch.main":
                mainBranch = value
            case "gitflow.branch.develop":
                developBranch = value
            case "gitflow.prefix.feature":
                featurePrefix = value
            case "gitflow.prefix.release":
                releasePrefix = value
            case "gitflow.prefix.hotfix":
                hotfixPrefix = value
            case "gitflow.prefix.support":
                supportPrefix = value
            case "gitflow.prefix.versiontag":
                versionTagPrefix = value
            default:
                break
            }
        }

        return GitFlowConfig(
            mainBranch: mainBranch,
            developBranch: developBranch,
            featurePrefix: featurePrefix,
            releasePrefix: releasePrefix,
            hotfixPrefix: hotfixPrefix,
            supportPrefix: supportPrefix,
            versionTagPrefix: versionTagPrefix
        )
    }
}

// MARK: - Git-Flow Initialize

/// Command to initialize git-flow in a repository.
/// This sets up the git config values for git-flow.
struct InitializeGitFlowCommand: VoidGitCommand {
    let config: GitFlowConfig

    var arguments: [String] {
        // We'll use multiple config commands, but for simplicity we return the first
        // The actual initialization is done through multiple git config calls
        ["config", "gitflow.branch.master", config.mainBranch]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}

// MARK: - Feature Commands

/// Command to start a new feature branch.
struct StartFeatureCommand: VoidGitCommand {
    let featureName: String
    let baseBranch: String

    var arguments: [String] {
        ["checkout", "-b", featureName, baseBranch]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}

/// Command to finish a feature branch (merge back to develop).
struct FinishFeatureCommand: VoidGitCommand {
    let featureBranch: String
    let developBranch: String
    let deleteBranch: Bool

    var arguments: [String] {
        // First we need to checkout develop and merge
        // This is a simplified version - real git-flow does multiple steps
        ["merge", "--no-ff", featureBranch, "-m", "Merge branch '\(featureBranch)' into \(developBranch)"]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}

// MARK: - Release Commands

/// Command to start a new release branch.
struct StartReleaseCommand: VoidGitCommand {
    let releaseName: String
    let baseBranch: String

    var arguments: [String] {
        ["checkout", "-b", releaseName, baseBranch]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}

/// Command to finish a release branch.
/// This merges to both main and develop, and creates a tag.
struct FinishReleaseCommand: VoidGitCommand {
    let releaseBranch: String
    let mainBranch: String
    let tagName: String
    let tagMessage: String?

    var arguments: [String] {
        // First step: merge to main
        ["merge", "--no-ff", releaseBranch, "-m", "Merge branch '\(releaseBranch)'"]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}

// MARK: - Hotfix Commands

/// Command to start a new hotfix branch.
struct StartHotfixCommand: VoidGitCommand {
    let hotfixName: String
    let baseBranch: String

    var arguments: [String] {
        ["checkout", "-b", hotfixName, baseBranch]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}

/// Command to finish a hotfix branch.
/// This merges to both main and develop, and creates a tag.
struct FinishHotfixCommand: VoidGitCommand {
    let hotfixBranch: String
    let mainBranch: String
    let tagName: String
    let tagMessage: String?

    var arguments: [String] {
        // First step: merge to main
        ["merge", "--no-ff", hotfixBranch, "-m", "Merge branch '\(hotfixBranch)'"]
    }

    func parse(output: String) throws {
        // No output to parse
    }
}
