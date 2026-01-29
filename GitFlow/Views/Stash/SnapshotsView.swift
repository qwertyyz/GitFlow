import SwiftUI

/// View for managing stash snapshots - automatically captured working states.
struct SnapshotsView: View {
    @StateObject private var viewModel: SnapshotsViewModel
    @State private var showingCreateSheet = false
    @State private var selectedSnapshot: Snapshot?

    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: SnapshotsViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Snapshots")
                    .font(.headline)

                Spacer()

                Toggle("Auto-capture", isOn: $viewModel.settings.autoCapture)
                    .toggleStyle(.switch)
                    .onChange(of: viewModel.settings.autoCapture) { _ in
                        viewModel.saveSettings()
                    }

                Button(action: { showingCreateSheet = true }) {
                    Label("Create Snapshot", systemImage: "camera")
                }
            }
            .padding()

            Divider()

            if viewModel.snapshots.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    // Snapshot list
                    List(viewModel.snapshots, selection: $selectedSnapshot) { snapshot in
                        SnapshotRow(
                            snapshot: snapshot,
                            onRestore: { viewModel.restoreSnapshot(snapshot) },
                            onDelete: { viewModel.deleteSnapshot(snapshot) }
                        )
                    }
                    .listStyle(.plain)
                    .frame(minWidth: 250)

                    // Snapshot detail
                    if let snapshot = selectedSnapshot {
                        SnapshotDetailView(snapshot: snapshot, viewModel: viewModel)
                    } else {
                        VStack {
                            Text("Select a snapshot to view details")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateSnapshotSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadSnapshots()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Snapshots")
                .font(.headline)

            Text("Snapshots capture the complete state of your working directory.\nThey're like stashes but with more context.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Create Snapshot") {
                    showingCreateSheet = true
                }
                .buttonStyle(.borderedProminent)

                if !viewModel.settings.autoCapture {
                    Button("Enable Auto-capture") {
                        viewModel.settings.autoCapture = true
                        viewModel.saveSettings()
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Snapshot Row

struct SnapshotRow: View {
    let snapshot: Snapshot
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Image(systemName: snapshot.trigger.icon)
                .foregroundColor(snapshot.trigger.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snapshot.name)
                        .font(.headline)
                        .lineLimit(1)

                    if snapshot.trigger == .manual {
                        Image(systemName: "hand.tap")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Label(snapshot.branch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // File count
                HStack(spacing: 8) {
                    if snapshot.stagedCount > 0 {
                        Text("\(snapshot.stagedCount) staged")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    if snapshot.unstagedCount > 0 {
                        Text("\(snapshot.unstagedCount) unstaged")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if snapshot.untrackedCount > 0 {
                        Text("\(snapshot.untrackedCount) untracked")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onRestore) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("Restore snapshot")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete snapshot")
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Snapshot Detail View

struct SnapshotDetailView: View {
    let snapshot: Snapshot
    @ObservedObject var viewModel: SnapshotsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        Label(snapshot.branch, systemImage: "arrow.triangle.branch")
                        Text(snapshot.createdAt.formatted())
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button("Restore") {
                    viewModel.restoreSnapshot(snapshot)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Description
            if let description = snapshot.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            }

            // File list
            List {
                if !snapshot.stagedFiles.isEmpty {
                    Section("Staged Changes (\(snapshot.stagedFiles.count))") {
                        ForEach(snapshot.stagedFiles, id: \.self) { file in
                            FileRow(path: file, status: .staged)
                        }
                    }
                }

                if !snapshot.unstagedFiles.isEmpty {
                    Section("Unstaged Changes (\(snapshot.unstagedFiles.count))") {
                        ForEach(snapshot.unstagedFiles, id: \.self) { file in
                            FileRow(path: file, status: .unstaged)
                        }
                    }
                }

                if !snapshot.untrackedFiles.isEmpty {
                    Section("Untracked Files (\(snapshot.untrackedFiles.count))") {
                        ForEach(snapshot.untrackedFiles, id: \.self) { file in
                            FileRow(path: file, status: .untracked)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct FileRow: View {
    let path: String
    let status: FileStatus

    enum FileStatus {
        case staged, unstaged, untracked

        var color: Color {
            switch self {
            case .staged: return .green
            case .unstaged: return .orange
            case .untracked: return .secondary
            }
        }

        var icon: String {
            switch self {
            case .staged: return "checkmark.circle.fill"
            case .unstaged: return "pencil.circle"
            case .untracked: return "questionmark.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.caption)

            Text(path)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

// MARK: - Create Snapshot Sheet

struct CreateSnapshotSheet: View {
    @ObservedObject var viewModel: SnapshotsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var includeUntracked: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Snapshot")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                Section {
                    Toggle("Include untracked files", isOn: $includeUntracked)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Create") {
                    createSnapshot()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 320)
        .onAppear {
            name = "Snapshot \(Date().formatted(date: .abbreviated, time: .shortened))"
        }
    }

    private func createSnapshot() {
        Task {
            await viewModel.createSnapshot(
                name: name,
                description: description.isEmpty ? nil : description,
                includeUntracked: includeUntracked
            )
            dismiss()
        }
    }
}

// MARK: - Data Models

struct Snapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let branch: String
    let commitHash: String
    let createdAt: Date
    let trigger: SnapshotTrigger
    let stagedFiles: [String]
    let unstagedFiles: [String]
    let untrackedFiles: [String]
    let stashRef: String?

    var stagedCount: Int { stagedFiles.count }
    var unstagedCount: Int { unstagedFiles.count }
    var untrackedCount: Int { untrackedFiles.count }
}

enum SnapshotTrigger: String, Codable {
    case manual
    case autoBeforeCheckout
    case autoBeforePull
    case autoBeforeRebase
    case autoBeforeMerge
    case scheduled

    var icon: String {
        switch self {
        case .manual: return "hand.tap"
        case .autoBeforeCheckout: return "arrow.triangle.branch"
        case .autoBeforePull: return "arrow.down"
        case .autoBeforeRebase: return "arrow.triangle.swap"
        case .autoBeforeMerge: return "arrow.triangle.merge"
        case .scheduled: return "clock"
        }
    }

    var color: Color {
        switch self {
        case .manual: return .blue
        case .autoBeforeCheckout: return .green
        case .autoBeforePull: return .orange
        case .autoBeforeRebase: return .purple
        case .autoBeforeMerge: return .pink
        case .scheduled: return .secondary
        }
    }
}

struct SnapshotSettings: Codable {
    var autoCapture: Bool = false
    var captureBeforeCheckout: Bool = true
    var captureBeforePull: Bool = true
    var captureBeforeRebase: Bool = true
    var captureBeforeMerge: Bool = true
    var includeUntracked: Bool = true
    var maxSnapshots: Int = 50
    var autoCleanupDays: Int = 30

    private static let key = "snapshotSettings"

    static func load() -> SnapshotSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(SnapshotSettings.self, from: data) else {
            return SnapshotSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SnapshotSettings.key)
        }
    }
}

// MARK: - View Model

@MainActor
class SnapshotsViewModel: ObservableObject {
    @Published var snapshots: [Snapshot] = []
    @Published var settings: SnapshotSettings
    @Published var isLoading = false

    let repository: Repository
    private let gitService = GitService()
    private let storageKey: String

    init(repository: Repository) {
        self.repository = repository
        self.storageKey = "snapshots_\(repository.path.hashValue)"
        self.settings = SnapshotSettings.load()
        Task {
            await loadSnapshots()
        }
    }

    func loadSnapshots() async {
        isLoading = true
        defer { isLoading = false }

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Snapshot].self, from: data) {
            snapshots = saved.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func createSnapshot(name: String, description: String?, includeUntracked: Bool) async {
        do {
            // Get current state
            let branch = (try? await gitService.getCurrentBranch(in: repository)) ?? "unknown"
            let status = try await gitService.getStatus(in: repository)
            let headCommits = try? await gitService.getHistory(in: repository, limit: 1)
            let headCommit = headCommits?.first?.hash ?? ""

            // Create stash for the snapshot
            let stashMessage = "GitFlow snapshot: \(name)"

            try await gitService.createStash(
                message: stashMessage,
                includeUntracked: includeUntracked,
                in: repository
            )

            // Get the stash ref
            let stashes = try await gitService.getStashes(in: repository)
            let stashRef = stashes.first?.refName

            // Immediately re-apply the stash to restore working state
            if stashRef != nil {
                try await gitService.applyStash("stash@{0}", in: repository)
            }

            // Create snapshot record
            let snapshot = Snapshot(
                id: UUID(),
                name: name,
                description: description,
                branch: branch,
                commitHash: headCommit,
                createdAt: Date(),
                trigger: .manual,
                stagedFiles: status.stagedFiles.map { $0.path },
                unstagedFiles: status.unstagedFiles.map { $0.path },
                untrackedFiles: includeUntracked ? status.untrackedFiles.map { $0.path } : [],
                stashRef: stashRef
            )

            snapshots.insert(snapshot, at: 0)
            saveSnapshots()

            // Cleanup old snapshots if needed
            cleanupOldSnapshots()
        } catch {
            print("Failed to create snapshot: \(error)")
        }
    }

    func restoreSnapshot(_ snapshot: Snapshot) {
        Task {
            // Would apply the stash associated with this snapshot
            // For now, just mark as restored
            print("Restoring snapshot: \(snapshot.name)")
        }
    }

    func deleteSnapshot(_ snapshot: Snapshot) {
        snapshots.removeAll { $0.id == snapshot.id }
        saveSnapshots()
    }

    func saveSettings() {
        settings.save()
    }

    private func saveSnapshots() {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func cleanupOldSnapshots() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -settings.autoCleanupDays, to: Date()) ?? Date()
        snapshots = snapshots.filter { $0.createdAt > cutoffDate }

        // Also limit to max snapshots
        if snapshots.count > settings.maxSnapshots {
            snapshots = Array(snapshots.prefix(settings.maxSnapshots))
        }

        saveSnapshots()
    }
}

#Preview {
    SnapshotsView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
        .frame(width: 700, height: 500)
}
