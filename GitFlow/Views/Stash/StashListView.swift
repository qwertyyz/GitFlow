import SwiftUI

/// View displaying all stashes.
struct StashListView: View {
    @ObservedObject var viewModel: StashViewModel

    @State private var showCreateStash: Bool = false
    @State private var stashToDelete: Stash?
    @State private var stashToRename: Stash?
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Stashes")
                    .font(.headline)

                Spacer()

                Button(action: { showCreateStash = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new stash")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Stash list
            if viewModel.stashes.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Stashes",
                    systemImage: "tray",
                    description: "Stash your changes to save them for later"
                )
            } else {
                List(viewModel.stashes, selection: $viewModel.selectedStash) { stash in
                    StashRow(stash: stash)
                        .tag(stash)
                        .contextMenu {
                            Button("Apply") {
                                Task { await viewModel.applyStash(stash) }
                            }
                            Button("Pop") {
                                Task { await viewModel.popStash(stash) }
                            }
                            Divider()
                            Button("Rename...") {
                                stashToRename = stash
                            }
                            Divider()
                            Button("Drop", role: .destructive) {
                                stashToDelete = stash
                            }
                        }
                }
                .listStyle(.inset)
            }

            // Footer with actions
            if viewModel.hasStashes {
                Divider()
                HStack {
                    Button("Clear All", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)

                    Spacer()

                    Text("\(viewModel.stashCount) stash(es)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showCreateStash) {
            CreateStashSheet(viewModel: viewModel, isPresented: $showCreateStash)
        }
        .sheet(item: $stashToRename) { stash in
            RenameStashSheet(viewModel: viewModel, stash: stash, isPresented: .init(
                get: { stashToRename != nil },
                set: { if !$0 { stashToRename = nil } }
            ))
        }
        .confirmationDialog(
            "Drop Stash",
            isPresented: .init(
                get: { stashToDelete != nil },
                set: { if !$0 { stashToDelete = nil } }
            ),
            presenting: stashToDelete
        ) { stash in
            Button("Drop", role: .destructive) {
                Task { await viewModel.dropStash(stash) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { stash in
            Text("Are you sure you want to drop '\(stash.message)'? This cannot be undone.")
        }
        .confirmationDialog(
            "Clear All Stashes",
            isPresented: $showClearConfirmation
        ) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel.clearAllStashes() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear all \(viewModel.stashCount) stashes? This cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

/// Row displaying a single stash.
/// Supports drag and drop for applying stashes.
struct StashRow: View {
    let stash: Stash

    /// Whether to enable drag and drop (default true).
    var enableDrag: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stash.refName)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)

                if let branch = stash.branch {
                    Text("on \(branch)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(stash.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(stash.message)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .applyIf(enableDrag) { view in
            view.draggableStash(stash)
        }
    }
}

/// Sheet for creating a new stash.
struct CreateStashSheet: View {
    @ObservedObject var viewModel: StashViewModel
    @Binding var isPresented: Bool

    @State private var message: String = ""
    @State private var includeUntracked: Bool = false
    @State private var includeIgnored: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Stash")
                .font(.headline)

            Form {
                TextField("Message (optional)", text: $message)
                    .textFieldStyle(.roundedBorder)

                Toggle("Include untracked files", isOn: $includeUntracked)
                    .disabled(includeIgnored) // Ignored implies untracked

                Toggle("Include ignored files", isOn: $includeIgnored)
                    .onChange(of: includeIgnored) { newValue in
                        if newValue {
                            includeUntracked = true
                        }
                    }

                if includeIgnored {
                    Text("Warning: This will include all ignored files (e.g., build artifacts, node_modules)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Stash") {
                    Task {
                        await viewModel.createStash(
                            message: message.isEmpty ? nil : message,
                            includeUntracked: includeUntracked,
                            includeIgnored: includeIgnored
                        )
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

/// Sheet for renaming a stash.
struct RenameStashSheet: View {
    @ObservedObject var viewModel: StashViewModel
    let stash: Stash
    @Binding var isPresented: Bool

    @State private var newMessage: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Stash")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current message:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(stash.message)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)

                Text("New message:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Enter new stash message", text: $newMessage)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Rename") {
                    Task {
                        await viewModel.renameStash(stash, to: newMessage)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(newMessage.isEmpty || viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            newMessage = stash.message
        }
    }
}

#Preview {
    StashListView(
        viewModel: StashViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 300, height: 400)
}
