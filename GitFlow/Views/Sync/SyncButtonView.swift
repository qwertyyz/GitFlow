import SwiftUI

/// One-click Sync button that performs Pull + Push in sequence.
struct SyncButtonView: View {
    @StateObject private var viewModel: SyncButtonViewModel

    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: SyncButtonViewModel(repository: repository))
    }

    var body: some View {
        Button(action: { viewModel.sync() }) {
            HStack(spacing: 6) {
                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }

                Text(viewModel.buttonTitle)

                if viewModel.hasChanges {
                    HStack(spacing: 4) {
                        if viewModel.behindCount > 0 {
                            Text("↓\(viewModel.behindCount)")
                                .font(.caption)
                        }
                        if viewModel.aheadCount > 0 {
                            Text("↑\(viewModel.aheadCount)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isSyncing || !viewModel.canSync)
        .help(viewModel.helpText)
        .popover(isPresented: $viewModel.showingSyncOptions) {
            SyncOptionsPopover(viewModel: viewModel)
        }
        .contextMenu {
            Button("Pull Only") {
                viewModel.pullOnly()
            }
            .disabled(viewModel.behindCount == 0)

            Button("Push Only") {
                viewModel.pushOnly()
            }
            .disabled(viewModel.aheadCount == 0)

            Divider()

            Button("Fetch") {
                viewModel.fetchOnly()
            }

            Divider()

            Toggle("Pull with Rebase", isOn: $viewModel.useRebase)

            Button("Sync Options...") {
                viewModel.showingSyncOptions = true
            }
        }
        .alert("Sync Error", isPresented: $viewModel.showingError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred during sync")
        }
        .alert("Sync Conflicts", isPresented: $viewModel.showingConflicts) {
            Button("Resolve Manually") {
                viewModel.showConflictResolver()
            }
            Button("Abort") {
                viewModel.abortSync()
            }
        } message: {
            Text("There are conflicts that need to be resolved before completing the sync.")
        }
    }
}

// MARK: - Sync Options Popover

struct SyncOptionsPopover: View {
    @ObservedObject var viewModel: SyncButtonViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Options")
                .font(.headline)

            // Pull options
            VStack(alignment: .leading, spacing: 8) {
                Text("Pull Strategy")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.pullStrategy) {
                    Text("Merge").tag(PullStrategy.merge)
                    Text("Rebase").tag(PullStrategy.rebase)
                    Text("Fast-forward only").tag(PullStrategy.fastForwardOnly)
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            // Push options
            VStack(alignment: .leading, spacing: 8) {
                Text("Push Options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Push tags", isOn: $viewModel.pushTags)
                Toggle("Force push (with lease)", isOn: $viewModel.forcePush)
            }

            Divider()

            // Auto-sync
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto Sync")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Auto-fetch on open", isOn: $viewModel.autoFetchOnOpen)
                Toggle("Auto-fetch periodically", isOn: $viewModel.autoFetchPeriodically)

                if viewModel.autoFetchPeriodically {
                    Picker("Interval", selection: $viewModel.autoFetchInterval) {
                        Text("Every 5 minutes").tag(5)
                        Text("Every 10 minutes").tag(10)
                        Text("Every 15 minutes").tag(15)
                        Text("Every 30 minutes").tag(30)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

// MARK: - View Model

@MainActor
class SyncButtonViewModel: ObservableObject {
    @Published var isSyncing = false
    @Published var aheadCount = 0
    @Published var behindCount = 0
    @Published var canSync = true
    @Published var showingSyncOptions = false
    @Published var showingError = false
    @Published var showingConflicts = false
    @Published var errorMessage: String?

    // Options
    @Published var useRebase = false
    @Published var pullStrategy: PullStrategy = .merge
    @Published var pushTags = false
    @Published var forcePush = false
    @Published var autoFetchOnOpen = true
    @Published var autoFetchPeriodically = false
    @Published var autoFetchInterval = 10

    let repository: Repository
    private var autoFetchTimer: Timer?

    var buttonTitle: String {
        if isSyncing {
            return "Syncing..."
        }
        return "Sync"
    }

    var hasChanges: Bool {
        aheadCount > 0 || behindCount > 0
    }

    var helpText: String {
        var parts: [String] = []
        if behindCount > 0 {
            parts.append("\(behindCount) commit\(behindCount == 1 ? "" : "s") to pull")
        }
        if aheadCount > 0 {
            parts.append("\(aheadCount) commit\(aheadCount == 1 ? "" : "s") to push")
        }
        return parts.isEmpty ? "Sync with remote" : parts.joined(separator: ", ")
    }

    init(repository: Repository) {
        self.repository = repository
        loadSettings()
        setupAutoFetch()

        Task {
            await refreshStatus()
        }
    }

    deinit {
        autoFetchTimer?.invalidate()
    }

    // MARK: - Sync Operations

    func sync() {
        isSyncing = true
        errorMessage = nil

        Task {
            do {
                // Step 1: Fetch
                try await fetch()

                // Step 2: Pull (if behind)
                if behindCount > 0 {
                    try await pull()
                }

                // Step 3: Push (if ahead)
                if aheadCount > 0 {
                    try await push()
                }

                await refreshStatus()

                await MainActor.run {
                    isSyncing = false
                    NotificationCenter.default.post(name: .syncCompleted, object: nil)
                }
            } catch let error as SyncError {
                await MainActor.run {
                    handleSyncError(error)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSyncing = false
                }
            }
        }
    }

    func pullOnly() {
        isSyncing = true

        Task {
            do {
                try await fetch()
                try await pull()
                await refreshStatus()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }

            await MainActor.run {
                isSyncing = false
            }
        }
    }

    func pushOnly() {
        isSyncing = true

        Task {
            do {
                try await push()
                await refreshStatus()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }

            await MainActor.run {
                isSyncing = false
            }
        }
    }

    func fetchOnly() {
        Task {
            do {
                try await fetch()
                await refreshStatus()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    // MARK: - Git Operations

    private func fetch() async throws {
        // Run git fetch
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["fetch", "--all", "--prune"]
        process.currentDirectoryURL = repository.rootURL

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SyncError.fetchFailed
        }
    }

    private func pull() async throws {
        var arguments = ["pull"]

        switch pullStrategy {
        case .merge:
            arguments.append("--no-rebase")
        case .rebase:
            arguments.append("--rebase")
        case .fastForwardOnly:
            arguments.append("--ff-only")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = repository.rootURL

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if errorOutput.contains("CONFLICT") {
                throw SyncError.conflicts
            }
            throw SyncError.pullFailed
        }
    }

    private func push() async throws {
        var arguments = ["push"]

        if pushTags {
            arguments.append("--tags")
        }

        if forcePush {
            arguments.append("--force-with-lease")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = repository.rootURL

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SyncError.pushFailed
        }
    }

    func refreshStatus() async {
        // Get ahead/behind counts
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"]
        process.currentDirectoryURL = repository.rootURL

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let parts = output.split(separator: "\t")
            if parts.count == 2 {
                await MainActor.run {
                    behindCount = Int(parts[0]) ?? 0
                    aheadCount = Int(parts[1]) ?? 0
                }
            }
        } catch {
            // Ignore errors - might not have upstream
        }
    }

    // MARK: - Error Handling

    private func handleSyncError(_ error: SyncError) {
        isSyncing = false

        switch error {
        case .conflicts:
            showingConflicts = true
        case .fetchFailed:
            errorMessage = "Failed to fetch from remote"
            showingError = true
        case .pullFailed:
            errorMessage = "Failed to pull changes"
            showingError = true
        case .pushFailed:
            errorMessage = "Failed to push changes"
            showingError = true
        case .noRemote:
            errorMessage = "No remote configured"
            showingError = true
        }
    }

    func showConflictResolver() {
        // Post notification to show conflict resolver
        NotificationCenter.default.post(name: .showConflictResolver, object: nil)
    }

    func abortSync() {
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = useRebase ? ["rebase", "--abort"] : ["merge", "--abort"]
            process.currentDirectoryURL = repository.rootURL

            try? process.run()
            process.waitUntilExit()

            await refreshStatus()
        }
    }

    // MARK: - Auto-Fetch

    private func setupAutoFetch() {
        guard autoFetchPeriodically else { return }

        autoFetchTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoFetchInterval * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchOnly()
            }
        }
    }

    // MARK: - Settings

    private func loadSettings() {
        useRebase = UserDefaults.standard.bool(forKey: "sync.useRebase")
        pullStrategy = PullStrategy(rawValue: UserDefaults.standard.string(forKey: "sync.pullStrategy") ?? "") ?? .merge
        pushTags = UserDefaults.standard.bool(forKey: "sync.pushTags")
        autoFetchOnOpen = UserDefaults.standard.object(forKey: "sync.autoFetchOnOpen") as? Bool ?? true
        autoFetchPeriodically = UserDefaults.standard.bool(forKey: "sync.autoFetchPeriodically")
        autoFetchInterval = UserDefaults.standard.integer(forKey: "sync.autoFetchInterval")
        if autoFetchInterval == 0 {
            autoFetchInterval = 10
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(useRebase, forKey: "sync.useRebase")
        UserDefaults.standard.set(pullStrategy.rawValue, forKey: "sync.pullStrategy")
        UserDefaults.standard.set(pushTags, forKey: "sync.pushTags")
        UserDefaults.standard.set(autoFetchOnOpen, forKey: "sync.autoFetchOnOpen")
        UserDefaults.standard.set(autoFetchPeriodically, forKey: "sync.autoFetchPeriodically")
        UserDefaults.standard.set(autoFetchInterval, forKey: "sync.autoFetchInterval")
    }
}

// MARK: - Models

enum PullStrategy: String {
    case merge
    case rebase
    case fastForwardOnly = "ff-only"
}

enum SyncError: Error {
    case fetchFailed
    case pullFailed
    case pushFailed
    case conflicts
    case noRemote
}

// MARK: - Notifications

extension Notification.Name {
    static let syncCompleted = Notification.Name("syncCompleted")
    static let showConflictResolver = Notification.Name("showConflictResolver")
}

// MARK: - Toolbar Sync Button

struct ToolbarSyncButton: View {
    let repository: Repository

    var body: some View {
        SyncButtonView(repository: repository)
    }
}

#Preview {
    SyncButtonView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
        .padding()
}
