import SwiftUI

/// Sheet for merging a branch into the current branch.
struct MergeBranchSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    let sourceBranch: Branch
    @Binding var isPresented: Bool

    @State private var selectedMergeType: MergeType = .normal
    @State private var customMessage: String = ""
    @State private var useCustomMessage: Bool = false
    @State private var isMerging: Bool = false
    @State private var showPreview: Bool = false
    @State private var previewResult: MergePreviewResult?
    @State private var isLoadingPreview: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Merge Branch")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Merge info
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundStyle(.blue)
                                Text(sourceBranch.name)
                                    .font(.body.monospaced())
                            }
                        }

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundStyle(.green)
                                Text(viewModel.currentBranchName ?? "HEAD")
                                    .font(.body.monospaced())
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Merge Preview Section
                    if let preview = previewResult {
                        MergePreviewSection(preview: preview)
                    } else if isLoadingPreview {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading preview...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                    // Merge type selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merge Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Merge Type", selection: $selectedMergeType) {
                            Text("Normal Merge").tag(MergeType.normal)
                            Text("Squash Merge").tag(MergeType.squash)
                            Text("Fast-Forward Only").tag(MergeType.fastForwardOnly)
                            Text("No Fast-Forward").tag(MergeType.noFastForward)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()

                        // Merge type description
                        Text(mergeTypeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                    }

                    // Custom message
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use custom commit message", isOn: $useCustomMessage)
                            .toggleStyle(.checkbox)

                        if useCustomMessage {
                            TextEditor(text: $customMessage)
                                .font(.body.monospaced())
                                .frame(height: 80)
                                .border(Color(NSColor.separatorColor), width: 1)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                // Preview button
                Button("Preview") {
                    loadPreview()
                }
                .disabled(isLoadingPreview)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Merge") {
                    merge()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isMerging || (previewResult?.hasConflicts ?? false))
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .onAppear {
            customMessage = "Merge branch '\(sourceBranch.name)' into \(viewModel.currentBranchName ?? "HEAD")"
            loadPreview()
        }
    }

    private func loadPreview() {
        isLoadingPreview = true
        previewResult = nil

        Task {
            do {
                let preview = try await viewModel.gitService.previewMerge(
                    sourceBranch: sourceBranch.name,
                    targetBranch: viewModel.currentBranchName ?? "HEAD",
                    in: viewModel.repository
                )
                await MainActor.run {
                    previewResult = preview
                    isLoadingPreview = false
                }
            } catch {
                await MainActor.run {
                    isLoadingPreview = false
                }
            }
        }
    }

    private var mergeTypeDescription: String {
        switch selectedMergeType {
        case .normal:
            return "Creates a merge commit, preserving the branch history."
        case .squash:
            return "Combines all commits into one. Requires a separate commit."
        case .fastForwardOnly:
            return "Only merge if fast-forward is possible. Fails otherwise."
        case .noFastForward:
            return "Always creates a merge commit, even if fast-forward is possible."
        }
    }

    private func merge() {
        isMerging = true

        Task {
            let message = useCustomMessage ? customMessage : nil
            await viewModel.merge(
                branchName: sourceBranch.name,
                mergeType: selectedMergeType,
                message: message
            )

            isMerging = false
            if viewModel.error == nil {
                isPresented = false
            }
        }
    }
}

// MARK: - Merge Preview Section

/// Shows the preview of what merging would do.
private struct MergePreviewSection: View {
    let preview: MergePreviewResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Merge Preview")
                    .font(.subheadline.bold())

                Spacer()

                if preview.hasConflicts {
                    Label("Conflicts Detected", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Label("No Conflicts", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Summary stats
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("\(preview.commitCount)")
                        .font(.title2.bold())
                    Text("commits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("\(preview.fileChanges.count)")
                        .font(.title2.bold())
                    Text("files changed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !preview.conflictedFiles.isEmpty {
                    VStack(alignment: .leading) {
                        Text("\(preview.conflictedFiles.count)")
                            .font(.title2.bold())
                            .foregroundStyle(.red)
                        Text("conflicts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            // Conflicted files (if any)
            if !preview.conflictedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conflicted Files:")
                        .font(.caption.bold())
                        .foregroundStyle(.red)

                    ForEach(preview.conflictedFiles.prefix(5), id: \.path) { file in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text(file.path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                        }
                    }

                    if preview.conflictedFiles.count > 5 {
                        Text("... and \(preview.conflictedFiles.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            // File changes summary
            if !preview.fileChanges.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Changed Files:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(preview.fileChanges.prefix(8)) { change in
                        HStack {
                            Image(systemName: iconFor(change.changeType))
                                .font(.caption)
                                .foregroundStyle(colorFor(change.changeType))
                                .frame(width: 12)
                            Text(change.path)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Text(change.changeType.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if preview.fileChanges.count > 8 {
                        Text("... and \(preview.fileChanges.count - 8) more files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func iconFor(_ changeType: MergePreviewChangeType) -> String {
        switch changeType {
        case .added: return "plus.circle"
        case .deleted: return "minus.circle"
        case .modified: return "pencil.circle"
        case .renamed: return "arrow.right.circle"
        case .copied: return "doc.on.doc"
        }
    }

    private func colorFor(_ changeType: MergePreviewChangeType) -> Color {
        switch changeType {
        case .added: return .green
        case .deleted: return .red
        case .modified: return .orange
        case .renamed: return .blue
        case .copied: return .purple
        }
    }
}

#Preview {
    MergeBranchSheet(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        sourceBranch: .local(name: "feature/new-feature", commitHash: "abc123"),
        isPresented: .constant(true)
    )
}
