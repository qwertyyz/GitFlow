import Foundation
import AppKit
import SwiftUI

/// Service for 1Password SSH Agent integration.
/// Allows using SSH keys stored in 1Password for Git operations.
@MainActor
class OnePasswordSSHAgentService: ObservableObject {
    static let shared = OnePasswordSSHAgentService()

    @Published var isAvailable: Bool = false
    @Published var isEnabled: Bool = false
    @Published var agentSocketPath: String = ""
    @Published var availableKeys: [OnePasswordSSHKey] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let defaultSocketPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    private let settingsKey = "onePasswordSSHEnabled"

    private init() {
        loadSettings()
        checkAvailability()
    }

    // MARK: - Availability Check

    /// Check if 1Password SSH Agent is available
    func checkAvailability() {
        let expandedPath = NSString(string: defaultSocketPath).expandingTildeInPath
        let fileManager = FileManager.default

        // Check if the socket file exists
        isAvailable = fileManager.fileExists(atPath: expandedPath)

        if isAvailable {
            agentSocketPath = expandedPath
        }
    }

    /// Check if 1Password CLI is installed
    func checkCLIAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["op"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Enable/Disable

    /// Enable 1Password SSH Agent for Git operations
    func enable() {
        guard isAvailable else {
            error = "1Password SSH Agent is not available"
            return
        }

        isEnabled = true
        saveSettings()

        // Configure Git to use 1Password SSH Agent
        configureGitSSH()
    }

    /// Disable 1Password SSH Agent
    func disable() {
        isEnabled = false
        saveSettings()

        // Remove Git SSH configuration
        removeGitSSHConfig()
    }

    // MARK: - Git Configuration

    /// Configure Git to use 1Password SSH Agent
    private func configureGitSSH() {
        // Set SSH_AUTH_SOCK environment variable
        setenv("SSH_AUTH_SOCK", agentSocketPath, 1)

        // Optionally set GIT_SSH_COMMAND if needed
        let sshCommand = "ssh -o IdentityAgent=\(agentSocketPath)"
        setenv("GIT_SSH_COMMAND", sshCommand, 1)
    }

    /// Remove Git SSH configuration
    private func removeGitSSHConfig() {
        unsetenv("SSH_AUTH_SOCK")
        unsetenv("GIT_SSH_COMMAND")
    }

    /// Get environment variables for Git commands
    func getEnvironment() -> [String: String] {
        guard isEnabled && isAvailable else {
            return [:]
        }

        return [
            "SSH_AUTH_SOCK": agentSocketPath
        ]
    }

    // MARK: - Key Management

    /// List available SSH keys from 1Password
    func listKeys() async {
        isLoading = true
        defer { isLoading = false }

        // Try using ssh-add to list keys from the agent
        do {
            let keys = try await listKeysFromAgent()
            availableKeys = keys
        } catch {
            self.error = "Failed to list keys: \(error.localizedDescription)"
        }
    }

    private func listKeysFromAgent() async throws -> [OnePasswordSSHKey] {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
            process.arguments = ["-l"]
            process.environment = ["SSH_AUTH_SOCK": agentSocketPath]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                let keys = parseSSHAddOutput(output)
                continuation.resume(returning: keys)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseSSHAddOutput(_ output: String) -> [OnePasswordSSHKey] {
        var keys: [OnePasswordSSHKey] = []

        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: " ")
            if parts.count >= 3 {
                let key = OnePasswordSSHKey(
                    id: UUID(),
                    bits: Int(parts[0]) ?? 0,
                    fingerprint: parts[1],
                    comment: parts.dropFirst(2).joined(separator: " "),
                    type: extractKeyType(from: parts[1])
                )
                keys.append(key)
            }
        }

        return keys
    }

    private func extractKeyType(from fingerprint: String) -> String {
        if fingerprint.contains("SHA256") {
            return "SHA256"
        }
        return "Unknown"
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: settingsKey)
    }

    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: settingsKey)
    }

    // MARK: - 1Password CLI Integration

    /// Sign a commit using 1Password CLI (for SSH signing)
    func signCommit(message: String, keyFingerprint: String?) async throws -> String {
        // This would use `op ssh-sign` if available
        // For now, return the message as-is
        return message
    }
}

// MARK: - Data Models

struct OnePasswordSSHKey: Identifiable {
    let id: UUID
    let bits: Int
    let fingerprint: String
    let comment: String
    let type: String

    var displayName: String {
        if comment.isEmpty {
            return fingerprint
        }
        return comment
    }

    var shortFingerprint: String {
        String(fingerprint.prefix(16))
    }
}

// MARK: - Settings View

struct OnePasswordSSHSettingsView: View {
    @ObservedObject private var service = OnePasswordSSHAgentService.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1Password SSH Agent")
                            .font(.headline)

                        HStack {
                            Circle()
                                .fill(service.isAvailable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(service.isAvailable ? "Available" : "Not Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { service.isEnabled },
                        set: { enabled in
                            if enabled {
                                service.enable()
                            } else {
                                service.disable()
                            }
                        }
                    ))
                    .labelsHidden()
                    .disabled(!service.isAvailable)
                }
            }

            if !service.isAvailable {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1Password SSH Agent not detected")
                            .font(.subheadline)
                            .foregroundColor(.orange)

                        Text("To use 1Password for SSH authentication:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open 1Password app")
                            Text("2. Go to Settings → Developer")
                            Text("3. Enable 'Use the SSH Agent'")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Button("Check Again") {
                            service.checkAvailability()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }

            if service.isEnabled && service.isAvailable {
                Section("SSH Keys") {
                    if service.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading keys...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if service.availableKeys.isEmpty {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.secondary)
                            Text("No SSH keys found in 1Password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(service.availableKeys) { key in
                            OnePasswordSSHKeyRow(key: key)
                        }
                    }

                    Button("Refresh Keys") {
                        Task {
                            await service.listKeys()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Section("Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Agent Socket Path")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(service.agentSocketPath)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Text("When enabled, GitFlow will use SSH keys stored in 1Password for Git operations. Your keys never leave 1Password - authentication happens through the SSH agent.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = service.error {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if service.isEnabled && service.isAvailable {
                await service.listKeys()
            }
        }
    }
}

struct OnePasswordSSHKeyRow: View {
    let key: OnePasswordSSHKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(key.displayName)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    Text(key.shortFingerprint)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)

                    Text("\(key.bits) bits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Git Service Extension

extension OnePasswordSSHAgentService {
    /// Create an environment dictionary for running Git commands with 1Password SSH
    func gitEnvironment() -> [String: String]? {
        guard isEnabled && isAvailable else {
            return nil
        }

        return [
            "SSH_AUTH_SOCK": agentSocketPath,
            "GIT_SSH_COMMAND": "ssh -o IdentityAgent=\(agentSocketPath)"
        ]
    }
}

#Preview {
    OnePasswordSSHSettingsView()
        .frame(width: 500)
}
