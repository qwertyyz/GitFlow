import Foundation
import UserNotifications

/// Service for managing system notifications.
actor NotificationService {
    static let shared = NotificationService()

    private var isAuthorized = false

    // MARK: - Authorization

    /// Requests notification authorization from the user.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    /// Checks the current authorization status.
    func checkAuthorization() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        return isAuthorized
    }

    // MARK: - Repository Notifications

    /// Sends a notification when a push completes.
    func notifyPushComplete(branch: String, repository: String, success: Bool) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = success ? "Push Complete" : "Push Failed"
        content.body = success
            ? "Successfully pushed '\(branch)' to \(repository)"
            : "Failed to push '\(branch)' to \(repository)"
        content.sound = success ? .default : UNNotificationSound.defaultCritical
        content.categoryIdentifier = "PUSH_COMPLETE"

        await sendNotification(content: content, identifier: "push-\(UUID().uuidString)")
    }

    /// Sends a notification when a pull completes.
    func notifyPullComplete(branch: String, repository: String, newCommits: Int, success: Bool) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = success ? "Pull Complete" : "Pull Failed"

        if success {
            if newCommits > 0 {
                content.body = "Pulled \(newCommits) new commit\(newCommits == 1 ? "" : "s") to '\(branch)' in \(repository)"
            } else {
                content.body = "'\(branch)' is already up to date in \(repository)"
            }
        } else {
            content.body = "Failed to pull '\(branch)' in \(repository)"
        }

        content.sound = success ? .default : UNNotificationSound.defaultCritical
        content.categoryIdentifier = "PULL_COMPLETE"

        await sendNotification(content: content, identifier: "pull-\(UUID().uuidString)")
    }

    /// Sends a notification when fetch finds new changes.
    func notifyFetchComplete(repository: String, newBranches: [String], updatedBranches: [String]) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fetch Complete"

        var bodyParts: [String] = []
        if !newBranches.isEmpty {
            bodyParts.append("\(newBranches.count) new branch\(newBranches.count == 1 ? "" : "es")")
        }
        if !updatedBranches.isEmpty {
            bodyParts.append("\(updatedBranches.count) updated branch\(updatedBranches.count == 1 ? "" : "es")")
        }

        if bodyParts.isEmpty {
            content.body = "No new changes in \(repository)"
        } else {
            content.body = "\(bodyParts.joined(separator: ", ")) in \(repository)"
        }

        content.sound = .default
        content.categoryIdentifier = "FETCH_COMPLETE"

        await sendNotification(content: content, identifier: "fetch-\(UUID().uuidString)")
    }

    /// Sends a notification when a clone completes.
    func notifyCloneComplete(repository: String, success: Bool) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = success ? "Clone Complete" : "Clone Failed"
        content.body = success
            ? "Successfully cloned \(repository)"
            : "Failed to clone \(repository)"
        content.sound = success ? .default : UNNotificationSound.defaultCritical
        content.categoryIdentifier = "CLONE_COMPLETE"

        await sendNotification(content: content, identifier: "clone-\(UUID().uuidString)")
    }

    /// Sends a notification for merge conflicts.
    func notifyMergeConflicts(repository: String, conflictCount: Int) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Merge Conflicts"
        content.body = "\(conflictCount) conflict\(conflictCount == 1 ? "" : "s") need\(conflictCount == 1 ? "s" : "") resolution in \(repository)"
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "MERGE_CONFLICTS"

        await sendNotification(content: content, identifier: "conflict-\(UUID().uuidString)")
    }

    // MARK: - PR Notifications

    /// Sends a notification for new PR activity.
    func notifyPRActivity(repository: String, prNumber: Int, title: String, activity: PRActivityType) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()

        switch activity {
        case .newComment(let author):
            content.title = "New Comment on PR #\(prNumber)"
            content.body = "\(author) commented on '\(title)'"
        case .approved(let reviewer):
            content.title = "PR #\(prNumber) Approved"
            content.body = "\(reviewer) approved '\(title)'"
        case .changesRequested(let reviewer):
            content.title = "Changes Requested on PR #\(prNumber)"
            content.body = "\(reviewer) requested changes on '\(title)'"
        case .merged:
            content.title = "PR #\(prNumber) Merged"
            content.body = "'\(title)' has been merged"
        case .closed:
            content.title = "PR #\(prNumber) Closed"
            content.body = "'\(title)' has been closed"
        }

        content.sound = .default
        content.categoryIdentifier = "PR_ACTIVITY"
        content.userInfo = [
            "repository": repository,
            "prNumber": prNumber
        ]

        await sendNotification(content: content, identifier: "pr-\(prNumber)-\(UUID().uuidString)")
    }

    // MARK: - CI/CD Notifications

    /// Sends a notification for CI status changes.
    func notifyCIStatus(repository: String, branch: String, status: CIStatus, checkName: String?) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()

        switch status {
        case .success:
            content.title = "CI Passed"
            content.body = checkName.map { "\($0) passed on '\(branch)' in \(repository)" }
                ?? "All checks passed on '\(branch)' in \(repository)"
        case .failure:
            content.title = "CI Failed"
            content.body = checkName.map { "\($0) failed on '\(branch)' in \(repository)" }
                ?? "Checks failed on '\(branch)' in \(repository)"
        case .pending:
            content.title = "CI Running"
            content.body = "Checks are running on '\(branch)' in \(repository)"
        }

        content.sound = status == .failure ? UNNotificationSound.defaultCritical : .default
        content.categoryIdentifier = "CI_STATUS"

        await sendNotification(content: content, identifier: "ci-\(branch)-\(UUID().uuidString)")
    }

    // MARK: - Background Operations

    /// Sends a notification when a long-running operation completes.
    func notifyOperationComplete(operation: String, repository: String, success: Bool, details: String? = nil) async {
        guard await checkAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = success ? "\(operation) Complete" : "\(operation) Failed"
        content.body = details ?? (success
            ? "\(operation) completed successfully in \(repository)"
            : "\(operation) failed in \(repository)")
        content.sound = success ? .default : UNNotificationSound.defaultCritical
        content.categoryIdentifier = "OPERATION_COMPLETE"

        await sendNotification(content: content, identifier: "op-\(UUID().uuidString)")
    }

    // MARK: - Helpers

    private func sendNotification(content: UNMutableNotificationContent, identifier: String) async {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }

    /// Removes all pending notifications.
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Removes all delivered notifications.
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - Supporting Types

enum PRActivityType {
    case newComment(author: String)
    case approved(reviewer: String)
    case changesRequested(reviewer: String)
    case merged
    case closed
}

enum CIStatus {
    case success
    case failure
    case pending
}

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var pushNotificationsEnabled: Bool = true
    var pullNotificationsEnabled: Bool = true
    var fetchNotificationsEnabled: Bool = false
    var cloneNotificationsEnabled: Bool = true
    var conflictNotificationsEnabled: Bool = true
    var prNotificationsEnabled: Bool = true
    var ciNotificationsEnabled: Bool = true

    static var `default`: NotificationSettings { NotificationSettings() }

    private static let key = "notificationSettings"

    static func load() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: NotificationSettings.key)
        }
    }
}
