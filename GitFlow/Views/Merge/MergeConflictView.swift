import SwiftUI

/// Main view for merge conflict resolution.
struct MergeConflictView: View {
    @ObservedObject var viewModel: MergeConflictViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MergeConflictHeader(viewModel: viewModel)

            Divider()

            if !viewModel.isMerging {
                // Not in a merge state
                EmptyStateView(
                    "No Merge in Progress",
                    systemImage: "arrow.triangle.merge",
                    description: "Start a merge to resolve conflicts here"
                )
            } else if viewModel.mergeState.conflictedFiles.isEmpty && !viewModel.isLoading {
                // All conflicts resolved
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("All Conflicts Resolved")
                        .font(.headline)

                    Text("You can now continue the merge")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Continue Merge") {
                        Task { await viewModel.continueMerge() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Split view: file list and editor
                HSplitView {
                    // Left: File list
                    ConflictFileList(viewModel: viewModel)
                        .frame(minWidth: 200, maxWidth: 300)

                    // Right: Merge editor
                    if viewModel.selectedFile != nil {
                        ThreeWayMergeEditor(viewModel: viewModel)
                    } else {
                        EmptyStateView(
                            "Select a File",
                            systemImage: "doc.text",
                            description: "Choose a conflicted file to resolve"
                        )
                    }
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
        .alert("Merge Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Header

private struct MergeConflictHeader: View {
    @ObservedObject var viewModel: MergeConflictViewModel

    var body: some View {
        HStack {
            // Merge info
            if viewModel.isMerging {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundStyle(.orange)

                    if let merging = viewModel.mergeState.mergingBranch {
                        Text("Merging")
                            .foregroundStyle(.secondary)
                        Text(merging)
                            .fontWeight(.medium)
                        Text("into")
                            .foregroundStyle(.secondary)
                        Text(viewModel.mergeState.currentBranch ?? "HEAD")
                            .fontWeight(.medium)
                    } else {
                        Text("Merge in progress")
                    }
                }
            } else {
                Text("Merge Conflicts")
                    .font(.headline)
            }

            Spacer()

            if viewModel.isMerging {
                // Progress
                Text(viewModel.progressString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 16)

                // Actions
                Button("Abort Merge") {
                    Task { await viewModel.abortMerge() }
                }
                .foregroundStyle(.red)

                if viewModel.allResolved {
                    Button("Continue Merge") {
                        Task { await viewModel.continueMerge() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if viewModel.isLoading || viewModel.isOperationInProgress {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - File List

private struct ConflictFileList: View {
    @ObservedObject var viewModel: MergeConflictViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conflicts")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(viewModel.mergeState.unresolvedCount) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // File list
            List(viewModel.mergeState.conflictedFiles, selection: $viewModel.selectedFile) { file in
                ConflictFileRow(file: file)
                    .tag(file)
            }
            .listStyle(.inset)
            .onChange(of: viewModel.selectedFile) { _, newFile in
                if let file = newFile {
                    Task { await viewModel.loadFileContent(for: file) }
                }
            }
        }
    }
}

private struct ConflictFileRow: View {
    let file: ConflictedFile

    var body: some View {
        HStack {
            Image(systemName: file.isResolved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(file.isResolved ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.body)

                if !file.directory.isEmpty {
                    Text(file.directory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Three-Way Merge Editor

private struct ThreeWayMergeEditor: View {
    @ObservedObject var viewModel: MergeConflictViewModel

    @State private var selectedPane: MergePane = .merged

    enum MergePane: String, CaseIterable {
        case ours = "Ours"
        case base = "Base"
        case theirs = "Theirs"
        case merged = "Merged"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if let file = viewModel.selectedFile {
                    Text(file.fileName)
                        .font(.headline)

                    Text("(\(file.conflictType.description))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Quick resolution buttons
                Button("Use Ours") {
                    Task { await viewModel.useOurs() }
                }
                .help("Use our version (current branch)")

                Button("Use Theirs") {
                    Task { await viewModel.useTheirs() }
                }
                .help("Use their version (merging branch)")

                Divider()
                    .frame(height: 16)

                // Pane selector
                Picker("View", selection: $selectedPane) {
                    ForEach(MergePane.allCases, id: \.self) { pane in
                        Text(pane.rawValue).tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content panes
            Group {
                switch selectedPane {
                case .ours:
                    ReadOnlyCodeView(content: viewModel.oursContent, label: "Ours (Current Branch)")
                case .base:
                    ReadOnlyCodeView(content: viewModel.baseContent, label: "Base (Common Ancestor)")
                case .theirs:
                    ReadOnlyCodeView(content: viewModel.theirsContent, label: "Theirs (Merging Branch)")
                case .merged:
                    MergedContentEditor(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer with conflict sections
            if !viewModel.conflictSections.isEmpty {
                Divider()
                ConflictSectionList(viewModel: viewModel)
            }
        }
    }
}

private struct ReadOnlyCodeView: View {
    let content: String
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
    }
}

private struct MergedContentEditor: View {
    @ObservedObject var viewModel: MergeConflictViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Merged Result")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !viewModel.mergedContentHasNoConflicts {
                    Label("Contains conflict markers", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Button("Save & Mark Resolved") {
                    Task { await viewModel.saveMergedContent() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.mergedContentHasNoConflicts)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            TextEditor(text: $viewModel.mergedContent)
                .font(.system(.body, design: .monospaced))
        }
    }
}

private struct ConflictSectionList: View {
    @ObservedObject var viewModel: MergeConflictViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Conflict Sections")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("(\(viewModel.conflictSections.count) remaining)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.conflictSections) { section in
                        ConflictSectionCard(section: section, viewModel: viewModel)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 120)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct ConflictSectionCard: View {
    let section: ConflictSection
    @ObservedObject var viewModel: MergeConflictViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lines \(section.startLine)-\(section.endLine)")
                .font(.caption)
                .fontWeight(.medium)

            HStack(spacing: 4) {
                Button("Ours") {
                    viewModel.resolveSection(section, with: .ours)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Theirs") {
                    viewModel.resolveSection(section, with: .theirs)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Both") {
                    viewModel.resolveSection(section, with: .both)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    MergeConflictView(
        viewModel: MergeConflictViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 800, height: 600)
}
