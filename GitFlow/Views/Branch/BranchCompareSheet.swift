import SwiftUI

/// Sheet for comparing two branches.
struct BranchCompareSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    let compareBranch: Branch
    @Binding var isPresented: Bool

    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Compare Branches")
                    .font(.headline)
                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Branch comparison header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Base")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.blue)
                        Text(viewModel.currentBranchName ?? "HEAD")
                            .font(.body.monospaced())
                    }
                }

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.green)
                        Text(compareBranch.name)
                            .font(.body.monospaced())
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if viewModel.comparisonCommits.isEmpty && viewModel.comparisonDiffs.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Branches are identical")
                        .font(.headline)
                    Text("No differences found between the branches")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView {
                    // Commits tab
                    CommitsComparisonView(commits: viewModel.comparisonCommits)
                        .tabItem {
                            Label("Commits (\(viewModel.comparisonCommits.count))", systemImage: "list.bullet")
                        }

                    // Files tab
                    FilesComparisonView(diffs: viewModel.comparisonDiffs)
                        .tabItem {
                            Label("Files (\(viewModel.comparisonDiffs.count))", systemImage: "doc.text")
                        }
                }
                .padding(.top, 8)
            }

            Divider()

            // Actions
            HStack {
                Button("Refresh") {
                    loadComparison()
                }
                .disabled(isLoading)

                Spacer()

                Button("Close") {
                    viewModel.clearComparison()
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadComparison()
        }
        .onDisappear {
            viewModel.clearComparison()
        }
    }

    private func loadComparison() {
        isLoading = true
        Task {
            await viewModel.compareBranches(
                base: viewModel.currentBranchName ?? "HEAD",
                compare: compareBranch.name
            )
            isLoading = false
        }
    }
}

// MARK: - Commits Comparison View

private struct CommitsComparisonView: View {
    let commits: [Commit]

    var body: some View {
        if commits.isEmpty {
            Text("No commits to display")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(commits) { commit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(commit.shortHash)
                            .font(.body.monospaced())
                            .foregroundStyle(.blue)

                        Text(commit.subject)
                            .font(.body)
                            .lineLimit(1)
                    }

                    HStack {
                        Text(commit.authorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(commit.authorDate.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Files Comparison View

private struct FilesComparisonView: View {
    let diffs: [FileDiff]

    var body: some View {
        if diffs.isEmpty {
            Text("No file changes to display")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(diffs) { diff in
                HStack {
                    Image(systemName: iconForChangeType(diff.changeType))
                        .foregroundStyle(colorForChangeType(diff.changeType))

                    Text(diff.path)
                        .font(.body.monospaced())
                        .lineLimit(1)

                    Spacer()

                    if !diff.isBinary {
                        HStack(spacing: 8) {
                            Text("+\(diff.additions)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.green)

                            Text("-\(diff.deletions)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("Binary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    private func iconForChangeType(_ type: FileChangeType) -> String {
        switch type {
        case .added:
            return "plus.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .renamed:
            return "arrow.right.circle.fill"
        case .copied:
            return "doc.on.doc.fill"
        default:
            return "circle.fill"
        }
    }

    private func colorForChangeType(_ type: FileChangeType) -> Color {
        switch type {
        case .added:
            return .green
        case .deleted:
            return .red
        case .modified:
            return .orange
        case .renamed:
            return .blue
        case .copied:
            return .purple
        default:
            return .secondary
        }
    }
}

#Preview {
    BranchCompareSheet(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        compareBranch: .local(name: "feature/test", commitHash: "abc123"),
        isPresented: .constant(true)
    )
}
