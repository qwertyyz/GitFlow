import SwiftUI

/// View for managing Git worktrees.
struct WorktreeView: View {
    @StateObject private var viewModel = WorktreeViewModel()
    let repository: Repository

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Content
            if viewModel.isLoading && viewModel.worktrees.isEmpty {
                loadingView
            } else if viewModel.worktrees.isEmpty {
                emptyView
            } else {
                worktreeList
            }
        }
        .frame(minWidth: 300)
        .onAppear {
            viewModel.setRepository(repository)
        }
        .sheet(isPresented: $viewModel.showingCreateSheet) {
            CreateWorktreeSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingLockSheet) {
            LockWorktreeSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingMoveSheet) {
            MoveWorktreeSheet(viewModel: viewModel)
        }
        .alert("Remove Worktree", isPresented: $viewModel.showingRemoveConfirmation) {
            removeConfirmationAlert
        } message: {
            if let worktree = viewModel.worktreeToRemove {
                Text("Are you sure you want to remove the worktree at '\(worktree.name)'?")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Worktrees")
                .font(.headline)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
            }

            Button {
                Task {
                    await viewModel.loadWorktrees()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh worktrees")

            Menu {
                Button("Prune Stale Worktrees") {
                    Task {
                        await viewModel.pruneWorktrees()
                    }
                }
                Button("Repair Worktrees") {
                    Task {
                        await viewModel.repairWorktrees()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                viewModel.showCreateSheet()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add worktree")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Content Views

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading worktrees...")
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Worktrees")
                .font(.headline)
            Text("Create a worktree to work on multiple branches simultaneously.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Worktree") {
                viewModel.showCreateSheet()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var worktreeList: some View {
        List(viewModel.worktrees, selection: $viewModel.selectedWorktree) { worktree in
            WorktreeRow(worktree: worktree)
                .tag(worktree)
                .contextMenu {
                    worktreeContextMenu(for: worktree)
                }
        }
        .listStyle(.inset)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func worktreeContextMenu(for worktree: Worktree) -> some View {
        Button("Open in Finder") {
            viewModel.openInFinder(worktree)
        }

        Button("Open in Terminal") {
            viewModel.openInTerminal(worktree)
        }

        Divider()

        if worktree.isLocked {
            Button("Unlock") {
                Task {
                    await viewModel.unlockWorktree(worktree)
                }
            }
        } else {
            Button("Lock...") {
                viewModel.showLockSheet(for: worktree)
            }
        }

        if !worktree.isMain {
            Button("Move...") {
                viewModel.showMoveSheet(for: worktree)
            }

            Divider()

            Button("Remove", role: .destructive) {
                viewModel.showRemoveConfirmation(for: worktree)
            }
        }
    }

    // MARK: - Alert Content

    @ViewBuilder
    private var removeConfirmationAlert: some View {
        Button("Cancel", role: .cancel) {
            viewModel.showingRemoveConfirmation = false
        }

        Button("Remove", role: .destructive) {
            Task {
                await viewModel.removeWorktree()
            }
        }

        if viewModel.worktreeToRemove?.isLocked == true {
            Button("Force Remove", role: .destructive) {
                viewModel.forceRemove = true
                Task {
                    await viewModel.removeWorktree()
                }
            }
        }
    }
}

// MARK: - Worktree Row

struct WorktreeRow: View {
    let worktree: Worktree

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 32, height: 32)

                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(worktree.name)
                        .font(.body)
                        .fontWeight(.medium)

                    if worktree.isMain {
                        Text("Main")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    if worktree.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if worktree.isPrunable {
                        Text("Prunable")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }

                Text(worktree.displayBranch)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(worktree.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Short hash
            if let shortHead = worktree.shortHead {
                Text(shortHead)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if worktree.isMain {
            return "house.fill"
        } else if worktree.isDetached {
            return "tag"
        } else {
            return "folder"
        }
    }

    private var iconColor: Color {
        if worktree.isMain {
            return .blue
        } else if worktree.isPrunable {
            return .red
        } else if worktree.isDetached {
            return .orange
        } else {
            return .green
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.15)
    }
}

// MARK: - Create Worktree Sheet

struct CreateWorktreeSheet: View {
    @ObservedObject var viewModel: WorktreeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Worktree")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Location") {
                    HStack {
                        TextField("Path", text: $viewModel.newWorktreePath)
                        Button("Browse...") {
                            browseForPath()
                        }
                    }
                }

                Section("Branch") {
                    Picker("Mode", selection: $viewModel.createNewBranch) {
                        Text("Create new branch").tag(true)
                        Text("Use existing branch").tag(false)
                    }
                    .pickerStyle(.radioGroup)

                    TextField(viewModel.createNewBranch ? "New branch name" : "Existing branch name",
                             text: $viewModel.newWorktreeBranch)

                    if viewModel.createNewBranch {
                        TextField("Base branch (optional)", text: $viewModel.baseBranch)
                    }

                    Toggle("Detach HEAD", isOn: $viewModel.detachHead)
                }

                Section("Options") {
                    Toggle("Lock worktree after creation", isOn: $viewModel.lockAfterCreate)

                    if viewModel.lockAfterCreate {
                        TextField("Lock reason (optional)", text: $viewModel.lockReason)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add Worktree") {
                    Task {
                        await viewModel.createWorktree()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newWorktreePath.isEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    private func browseForPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a location for the new worktree"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.newWorktreePath = url.path
        }
    }
}

// MARK: - Lock Worktree Sheet

struct LockWorktreeSheet: View {
    @ObservedObject var viewModel: WorktreeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Lock Worktree")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                if let worktree = viewModel.worktreeToLock {
                    Text("Lock the worktree at '\(worktree.name)' to prevent accidental removal.")
                        .foregroundColor(.secondary)

                    TextField("Reason (optional)", text: $viewModel.lockReasonInput)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()

            Spacer()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Lock") {
                    Task {
                        await viewModel.lockWorktree()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}

// MARK: - Move Worktree Sheet

struct MoveWorktreeSheet: View {
    @ObservedObject var viewModel: WorktreeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Move Worktree")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                if let worktree = viewModel.worktreeToMove {
                    Text("Move '\(worktree.name)' to a new location.")
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("New path", text: $viewModel.newPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            browseForPath()
                        }
                    }

                    Toggle("Force move", isOn: $viewModel.forceMove)
                        .help("Force move even if the worktree is locked")
                }
            }
            .padding()

            Spacer()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Move") {
                    Task {
                        await viewModel.moveWorktree()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newPath.isEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .frame(width: 450, height: 220)
    }

    private func browseForPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a new location for the worktree"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.newPath = url.path
        }
    }
}

// MARK: - Preview

#Preview {
    WorktreeView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
        .frame(width: 400, height: 500)
}
