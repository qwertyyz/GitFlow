import Foundation
import AppKit

/// Service for undoing discard operations by backing up changes before discarding.
actor UndoDiscardService {
    static let shared = UndoDiscardService()

    private var undoStack: [DiscardBackup] = []
    private let maxUndoCount = 10
    private let backupDirectory: URL

    private init() {
        // Use Application Support for backups
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupDirectory = appSupport.appendingPathComponent("GitFlow/DiscardBackups", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        // Clean up old backups on init
        Task {
            await cleanupOldBackups()
        }
    }

    // MARK: - Backup Before Discard

    /// Backup a file's changes before discarding
    func backupBeforeDiscard(
        file: URL,
        content: Data,
        repositoryPath: URL,
        description: String
    ) async throws {
        let backup = DiscardBackup(
            id: UUID(),
            originalPath: file,
            repositoryPath: repositoryPath,
            content: content,
            description: description,
            timestamp: Date()
        )

        // Save content to backup file
        let backupFile = backupDirectory.appendingPathComponent("\(backup.id).backup")
        try content.write(to: backupFile)

        // Add to undo stack
        undoStack.insert(backup, at: 0)

        // Trim stack if needed
        while undoStack.count > maxUndoCount {
            let removed = undoStack.removeLast()
            await deleteBackupFile(for: removed)
        }

        // Save metadata
        await saveMetadata()

        // Post notification for UI update
        await MainActor.run {
            NotificationCenter.default.post(
                name: .discardBackupCreated,
                object: nil,
                userInfo: ["backup": backup]
            )
        }
    }

    /// Backup multiple files before discarding
    func backupFilesBeforeDiscard(
        files: [(url: URL, content: Data)],
        repositoryPath: URL,
        description: String
    ) async throws {
        let backup = DiscardBackup(
            id: UUID(),
            originalPath: files.first?.url ?? repositoryPath,
            repositoryPath: repositoryPath,
            content: Data(), // Will store multiple files
            description: description,
            timestamp: Date(),
            additionalFiles: files.map { ($0.url.path, $0.content) }
        )

        // Save content to backup files
        let backupDir = backupDirectory.appendingPathComponent(backup.id.uuidString)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        for (url, content) in files {
            let fileName = url.lastPathComponent
            let backupFile = backupDir.appendingPathComponent(fileName)
            try content.write(to: backupFile)
        }

        // Save file mapping
        let mapping = files.map { $0.url.path }
        let mappingData = try JSONEncoder().encode(mapping)
        try mappingData.write(to: backupDir.appendingPathComponent("_mapping.json"))

        // Add to undo stack
        undoStack.insert(backup, at: 0)

        // Trim stack if needed
        while undoStack.count > maxUndoCount {
            let removed = undoStack.removeLast()
            await deleteBackupFile(for: removed)
        }

        await saveMetadata()

        await MainActor.run {
            NotificationCenter.default.post(
                name: .discardBackupCreated,
                object: nil,
                userInfo: ["backup": backup]
            )
        }
    }

    // MARK: - Undo Discard

    /// Check if there are any undoable discards
    func canUndo() -> Bool {
        !undoStack.isEmpty
    }

    /// Get the most recent backup that can be undone
    func getMostRecentBackup() -> DiscardBackup? {
        undoStack.first
    }

    /// Get all available backups
    func getAllBackups() -> [DiscardBackup] {
        undoStack
    }

    /// Undo the most recent discard
    func undoLastDiscard() async throws -> DiscardBackup? {
        guard let backup = undoStack.first else {
            return nil
        }

        try await restoreBackup(backup)
        undoStack.removeFirst()
        await saveMetadata()

        await MainActor.run {
            NotificationCenter.default.post(
                name: .discardUndone,
                object: nil,
                userInfo: ["backup": backup]
            )
        }

        return backup
    }

    /// Undo a specific backup
    func undoDiscard(_ backup: DiscardBackup) async throws {
        try await restoreBackup(backup)

        if let index = undoStack.firstIndex(where: { $0.id == backup.id }) {
            undoStack.remove(at: index)
        }

        await saveMetadata()

        await MainActor.run {
            NotificationCenter.default.post(
                name: .discardUndone,
                object: nil,
                userInfo: ["backup": backup]
            )
        }
    }

    /// Restore a backup to its original location
    private func restoreBackup(_ backup: DiscardBackup) async throws {
        if backup.additionalFiles.isEmpty {
            // Single file backup
            let backupFile = backupDirectory.appendingPathComponent("\(backup.id).backup")
            let content = try Data(contentsOf: backupFile)
            try content.write(to: backup.originalPath)

            // Clean up backup file
            try? FileManager.default.removeItem(at: backupFile)
        } else {
            // Multiple files backup
            let backupDir = backupDirectory.appendingPathComponent(backup.id.uuidString)

            // Read mapping
            let mappingFile = backupDir.appendingPathComponent("_mapping.json")
            let mappingData = try Data(contentsOf: mappingFile)
            let paths = try JSONDecoder().decode([String].self, from: mappingData)

            // Restore each file
            for path in paths {
                let fileName = URL(fileURLWithPath: path).lastPathComponent
                let backupFile = backupDir.appendingPathComponent(fileName)
                let content = try Data(contentsOf: backupFile)
                try content.write(to: URL(fileURLWithPath: path))
            }

            // Clean up backup directory
            try? FileManager.default.removeItem(at: backupDir)
        }
    }

    // MARK: - Cleanup

    /// Clear all backups
    func clearAllBackups() async {
        for backup in undoStack {
            await deleteBackupFile(for: backup)
        }
        undoStack.removeAll()
        await saveMetadata()
    }

    /// Clear backups for a specific repository
    func clearBackups(for repositoryPath: URL) async {
        let toRemove = undoStack.filter { $0.repositoryPath == repositoryPath }
        for backup in toRemove {
            await deleteBackupFile(for: backup)
        }
        undoStack.removeAll { $0.repositoryPath == repositoryPath }
        await saveMetadata()
    }

    private func deleteBackupFile(for backup: DiscardBackup) async {
        if backup.additionalFiles.isEmpty {
            let backupFile = backupDirectory.appendingPathComponent("\(backup.id).backup")
            try? FileManager.default.removeItem(at: backupFile)
        } else {
            let backupDir = backupDirectory.appendingPathComponent(backup.id.uuidString)
            try? FileManager.default.removeItem(at: backupDir)
        }
    }

    private func cleanupOldBackups() async {
        // Remove backups older than 7 days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oldBackups = undoStack.filter { $0.timestamp < cutoffDate }

        for backup in oldBackups {
            await deleteBackupFile(for: backup)
        }

        undoStack.removeAll { $0.timestamp < cutoffDate }
        await saveMetadata()
    }

    // MARK: - Persistence

    private func saveMetadata() async {
        let metadata = undoStack.map { backup in
            DiscardBackupMetadata(
                id: backup.id,
                originalPath: backup.originalPath.path,
                repositoryPath: backup.repositoryPath.path,
                description: backup.description,
                timestamp: backup.timestamp,
                fileCount: backup.additionalFiles.isEmpty ? 1 : backup.additionalFiles.count
            )
        }

        if let data = try? JSONEncoder().encode(metadata) {
            let metadataFile = backupDirectory.appendingPathComponent("metadata.json")
            try? data.write(to: metadataFile)
        }
    }

    private func loadMetadata() async {
        let metadataFile = backupDirectory.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataFile),
              let metadata = try? JSONDecoder().decode([DiscardBackupMetadata].self, from: data) else {
            return
        }

        undoStack = metadata.compactMap { meta in
            DiscardBackup(
                id: meta.id,
                originalPath: URL(fileURLWithPath: meta.originalPath),
                repositoryPath: URL(fileURLWithPath: meta.repositoryPath),
                content: Data(),
                description: meta.description,
                timestamp: meta.timestamp
            )
        }
    }
}

// MARK: - Data Models

struct DiscardBackup: Identifiable, Sendable {
    let id: UUID
    let originalPath: URL
    let repositoryPath: URL
    let content: Data
    let description: String
    let timestamp: Date
    var additionalFiles: [(String, Data)] = []

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var fileName: String {
        originalPath.lastPathComponent
    }
}

struct DiscardBackupMetadata: Codable {
    let id: UUID
    let originalPath: String
    let repositoryPath: String
    let description: String
    let timestamp: Date
    let fileCount: Int
}

// MARK: - Notifications

extension Notification.Name {
    static let discardBackupCreated = Notification.Name("discardBackupCreated")
    static let discardUndone = Notification.Name("discardUndone")
}

// MARK: - Undo Discard View

import SwiftUI

struct UndoDiscardView: View {
    @StateObject private var viewModel = UndoDiscardViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Undo Discard")
                    .font(.headline)

                Spacer()

                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            if viewModel.backups.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(viewModel.backups) { backup in
                        DiscardBackupRow(
                            backup: backup,
                            onUndo: { viewModel.undoDiscard(backup) }
                        )
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer
            HStack {
                if !viewModel.backups.isEmpty {
                    Button("Clear All") {
                        viewModel.clearAllBackups()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer()

                Text("Backups are kept for 7 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .task {
            await viewModel.loadBackups()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Discarded Changes")
                .font(.headline)

            Text("When you discard changes, they'll appear here so you can restore them if needed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DiscardBackupRow: View {
    let backup: DiscardBackup
    let onUndo: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.fileName)
                    .font(.headline)

                Text(backup.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(backup.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if backup.additionalFiles.count > 1 {
                        Text("\(backup.additionalFiles.count) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class UndoDiscardViewModel: ObservableObject {
    @Published var backups: [DiscardBackup] = []
    @Published var isLoading = false

    private let service = UndoDiscardService.shared

    func loadBackups() async {
        backups = await service.getAllBackups()
    }

    func undoDiscard(_ backup: DiscardBackup) {
        Task {
            do {
                try await service.undoDiscard(backup)
                await loadBackups()
            } catch {
                // Show error
                print("Failed to undo discard: \(error)")
            }
        }
    }

    func clearAllBackups() {
        Task {
            await service.clearAllBackups()
            await loadBackups()
        }
    }
}

// MARK: - Undo Discard Toast

struct UndoDiscardToast: View {
    let backup: DiscardBackup
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var timeRemaining = 5

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Changes discarded")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(backup.fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
        .onAppear {
            // Auto-dismiss after 5 seconds
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                timeRemaining -= 1
                if timeRemaining <= 0 {
                    timer.invalidate()
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    UndoDiscardView()
}
