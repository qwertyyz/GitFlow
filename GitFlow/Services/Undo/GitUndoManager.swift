import SwiftUI
import Foundation

/// Manages undo/redo operations for Git actions.
/// Tracks operations and provides the ability to reverse them.
@MainActor
class GitUndoManager: ObservableObject {
    static let shared = GitUndoManager()

    @Published var undoStack: [GitUndoableAction] = []
    @Published var redoStack: [GitUndoableAction] = []
    @Published var isProcessing: Bool = false
    @Published var lastActionMessage: String?
    @Published var showingUndoToast: Bool = false

    private let maxStackSize = 50

    private init() {}

    // MARK: - Stack Management

    var canUndo: Bool {
        !undoStack.isEmpty && !isProcessing
    }

    var canRedo: Bool {
        !redoStack.isEmpty && !isProcessing
    }

    var undoActionName: String? {
        undoStack.last?.description
    }

    var redoActionName: String? {
        redoStack.last?.description
    }

    /// Record an action that can be undone
    func recordAction(_ action: GitUndoableAction) {
        undoStack.append(action)

        // Clear redo stack when new action is recorded
        redoStack.removeAll()

        // Trim stack if too large
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }

        // Show toast notification
        lastActionMessage = action.description
        showingUndoToast = true

        // Auto-hide toast after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showingUndoToast = false
        }
    }

    /// Undo the last action
    func undo() async throws {
        guard let action = undoStack.popLast() else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await action.undo()
            redoStack.append(action)
            lastActionMessage = "Undid: \(action.description)"

            NotificationCenter.default.post(name: .gitUndoPerformed, object: action)
        } catch {
            // Put action back if undo failed
            undoStack.append(action)
            throw error
        }
    }

    /// Redo the last undone action
    func redo() async throws {
        guard let action = redoStack.popLast() else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await action.redo()
            undoStack.append(action)
            lastActionMessage = "Redid: \(action.description)"

            NotificationCenter.default.post(name: .gitRedoPerformed, object: action)
        } catch {
            // Put action back if redo failed
            redoStack.append(action)
            throw error
        }
    }

    /// Clear all undo/redo history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Clear history for a specific repository
    func clearHistory(for repositoryPath: URL) {
        undoStack.removeAll { $0.repositoryPath == repositoryPath }
        redoStack.removeAll { $0.repositoryPath == repositoryPath }
    }
}

// MARK: - Undoable Action Protocol

protocol GitUndoableAction {
    var id: UUID { get }
    var description: String { get }
    var timestamp: Date { get }
    var repositoryPath: URL { get }

    func undo() async throws
    func redo() async throws
}

// MARK: - Concrete Undoable Actions

/// Undo a commit operation
struct UndoCommitAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let commitHash: String

    func undo() async throws {
        // git reset --soft HEAD~1
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["reset", "--soft", "HEAD~1"]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to undo commit")
        }
    }

    func redo() async throws {
        // Recommit with same message - this is simplified
        // In practice, you'd want to store the commit message
        throw GitUndoError.redoNotSupported
    }
}

/// Undo a branch creation
struct UndoBranchCreateAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let branchName: String

    func undo() async throws {
        // git branch -D branchName
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["branch", "-D", branchName]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to delete branch")
        }
    }

    func redo() async throws {
        // Recreate the branch - would need to know the commit
        throw GitUndoError.redoNotSupported
    }
}

/// Undo a branch deletion (uses reflog)
struct UndoBranchDeleteAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let branchName: String
    let lastCommitHash: String

    func undo() async throws {
        // git branch branchName lastCommitHash
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["branch", branchName, lastCommitHash]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to restore branch")
        }
    }

    func redo() async throws {
        // Delete the branch again
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["branch", "-D", branchName]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to delete branch")
        }
    }
}

/// Undo a checkout operation
struct UndoCheckoutAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let previousBranch: String
    let newBranch: String

    func undo() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["checkout", previousBranch]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to checkout previous branch")
        }
    }

    func redo() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["checkout", newBranch]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to checkout branch")
        }
    }
}

/// Undo a merge operation
struct UndoMergeAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let previousHeadHash: String
    let mergedBranch: String

    func undo() async throws {
        // git reset --hard previousHeadHash
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["reset", "--hard", previousHeadHash]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to undo merge")
        }
    }

    func redo() async throws {
        // Re-merge the branch
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["merge", mergedBranch]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to redo merge")
        }
    }
}

/// Undo a rebase operation (using ORIG_HEAD)
struct UndoRebaseAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let origHead: String

    func undo() async throws {
        // git reset --hard ORIG_HEAD (or stored hash)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["reset", "--hard", origHead]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to undo rebase")
        }
    }

    func redo() async throws {
        // Cannot easily redo a rebase
        throw GitUndoError.redoNotSupported
    }
}

/// Undo a stash application
struct UndoStashApplyAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let stashRef: String
    let affectedFiles: [String]

    func undo() async throws {
        // This would need to checkout the affected files from HEAD
        // Simplified version
        for file in affectedFiles {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["checkout", "HEAD", "--", file]
            process.currentDirectoryURL = repositoryPath

            try process.run()
            process.waitUntilExit()
        }
    }

    func redo() async throws {
        // Reapply the stash
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["stash", "apply", stashRef]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to reapply stash")
        }
    }
}

/// Undo a tag creation
struct UndoTagCreateAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let tagName: String

    func undo() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["tag", "-d", tagName]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to delete tag")
        }
    }

    func redo() async throws {
        throw GitUndoError.redoNotSupported
    }
}

/// Undo a reset operation
struct UndoResetAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let previousHead: String

    func undo() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["reset", "--hard", previousHead]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to undo reset")
        }
    }

    func redo() async throws {
        throw GitUndoError.redoNotSupported
    }
}

/// Undo a cherry-pick operation
struct UndoCherryPickAction: GitUndoableAction {
    let id = UUID()
    let description: String
    let timestamp = Date()
    let repositoryPath: URL
    let previousHead: String
    let cherryPickedCommit: String

    func undo() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["reset", "--hard", previousHead]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to undo cherry-pick")
        }
    }

    func redo() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["cherry-pick", cherryPickedCommit]
        process.currentDirectoryURL = repositoryPath

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw GitUndoError.operationFailed("Failed to redo cherry-pick")
        }
    }
}

// MARK: - Errors

enum GitUndoError: LocalizedError {
    case operationFailed(String)
    case redoNotSupported
    case nothingToUndo
    case nothingToRedo

    var errorDescription: String? {
        switch self {
        case .operationFailed(let message):
            return message
        case .redoNotSupported:
            return "Redo is not supported for this operation"
        case .nothingToUndo:
            return "Nothing to undo"
        case .nothingToRedo:
            return "Nothing to redo"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let gitUndoPerformed = Notification.Name("gitUndoPerformed")
    static let gitRedoPerformed = Notification.Name("gitRedoPerformed")
}

// MARK: - Undo History View

struct UndoHistoryView: View {
    @ObservedObject var undoManager = GitUndoManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Action History")
                    .font(.headline)
                Spacer()
                Button("Clear History") {
                    undoManager.clearHistory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(undoManager.undoStack.isEmpty && undoManager.redoStack.isEmpty)
            }
            .padding()

            Divider()

            // Content
            if undoManager.undoStack.isEmpty && undoManager.redoStack.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No actions recorded")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !undoManager.undoStack.isEmpty {
                        Section("Can Undo") {
                            ForEach(undoManager.undoStack.reversed(), id: \.id) { action in
                                ActionRow(action: action, canUndo: true)
                            }
                        }
                    }

                    if !undoManager.redoStack.isEmpty {
                        Section("Can Redo") {
                            ForEach(undoManager.redoStack.reversed(), id: \.id) { action in
                                ActionRow(action: action, canUndo: false)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Undo") {
                    Task {
                        try? await undoManager.undo()
                    }
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!undoManager.canUndo)

                Button("Redo") {
                    Task {
                        try? await undoManager.redo()
                    }
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!undoManager.canRedo)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
}

struct ActionRow: View {
    let action: GitUndoableAction
    let canUndo: Bool

    var body: some View {
        HStack {
            Image(systemName: canUndo ? "arrow.uturn.backward.circle" : "arrow.uturn.forward.circle")
                .foregroundColor(canUndo ? .blue : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.description)
                    .lineLimit(1)
                Text(action.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Undo Toast View

struct UndoToastView: View {
    @ObservedObject var undoManager = GitUndoManager.shared

    var body: some View {
        if undoManager.showingUndoToast, let message = undoManager.lastActionMessage {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                Text(message)
                    .lineLimit(1)

                Button("Undo") {
                    Task {
                        try? await undoManager.undo()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .cornerRadius(10)
            .shadow(radius: 5)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: undoManager.showingUndoToast)
        }
    }
}

// MARK: - Menu Commands

struct UndoMenuCommands: Commands {
    @ObservedObject var undoManager: GitUndoManager

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo \(undoManager.undoActionName ?? "")") {
                Task {
                    try? await undoManager.undo()
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!undoManager.canUndo)

            Button("Redo \(undoManager.redoActionName ?? "")") {
                Task {
                    try? await undoManager.redo()
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!undoManager.canRedo)
        }
    }
}

// MARK: - Helper for Recording Actions

extension GitUndoManager {
    /// Helper to get current HEAD hash
    func getCurrentHead(at path: URL) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]
        process.currentDirectoryURL = path

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Helper to get current branch
    func getCurrentBranch(at path: URL) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = path

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

#Preview {
    UndoHistoryView()
}
