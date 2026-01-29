import SwiftUI
import AppKit

/// Manager for macOS Handoff support, allowing users to continue working on another device.
@MainActor
class HandoffManager: NSObject, ObservableObject {
    static let shared = HandoffManager()

    // Activity type identifiers
    enum ActivityType: String {
        case viewRepository = "com.gitflow.viewRepository"
        case viewCommit = "com.gitflow.viewCommit"
        case viewBranch = "com.gitflow.viewBranch"
        case viewPullRequest = "com.gitflow.viewPullRequest"

        var title: String {
            switch self {
            case .viewRepository: return "View Repository"
            case .viewCommit: return "View Commit"
            case .viewBranch: return "View Branch"
            case .viewPullRequest: return "View Pull Request"
            }
        }
    }

    // User info keys
    enum UserInfoKey: String {
        case repositoryPath = "repositoryPath"
        case repositoryName = "repositoryName"
        case commitHash = "commitHash"
        case branchName = "branchName"
        case pullRequestNumber = "pullRequestNumber"
        case pullRequestURL = "pullRequestURL"
        case remoteURL = "remoteURL"
    }

    @Published var currentActivity: NSUserActivity?
    @Published var isHandoffEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHandoffEnabled, forKey: "handoffEnabled")
        }
    }

    private override init() {
        self.isHandoffEnabled = UserDefaults.standard.bool(forKey: "handoffEnabled")
        // Default to enabled if not set
        if !UserDefaults.standard.contains(key: "handoffEnabled") {
            self.isHandoffEnabled = true
        }
        super.init()
    }

    // MARK: - Create Activities

    /// Create a user activity for viewing a repository
    func createRepositoryActivity(path: String, name: String, remoteURL: String?) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.viewRepository.rawValue)
        activity.title = "View \(name)"
        activity.isEligibleForHandoff = isHandoffEnabled
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false

        var userInfo: [String: Any] = [
            UserInfoKey.repositoryPath.rawValue: path,
            UserInfoKey.repositoryName.rawValue: name
        ]

        if let remote = remoteURL {
            userInfo[UserInfoKey.remoteURL.rawValue] = remote
            activity.webpageURL = URL(string: remote)
        }

        activity.userInfo = userInfo
        activity.keywords = Set(["git", "repository", name])
        activity.requiredUserInfoKeys = Set([UserInfoKey.repositoryPath.rawValue])

        return activity
    }

    /// Create a user activity for viewing a commit
    func createCommitActivity(
        repositoryPath: String,
        repositoryName: String,
        commitHash: String,
        remoteURL: String?
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.viewCommit.rawValue)
        activity.title = "View Commit \(String(commitHash.prefix(7)))"
        activity.isEligibleForHandoff = isHandoffEnabled
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false

        var userInfo: [String: Any] = [
            UserInfoKey.repositoryPath.rawValue: repositoryPath,
            UserInfoKey.repositoryName.rawValue: repositoryName,
            UserInfoKey.commitHash.rawValue: commitHash
        ]

        if let remote = remoteURL {
            userInfo[UserInfoKey.remoteURL.rawValue] = remote
            // Create web URL for GitHub/GitLab commit
            if let commitURL = createCommitWebURL(remote: remote, hash: commitHash) {
                activity.webpageURL = commitURL
            }
        }

        activity.userInfo = userInfo
        activity.keywords = Set(["git", "commit", commitHash])
        activity.requiredUserInfoKeys = Set([UserInfoKey.repositoryPath.rawValue, UserInfoKey.commitHash.rawValue])

        return activity
    }

    /// Create a user activity for viewing a branch
    func createBranchActivity(
        repositoryPath: String,
        repositoryName: String,
        branchName: String,
        remoteURL: String?
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.viewBranch.rawValue)
        activity.title = "View Branch \(branchName)"
        activity.isEligibleForHandoff = isHandoffEnabled
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false

        var userInfo: [String: Any] = [
            UserInfoKey.repositoryPath.rawValue: repositoryPath,
            UserInfoKey.repositoryName.rawValue: repositoryName,
            UserInfoKey.branchName.rawValue: branchName
        ]

        if let remote = remoteURL {
            userInfo[UserInfoKey.remoteURL.rawValue] = remote
            // Create web URL for GitHub/GitLab branch
            if let branchURL = createBranchWebURL(remote: remote, branch: branchName) {
                activity.webpageURL = branchURL
            }
        }

        activity.userInfo = userInfo
        activity.keywords = Set(["git", "branch", branchName])
        activity.requiredUserInfoKeys = Set([UserInfoKey.repositoryPath.rawValue, UserInfoKey.branchName.rawValue])

        return activity
    }

    /// Create a user activity for viewing a pull request
    func createPullRequestActivity(
        repositoryPath: String,
        repositoryName: String,
        prNumber: Int,
        prURL: String
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.viewPullRequest.rawValue)
        activity.title = "View Pull Request #\(prNumber)"
        activity.isEligibleForHandoff = isHandoffEnabled
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false

        let userInfo: [String: Any] = [
            UserInfoKey.repositoryPath.rawValue: repositoryPath,
            UserInfoKey.repositoryName.rawValue: repositoryName,
            UserInfoKey.pullRequestNumber.rawValue: prNumber,
            UserInfoKey.pullRequestURL.rawValue: prURL
        ]

        activity.userInfo = userInfo
        activity.webpageURL = URL(string: prURL)
        activity.keywords = Set(["git", "pull request", "pr", "#\(prNumber)"])
        activity.requiredUserInfoKeys = Set([UserInfoKey.pullRequestURL.rawValue])

        return activity
    }

    // MARK: - Activity Management

    /// Set the current activity and make it current
    func becomeCurrentActivity(_ activity: NSUserActivity) {
        guard isHandoffEnabled else { return }

        currentActivity?.invalidate()
        currentActivity = activity
        activity.becomeCurrent()
    }

    /// Resign the current activity
    func resignCurrentActivity() {
        currentActivity?.resignCurrent()
        currentActivity?.invalidate()
        currentActivity = nil
    }

    /// Update the current activity with new info
    func updateCurrentActivity(userInfo: [String: Any]) {
        guard let activity = currentActivity else { return }
        var newUserInfo = activity.userInfo ?? [:]
        for (key, value) in userInfo {
            newUserInfo[key] = value
        }
        activity.userInfo = newUserInfo
        activity.needsSave = true
    }

    // MARK: - Handle Incoming Activities

    /// Handle an incoming user activity from Handoff
    func handleIncomingActivity(_ activity: NSUserActivity) -> HandoffAction? {
        guard let activityType = ActivityType(rawValue: activity.activityType),
              let userInfo = activity.userInfo else {
            return nil
        }

        switch activityType {
        case .viewRepository:
            guard let path = userInfo[UserInfoKey.repositoryPath.rawValue] as? String else {
                return nil
            }
            return .openRepository(path: path)

        case .viewCommit:
            guard let path = userInfo[UserInfoKey.repositoryPath.rawValue] as? String,
                  let hash = userInfo[UserInfoKey.commitHash.rawValue] as? String else {
                return nil
            }
            return .viewCommit(repositoryPath: path, hash: hash)

        case .viewBranch:
            guard let path = userInfo[UserInfoKey.repositoryPath.rawValue] as? String,
                  let branch = userInfo[UserInfoKey.branchName.rawValue] as? String else {
                return nil
            }
            return .viewBranch(repositoryPath: path, name: branch)

        case .viewPullRequest:
            guard let urlString = userInfo[UserInfoKey.pullRequestURL.rawValue] as? String,
                  let url = URL(string: urlString) else {
                return nil
            }
            let path = userInfo[UserInfoKey.repositoryPath.rawValue] as? String
            return .viewPullRequest(repositoryPath: path, url: url)
        }
    }

    // MARK: - Helper Methods

    private func createCommitWebURL(remote: String, hash: String) -> URL? {
        // Parse remote URL and create web URL for commit
        guard let baseURL = parseGitRemoteToWebURL(remote) else { return nil }

        if remote.contains("github.com") {
            return URL(string: "\(baseURL)/commit/\(hash)")
        } else if remote.contains("gitlab.com") {
            return URL(string: "\(baseURL)/-/commit/\(hash)")
        } else if remote.contains("bitbucket.org") {
            return URL(string: "\(baseURL)/commits/\(hash)")
        }

        return nil
    }

    private func createBranchWebURL(remote: String, branch: String) -> URL? {
        guard let baseURL = parseGitRemoteToWebURL(remote) else { return nil }
        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? branch

        if remote.contains("github.com") {
            return URL(string: "\(baseURL)/tree/\(encodedBranch)")
        } else if remote.contains("gitlab.com") {
            return URL(string: "\(baseURL)/-/tree/\(encodedBranch)")
        } else if remote.contains("bitbucket.org") {
            return URL(string: "\(baseURL)/src/\(encodedBranch)")
        }

        return nil
    }

    private func parseGitRemoteToWebURL(_ remote: String) -> String? {
        var url = remote

        // Handle SSH URLs
        if url.hasPrefix("git@") {
            url = url.replacingOccurrences(of: "git@", with: "https://")
            url = url.replacingOccurrences(of: ":", with: "/", range: url.range(of: ":"))
        }

        // Remove .git suffix
        if url.hasSuffix(".git") {
            url = String(url.dropLast(4))
        }

        // Ensure HTTPS
        if url.hasPrefix("http://") {
            url = url.replacingOccurrences(of: "http://", with: "https://")
        }

        return url
    }
}

// MARK: - Handoff Action

enum HandoffAction {
    case openRepository(path: String)
    case viewCommit(repositoryPath: String, hash: String)
    case viewBranch(repositoryPath: String, name: String)
    case viewPullRequest(repositoryPath: String?, url: URL)
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// MARK: - Handoff Settings View

struct HandoffSettingsView: View {
    @ObservedObject private var handoffManager = HandoffManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Handoff", isOn: $handoffManager.isHandoffEnabled)

                Text("Handoff allows you to continue your work on another Mac or iOS device. When enabled, your current repository view can be picked up on other devices signed into the same iCloud account.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("How Handoff Works") {
                VStack(alignment: .leading, spacing: 12) {
                    HandoffInfoRow(
                        icon: "laptopcomputer.and.iphone",
                        title: "Cross-Device Continuity",
                        description: "Continue viewing repositories, commits, and branches on another device"
                    )

                    HandoffInfoRow(
                        icon: "globe",
                        title: "Web Fallback",
                        description: "If GitFlow isn't installed, opens in the browser (GitHub, GitLab, etc.)"
                    )

                    HandoffInfoRow(
                        icon: "lock.shield",
                        title: "Same iCloud Account",
                        description: "Works only between devices signed into your iCloud account"
                    )
                }
                .padding(.vertical, 8)
            }

            Section("Supported Activities") {
                ForEach(supportedActivities, id: \.0) { activity in
                    HStack(spacing: 12) {
                        Image(systemName: activity.1)
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.0)
                                .font(.subheadline)
                            Text(activity.2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var supportedActivities: [(String, String, String)] {
        [
            ("View Repository", "folder", "Continue browsing a repository"),
            ("View Commit", "clock.arrow.circlepath", "Continue viewing a specific commit"),
            ("View Branch", "arrow.triangle.branch", "Continue viewing branch details"),
            ("View Pull Request", "arrow.triangle.pull", "Continue reviewing a pull request")
        ]
    }
}

struct HandoffInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - View Extension for Handoff

extension View {
    /// Attach a user activity to this view for Handoff
    func userActivity(
        _ activityType: HandoffManager.ActivityType,
        isActive: Bool = true,
        userInfo: [String: Any],
        onUpdate: ((NSUserActivity) -> Void)? = nil
    ) -> some View {
        self.userActivity(activityType.rawValue, isActive: isActive) { activity in
            activity.isEligibleForHandoff = HandoffManager.shared.isHandoffEnabled
            activity.userInfo = userInfo
            onUpdate?(activity)
        }
    }
}

#Preview {
    HandoffSettingsView()
        .frame(width: 500)
}
