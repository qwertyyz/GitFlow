import SwiftUI

/// View for displaying pull request diff and files changed.
struct PRDiffView: View {
    let pullRequest: GitHubPullRequest
    let repository: Repository
    let gitService: GitService
    let gitHubService: GitHubService

    @State private var files: [PRFileChange] = []
    @State private var selectedFile: PRFileChange?
    @State private var fileDiff: String?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        HSplitView {
            // File list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Files Changed")
                        .font(.headline)
                    Spacer()
                    if !files.isEmpty {
                        Text("\(files.count) files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                Divider()

                // File list
                if isLoading && files.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if files.isEmpty {
                    Spacer()
                    Text("No files changed")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    fileList
                }

                // Stats
                if !files.isEmpty {
                    Divider()
                    statsBar
                }
            }
            .frame(minWidth: 250, maxWidth: 350)

            // Diff view
            VStack(spacing: 0) {
                if let file = selectedFile {
                    diffView(for: file)
                } else {
                    emptyDiffView
                }
            }
            .frame(minWidth: 400)
        }
        .onAppear {
            loadFiles()
        }
    }

    // MARK: - File List

    private var fileList: some View {
        List(files, selection: $selectedFile) { file in
            PRFileRow(file: file)
                .tag(file)
        }
        .listStyle(.inset)
        .onChange(of: selectedFile) { newFile in
            if let file = newFile {
                loadFileDiff(file)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("+\(totalAdditions)")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            HStack(spacing: 4) {
                Text("-\(totalDeletions)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var totalAdditions: Int {
        files.reduce(0) { $0 + $1.additions }
    }

    private var totalDeletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }

    // MARK: - Diff View

    @ViewBuilder
    private func diffView(for file: PRFileChange) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: file.statusIcon)
                    .foregroundColor(file.statusColor)
                Text(file.filename)
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text("+\(file.additions)")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("-\(file.deletions)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()

            Divider()

            // Diff content
            if let diff = fileDiff {
                ScrollView {
                    DiffContentView(diff: diff)
                        .padding()
                }
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }

    private var emptyDiffView: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a file to view diff")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Loading

    private func loadFiles() {
        guard let repoInfo = GitHubRemoteInfo.parse(from: repository.remoteURL ?? "") else {
            error = "Could not parse GitHub repository info"
            return
        }

        isLoading = true
        error = nil

        Task {
            do {
                files = try await gitHubService.getPullRequestFiles(
                    owner: repoInfo.owner,
                    repo: repoInfo.repo,
                    number: pullRequest.number
                )
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadFileDiff(_ file: PRFileChange) {
        fileDiff = nil

        // For now, use the patch from the file if available
        if let patch = file.patch {
            fileDiff = patch
        } else {
            // Could fetch the full diff from Git
            fileDiff = "Binary file or no diff available"
        }
    }
}

// MARK: - PR File Row

private struct PRFileRow: View {
    let file: PRFileChange

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.statusIcon)
                .foregroundColor(file.statusColor)
                .font(.caption)

            Text(file.filename)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 4) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Diff Content View

private struct DiffContentView: View {
    let diff: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diff.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                PRDiffLineView(line: line, lineNumber: index + 1)
            }
        }
        .font(.system(.body, design: .monospaced))
    }
}

private struct PRDiffLineView: View {
    let line: String
    let lineNumber: Int

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .frame(width: 40, alignment: .trailing)
                .foregroundColor(.secondary)
                .font(.caption)

            Text(" ")

            Text(line)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return Color.green.opacity(0.15)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return Color.red.opacity(0.15)
        } else if line.hasPrefix("@@") {
            return Color.blue.opacity(0.1)
        }
        return Color.clear
    }
}

// MARK: - Preview

#Preview {
    PRDiffView(
        pullRequest: GitHubPullRequest(
            id: 1,
            number: 123,
            title: "Test PR",
            body: nil,
            state: "open",
            htmlUrl: "https://github.com/test/test/pull/123",
            user: GitHubUser(id: 1, login: "test", avatarUrl: "", htmlUrl: "", type: "User"),
            labels: [],
            assignees: [],
            createdAt: Date(),
            updatedAt: Date(),
            closedAt: nil,
            mergedAt: nil,
            head: GitHubBranchRef(ref: "feature", sha: "abc123", repo: nil),
            base: GitHubBranchRef(ref: "main", sha: "def456", repo: nil),
            isDraft: false,
            mergeable: true,
            additions: 10,
            deletions: 5,
            changedFiles: 3
        ),
        repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")),
        gitService: GitService(),
        gitHubService: GitHubService()
    )
    .frame(width: 800, height: 600)
}
