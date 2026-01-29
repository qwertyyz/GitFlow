import SwiftUI

/// View for browsing files at a specific commit (tree mode).
struct CommitTreeView: View {
    let commit: Commit
    let repository: Repository
    let gitService: GitService

    @State private var entries: [TreeEntry] = []
    @State private var currentPath: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedEntry: TreeEntry?
    @State private var fileContent: String?

    var body: some View {
        HSplitView {
            // File tree
            VStack(spacing: 0) {
                // Breadcrumb navigation
                breadcrumb

                Divider()

                // File list
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = error {
                    Spacer()
                    Text(error)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    fileList
                }
            }
            .frame(minWidth: 250)

            // File preview
            VStack(spacing: 0) {
                if let entry = selectedEntry, !entry.isDirectory {
                    filePreview(for: entry)
                } else {
                    emptyPreview
                }
            }
            .frame(minWidth: 300)
        }
        .onAppear {
            loadTree()
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    navigateToRoot()
                } label: {
                    Image(systemName: "house")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                ForEach(Array(currentPath.enumerated()), id: \.offset) { index, component in
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Button {
                            navigateTo(index: index)
                        } label: {
                            Text(component)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(index == currentPath.count - 1 ? .primary : .accentColor)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - File List

    private var fileList: some View {
        List(entries, selection: $selectedEntry) { entry in
            FileEntryRow(entry: entry)
                .tag(entry)
                .onTapGesture(count: 2) {
                    if entry.isDirectory {
                        navigateInto(entry)
                    }
                }
        }
        .listStyle(.inset)
    }

    // MARK: - File Preview

    @ViewBuilder
    private func filePreview(for entry: TreeEntry) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: iconForEntry(entry))
                    .foregroundColor(.secondary)
                Text(entry.name)
                    .font(.headline)
                Spacer()
                Text(entry.hash.prefix(7))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Content
            if let content = fileContent {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
            }
        }
        .onChange(of: selectedEntry) { newEntry in
            if let entry = newEntry, !entry.isDirectory {
                loadFileContent(entry)
            } else {
                fileContent = nil
            }
        }
    }

    private var emptyPreview: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a file to preview")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Navigation

    private func navigateToRoot() {
        currentPath = []
        loadTree()
    }

    private func navigateTo(index: Int) {
        currentPath = Array(currentPath.prefix(index + 1))
        loadTree()
    }

    private func navigateInto(_ entry: TreeEntry) {
        guard entry.isDirectory else { return }
        currentPath.append(entry.name)
        loadTree()
    }

    // MARK: - Loading

    private func loadTree() {
        isLoading = true
        error = nil
        selectedEntry = nil
        fileContent = nil

        let path = currentPath.joined(separator: "/")

        Task {
            do {
                let command = ListTreeCommand(ref: commit.hash, path: path.isEmpty ? nil : path)
                let output = try await gitService.executor.executeOrThrow(
                    arguments: command.arguments,
                    workingDirectory: repository.rootURL
                )
                entries = try command.parse(output: output)
            } catch {
                self.error = "Failed to load tree: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func loadFileContent(_ entry: TreeEntry) {
        fileContent = nil

        Task {
            do {
                let command = ShowFileAtRefCommand(ref: commit.hash, path: entry.path)
                let output = try await gitService.executor.executeOrThrow(
                    arguments: command.arguments,
                    workingDirectory: repository.rootURL
                )
                fileContent = try command.parse(output: output)
            } catch {
                fileContent = "Failed to load file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func iconForEntry(_ entry: TreeEntry) -> String {
        switch entry.type {
        case .tree:
            return "folder.fill"
        case .commit:
            return "link"
        case .blob:
            return iconForFileName(entry.name)
        }
    }

    private func iconForFileName(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return "swift"
        case "js", "ts", "jsx", "tsx":
            return "doc.text"
        case "json":
            return "curlybraces"
        case "md", "txt":
            return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "zip", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc"
        }
    }
}

// MARK: - File Entry Row

private struct FileEntryRow: View {
    let entry: TreeEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(entry.name)
                .lineLimit(1)

            Spacer()

            if !entry.isDirectory {
                Text(entry.hash.prefix(7))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch entry.type {
        case .tree:
            return "folder.fill"
        case .commit:
            return "link"
        case .blob:
            return "doc"
        }
    }

    private var iconColor: Color {
        switch entry.type {
        case .tree:
            return .blue
        case .commit:
            return .purple
        case .blob:
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    CommitTreeView(
        commit: Commit(
            hash: "abc123",
            shortHash: "abc123",
            subject: "Test commit",
            body: "",
            authorName: "Test Author",
            authorEmail: "test@example.com",
            authorDate: Date(),
            parentHashes: []
        ),
        repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")),
        gitService: GitService()
    )
    .frame(width: 800, height: 600)
}
