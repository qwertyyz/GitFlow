import SwiftUI

/// View for safely deleting a repository from disk.
struct DeleteRepositoryView: View {
    let repository: Repository
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var confirmText: String = ""
    @State private var deleteFromDisk: Bool = false
    @State private var isDeleting: Bool = false
    @State private var error: String?

    private var expectedConfirmText: String {
        repository.name
    }

    private var canDelete: Bool {
        confirmText == expectedConfirmText && !isDeleting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with warning
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)

                Text("Delete Repository")
                    .font(.title)
                    .fontWeight(.bold)

                Text("This action cannot be undone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))

            Divider()

            // Repository info
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repository")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(repository.name)
                                .font(.headline)
                            Text(repository.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }

                // Delete options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Delete Options")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle(isOn: $deleteFromDisk) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delete from disk")
                                .font(.body)
                            Text("Permanently remove all files. This cannot be recovered!")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .toggleStyle(.checkbox)

                    if !deleteFromDisk {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("The repository will only be removed from GitFlow's list. Files will remain on disk.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // Confirmation
                if deleteFromDisk {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type '\(expectedConfirmText)' to confirm")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Repository name", text: $confirmText)
                            .textFieldStyle(.roundedBorder)

                        if !confirmText.isEmpty && confirmText != expectedConfirmText {
                            Text("Name does not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Error message
                if let error = error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isDeleting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }

                Button(deleteFromDisk ? "Delete Permanently" : "Remove from List") {
                    performDelete()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(deleteFromDisk && !canDelete)
            }
            .padding()
        }
        .frame(width: 450)
    }

    private func performDelete() {
        isDeleting = true
        error = nil

        Task {
            do {
                if deleteFromDisk {
                    // Move to trash instead of permanent delete for safety
                    try await moveToTrash()
                }

                // Remove from app's repository list
                await MainActor.run {
                    onDelete()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isDeleting = false
                }
            }
        }
    }

    private func moveToTrash() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: URL(fileURLWithPath: repository.path), resultingItemURL: &trashedURL)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Delete Repository Confirmation Sheet

struct DeleteRepositorySheet: View {
    @Binding var isPresented: Bool
    let repository: Repository
    let onDelete: () -> Void

    var body: some View {
        DeleteRepositoryView(
            repository: repository,
            onDelete: {
                onDelete()
                isPresented = false
            },
            onCancel: {
                isPresented = false
            }
        )
    }
}

// MARK: - Repository Manager Extension

extension RepositoryManagerViewModel {
    func deleteRepository(_ repository: Repository, fromDisk: Bool) async throws {
        if fromDisk {
            // Move to trash
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: repository.path), resultingItemURL: &trashedURL)
        }

        // Remove from list
        // This would update the repository list
    }
}

#Preview {
    DeleteRepositoryView(
        repository: Repository(rootURL: URL(fileURLWithPath: "/Users/test/Projects/MyProject")),
        onDelete: {},
        onCancel: {}
    )
}
