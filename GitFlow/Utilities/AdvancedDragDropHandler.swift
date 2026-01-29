import SwiftUI
import UniformTypeIdentifiers

/// Advanced drag and drop handler for complex Git operations.
/// Handles: drag to create PR, drag to squash, drag commit changes to working copy
@MainActor
class AdvancedDragDropHandler: ObservableObject {
    static let shared = AdvancedDragDropHandler()

    // MARK: - Drag Types

    enum DragItemType: String {
        case branch = "com.gitflow.branch"
        case commit = "com.gitflow.commit"
        case commitFile = "com.gitflow.commitFile"
        case stash = "com.gitflow.stash"
    }

    // MARK: - Drop Targets

    enum DropTarget: Equatable {
        case pullRequestSection
        case workingCopy
        case commit(hash: String)
        case branchesHeader
        case tagsHeader
        case remoteSection
    }

    // MARK: - Published State

    @Published var isDragging = false
    @Published var currentDragType: DragItemType?
    @Published var validDropTargets: Set<String> = []
    @Published var highlightedTarget: DropTarget?

    // Callbacks
    var onCreatePullRequest: ((String, String?) -> Void)?  // branch, targetBranch
    var onSquashCommits: ((String, String) -> Void)?  // commitHash1, commitHash2
    var onApplyCommitChanges: ((String, [String]) -> Void)?  // commitHash, filePaths
    var onCherryPick: ((String) -> Void)?  // commitHash

    private init() {}

    // MARK: - Drag to Create PR

    /// Create a draggable branch item for PR creation
    func createBranchDragItem(branchName: String, repositoryPath: String) -> NSItemProvider {
        let data = BranchDragData(branchName: branchName, repositoryPath: repositoryPath)
        let provider = NSItemProvider()

        if let encoded = try? JSONEncoder().encode(data) {
            provider.registerDataRepresentation(
                forTypeIdentifier: DragItemType.branch.rawValue,
                visibility: .all
            ) { completion in
                completion(encoded, nil)
                return nil
            }
        }

        return provider
    }

    /// Handle drop on Pull Requests section
    func handleDropOnPullRequests(providers: [NSItemProvider], targetBranch: String? = nil) async -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(DragItemType.branch.rawValue) {
                guard let data = await loadData(from: provider, type: DragItemType.branch.rawValue),
                      let branchData = try? JSONDecoder().decode(BranchDragData.self, from: data) else {
                    continue
                }

                onCreatePullRequest?(branchData.branchName, targetBranch)
                return true
            }
        }
        return false
    }

    // MARK: - Drag to Squash

    /// Create a draggable commit item
    func createCommitDragItem(
        commitHash: String,
        message: String,
        repositoryPath: String
    ) -> NSItemProvider {
        let data = CommitDragData(
            commitHash: commitHash,
            message: message,
            repositoryPath: repositoryPath
        )
        let provider = NSItemProvider()

        if let encoded = try? JSONEncoder().encode(data) {
            provider.registerDataRepresentation(
                forTypeIdentifier: DragItemType.commit.rawValue,
                visibility: .all
            ) { completion in
                completion(encoded, nil)
                return nil
            }
        }

        return provider
    }

    /// Handle drop on another commit (squash)
    func handleDropOnCommit(
        providers: [NSItemProvider],
        targetCommitHash: String
    ) async -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(DragItemType.commit.rawValue) {
                guard let data = await loadData(from: provider, type: DragItemType.commit.rawValue),
                      let commitData = try? JSONDecoder().decode(CommitDragData.self, from: data) else {
                    continue
                }

                // Don't squash commit onto itself
                guard commitData.commitHash != targetCommitHash else {
                    return false
                }

                onSquashCommits?(commitData.commitHash, targetCommitHash)
                return true
            }
        }
        return false
    }

    // MARK: - Drag Commit Changes to Working Copy

    /// Create a draggable item for files from a commit diff
    func createCommitFileDragItem(
        commitHash: String,
        filePaths: [String],
        repositoryPath: String
    ) -> NSItemProvider {
        let data = CommitFileDragData(
            commitHash: commitHash,
            filePaths: filePaths,
            repositoryPath: repositoryPath
        )
        let provider = NSItemProvider()

        if let encoded = try? JSONEncoder().encode(data) {
            provider.registerDataRepresentation(
                forTypeIdentifier: DragItemType.commitFile.rawValue,
                visibility: .all
            ) { completion in
                completion(encoded, nil)
                return nil
            }
        }

        return provider
    }

    /// Handle drop on Working Copy (apply commit changes)
    func handleDropOnWorkingCopy(providers: [NSItemProvider]) async -> Bool {
        for provider in providers {
            // Handle commit file drag
            if provider.hasItemConformingToTypeIdentifier(DragItemType.commitFile.rawValue) {
                guard let data = await loadData(from: provider, type: DragItemType.commitFile.rawValue),
                      let fileData = try? JSONDecoder().decode(CommitFileDragData.self, from: data) else {
                    continue
                }

                onApplyCommitChanges?(fileData.commitHash, fileData.filePaths)
                return true
            }

            // Handle full commit drag (cherry-pick)
            if provider.hasItemConformingToTypeIdentifier(DragItemType.commit.rawValue) {
                guard let data = await loadData(from: provider, type: DragItemType.commit.rawValue),
                      let commitData = try? JSONDecoder().decode(CommitDragData.self, from: data) else {
                    continue
                }

                onCherryPick?(commitData.commitHash)
                return true
            }
        }
        return false
    }

    // MARK: - Validation

    /// Check if a drag item can be dropped on a target
    func canDrop(providers: [NSItemProvider], on target: DropTarget) -> Bool {
        for provider in providers {
            switch target {
            case .pullRequestSection:
                if provider.hasItemConformingToTypeIdentifier(DragItemType.branch.rawValue) {
                    return true
                }

            case .workingCopy:
                if provider.hasItemConformingToTypeIdentifier(DragItemType.commit.rawValue) ||
                   provider.hasItemConformingToTypeIdentifier(DragItemType.commitFile.rawValue) ||
                   provider.hasItemConformingToTypeIdentifier(DragItemType.stash.rawValue) {
                    return true
                }

            case .commit:
                if provider.hasItemConformingToTypeIdentifier(DragItemType.commit.rawValue) {
                    return true
                }

            case .branchesHeader, .tagsHeader, .remoteSection:
                // Already handled by existing drag-drop
                return true
            }
        }
        return false
    }

    /// Update drag state
    func updateDragState(isDragging: Bool, type: DragItemType?) {
        self.isDragging = isDragging
        self.currentDragType = type

        if isDragging, let type = type {
            // Set valid drop targets based on drag type
            switch type {
            case .branch:
                validDropTargets = ["pullRequests", "remote"]
            case .commit:
                validDropTargets = ["workingCopy", "commit", "branches", "tags"]
            case .commitFile:
                validDropTargets = ["workingCopy"]
            case .stash:
                validDropTargets = ["workingCopy"]
            }
        } else {
            validDropTargets = []
        }
    }

    // MARK: - Helpers

    private func loadData(from provider: NSItemProvider, type: String) async -> Data? {
        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                continuation.resume(returning: data)
            }
        }
    }
}

// MARK: - Drag Data Models

struct BranchDragData: Codable {
    let branchName: String
    let repositoryPath: String
}

struct CommitDragData: Codable {
    let commitHash: String
    let message: String
    let repositoryPath: String
}

struct CommitFileDragData: Codable {
    let commitHash: String
    let filePaths: [String]
    let repositoryPath: String
}

// MARK: - Drop Delegate Views

/// Drop delegate for Pull Requests section
struct PullRequestDropDelegate: DropDelegate {
    let handler: AdvancedDragDropHandler
    let targetBranch: String?
    let onHighlight: (Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        handler.canDrop(providers: info.itemProviders(for: [.data]), on: .pullRequestSection)
    }

    func dropEntered(info: DropInfo) {
        onHighlight(true)
        handler.highlightedTarget = .pullRequestSection
    }

    func dropExited(info: DropInfo) {
        onHighlight(false)
        handler.highlightedTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        onHighlight(false)
        Task {
            await handler.handleDropOnPullRequests(
                providers: info.itemProviders(for: [.data]),
                targetBranch: targetBranch
            )
        }
        return true
    }
}

/// Drop delegate for commit squash
struct CommitSquashDropDelegate: DropDelegate {
    let handler: AdvancedDragDropHandler
    let targetCommitHash: String
    let onHighlight: (Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        handler.canDrop(providers: info.itemProviders(for: [.data]), on: .commit(hash: targetCommitHash))
    }

    func dropEntered(info: DropInfo) {
        onHighlight(true)
        handler.highlightedTarget = .commit(hash: targetCommitHash)
    }

    func dropExited(info: DropInfo) {
        onHighlight(false)
        handler.highlightedTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        onHighlight(false)
        Task {
            await handler.handleDropOnCommit(
                providers: info.itemProviders(for: [.data]),
                targetCommitHash: targetCommitHash
            )
        }
        return true
    }
}

/// Drop delegate for Working Copy
struct WorkingCopyDropDelegate: DropDelegate {
    let handler: AdvancedDragDropHandler
    let onHighlight: (Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        handler.canDrop(providers: info.itemProviders(for: [.data]), on: .workingCopy)
    }

    func dropEntered(info: DropInfo) {
        onHighlight(true)
        handler.highlightedTarget = .workingCopy
    }

    func dropExited(info: DropInfo) {
        onHighlight(false)
        handler.highlightedTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        onHighlight(false)
        Task {
            await handler.handleDropOnWorkingCopy(providers: info.itemProviders(for: [.data]))
        }
        return true
    }
}

// MARK: - View Modifiers

extension View {
    /// Make a branch draggable for PR creation
    func draggableBranch(name: String, repositoryPath: String) -> some View {
        self.onDrag {
            let handler = AdvancedDragDropHandler.shared
            handler.updateDragState(isDragging: true, type: .branch)
            return handler.createBranchDragItem(branchName: name, repositoryPath: repositoryPath)
        }
    }

    /// Make a commit draggable for squash/cherry-pick
    func draggableCommit(hash: String, message: String, repositoryPath: String) -> some View {
        self.onDrag {
            let handler = AdvancedDragDropHandler.shared
            handler.updateDragState(isDragging: true, type: .commit)
            return handler.createCommitDragItem(commitHash: hash, message: message, repositoryPath: repositoryPath)
        }
    }

    /// Make commit files draggable
    func draggableCommitFiles(commitHash: String, filePaths: [String], repositoryPath: String) -> some View {
        self.onDrag {
            let handler = AdvancedDragDropHandler.shared
            handler.updateDragState(isDragging: true, type: .commitFile)
            return handler.createCommitFileDragItem(commitHash: commitHash, filePaths: filePaths, repositoryPath: repositoryPath)
        }
    }

    /// Accept PR drop
    func onDropForPullRequest(
        targetBranch: String? = nil,
        isHighlighted: Binding<Bool>,
        action: @escaping (String, String?) -> Void
    ) -> some View {
        let handler = AdvancedDragDropHandler.shared
        handler.onCreatePullRequest = action

        return self.onDrop(of: [.data], delegate: PullRequestDropDelegate(
            handler: handler,
            targetBranch: targetBranch,
            onHighlight: { isHighlighted.wrappedValue = $0 }
        ))
    }

    /// Accept squash drop
    func onDropForSquash(
        targetCommitHash: String,
        isHighlighted: Binding<Bool>,
        action: @escaping (String, String) -> Void
    ) -> some View {
        let handler = AdvancedDragDropHandler.shared
        handler.onSquashCommits = action

        return self.onDrop(of: [.data], delegate: CommitSquashDropDelegate(
            handler: handler,
            targetCommitHash: targetCommitHash,
            onHighlight: { isHighlighted.wrappedValue = $0 }
        ))
    }

    /// Accept working copy drop
    func onDropForWorkingCopy(
        isHighlighted: Binding<Bool>,
        onApplyChanges: @escaping (String, [String]) -> Void,
        onCherryPick: @escaping (String) -> Void
    ) -> some View {
        let handler = AdvancedDragDropHandler.shared
        handler.onApplyCommitChanges = onApplyChanges
        handler.onCherryPick = onCherryPick

        return self.onDrop(of: [.data], delegate: WorkingCopyDropDelegate(
            handler: handler,
            onHighlight: { isHighlighted.wrappedValue = $0 }
        ))
    }
}

// MARK: - Create PR Sheet (triggered by drag)

struct CreatePRFromDragSheet: View {
    let sourceBranch: String
    let suggestedTargetBranch: String?
    let availableBranches: [String]
    let onClose: () -> Void
    let onCreate: (String, String, String, String?) -> Void

    @State private var targetBranch: String = ""
    @State private var title: String = ""
    @State private var prBody: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Pull Request")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onClose() }
            }
            .padding()

            Divider()

            Form {
                Section("Branches") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Label(sourceBranch, systemImage: "arrow.triangle.branch")
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading) {
                            Text("Into")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $targetBranch) {
                                ForEach(availableBranches, id: \.self) { branch in
                                    Text(branch).tag(branch)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description (optional)", text: $prBody, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Create Pull Request") {
                    onCreate(sourceBranch, targetBranch, title, prBody.isEmpty ? nil : prBody)
                }
                .buttonStyle(.borderedProminent)
                .disabled(targetBranch.isEmpty || title.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            targetBranch = suggestedTargetBranch ?? availableBranches.first ?? ""
            title = "Merge \(sourceBranch)"
        }
    }
}

// MARK: - Squash Confirmation Sheet

struct SquashConfirmationSheet: View {
    let sourceCommit: String
    let targetCommit: String
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Squash Commits")
                .font(.title2)
                .fontWeight(.bold)

            Text("This will squash commit \(String(sourceCommit.prefix(7))) into \(String(targetCommit.prefix(7))).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(String(sourceCommit.prefix(7)))
                        .font(.caption.monospaced())
                    Text("→ will be squashed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(String(targetCommit.prefix(7)))
                        .font(.caption.monospaced())
                    Text("→ target commit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Button("Cancel") { onClose() }
                    .keyboardShortcut(.cancelAction)

                Button("Squash") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}

#Preview("Create PR Sheet") {
    CreatePRFromDragSheet(
        sourceBranch: "feature/new-feature",
        suggestedTargetBranch: "main",
        availableBranches: ["main", "develop", "release/1.0"],
        onClose: {},
        onCreate: { _, _, _, _ in }
    )
}

#Preview("Squash Confirmation") {
    SquashConfirmationSheet(
        sourceCommit: "abc123def456",
        targetCommit: "789xyz012abc",
        onClose: {},
        onConfirm: {}
    )
}
