import SwiftUI

/// View for creating and applying Git patches.
struct PatchView: View {
    @StateObject private var viewModel = PatchViewModel()
    let repository: Repository

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            if viewModel.isPatchInProgress {
                patchInProgressView
            } else {
                mainContent
            }
        }
        .frame(minWidth: 300)
        .onAppear {
            viewModel.setRepository(repository)
        }
        .sheet(isPresented: $viewModel.showingCreateSheet) {
            CreatePatchSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingApplySheet) {
            ApplyPatchSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.successMessage = nil
            }
        } message: {
            if let message = viewModel.successMessage {
                Text(message)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Patches")
                .font(.headline)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 20) {
            Spacer()

            // Create Patch Section
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Create Patch")
                    .font(.headline)

                Text("Generate a patch from your changes or commits.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Create Patch...") {
                    viewModel.showCreateSheet()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)

            // Apply Patch Section
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Apply Patch")
                    .font(.headline)

                Text("Apply a patch file to your working copy.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Apply Patch...") {
                    viewModel.showApplySheet()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Patch In Progress View

    private var patchInProgressView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Patch Application In Progress")
                .font(.headline)

            Text("A patch operation is currently in progress. Resolve any conflicts and choose an action.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Abort") {
                    Task {
                        await viewModel.abortPatch()
                    }
                }
                .buttonStyle(.bordered)

                Button("Skip") {
                    Task {
                        await viewModel.skipPatch()
                    }
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    Task {
                        await viewModel.continuePatch()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Create Patch Sheet

struct CreatePatchSheet: View {
    @ObservedObject var viewModel: PatchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Patch")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Source Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Patch Source")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Source", selection: $viewModel.patchSource) {
                    Text("Staged Changes").tag(PatchViewModel.PatchSource.staged)
                    Text("Unstaged Changes").tag(PatchViewModel.PatchSource.unstaged)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding()

            Divider()

            // Generate Button
            HStack {
                Button("Generate Patch") {
                    Task {
                        switch viewModel.patchSource {
                        case .staged:
                            await viewModel.createPatchFromStaged()
                        case .unstaged:
                            await viewModel.createPatchFromUnstaged()
                        default:
                            break
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()

            Divider()

            // Generated Patch Preview
            if !viewModel.generatedPatch.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Generated Patch")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(viewModel.generatedPatch.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ScrollView {
                        Text(viewModel.generatedPatch)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
                }
                .padding()
            }

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.generatedPatch, forType: .string)
                }
                .disabled(viewModel.generatedPatch.isEmpty)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save as File...") {
                    savePatchToFile()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.generatedPatch.isEmpty)
            }
            .padding()
        }
        .frame(width: 550, height: 500)
    }

    private func savePatchToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "changes.patch"
        panel.message = "Save the patch file"

        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.savePatch(to: url) }
        }
    }
}

// MARK: - Apply Patch Sheet

struct ApplyPatchSheet: View {
    @ObservedObject var viewModel: PatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputMode: InputMode = .file

    enum InputMode: String, CaseIterable {
        case file = "From File"
        case paste = "Paste Content"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Apply Patch")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Input Mode Selection
            Picker("Input", selection: $inputMode) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Input Area
            switch inputMode {
            case .file:
                fileInputView
            case .paste:
                pasteInputView
            }

            Divider()

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Use 3-way merge if patch fails", isOn: $viewModel.useThreeWay)

                if inputMode == .file {
                    Toggle("Apply as email patch (git am)", isOn: $viewModel.applyAsEmail)
                }
            }
            .padding()

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("Check Patch") {
                    Task {
                        await viewModel.checkPatch()
                    }
                }
                .disabled(isPatchEmpty)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    Task {
                        if inputMode == .file {
                            await viewModel.applyPatchFromFile()
                        } else {
                            await viewModel.applyPatchFromContent()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isPatchEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }

    private var isPatchEmpty: Bool {
        inputMode == .file ? viewModel.patchFilePath.isEmpty : viewModel.patchContent.isEmpty
    }

    private var fileInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patch File")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                TextField("Select a patch file...", text: $viewModel.patchFilePath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Button("Browse...") {
                    browseForPatchFile()
                }
            }
        }
        .padding()
    }

    private var pasteInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Patch Content")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Paste from Clipboard") {
                    if let content = NSPasteboard.general.string(forType: .string) {
                        viewModel.patchContent = content
                    }
                }
                .font(.caption)
            }

            TextEditor(text: $viewModel.patchContent)
                .font(.system(.body, design: .monospaced))
                .frame(height: 200)
                .border(Color.gray.opacity(0.3))
        }
        .padding()
    }

    private func browseForPatchFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText]
        panel.message = "Select a patch file"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.patchFilePath = url.path
        }
    }
}

// MARK: - Preview

#Preview {
    PatchView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
        .frame(width: 400, height: 500)
}
