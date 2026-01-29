import SwiftUI

/// Settings view for managing GPG keys and commit signing.
struct GPGKeysSettingsView: View {
    @StateObject private var viewModel = GPGKeysViewModel()
    @State private var showingSecretKeysOnly = true

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("GPG Keys")
                    .font(.headline)

                Spacer()

                Toggle("Secret Keys Only", isOn: $showingSecretKeysOnly)
                    .toggleStyle(.checkbox)
                    .help("Show only keys you can sign with")

                Button(action: { Task { await viewModel.loadKeys(secretOnly: showingSecretKeysOnly) } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh GPG key list")
            }
            .padding()

            Divider()

            if viewModel.isLoading {
                ProgressView("Loading GPG keys...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.isGPGInstalled {
                gpgNotInstalledView
            } else if viewModel.keys.isEmpty {
                emptyStateView
            } else {
                keyListView
            }

            // GPG version info
            if let version = viewModel.gpgVersion {
                Divider()
                HStack {
                    Text(version)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .task {
            await viewModel.loadKeys(secretOnly: showingSecretKeysOnly)
        }
        .onChange(of: showingSecretKeysOnly) { newValue in
            Task { await viewModel.loadKeys(secretOnly: newValue) }
        }
    }

    private var gpgNotInstalledView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("GPG Not Found")
                .font(.headline)

            Text("GPG (GnuPG) is required for signing commits.\nInstall GPG using Homebrew or download from gnupg.org.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Open GnuPG Website") {
                    if let url = URL(string: "https://gnupg.org/download/") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Install with Homebrew") {
                    openTerminalWithCommand("brew install gnupg")
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "signature")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No GPG Keys Found")
                .font(.headline)

            Text("GPG keys are used to cryptographically sign commits.\nGenerate a new key using GPG or import an existing one.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Generate Key in Terminal") {
                    openTerminalWithCommand("gpg --full-generate-key")
                }

                Button("Learn More") {
                    if let url = URL(string: "https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var keyListView: some View {
        List {
            ForEach(viewModel.keys) { key in
                GPGKeyRow(key: key)
            }
        }
        .listStyle(.inset)
    }

    private func openTerminalWithCommand(_ command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - GPG Key Row

struct GPGKeyRow: View {
    let key: GPGKey

    var body: some View {
        HStack(spacing: 12) {
            // Key status icon
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(key.userId)
                        .font(.headline)
                        .lineLimit(1)

                    if key.isExpired {
                        statusBadge("Expired", color: .orange)
                    } else if key.isRevoked {
                        statusBadge("Revoked", color: .red)
                    } else if key.isValidForSigning {
                        statusBadge("Valid", color: .green)
                    }
                }

                HStack(spacing: 8) {
                    Text(key.shortKeyId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(key.trustLevel.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trustColor.opacity(0.2))
                        .foregroundColor(trustColor)
                        .cornerRadius(4)
                }

                HStack(spacing: 16) {
                    if let email = key.email {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let date = key.createdDate {
                        Label("Created: \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let expires = key.expirationDate {
                    Label("Expires: \(expires.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(key.isExpired ? .orange : .secondary)
                }

                // Capabilities
                HStack(spacing: 8) {
                    if key.canSign {
                        capabilityBadge("Sign", icon: "signature")
                    }
                    if key.canEncrypt {
                        capabilityBadge("Encrypt", icon: "lock")
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: { copyKeyId() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy key ID to clipboard")

                Button(action: { copyFingerprint() }) {
                    Image(systemName: "number")
                }
                .buttonStyle(.borderless)
                .help("Copy fingerprint to clipboard")

                Button(action: { exportPublicKey() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export public key")
            }
        }
        .padding(.vertical, 8)
        .opacity(key.isExpired || key.isRevoked ? 0.6 : 1.0)
    }

    private var statusIcon: String {
        if key.isRevoked {
            return "xmark.seal.fill"
        } else if key.isExpired {
            return "clock.badge.exclamationmark.fill"
        } else if key.isValidForSigning {
            return "checkmark.seal.fill"
        }
        return "key.fill"
    }

    private var statusColor: Color {
        if key.isRevoked {
            return .red
        } else if key.isExpired {
            return .orange
        } else if key.isValidForSigning {
            return .green
        }
        return .secondary
    }

    private var trustColor: Color {
        switch key.trustLevel {
        case .ultimate:
            return .green
        case .full:
            return .blue
        case .marginal:
            return .yellow
        case .never:
            return .red
        case .unknown:
            return .secondary
        }
    }

    @ViewBuilder
    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    @ViewBuilder
    private func capabilityBadge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }

    private func copyKeyId() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.keyId, forType: .string)
    }

    private func copyFingerprint() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.fingerprint, forType: .string)
    }

    private func exportPublicKey() {
        let script = """
        tell application "Terminal"
            activate
            do script "gpg --armor --export \(key.keyId)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - View Model

@MainActor
class GPGKeysViewModel: ObservableObject {
    @Published var keys: [GPGKey] = []
    @Published var isLoading = false
    @Published var isGPGInstalled = true
    @Published var gpgVersion: String?
    @Published var error: Error?

    private let gpgService = GPGService()

    func loadKeys(secretOnly: Bool) async {
        isLoading = true
        defer { isLoading = false }

        // Check if GPG is installed
        isGPGInstalled = await gpgService.isGPGInstalled()

        if !isGPGInstalled {
            keys = []
            gpgVersion = nil
            return
        }

        // Get GPG version
        gpgVersion = await gpgService.getVersion()

        // Load keys
        do {
            if secretOnly {
                keys = try await gpgService.listSecretKeys()
            } else {
                keys = try await gpgService.listKeys()
            }
        } catch {
            self.error = error
            keys = []
        }
    }
}

// MARK: - Signature Verification View

/// A small view showing commit signature verification status.
struct SignatureVerificationBadge: View {
    let verification: SignatureVerification

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: verification.status.icon)
                .foregroundColor(statusColor)

            if let signer = verification.signerName {
                Text(signer)
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text(verification.status.rawValue)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(6)
        .help(helpText)
    }

    private var statusColor: Color {
        switch verification.status.color {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        default: return .secondary
        }
    }

    private var helpText: String {
        var text = "Signature: \(verification.status.rawValue)"
        if let keyId = verification.keyId {
            text += "\nKey ID: \(keyId)"
        }
        if let message = verification.message {
            text += "\n\(message)"
        }
        return text
    }
}

#Preview("GPG Keys") {
    GPGKeysSettingsView()
}

#Preview("Signature Badge - Good") {
    SignatureVerificationBadge(verification: SignatureVerification(
        isVerified: true,
        signerName: "John Doe",
        signerEmail: "john@example.com",
        keyId: "ABC123",
        status: .good,
        message: nil
    ))
}

#Preview("Signature Badge - Bad") {
    SignatureVerificationBadge(verification: SignatureVerification(
        isVerified: false,
        signerName: nil,
        signerEmail: nil,
        keyId: nil,
        status: .bad,
        message: nil
    ))
}
