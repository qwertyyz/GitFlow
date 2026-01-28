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

            Divider()

            // Actions
            HStack {
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
                .disabled(isMerging)
            }
            .padding()
        }
        .frame(width: 450)
        .onAppear {
            customMessage = "Merge branch '\(sourceBranch.name)' into \(viewModel.currentBranchName ?? "HEAD")"
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
