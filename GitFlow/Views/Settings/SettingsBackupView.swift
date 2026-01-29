import SwiftUI
import UniformTypeIdentifiers

/// Settings view for importing and exporting app settings.
struct SettingsBackupView: View {
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingImportConfirmation = false
    @State private var importedSettings: SettingsBundle?
    @State private var lastBackupDate: Date?
    @State private var alertMessage: String?
    @State private var showingAlert = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings Backup")
                        .font(.headline)

                    Text("Export your GitFlow settings to a file for backup or transfer to another machine. Import settings to restore a previous configuration.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Export Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export all your GitFlow settings including preferences, commit templates, user profiles, and more.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Export Settings...") {
                            exportSettings()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        if let date = lastBackupDate {
                            Text("Last backup: \(date.formatted())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Import Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import settings from a previously exported file. This will replace your current settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Import Settings...") {
                            showingImportSheet = true
                        }

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            Section("What's Included") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsIncludedRow(icon: "gearshape", title: "General Preferences", description: "Theme, auto-fetch, and other general settings")
                    SettingsIncludedRow(icon: "doc.text", title: "Commit Templates", description: "All saved commit message templates")
                    SettingsIncludedRow(icon: "person.crop.circle", title: "User Profiles", description: "Git identity profiles for committing")
                    SettingsIncludedRow(icon: "link", title: "Service Accounts", description: "GitHub, GitLab, Bitbucket connections")
                    SettingsIncludedRow(icon: "terminal", title: "External Tools", description: "Diff, merge, and editor tool configuration")
                    SettingsIncludedRow(icon: "keyboard", title: "Keyboard Shortcuts", description: "Custom keyboard shortcut bindings")
                }
                .padding(.vertical, 8)
            }

            Section("Note") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Sensitive information like API tokens are encrypted in the backup file. SSH keys and GPG keys are NOT included for security reasons.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Settings?", isPresented: $showingImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import", role: .destructive) {
                if let settings = importedSettings {
                    applyImportedSettings(settings)
                }
            }
        } message: {
            Text("This will replace your current settings. This action cannot be undone. Are you sure you want to continue?")
        }
        .alert("Settings Backup", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            loadLastBackupDate()
        }
    }

    // MARK: - Export

    private func exportSettings() {
        let bundle = SettingsBackupManager.shared.exportSettings()

        guard let data = try? JSONEncoder().encode(bundle) else {
            alertMessage = "Failed to encode settings"
            showingAlert = true
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "GitFlow-Settings-\(Date().formatted(date: .numeric, time: .omitted)).json"
        panel.title = "Export GitFlow Settings"
        panel.message = "Choose where to save your settings backup"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                lastBackupDate = Date()
                UserDefaults.standard.set(Date(), forKey: "lastSettingsBackupDate")
                alertMessage = "Settings exported successfully"
                showingAlert = true
            } catch {
                alertMessage = "Failed to save settings: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let data = try Data(contentsOf: url)
                let bundle = try JSONDecoder().decode(SettingsBundle.self, from: data)
                importedSettings = bundle
                showingImportConfirmation = true
            } catch {
                alertMessage = "Failed to read settings file: \(error.localizedDescription)"
                showingAlert = true
            }

        case .failure(let error):
            alertMessage = "Failed to open file: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func applyImportedSettings(_ bundle: SettingsBundle) {
        SettingsBackupManager.shared.importSettings(bundle)
        alertMessage = "Settings imported successfully. Some changes may require restarting GitFlow."
        showingAlert = true
    }

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastSettingsBackupDate") as? Date
    }
}

// MARK: - Supporting Views

struct SettingsIncludedRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Settings Bundle Model

struct SettingsBundle: Codable {
    var version: Int = 1
    var exportDate: Date = Date()
    var generalSettings: GeneralSettingsData?
    var diffSettings: DiffSettingsData?
    var commitTemplates: [CommitTemplateData]?
    var userProfiles: [UserProfileData]?
    var externalTools: ExternalToolsData?
    var notificationSettings: NotificationSettingsData?
    var serviceAccounts: [ServiceAccountData]?
}

struct GeneralSettingsData: Codable {
    var theme: String?
    var autoFetchInterval: Int?
    var showMenuBarIcon: Bool?
    var defaultClonePath: String?
}

struct DiffSettingsData: Codable {
    var showLineNumbers: Bool?
    var ignoreWhitespace: Bool?
    var contextLines: Int?
    var fontFamily: String?
    var fontSize: Int?
}

struct CommitTemplateData: Codable {
    var id: String
    var name: String
    var template: String
}

struct UserProfileData: Codable {
    var id: String
    var name: String
    var email: String
    var signingKey: String?
    var isDefault: Bool
}

struct ExternalToolsData: Codable {
    var diffTool: String?
    var diffToolPath: String?
    var mergeTool: String?
    var mergeToolPath: String?
    var editor: String?
    var editorPath: String?
}

struct NotificationSettingsData: Codable {
    var pushEnabled: Bool?
    var pullEnabled: Bool?
    var conflictEnabled: Bool?
    var prEnabled: Bool?
}

struct ServiceAccountData: Codable {
    var service: String
    var username: String
    // Token is encrypted
    var encryptedToken: String?
}

// MARK: - Settings Backup Manager

class SettingsBackupManager {
    static let shared = SettingsBackupManager()

    private init() {}

    func exportSettings() -> SettingsBundle {
        var bundle = SettingsBundle()

        // Export general settings
        bundle.generalSettings = GeneralSettingsData(
            theme: UserDefaults.standard.string(forKey: "appTheme"),
            autoFetchInterval: UserDefaults.standard.integer(forKey: "autoFetchInterval"),
            showMenuBarIcon: UserDefaults.standard.bool(forKey: "menuBarEnabled"),
            defaultClonePath: UserDefaults.standard.string(forKey: "defaultClonePath")
        )

        // Export diff settings
        bundle.diffSettings = DiffSettingsData(
            showLineNumbers: UserDefaults.standard.bool(forKey: "diffShowLineNumbers"),
            ignoreWhitespace: UserDefaults.standard.bool(forKey: "diffIgnoreWhitespace"),
            contextLines: UserDefaults.standard.integer(forKey: "diffContextLines"),
            fontFamily: UserDefaults.standard.string(forKey: "diffFontFamily"),
            fontSize: UserDefaults.standard.integer(forKey: "diffFontSize")
        )

        // Export notification settings
        bundle.notificationSettings = NotificationSettingsData(
            pushEnabled: UserDefaults.standard.bool(forKey: "notifyOnPush"),
            pullEnabled: UserDefaults.standard.bool(forKey: "notifyOnPull"),
            conflictEnabled: UserDefaults.standard.bool(forKey: "notifyOnConflict"),
            prEnabled: UserDefaults.standard.bool(forKey: "notifyOnPR")
        )

        // Export commit templates (from stored data)
        if let templatesData = UserDefaults.standard.data(forKey: "commitTemplates"),
           let templates = try? JSONDecoder().decode([CommitTemplateData].self, from: templatesData) {
            bundle.commitTemplates = templates
        }

        // Export user profiles (from stored data)
        if let profilesData = UserDefaults.standard.data(forKey: "userProfiles"),
           let profiles = try? JSONDecoder().decode([UserProfileData].self, from: profilesData) {
            bundle.userProfiles = profiles
        }

        return bundle
    }

    func importSettings(_ bundle: SettingsBundle) {
        // Import general settings
        if let general = bundle.generalSettings {
            if let theme = general.theme {
                UserDefaults.standard.set(theme, forKey: "appTheme")
            }
            if let interval = general.autoFetchInterval {
                UserDefaults.standard.set(interval, forKey: "autoFetchInterval")
            }
            if let showMenu = general.showMenuBarIcon {
                UserDefaults.standard.set(showMenu, forKey: "menuBarEnabled")
            }
            if let clonePath = general.defaultClonePath {
                UserDefaults.standard.set(clonePath, forKey: "defaultClonePath")
            }
        }

        // Import diff settings
        if let diff = bundle.diffSettings {
            if let showLines = diff.showLineNumbers {
                UserDefaults.standard.set(showLines, forKey: "diffShowLineNumbers")
            }
            if let ignoreWS = diff.ignoreWhitespace {
                UserDefaults.standard.set(ignoreWS, forKey: "diffIgnoreWhitespace")
            }
            if let context = diff.contextLines {
                UserDefaults.standard.set(context, forKey: "diffContextLines")
            }
            if let font = diff.fontFamily {
                UserDefaults.standard.set(font, forKey: "diffFontFamily")
            }
            if let fontSize = diff.fontSize {
                UserDefaults.standard.set(fontSize, forKey: "diffFontSize")
            }
        }

        // Import notification settings
        if let notify = bundle.notificationSettings {
            if let push = notify.pushEnabled {
                UserDefaults.standard.set(push, forKey: "notifyOnPush")
            }
            if let pull = notify.pullEnabled {
                UserDefaults.standard.set(pull, forKey: "notifyOnPull")
            }
            if let conflict = notify.conflictEnabled {
                UserDefaults.standard.set(conflict, forKey: "notifyOnConflict")
            }
            if let pr = notify.prEnabled {
                UserDefaults.standard.set(pr, forKey: "notifyOnPR")
            }
        }

        // Import commit templates
        if let templates = bundle.commitTemplates,
           let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: "commitTemplates")
        }

        // Import user profiles
        if let profiles = bundle.userProfiles,
           let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "userProfiles")
        }

        // Post notification for settings change
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}

#Preview {
    SettingsBackupView()
        .frame(width: 500, height: 600)
}
