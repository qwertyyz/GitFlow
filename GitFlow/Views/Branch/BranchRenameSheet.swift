import SwiftUI

/// Sheet for renaming a branch.
struct BranchRenameSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    let branch: Branch
    @Binding var isPresented: Bool

    @State private var newName: String = ""
    @State private var renameOnRemote: Bool = false
    @State private var isRenaming: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rename Branch")
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(branch.name)
                        .font(.body.monospaced())
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("New Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter new branch name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                }

                if branch.upstream != nil {
                    Toggle("Also rename on remote", isOn: $renameOnRemote)
                        .toggleStyle(.checkbox)

                    if renameOnRemote {
                        Text("This will delete the old branch on remote and push the renamed branch.")
                            .font(.caption)
                            .foregroundStyle(.orange)
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

                Button("Rename") {
                    rename()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValidName || isRenaming)
            }
            .padding()
        }
        .frame(width: 400)
        .onAppear {
            newName = branch.name
        }
    }

    private var isValidName: Bool {
        !newName.isEmpty && newName != branch.name && !newName.contains(" ")
    }

    private func rename() {
        isRenaming = true

        Task {
            if renameOnRemote, let remoteName = branch.remoteName ?? extractRemoteName(from: branch.upstream) {
                await viewModel.renameBranchOnRemote(
                    oldName: branch.name,
                    newName: newName,
                    remoteName: remoteName
                )
            } else {
                await viewModel.renameBranch(oldName: branch.name, newName: newName)
            }

            isRenaming = false
            if viewModel.error == nil {
                isPresented = false
            }
        }
    }

    private func extractRemoteName(from upstream: String?) -> String? {
        guard let upstream = upstream else { return nil }
        let parts = upstream.split(separator: "/")
        return parts.first.map(String.init)
    }
}

#Preview {
    BranchRenameSheet(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        branch: .local(name: "feature/test", commitHash: "abc123"),
        isPresented: .constant(true)
    )
}
