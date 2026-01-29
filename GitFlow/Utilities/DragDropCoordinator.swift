import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag Item Types

/// Uniform Type Identifiers for drag and drop operations.
extension UTType {
    /// UTType for dragging a Git branch.
    static let gitBranch = UTType(exportedAs: "com.gitflow.branch")

    /// UTType for dragging a Git commit.
    static let gitCommit = UTType(exportedAs: "com.gitflow.commit")

    /// UTType for dragging a Git stash.
    static let gitStash = UTType(exportedAs: "com.gitflow.stash")

    /// UTType for dragging a Git tag.
    static let gitTag = UTType(exportedAs: "com.gitflow.tag")
}

// MARK: - Draggable Data Models

/// Represents a draggable branch.
struct DraggableBranch: Codable, Transferable {
    let name: String
    let isRemote: Bool
    let remoteName: String?
    let commitHash: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DraggableBranch.self, contentType: .gitBranch)
    }

    init(from branch: Branch) {
        self.name = branch.name
        self.isRemote = branch.isRemote
        self.remoteName = branch.remoteName
        self.commitHash = branch.commitHash
    }
}

/// Represents a draggable commit.
struct DraggableCommit: Codable, Transferable, Identifiable {
    let hash: String
    let shortHash: String
    let subject: String
    let authorName: String

    var id: String { hash }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DraggableCommit.self, contentType: .gitCommit)
    }

    init(from commit: Commit) {
        self.hash = commit.hash
        self.shortHash = commit.shortHash
        self.subject = commit.subject
        self.authorName = commit.authorName
    }
}

/// Represents a draggable stash.
struct DraggableStash: Codable, Transferable {
    let refName: String
    let index: Int
    let message: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DraggableStash.self, contentType: .gitStash)
    }

    init(from stash: Stash) {
        self.refName = stash.refName
        self.index = stash.index
        self.message = stash.message
    }
}

/// Represents a draggable tag.
struct DraggableTag: Codable, Transferable {
    let name: String
    let commitHash: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DraggableTag.self, contentType: .gitTag)
    }

    init(from tag: Tag) {
        self.name = tag.name
        self.commitHash = tag.commitHash
    }
}

// MARK: - Drop Target Types

/// Defines the types of drop targets in the app.
enum DropTargetType: Hashable {
    /// The current branch (HEAD) - accepts branches for merge/rebase
    case currentBranch

    /// The working copy - accepts commits for cherry-pick, stashes for apply
    case workingCopy

    /// The branches section header - accepts commits to create branch
    case branchesHeader

    /// The tags section header - accepts commits to create tag
    case tagsHeader

    /// A remote section - accepts branches to push
    case remote(name: String)

    /// The remotes section header - accepts branches to publish
    case remotesSection

    /// A specific branch - accepts branches for merge into that branch
    case branch(name: String)

    /// Pull requests section - accepts branches to create PR
    case pullRequests
}

// MARK: - Drop Action Types

/// The action to perform when a drop occurs.
enum DropAction: Hashable {
    case merge(sourceBranch: String, targetBranch: String)
    case rebase(sourceBranch: String, ontoBranch: String)
    case cherryPick(commitHash: String)
    case createBranch(fromCommit: String)
    case createTag(fromCommit: String)
    case applyStash(refName: String)
    case pushBranch(branchName: String, remoteName: String)
    case createPullRequest(branchName: String)

    var description: String {
        switch self {
        case .merge(let source, let target):
            return "Merge \(source) into \(target)"
        case .rebase(let source, let onto):
            return "Rebase \(source) onto \(onto)"
        case .cherryPick(let hash):
            return "Cherry-pick \(String(hash.prefix(7)))"
        case .createBranch(let hash):
            return "Create branch from \(String(hash.prefix(7)))"
        case .createTag(let hash):
            return "Create tag at \(String(hash.prefix(7)))"
        case .applyStash(let ref):
            return "Apply \(ref)"
        case .pushBranch(let branch, let remote):
            return "Push \(branch) to \(remote)"
        case .createPullRequest(let branch):
            return "Create PR for \(branch)"
        }
    }
}

// MARK: - Drag Drop Coordinator

/// Coordinates drag and drop operations across the app.
@MainActor
final class DragDropCoordinator: ObservableObject {
    /// The repository view model for performing operations.
    weak var repositoryViewModel: RepositoryViewModel?

    /// Currently active drop action (for visual feedback).
    @Published var pendingDropAction: DropAction?

    /// Whether the option key is held (for rebase instead of merge).
    @Published var isOptionKeyPressed: Bool = false

    init() {
        setupKeyMonitor()
    }

    private func setupKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.isOptionKeyPressed = event.modifierFlags.contains(.option)
            return event
        }
    }

    // MARK: - Drop Validation

    /// Checks if a branch can be dropped on a target.
    func canDropBranch(_ branch: DraggableBranch, on target: DropTargetType) -> Bool {
        switch target {
        case .currentBranch:
            // Can merge/rebase any branch onto current (except current itself)
            return true
        case .branch(let targetName):
            // Can merge onto a different branch
            return branch.name != targetName
        case .remote:
            // Can push local branches to remotes
            return !branch.isRemote
        case .pullRequests:
            // Can create PR from local branches
            return !branch.isRemote
        default:
            return false
        }
    }

    /// Checks if a commit can be dropped on a target.
    func canDropCommit(_ commit: DraggableCommit, on target: DropTargetType) -> Bool {
        switch target {
        case .workingCopy:
            return true // Cherry-pick
        case .branchesHeader:
            return true // Create branch
        case .tagsHeader:
            return true // Create tag
        default:
            return false
        }
    }

    /// Checks if a stash can be dropped on a target.
    func canDropStash(_ stash: DraggableStash, on target: DropTargetType) -> Bool {
        switch target {
        case .workingCopy:
            return true // Apply stash
        default:
            return false
        }
    }

    // MARK: - Drop Handling

    /// Handles dropping a branch on a target.
    func handleBranchDrop(_ branch: DraggableBranch, on target: DropTargetType) async -> Bool {
        guard let viewModel = repositoryViewModel else { return false }

        switch target {
        case .currentBranch:
            if isOptionKeyPressed {
                // Rebase current branch onto the dropped branch
                await viewModel.branchViewModel.rebase(ontoBranch: branch.name)
            } else {
                // Merge the dropped branch into current
                await viewModel.branchViewModel.merge(branchName: branch.name)
            }
            await viewModel.refresh()
            return true

        case .branch(let targetName):
            // First checkout the target, then merge
            await viewModel.checkoutBranch(targetName)
            await viewModel.branchViewModel.merge(branchName: branch.name)
            await viewModel.refresh()
            return true

        case .remote(let remoteName):
            // Push the branch to the remote
            await viewModel.remoteViewModel.push(
                remote: remoteName,
                branch: branch.name,
                setUpstream: true
            )
            return true

        case .pullRequests:
            // TODO: Trigger create PR sheet
            return false

        default:
            return false
        }
    }

    /// Handles dropping a commit on a target.
    func handleCommitDrop(_ commit: DraggableCommit, on target: DropTargetType) async -> Bool {
        guard let viewModel = repositoryViewModel else { return false }

        switch target {
        case .workingCopy:
            // Cherry-pick the commit
            do {
                try await viewModel.gitService.cherryPick(commitHash: commit.hash, in: viewModel.repository)
                await viewModel.refresh()
                return true
            } catch {
                return false
            }

        case .branchesHeader:
            // Will need to show a sheet for branch name
            // For now, return false and let the UI handle this
            return false

        case .tagsHeader:
            // Will need to show a sheet for tag name
            return false

        default:
            return false
        }
    }

    /// Handles dropping a stash on a target.
    func handleStashDrop(_ stash: DraggableStash, on target: DropTargetType) async -> Bool {
        guard let viewModel = repositoryViewModel else { return false }

        switch target {
        case .workingCopy:
            // Apply the stash
            await viewModel.stashViewModel.applyStash(
                Stash(index: stash.index, commitHash: "", message: stash.message, date: Date())
            )
            return true

        default:
            return false
        }
    }

    // MARK: - Action Description

    /// Gets a description of what would happen if a branch is dropped on a target.
    func dropDescription(for branch: DraggableBranch, on target: DropTargetType) -> String? {
        guard canDropBranch(branch, on: target) else { return nil }

        switch target {
        case .currentBranch:
            if isOptionKeyPressed {
                return "Rebase onto \(branch.name)"
            } else {
                return "Merge \(branch.name)"
            }
        case .branch(let targetName):
            return "Merge \(branch.name) into \(targetName)"
        case .remote(let remoteName):
            return "Push \(branch.name) to \(remoteName)"
        case .pullRequests:
            return "Create PR for \(branch.name)"
        default:
            return nil
        }
    }

    /// Gets a description of what would happen if a commit is dropped on a target.
    func dropDescription(for commit: DraggableCommit, on target: DropTargetType) -> String? {
        guard canDropCommit(commit, on: target) else { return nil }

        switch target {
        case .workingCopy:
            return "Cherry-pick \(commit.shortHash)"
        case .branchesHeader:
            return "Create branch from \(commit.shortHash)"
        case .tagsHeader:
            return "Create tag at \(commit.shortHash)"
        default:
            return nil
        }
    }

    /// Gets a description of what would happen if a stash is dropped on a target.
    func dropDescription(for stash: DraggableStash, on target: DropTargetType) -> String? {
        guard canDropStash(stash, on: target) else { return nil }

        switch target {
        case .workingCopy:
            return "Apply \(stash.refName)"
        default:
            return nil
        }
    }
}

// MARK: - View Extensions for Drag and Drop

extension View {
    /// Makes a branch row draggable.
    func draggableBranch(_ branch: Branch) -> some View {
        self.draggable(DraggableBranch(from: branch)) {
            // Drag preview
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                Text(branch.name)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }

    /// Makes a commit row draggable.
    func draggableCommit(_ commit: Commit) -> some View {
        self.draggable(DraggableCommit(from: commit)) {
            // Drag preview
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                Text(commit.shortHash)
                    .fontDesign(.monospaced)
                Text(commit.subject)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(8)
            .frame(maxWidth: 300)
        }
    }

    /// Makes a stash row draggable.
    func draggableStash(_ stash: Stash) -> some View {
        self.draggable(DraggableStash(from: stash)) {
            // Drag preview
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down")
                Text(stash.refName)
                    .fontDesign(.monospaced)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DSColors.warning.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

// MARK: - Drop Target Modifier

/// A view modifier that makes a view a drop target.
struct DropTargetModifier: ViewModifier {
    let targetType: DropTargetType
    @ObservedObject var coordinator: DragDropCoordinator
    @State private var isTargeted: Bool = false

    // Callbacks for when we need UI interaction (sheets)
    var onBranchDropNeedsUI: ((DraggableBranch) -> Void)?
    var onCommitDropNeedsUI: ((DraggableCommit) -> Void)?
    var onStashDropNeedsUI: ((DraggableStash) -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: DSRadius.md)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(DSRadius.md)
                }
            }
            .dropDestination(for: DraggableBranch.self) { items, _ in
                guard let branch = items.first else { return false }
                if coordinator.canDropBranch(branch, on: targetType) {
                    Task {
                        _ = await coordinator.handleBranchDrop(branch, on: targetType)
                    }
                    return true
                }
                return false
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .dropDestination(for: DraggableCommit.self) { items, _ in
                guard let commit = items.first else { return false }
                if coordinator.canDropCommit(commit, on: targetType) {
                    // For branch/tag creation, we need UI
                    if targetType == .branchesHeader || targetType == .tagsHeader {
                        onCommitDropNeedsUI?(commit)
                        return true
                    }
                    Task {
                        _ = await coordinator.handleCommitDrop(commit, on: targetType)
                    }
                    return true
                }
                return false
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .dropDestination(for: DraggableStash.self) { items, _ in
                guard let stash = items.first else { return false }
                if coordinator.canDropStash(stash, on: targetType) {
                    Task {
                        _ = await coordinator.handleStashDrop(stash, on: targetType)
                    }
                    return true
                }
                return false
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}

extension View {
    /// Makes this view a drop target.
    func dropTarget(
        _ targetType: DropTargetType,
        coordinator: DragDropCoordinator,
        onBranchDropNeedsUI: ((DraggableBranch) -> Void)? = nil,
        onCommitDropNeedsUI: ((DraggableCommit) -> Void)? = nil,
        onStashDropNeedsUI: ((DraggableStash) -> Void)? = nil
    ) -> some View {
        self.modifier(DropTargetModifier(
            targetType: targetType,
            coordinator: coordinator,
            onBranchDropNeedsUI: onBranchDropNeedsUI,
            onCommitDropNeedsUI: onCommitDropNeedsUI,
            onStashDropNeedsUI: onStashDropNeedsUI
        ))
    }
}
