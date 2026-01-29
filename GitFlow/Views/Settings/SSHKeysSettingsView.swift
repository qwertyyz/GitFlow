import SwiftUI

/// Settings view for managing SSH keys.
struct SSHKeysSettingsView: View {
    @StateObject private var viewModel = SSHKeysViewModel()
    @State private var showingGenerateSheet = false
    @State private var showingImportSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var keyToDelete: SSHKey?
    @State private var showingPublicKeySheet = false
    @State private var selectedKeyForPublicKey: SSHKey?

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("SSH Keys")
                    .font(.headline)

                Spacer()

                Button(action: { showingGenerateSheet = true }) {
                    Label("Generate", systemImage: "plus")
                }

                Button(action: { showingImportSheet = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button(action: { Task { await viewModel.loadKeys() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh SSH key list")
            }
            .padding()

            Divider()

            if viewModel.isLoading {
                ProgressView("Loading SSH keys...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.keys.isEmpty {
                emptyStateView
            } else {
                keyListView
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .sheet(isPresented: $showingGenerateSheet) {
            GenerateSSHKeySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportSSHKeySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPublicKeySheet) {
            if let key = selectedKeyForPublicKey {
                PublicKeySheet(key: key)
            }
        }
        .alert("Delete SSH Key?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let key = keyToDelete {
                    Task { await viewModel.deleteKey(key) }
                }
            }
        } message: {
            if let key = keyToDelete {
                Text("Are you sure you want to delete the SSH key '\(key.name)'? This action cannot be undone.")
            }
        }
        .task {
            await viewModel.loadKeys()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No SSH Keys Found")
                .font(.headline)

            Text("SSH keys are used for secure authentication with Git remotes.\nGenerate a new key or import an existing one.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Generate New Key") {
                    showingGenerateSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("Import Existing Key") {
                    showingImportSheet = true
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
                SSHKeyRow(
                    key: key,
                    onCopyPublicKey: {
                        if let publicKey = key.publicKey {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(publicKey, forType: .string)
                        }
                    },
                    onShowPublicKey: {
                        selectedKeyForPublicKey = key
                        showingPublicKeySheet = true
                    },
                    onDelete: {
                        keyToDelete = key
                        showingDeleteConfirmation = true
                    },
                    onRevealInFinder: {
                        NSWorkspace.shared.selectFile(key.privateKeyPath, inFileViewerRootedAtPath: "")
                    }
                )
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - SSH Key Row

struct SSHKeyRow: View {
    let key: SSHKey
    let onCopyPublicKey: () -> Void
    let onShowPublicKey: () -> Void
    let onDelete: () -> Void
    let onRevealInFinder: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Key type icon
            Image(systemName: keyIcon)
                .font(.title2)
                .foregroundColor(keyColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(key.name)
                        .font(.headline)

                    Text(key.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                if let fingerprint = key.fingerprint {
                    Text(fingerprint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let comment = key.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let date = key.createdDate {
                    Text("Created: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: onCopyPublicKey) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy public key to clipboard")

                Button(action: onShowPublicKey) {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
                .help("Show public key")

                Button(action: onRevealInFinder) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete key")
            }
        }
        .padding(.vertical, 8)
    }

    private var keyIcon: String {
        switch key.type {
        case .ed25519:
            return "key.fill"
        case .rsa:
            return "lock.fill"
        case .ecdsa:
            return "shield.fill"
        case .dsa:
            return "key"
        }
    }

    private var keyColor: Color {
        switch key.type {
        case .ed25519:
            return .green
        case .rsa:
            return .blue
        case .ecdsa:
            return .purple
        case .dsa:
            return .orange
        }
    }
}

// MARK: - Generate SSH Key Sheet

struct GenerateSSHKeySheet: View {
    @ObservedObject var viewModel: SSHKeysViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var keyName = ""
    @State private var keyType: SSHKey.KeyType = .ed25519
    @State private var comment = ""
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Generate SSH Key")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    TextField("Key Name", text: $keyName)
                        .help("Name for the key file (e.g., id_github)")

                    Picker("Key Type", selection: $keyType) {
                        ForEach(SSHKey.KeyType.allCases, id: \.self) { type in
                            Text(keyTypeDescription(type)).tag(type)
                        }
                    }
                    .help("ED25519 is recommended for new keys")

                    TextField("Comment (optional)", text: $comment)
                        .help("Usually your email address")
                }

                Section("Passphrase (optional)") {
                    SecureField("Passphrase", text: $passphrase)
                    SecureField("Confirm Passphrase", text: $confirmPassphrase)

                    if !passphrase.isEmpty && passphrase != confirmPassphrase {
                        Text("Passphrases do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }

                Button("Generate") {
                    generateKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canGenerate)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    private var canGenerate: Bool {
        !keyName.isEmpty &&
        !isGenerating &&
        (passphrase.isEmpty || passphrase == confirmPassphrase)
    }

    private func keyTypeDescription(_ type: SSHKey.KeyType) -> String {
        switch type {
        case .ed25519:
            return "ED25519 (Recommended)"
        case .rsa:
            return "RSA (4096-bit)"
        case .ecdsa:
            return "ECDSA"
        case .dsa:
            return "DSA (Legacy)"
        }
    }

    private func generateKey() {
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                _ = try await viewModel.generateKey(
                    name: keyName,
                    type: keyType,
                    comment: comment.isEmpty ? nil : comment,
                    passphrase: passphrase.isEmpty ? nil : passphrase
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Import SSH Key Sheet

struct ImportSSHKeySheet: View {
    @ObservedObject var viewModel: SSHKeysViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var privateKeyPath = ""
    @State private var newName = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import SSH Key")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    HStack {
                        TextField("Private Key Path", text: $privateKeyPath)
                            .disabled(true)

                        Button("Browse...") {
                            browseForKey()
                        }
                    }

                    TextField("New Name (optional)", text: $newName)
                        .help("Leave empty to use original filename")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                if isImporting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }

                Button("Import") {
                    importKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(privateKeyPath.isEmpty || isImporting)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 280)
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select your SSH private key file"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }

    private func importKey() {
        isImporting = true
        errorMessage = nil

        Task {
            do {
                let url = URL(fileURLWithPath: privateKeyPath)
                _ = try await viewModel.importKey(
                    from: url,
                    name: newName.isEmpty ? nil : newName
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Public Key Sheet

struct PublicKeySheet: View {
    let key: SSHKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Public Key: \(key.name)")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Public key content
            ScrollView {
                if let publicKey = key.publicKey {
                    Text(publicKey)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Could not read public key")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                if let fingerprint = key.fingerprint {
                    Text("Fingerprint: \(fingerprint)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Copy to Clipboard") {
                    if let publicKey = key.publicKey {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(publicKey, forType: .string)
                    }
                }
            }
            .padding()
        }
        .frame(width: 600, height: 300)
    }
}

// MARK: - View Model

@MainActor
class SSHKeysViewModel: ObservableObject {
    @Published var keys: [SSHKey] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let sshKeyService = SSHKeyService()

    func loadKeys() async {
        isLoading = true
        defer { isLoading = false }

        do {
            keys = try await sshKeyService.listKeys()
        } catch {
            self.error = error
            keys = []
        }
    }

    func generateKey(name: String, type: SSHKey.KeyType, comment: String?, passphrase: String?) async throws -> SSHKey {
        let key = try await sshKeyService.generateKey(
            name: name,
            type: type,
            comment: comment,
            passphrase: passphrase
        )
        await loadKeys()
        return key
    }

    func importKey(from url: URL, name: String?) async throws -> SSHKey {
        let key = try await sshKeyService.importKey(from: url, name: name)
        await loadKeys()
        return key
    }

    func deleteKey(_ key: SSHKey) async {
        do {
            try await sshKeyService.deleteKey(key)
            await loadKeys()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    SSHKeysSettingsView()
}
