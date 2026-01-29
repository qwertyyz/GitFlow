import SwiftUI

/// View displaying detailed repository information and statistics.
struct RepositoryInfoView: View {
    let repository: Repository
    @StateObject private var viewModel: RepositoryInfoViewModel
    @Environment(\.dismiss) private var dismiss

    init(repository: Repository) {
        self.repository = repository
        self._viewModel = StateObject(wrappedValue: RepositoryInfoViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(repository.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(repository.path)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            if viewModel.isLoading {
                ProgressView("Loading repository statistics...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Quick stats
                        quickStatsSection

                        Divider()

                        // Branch statistics
                        branchStatsSection

                        Divider()

                        // Contributor statistics
                        contributorStatsSection

                        Divider()

                        // File statistics
                        fileStatsSection

                        Divider()

                        // Repository details
                        detailsSection
                    }
                    .padding()
                }
            }
        }
        .frame(width: 600, height: 700)
        .task {
            await viewModel.loadStatistics()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Commits",
                    value: "\(viewModel.stats.totalCommits)",
                    icon: "checkmark.circle",
                    color: .blue
                )
                StatCard(
                    title: "Branches",
                    value: "\(viewModel.stats.branchCount)",
                    icon: "arrow.triangle.branch",
                    color: .green
                )
                StatCard(
                    title: "Tags",
                    value: "\(viewModel.stats.tagCount)",
                    icon: "tag",
                    color: .orange
                )
                StatCard(
                    title: "Contributors",
                    value: "\(viewModel.stats.contributorCount)",
                    icon: "person.2",
                    color: .purple
                )
            }
        }
    }

    @ViewBuilder
    private var branchStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Branches")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.green)
                        Text(viewModel.stats.currentBranch)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(.yellow)
                        Text(viewModel.stats.defaultBranch)
                            .font(.body)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Branches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.stats.localBranchCount)")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Remote Branches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.stats.remoteBranchCount)")
                        .font(.body)
                }
            }

            if viewModel.stats.staleBranchCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("\(viewModel.stats.staleBranchCount) stale branch\(viewModel.stats.staleBranchCount == 1 ? "" : "es") (no activity in 30+ days)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var contributorStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Contributors")
                    .font(.headline)
                Spacer()
                Text("Last 30 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.stats.topContributors.isEmpty {
                Text("No recent commits")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.stats.topContributors.prefix(5)) { contributor in
                        ContributorRow(contributor: contributor, maxCommits: viewModel.stats.topContributors.first?.commits ?? 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fileStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Files")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.stats.fileCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.stats.repositorySize)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lines of Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.stats.linesOfCode)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            // Language breakdown
            if !viewModel.stats.languageBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Languages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(viewModel.stats.languageBreakdown.prefix(5)) { lang in
                        LanguageBar(language: lang, maxPercentage: viewModel.stats.languageBreakdown.first?.percentage ?? 100)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("First Commit")
                        .foregroundColor(.secondary)
                    Text(viewModel.stats.firstCommitDate ?? "Unknown")
                }

                GridRow {
                    Text("Last Commit")
                        .foregroundColor(.secondary)
                    Text(viewModel.stats.lastCommitDate ?? "Unknown")
                }

                GridRow {
                    Text("Remote URL")
                        .foregroundColor(.secondary)
                    Text(viewModel.stats.remoteURL ?? "None")
                        .lineLimit(1)
                }

                if viewModel.stats.isGitFlowInitialized {
                    GridRow {
                        Text("git-flow")
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Initialized")
                        }
                    }
                }

                if viewModel.stats.hasLFS {
                    GridRow {
                        Text("Git LFS")
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Enabled")
                        }
                    }
                }

                if viewModel.stats.submoduleCount > 0 {
                    GridRow {
                        Text("Submodules")
                            .foregroundColor(.secondary)
                        Text("\(viewModel.stats.submoduleCount)")
                    }
                }

                if viewModel.stats.worktreeCount > 1 {
                    GridRow {
                        Text("Worktrees")
                            .foregroundColor(.secondary)
                        Text("\(viewModel.stats.worktreeCount)")
                    }
                }
            }
            .font(.body)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ContributorRow: View {
    let contributor: Contributor
    let maxCommits: Int

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(contributor.name.prefix(1)).uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(contributor.name)
                    .font(.subheadline)
                Text("\(contributor.commits) commit\(contributor.commits == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                let width = geometry.size.width * CGFloat(contributor.commits) / CGFloat(maxCommits)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: max(4, width))
            }
            .frame(width: 100, height: 8)
        }
    }
}

struct LanguageBar: View {
    let language: LanguageStats
    let maxPercentage: Double

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(language.color)
                .frame(width: 12, height: 12)

            Text(language.name)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                let width = geometry.size.width * language.percentage / maxPercentage
                RoundedRectangle(cornerRadius: 4)
                    .fill(language.color.opacity(0.5))
                    .frame(width: max(4, width))
            }
            .frame(height: 8)

            Text(String(format: "%.1f%%", language.percentage))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - View Model

@MainActor
class RepositoryInfoViewModel: ObservableObject {
    let repository: Repository
    @Published var stats = RepositoryStats()
    @Published var isLoading = false

    private let gitService = GitService()

    init(repository: Repository) {
        self.repository = repository
    }

    func loadStatistics() async {
        isLoading = true
        defer { isLoading = false }

        // Load basic stats
        stats.currentBranch = (try? await gitService.getCurrentBranch(in: repository)) ?? "unknown"

        // Count branches
        if let branches = try? await gitService.getBranches(in: repository) {
            stats.localBranchCount = branches.filter { !$0.isRemote }.count
            stats.remoteBranchCount = branches.filter { $0.isRemote }.count
            stats.branchCount = stats.localBranchCount
        }

        // Count commits (approximate)
        stats.totalCommits = await countCommits()

        // Get contributors
        stats.topContributors = await getTopContributors()
        stats.contributorCount = stats.topContributors.count

        // Get file stats
        stats.fileCount = await countFiles()
        stats.repositorySize = await getRepositorySize()

        // Get other details
        stats.firstCommitDate = await getFirstCommitDate()
        stats.lastCommitDate = await getLastCommitDate()
        stats.remoteURL = await getRemoteURL()

        // Check for features
        stats.hasLFS = await checkLFS()
        stats.isGitFlowInitialized = await checkGitFlow()
        stats.submoduleCount = await countSubmodules()
        stats.worktreeCount = await countWorktrees()

        // Language breakdown
        stats.languageBreakdown = await getLanguageBreakdown()
    }

    private func countCommits() async -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-list", "--count", "HEAD"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
            return Int(output) ?? 0
        } catch {
            return 0
        }
    }

    private func getTopContributors() async -> [Contributor] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["shortlog", "-sne", "--since=30 days ago", "HEAD"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return output.components(separatedBy: .newlines)
                .compactMap { line -> Contributor? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return nil }

                    // Format: "  123\tName <email>"
                    let parts = trimmed.split(separator: "\t", maxSplits: 1)
                    guard parts.count == 2,
                          let commits = Int(parts[0].trimmingCharacters(in: .whitespaces)) else {
                        return nil
                    }

                    let nameEmail = String(parts[1])
                    let name = nameEmail.components(separatedBy: " <").first ?? nameEmail

                    return Contributor(name: name, commits: commits)
                }
        } catch {
            return []
        }
    }

    private func countFiles() async -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        } catch {
            return 0
        }
    }

    private func getRepositorySize() async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sh", repository.path]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.split(separator: "\t").first.map(String.init) ?? "Unknown"
        } catch {
            return "Unknown"
        }
    }

    private func getFirstCommitDate() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--reverse", "--format=%ci", "-1"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }

    private func getLastCommitDate() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--format=%ci", "-1"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }

    private func getRemoteURL() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["remote", "get-url", "origin"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }

    private func checkLFS() async -> Bool {
        let lfsPath = repository.rootURL.appendingPathComponent(".gitattributes")
        guard let content = try? String(contentsOf: lfsPath, encoding: .utf8) else {
            return false
        }
        return content.contains("filter=lfs")
    }

    private func checkGitFlow() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "--get", "gitflow.branch.master"]
        process.currentDirectoryURL = repository.rootURL

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func countSubmodules() async -> Int {
        let gitmodulesPath = repository.rootURL.appendingPathComponent(".gitmodules")
        guard FileManager.default.fileExists(atPath: gitmodulesPath.path),
              let content = try? String(contentsOf: gitmodulesPath, encoding: .utf8) else {
            return 0
        }
        return content.components(separatedBy: "[submodule").count - 1
    }

    private func countWorktrees() async -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "list"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        } catch {
            return 1
        }
    }

    private func getLanguageBreakdown() async -> [LanguageStats] {
        // Simple file extension based analysis
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files"]
        process.currentDirectoryURL = repository.rootURL

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var extensionCounts: [String: Int] = [:]

            for line in output.components(separatedBy: .newlines) {
                let ext = (line as NSString).pathExtension.lowercased()
                guard !ext.isEmpty else { continue }
                extensionCounts[ext, default: 0] += 1
            }

            let total = extensionCounts.values.reduce(0, +)
            guard total > 0 else { return [] }

            return extensionCounts
                .map { (ext, count) -> LanguageStats in
                    let name = languageName(for: ext)
                    let percentage = Double(count) / Double(total) * 100
                    let color = languageColor(for: ext)
                    return LanguageStats(name: name, percentage: percentage, color: color)
                }
                .sorted { $0.percentage > $1.percentage }
        } catch {
            return []
        }
    }

    private func languageName(for ext: String) -> String {
        let mapping: [String: String] = [
            "swift": "Swift",
            "m": "Objective-C",
            "h": "C/C++ Header",
            "c": "C",
            "cpp": "C++",
            "js": "JavaScript",
            "ts": "TypeScript",
            "tsx": "TypeScript",
            "jsx": "JavaScript",
            "py": "Python",
            "rb": "Ruby",
            "go": "Go",
            "rs": "Rust",
            "java": "Java",
            "kt": "Kotlin",
            "php": "PHP",
            "cs": "C#",
            "html": "HTML",
            "css": "CSS",
            "scss": "SCSS",
            "json": "JSON",
            "xml": "XML",
            "yaml": "YAML",
            "yml": "YAML",
            "md": "Markdown",
            "sh": "Shell",
            "sql": "SQL"
        ]
        return mapping[ext] ?? ext.uppercased()
    }

    private func languageColor(for ext: String) -> Color {
        let colorMapping: [String: Color] = [
            "swift": .orange,
            "m": .blue,
            "c": .gray,
            "cpp": .pink,
            "js": .yellow,
            "ts": .blue,
            "tsx": .blue,
            "jsx": .yellow,
            "py": .green,
            "rb": .red,
            "go": .cyan,
            "rs": .orange,
            "java": .red,
            "kt": .purple,
            "php": .indigo,
            "cs": .green,
            "html": .orange,
            "css": .blue,
            "json": .gray,
            "md": .gray,
            "sh": .green
        ]
        return colorMapping[ext] ?? .secondary
    }
}

// MARK: - Data Models

struct RepositoryStats {
    var totalCommits: Int = 0
    var branchCount: Int = 0
    var tagCount: Int = 0
    var contributorCount: Int = 0
    var localBranchCount: Int = 0
    var remoteBranchCount: Int = 0
    var staleBranchCount: Int = 0
    var currentBranch: String = ""
    var defaultBranch: String = "main"
    var fileCount: Int = 0
    var repositorySize: String = ""
    var linesOfCode: String = "N/A"
    var firstCommitDate: String?
    var lastCommitDate: String?
    var remoteURL: String?
    var hasLFS: Bool = false
    var isGitFlowInitialized: Bool = false
    var submoduleCount: Int = 0
    var worktreeCount: Int = 0
    var topContributors: [Contributor] = []
    var languageBreakdown: [LanguageStats] = []
}

struct Contributor: Identifiable {
    let id = UUID()
    let name: String
    let commits: Int
}

struct LanguageStats: Identifiable {
    let id = UUID()
    let name: String
    let percentage: Double
    let color: Color
}

#Preview {
    RepositoryInfoView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
}
