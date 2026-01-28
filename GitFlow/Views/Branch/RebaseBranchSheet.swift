import SwiftUI

/// Sheet for rebasing the current branch onto another branch.
struct RebaseBranchSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    let ontoBranch: Branch
    @Binding var isPresented: Bool

    @State private var isRebasing: Bool = false
    @State private var showWarning: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rebase Branch")
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
                // Rebase info
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(.green)
                            Text(viewModel.currentBranchName ?? "HEAD")
                                .font(.body.monospaced())
                        }
                    }

                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Onto Branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(.blue)
                            Text(ontoBranch.name)
                                .font(.body.monospaced())
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("What will happen:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Your commits will be replayed on top of '\(ontoBranch.name)'", systemImage: "arrow.triangle.swap")
                        Label("Commit hashes will change", systemImage: "number")
                        Label("The branch will have a linear history", systemImage: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                // Warning
                if showWarning && (viewModel.currentBranch?.upstream != nil) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("This branch has been pushed")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Rebasing a pushed branch will rewrite history. You may need to force-push after rebasing, which can cause issues for others working on this branch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
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

                Button("Rebase") {
                    rebase()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isRebasing)
            }
            .padding()
        }
        .frame(width: 450)
    }

    private func rebase() {
        isRebasing = true

        Task {
            await viewModel.rebase(ontoBranch: ontoBranch.name)

            isRebasing = false
            if viewModel.error == nil {
                isPresented = false
            }
        }
    }
}

#Preview {
    RebaseBranchSheet(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        ontoBranch: .local(name: "main", commitHash: "abc123"),
        isPresented: .constant(true)
    )
}
