import SwiftUI

/// View for installing and managing the GitFlow command-line tool.
struct CLIToolInstallerView: View {
    @StateObject private var viewModel = CLIToolInstallerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Install Command Line Tool")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GitFlow CLI")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Install the `gitflow` command to open GitFlow from the terminal. This creates a symbolic link to the GitFlow application.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    // Installation status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Image(systemName: viewModel.isInstalled ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(viewModel.isInstalled ? .green : .secondary)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.isInstalled ? "Installed" : "Not Installed")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if viewModel.isInstalled, let path = viewModel.installedPath {
                                    Text(path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    // Usage examples
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Usage")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            UsageExampleRow(command: "gitflow", description: "Open GitFlow application")
                            UsageExampleRow(command: "gitflow .", description: "Open current directory in GitFlow")
                            UsageExampleRow(command: "gitflow /path/to/repo", description: "Open specific repository")
                            UsageExampleRow(command: "gitflow clone <url>", description: "Clone repository and open")
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    // Installation location picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Installation Location")
                            .font(.headline)

                        Picker("Location", selection: $viewModel.selectedLocation) {
                            ForEach(CLIInstallLocation.allCases) { location in
                                Text(location.displayName).tag(location)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        Text(viewModel.selectedLocation.path)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if viewModel.selectedLocation.requiresAdmin {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("This location requires administrator privileges.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                if viewModel.isInstalled {
                    Button("Uninstall") {
                        Task { await viewModel.uninstall() }
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if viewModel.isInstalled {
                    Button("Reinstall") {
                        Task { await viewModel.install() }
                    }
                    .disabled(viewModel.isInstalling)
                } else {
                    Button("Install") {
                        Task { await viewModel.install() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isInstalling)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .task {
            await viewModel.checkInstallation()
        }
    }
}

// MARK: - Usage Example Row

struct UsageExampleRow: View {
    let command: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 180, alignment: .leading)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Install Location

enum CLIInstallLocation: String, CaseIterable, Identifiable {
    case usrLocalBin = "/usr/local/bin"
    case homeLocalBin = "~/bin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usrLocalBin:
            return "/usr/local/bin (System-wide)"
        case .homeLocalBin:
            return "~/bin (Current user only)"
        }
    }

    var path: String {
        switch self {
        case .usrLocalBin:
            return "/usr/local/bin/gitflow"
        case .homeLocalBin:
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/bin/gitflow"
        }
    }

    var expandedPath: String {
        switch self {
        case .usrLocalBin:
            return "/usr/local/bin/gitflow"
        case .homeLocalBin:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("bin/gitflow").path
        }
    }

    var requiresAdmin: Bool {
        switch self {
        case .usrLocalBin:
            return true
        case .homeLocalBin:
            return false
        }
    }
}

// MARK: - View Model

@MainActor
class CLIToolInstallerViewModel: ObservableObject {
    @Published var isInstalled = false
    @Published var installedPath: String?
    @Published var selectedLocation: CLIInstallLocation = .usrLocalBin
    @Published var isInstalling = false
    @Published var errorMessage: String?

    private let toolName = "gitflow"
    private let fileManager = FileManager.default

    func checkInstallation() async {
        // Check common locations
        let locations: [String] = [
            "/usr/local/bin/gitflow",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("bin/gitflow").path,
            "/opt/homebrew/bin/gitflow"
        ]

        for location in locations {
            if fileManager.fileExists(atPath: location) {
                isInstalled = true
                installedPath = location
                return
            }
        }

        isInstalled = false
        installedPath = nil
    }

    func install() async {
        isInstalling = true
        errorMessage = nil
        defer { isInstalling = false }

        let targetPath = selectedLocation.expandedPath

        // Ensure parent directory exists
        let parentDir = (targetPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: parentDir) {
            do {
                try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            } catch {
                errorMessage = "Failed to create directory: \(error.localizedDescription)"
                return
            }
        }

        // Get the app bundle path
        guard let appPath = Bundle.main.bundlePath as String?,
              appPath.hasSuffix(".app") else {
            errorMessage = "Could not determine application path"
            return
        }

        // Create the CLI script
        let scriptContent = """
        #!/bin/bash
        # GitFlow CLI launcher
        # Installed by GitFlow.app

        APP_PATH="\(appPath)"

        if [ -z "$1" ]; then
            # No arguments - just open the app
            open "$APP_PATH"
        elif [ "$1" = "clone" ] && [ -n "$2" ]; then
            # Clone command
            open "$APP_PATH" --args --clone "$2"
        elif [ -d "$1" ]; then
            # Directory path - open it
            open "$APP_PATH" --args "$1"
        else
            # Other arguments - pass through
            open "$APP_PATH" --args "$@"
        fi
        """

        if selectedLocation.requiresAdmin {
            // Use AppleScript to run with admin privileges
            let success = await installWithAdminPrivileges(scriptContent: scriptContent, targetPath: targetPath)
            if success {
                await checkInstallation()
            }
        } else {
            // Direct installation
            do {
                // Remove existing file if present
                if fileManager.fileExists(atPath: targetPath) {
                    try fileManager.removeItem(atPath: targetPath)
                }

                // Write the script
                try scriptContent.write(toFile: targetPath, atomically: true, encoding: .utf8)

                // Make executable
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetPath)

                await checkInstallation()
            } catch {
                errorMessage = "Installation failed: \(error.localizedDescription)"
            }
        }
    }

    func uninstall() async {
        guard let path = installedPath else { return }

        isInstalling = true
        errorMessage = nil
        defer { isInstalling = false }

        if path.hasPrefix("/usr/local") {
            // Requires admin
            let success = await uninstallWithAdminPrivileges(targetPath: path)
            if success {
                await checkInstallation()
            }
        } else {
            do {
                try fileManager.removeItem(atPath: path)
                await checkInstallation()
            } catch {
                errorMessage = "Uninstall failed: \(error.localizedDescription)"
            }
        }
    }

    private func installWithAdminPrivileges(scriptContent: String, targetPath: String) async -> Bool {
        // Write to temp file first
        let tempPath = NSTemporaryDirectory() + "gitflow-cli-temp"
        do {
            try scriptContent.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to create temp file: \(error.localizedDescription)"
            return false
        }

        let script = """
        do shell script "mv '\(tempPath)' '\(targetPath)' && chmod 755 '\(targetPath)'" with administrator privileges
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                self.errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return false
            }
            return true
        }

        errorMessage = "Failed to create AppleScript"
        return false
    }

    private func uninstallWithAdminPrivileges(targetPath: String) async -> Bool {
        let script = """
        do shell script "rm '\(targetPath)'" with administrator privileges
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                self.errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                return false
            }
            return true
        }

        errorMessage = "Failed to create AppleScript"
        return false
    }
}

#Preview {
    CLIToolInstallerView()
}
