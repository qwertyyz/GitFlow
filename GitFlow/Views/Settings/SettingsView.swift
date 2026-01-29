import SwiftUI

/// Main settings view.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var showDismissButton: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showDismissButton {
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Divider()
            }

            TabView {
                GeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }

                AccountsSettingsView()
                    .tabItem {
                        Label("Accounts", systemImage: "person.crop.circle")
                    }

                AppearanceSettingsTab()
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }

                DiffSettingsView()
                    .tabItem {
                        Label("Diff", systemImage: "text.alignleft")
                    }

                GitSettingsView()
                    .tabItem {
                        Label("Git", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                CommitTemplatesView()
                    .tabItem {
                        Label("Templates", systemImage: "doc.text")
                    }

                ExternalToolsSettingsTab()
                    .tabItem {
                        Label("External Tools", systemImage: "wrench.and.screwdriver")
                    }

                SecuritySettingsTab()
                    .tabItem {
                        Label("Security", systemImage: "lock.shield")
                    }

                AdvancedSettingsTab()
                    .tabItem {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
            }
        }
        .frame(width: 650, height: showDismissButton ? 550 : 500)
    }
}

/// Theme options for the app.
enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// General application settings.
struct GeneralSettingsView: View {
    @AppStorage("com.gitflow.showRemoteBranches") private var showRemoteBranches: Bool = true
    @AppStorage("com.gitflow.confirmDestructiveActions") private var confirmDestructiveActions: Bool = true
    @AppStorage("com.gitflow.theme") private var theme: String = "system"

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $theme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { appTheme in
                        Text(appTheme.displayName).tag(appTheme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: theme) { newValue in
                    applyTheme(newValue)
                }
            } header: {
                Text("Theme")
            }

            Section {
                Toggle("Show remote branches in branch list", isOn: $showRemoteBranches)
                Toggle("Confirm destructive actions", isOn: $confirmDestructiveActions)
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            applyTheme(theme)
        }
    }
}

/// Diff display settings.
struct DiffSettingsView: View {
    @AppStorage("com.gitflow.diffViewMode") private var diffViewMode: String = "unified"
    @AppStorage("com.gitflow.showLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("com.gitflow.wrapLines") private var wrapLines: Bool = false
    @AppStorage("com.gitflow.fontSize") private var fontSize: Double = 12.0

    var body: some View {
        Form {
            Section {
                Picker("Default view mode", selection: $diffViewMode) {
                    Text("Unified").tag("unified")
                    Text("Split (Side-by-Side)").tag("split")
                }
                .pickerStyle(.segmented)

                Toggle("Show line numbers", isOn: $showLineNumbers)
                Toggle("Wrap long lines", isOn: $wrapLines)
            } header: {
                Text("Display")
            }

            Section {
                HStack {
                    Slider(value: $fontSize, in: 9...18, step: 1) {
                        Text("Font size")
                    }
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 40)
                }
            } header: {
                Text("Font")
            }

            Section {
                // Preview of the font size
                Text("func example() { return true }")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Git executable settings.
struct GitSettingsView: View {
    @AppStorage("com.gitflow.gitPath") private var gitPath: String = "/usr/bin/git"
    @State private var gitVersion: String = ""
    @State private var isValidGitPath: Bool = true

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    TextField("Git executable path", text: $gitPath)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)

                    Button("Browse...") {
                        browseForGit()
                    }
                }

                if !isValidGitPath {
                    Label("Invalid Git path", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if !gitVersion.isEmpty {
                    Text(gitVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            
                Button("Detect Git") {
                    detectGit()
                }
            } header: {
                Text("Git Executable")
            } footer: {
                Text("GitFlow uses the system Git executable for all operations. You can specify a custom path if needed.")
            }

            Section {
                Button("Reset to Default") {
                    gitPath = "/usr/bin/git"
                    validateGitPath()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            validateGitPath()
        }
        .onChange(of: gitPath) { _ in
            validateGitPath()
        }
    }

    private func browseForGit() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the Git executable"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            gitPath = url.path
        }
    }

    private func detectGit() {
        // Try common Git locations
        let commonPaths = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git",
            "/opt/local/bin/git"
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                gitPath = path
                return
            }
        }
    }

    private func validateGitPath() {
        let fileManager = FileManager.default
        isValidGitPath = fileManager.isExecutableFile(atPath: gitPath)

        if isValidGitPath {
            // Get Git version
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitPath)
            process.arguments = ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    gitVersion = output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                gitVersion = ""
            }
        } else {
            gitVersion = ""
        }
    }
}

// MARK: - Accounts Settings Tab

/// Service accounts management.
struct AccountsSettingsView: View {
    var body: some View {
        Form {
            Section("Connected Accounts") {
                AccountRow(service: "GitHub", icon: "link.circle", isConnected: true)
                AccountRow(service: "GitLab", icon: "g.circle", isConnected: false)
                AccountRow(service: "Bitbucket", icon: "b.circle", isConnected: false)
                AccountRow(service: "Azure DevOps", icon: "a.circle", isConnected: false)
                AccountRow(service: "Gitea", icon: "leaf.circle", isConnected: false)
                AccountRow(service: "Beanstalk", icon: "tree", isConnected: false)
            }

            Section {
                Button("Add Account...") {
                    // Show add account sheet
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AccountRow: View {
    let service: String
    let icon: String
    let isConnected: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isConnected ? .blue : .secondary)
            Text(service)
            Spacer()
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Button("Disconnect") { }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("Connect") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Appearance Settings Tab

/// Extended appearance settings including syntax highlighting.
struct AppearanceSettingsTab: View {
    @AppStorage("com.gitflow.theme") private var theme: String = "system"
    @AppStorage("com.gitflow.compactToolbar") private var compactToolbar: Bool = false
    @AppStorage("com.gitflow.syntaxTheme") private var syntaxTheme: String = "default"

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Toolbar") {
                Toggle("Compact toolbar", isOn: $compactToolbar)
            }

            Section("Syntax Highlighting") {
                Picker("Theme", selection: $syntaxTheme) {
                    Text("Default").tag("default")
                    Text("Monokai").tag("monokai")
                    Text("Solarized Light").tag("solarized-light")
                    Text("Solarized Dark").tag("solarized-dark")
                    Text("GitHub").tag("github")
                    Text("Dracula").tag("dracula")
                    Text("One Dark").tag("one-dark")
                    Text("Nord").tag("nord")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - External Tools Settings Tab

/// External diff/merge/editor tool configuration.
struct ExternalToolsSettingsTab: View {
    @AppStorage("com.gitflow.externalDiffTool") private var diffTool: String = ""
    @AppStorage("com.gitflow.externalMergeTool") private var mergeTool: String = ""
    @AppStorage("com.gitflow.externalEditor") private var editor: String = ""

    var body: some View {
        Form {
            Section("Diff Tool") {
                Picker("External diff tool", selection: $diffTool) {
                    Text("None (use built-in)").tag("")
                    Text("FileMerge").tag("opendiff")
                    Text("Kaleidoscope").tag("ksdiff")
                    Text("Beyond Compare").tag("bcomp")
                    Text("VS Code").tag("code --diff")
                    Text("Custom...").tag("custom")
                }
            }

            Section("Merge Tool") {
                Picker("External merge tool", selection: $mergeTool) {
                    Text("None (use built-in)").tag("")
                    Text("FileMerge").tag("opendiff")
                    Text("Kaleidoscope").tag("ksdiff")
                    Text("Beyond Compare").tag("bcomp")
                    Text("VS Code").tag("code --merge")
                    Text("Custom...").tag("custom")
                }
            }

            Section("Editor") {
                Picker("External editor", selection: $editor) {
                    Text("System Default").tag("")
                    Text("VS Code").tag("code")
                    Text("Sublime Text").tag("subl")
                    Text("Atom").tag("atom")
                    Text("TextMate").tag("mate")
                    Text("Xcode").tag("xcode")
                    Text("Custom...").tag("custom")
                }
            }

            Section("Terminal") {
                Button("Open in Terminal") {
                    // Open terminal at current repo
                }
                .disabled(true)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Security Settings Tab

/// SSH and GPG key management.
struct SecuritySettingsTab: View {
    var body: some View {
        Form {
            Section("SSH Keys") {
                HStack {
                    Text("Manage SSH keys for authentication")
                    Spacer()
                    Button("Manage...") {
                        // Show SSH keys view
                    }
                }

                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                    Text("1Password SSH Agent")
                    Spacer()
                    Button("Configure...") {
                        // Show 1Password SSH settings
                    }
                }
            }

            Section("GPG Keys") {
                HStack {
                    Text("Manage GPG keys for commit signing")
                    Spacer()
                    Button("Manage...") {
                        // Show GPG keys view
                    }
                }

                Toggle("Sign commits by default", isOn: .constant(false))
            }

            Section("User Profiles") {
                HStack {
                    Text("Manage committer identities")
                    Spacer()
                    Button("Manage...") {
                        // Show user profiles view
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced Settings Tab

/// Advanced settings including LFS, environment variables, backup.
struct AdvancedSettingsTab: View {
    @AppStorage("com.gitflow.enableLFS") private var enableLFS: Bool = true
    @AppStorage("com.gitflow.autoFetch") private var autoFetch: Bool = false
    @AppStorage("com.gitflow.autoFetchInterval") private var autoFetchInterval: Int = 10

    var body: some View {
        Form {
            Section("Git LFS") {
                Toggle("Enable Git LFS support", isOn: $enableLFS)
                Button("View LFS Objects...") {
                    // Show LFS view
                }
                .disabled(!enableLFS)
            }

            Section("Auto-Fetch") {
                Toggle("Automatically fetch from remotes", isOn: $autoFetch)
                if autoFetch {
                    Picker("Fetch interval", selection: $autoFetchInterval) {
                        Text("Every 5 minutes").tag(5)
                        Text("Every 10 minutes").tag(10)
                        Text("Every 15 minutes").tag(15)
                        Text("Every 30 minutes").tag(30)
                    }
                }
            }

            Section("Environment Variables") {
                HStack {
                    Text("Configure custom environment variables")
                    Spacer()
                    Button("Configure...") {
                        // Show environment variables view
                    }
                }
            }

            Section("Keyboard Shortcuts") {
                HStack {
                    Text("Customize keyboard shortcuts")
                    Spacer()
                    Button("Customize...") {
                        // Show keyboard shortcuts view
                    }
                }
            }

            Section("Backup & Restore") {
                HStack {
                    Button("Export Settings...") {
                        // Export settings
                    }
                    Button("Import Settings...") {
                        // Import settings
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
