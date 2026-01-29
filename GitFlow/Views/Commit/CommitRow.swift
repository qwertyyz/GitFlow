import SwiftUI

/// Row displaying a single commit in the history list.
/// Supports drag and drop for cherry-pick, branch creation, and tag creation.
struct CommitRow: View {
    let commit: Commit

    /// Whether to enable drag and drop (default true).
    var enableDrag: Bool = true

    /// Optional callback for commit operations.
    var onCreateBranch: ((Commit) -> Void)?
    var onCreateTag: ((Commit) -> Void)?
    var onCherryPick: ((Commit) -> Void)?
    var onRevert: ((Commit) -> Void)?
    var onReset: ((Commit, ResetMode) -> Void)?
    var onCreatePatch: ((Commit) -> Void)?
    var onExportZip: ((Commit) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            // Author avatar
            AvatarView(
                name: commit.authorName,
                email: commit.authorEmail,
                size: 28
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                // Subject line
                Text(commit.subject)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Metadata
                HStack(spacing: 8) {
                    // Hash
                    Text(commit.shortHash)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)

                    // Author
                    Text(commit.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Date
                    Text(commit.authorDate.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Merge indicator
                if commit.isMerge {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.caption2)
                        Text("Merge commit")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .applyIf(enableDrag) { view in
            view.draggableCommit(commit)
        }
        .contextMenu {
            // Copy operations
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.hash, forType: .string)
            } label: {
                Label("Copy Commit Hash", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.subject, forType: .string)
            } label: {
                Label("Copy Commit Message", systemImage: "doc.on.doc")
            }

            Divider()

            // Create operations
            Button {
                onCreateBranch?(commit)
            } label: {
                Label("Create Branch From Here...", systemImage: "arrow.triangle.branch")
            }

            Button {
                onCreateTag?(commit)
            } label: {
                Label("Create Tag From Here...", systemImage: "tag")
            }

            Divider()

            // Apply operations
            Button {
                onCherryPick?(commit)
            } label: {
                Label("Cherry-pick Commit", systemImage: "arrow.right.circle")
            }

            Button {
                onRevert?(commit)
            } label: {
                Label("Revert Commit", systemImage: "arrow.uturn.backward")
            }

            Divider()

            // Reset operations
            Menu {
                Button("Soft (keep changes staged)") {
                    onReset?(commit, .soft)
                }
                Button("Mixed (keep changes unstaged)") {
                    onReset?(commit, .mixed)
                }
                Button("Hard (discard all changes)") {
                    onReset?(commit, .hard)
                }
            } label: {
                Label("Reset to This Commit", systemImage: "arrow.counterclockwise")
            }

            Divider()

            // Export operations
            Button {
                onCreatePatch?(commit)
            } label: {
                Label("Create Patch...", systemImage: "doc.badge.plus")
            }

            Button {
                onExportZip?(commit)
            } label: {
                Label("Export as ZIP...", systemImage: "arrow.down.doc")
            }

            Divider()

            // Show file history for this commit
            Button {
                // Show commit in detailed view
            } label: {
                Label("Show Commit Details", systemImage: "info.circle")
            }
        }
    }
}

/// Reset modes for git reset operations.
enum ResetMode: String {
    case soft = "--soft"
    case mixed = "--mixed"
    case hard = "--hard"
}

/// Compact commit row for inline display.
struct CompactCommitRow: View {
    let commit: Commit

    var body: some View {
        HStack(spacing: 8) {
            Text(commit.shortHash)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)

            Text(commit.subject)
                .lineLimit(1)

            Spacer()

            Text(commit.authorDate.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        CommitRow(commit: Commit(
            hash: "abc123def456789012345678901234567890abcd",
            subject: "Add new feature for user authentication",
            authorName: "John Doe",
            authorEmail: "john@example.com",
            authorDate: Date().addingTimeInterval(-3600)
        ))

        Divider()

        CommitRow(commit: Commit(
            hash: "def456abc789012345678901234567890abcdef12",
            subject: "Merge branch 'feature' into main",
            authorName: "Jane Smith",
            authorEmail: "jane@example.com",
            authorDate: Date().addingTimeInterval(-86400),
            parentHashes: ["abc123", "def456"]
        ))
    }
    .padding()
}
