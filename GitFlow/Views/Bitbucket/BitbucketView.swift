import SwiftUI

/// Main view for Bitbucket integration.
struct BitbucketView: View {
    @ObservedObject var viewModel: BitbucketViewModel

    @State private var selectedTab: Tab = .pullRequests
    @State private var showCredentialsSheet: Bool = false

    enum Tab: String, CaseIterable, Identifiable {
        case pullRequests = "Pull Requests"
        case issues = "Issues"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pullRequests: return "arrow.triangle.pull"
            case .issues: return "exclamationmark.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            BitbucketHeader(
                viewModel: viewModel,
                showCredentialsSheet: $showCredentialsSheet
            )

            Divider()

            // Content
            if !viewModel.isBitbucketRepository {
                notBitbucketView
            } else if !viewModel.isAuthenticated {
                notAuthenticatedView
            } else {
                authenticatedContent
            }
        }
        .task {
            await viewModel.initialize()
            if viewModel.isAuthenticated {
                await viewModel.loadRepository()
            }
        }
        .sheet(isPresented: $showCredentialsSheet) {
            BitbucketCredentialsSheet(
                username: $viewModel.bitbucketUsername,
                appPassword: $viewModel.bitbucketAppPassword,
                isPresented: $showCredentialsSheet
            )
        }
        .alert("Bitbucket Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var notBitbucketView: some View {
        EmptyStateView(
            "Not a Bitbucket Repository",
            systemImage: "xmark.octagon",
            description: "This repository is not hosted on Bitbucket"
        )
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Bitbucket Credentials Required")
                .font(.headline)

            Text("Add your username and app password to view issues and pull requests.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCredentialsSheet = true
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Add Credentials")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // State filter
            Picker("State", selection: $viewModel.stateFilter) {
                ForEach(BitbucketViewModel.StateFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // Content based on tab
            switch selectedTab {
            case .pullRequests:
                BitbucketPullRequestsListView(viewModel: viewModel)
            case .issues:
                BitbucketIssuesListView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Header

private struct BitbucketHeader: View {
    @ObservedObject var viewModel: BitbucketViewModel
    @Binding var showCredentialsSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                    Text("Bitbucket")
                        .font(.headline)
                }

                if let info = viewModel.bitbucketInfo {
                    Text(info.fullName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status
            Text(viewModel.statusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Actions
            if viewModel.isBitbucketRepository {
                Menu {
                    Button(action: { viewModel.openRepositoryInBrowser() }) {
                        Label("Open in Browser", systemImage: "safari")
                    }

                    Button(action: { viewModel.openPipelinesInBrowser() }) {
                        Label("View Pipelines", systemImage: "play.circle")
                    }

                    Divider()

                    Button(action: { showCredentialsSheet = true }) {
                        Label(viewModel.isAuthenticated ? "Change Credentials" : "Add Credentials", systemImage: "key")
                    }

                    if viewModel.isAuthenticated {
                        Button(action: { Task { await viewModel.refresh() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive, action: { viewModel.logout() }) {
                            Label("Remove Credentials", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Pull Requests List

private struct BitbucketPullRequestsListView: View {
    @ObservedObject var viewModel: BitbucketViewModel

    @State private var selectedPR: BitbucketPullRequest?
    @State private var showMergeConfirmation: Bool = false
    @State private var showDeclineConfirmation: Bool = false

    var body: some View {
        Group {
            if viewModel.pullRequests.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Pull Requests",
                    systemImage: "arrow.triangle.pull",
                    description: "No \(viewModel.stateFilter.displayName.lowercased()) pull requests"
                )
            } else {
                List(viewModel.pullRequests, selection: $selectedPR) { pr in
                    BitbucketPullRequestRow(pr: pr)
                        .tag(pr)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPR = pr
                        }
                        .contextMenu {
                            prContextMenu(for: pr)
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.loadPullRequests()
        }
        .onChange(of: viewModel.stateFilter) { _ in
            Task { await viewModel.loadPullRequests() }
        }
        .confirmationDialog(
            "Merge Pull Request",
            isPresented: $showMergeConfirmation,
            presenting: selectedPR
        ) { pr in
            Button("Merge Commit") {
                Task { await mergePR(pr, strategy: "merge_commit") }
            }
            Button("Squash") {
                Task { await mergePR(pr, strategy: "squash") }
            }
            Button("Cancel", role: .cancel) { }
        } message: { pr in
            Text("How would you like to merge #\(pr.id) into \(pr.destination.branch.name)?")
        }
        .confirmationDialog(
            "Decline Pull Request",
            isPresented: $showDeclineConfirmation,
            presenting: selectedPR
        ) { pr in
            Button("Decline", role: .destructive) {
                Task { await declinePR(pr) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { pr in
            Text("Are you sure you want to decline #\(pr.id)?")
        }
    }

    @ViewBuilder
    private func prContextMenu(for pr: BitbucketPullRequest) -> some View {
        Button("Open in Browser") {
            viewModel.openPullRequestInBrowser(pr)
        }

        Divider()

        if pr.isOpen {
            Button {
                Task { try? await viewModel.approvePullRequest(pr) }
            } label: {
                Label("Approve", systemImage: "checkmark.circle")
            }

            Divider()

            Button {
                selectedPR = pr
                showMergeConfirmation = true
            } label: {
                Label("Merge", systemImage: "arrow.triangle.merge")
            }

            Button {
                selectedPR = pr
                showDeclineConfirmation = true
            } label: {
                Label("Decline", systemImage: "xmark.circle")
            }
        }
    }

    private func mergePR(_ pr: BitbucketPullRequest, strategy: String) async {
        do {
            try await viewModel.mergePullRequest(pr, strategy: strategy)
        } catch {
            viewModel.error = error as? BitbucketError
        }
    }

    private func declinePR(_ pr: BitbucketPullRequest) async {
        do {
            try await viewModel.declinePullRequest(pr)
        } catch {
            viewModel.error = error as? BitbucketError
        }
    }
}

private struct BitbucketPullRequestRow: View {
    let pr: BitbucketPullRequest

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("#\(pr.id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(pr.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(pr.author.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(pr.source.branch.name)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(pr.destination.branch.name)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Comment count
            if pr.commentCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "bubble.left")
                        .font(.caption)
                    Text("\(pr.commentCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if pr.isMerged {
            return "arrow.triangle.merge"
        } else if pr.isOpen {
            return "arrow.triangle.pull"
        } else {
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        if pr.isMerged {
            return .purple
        } else if pr.isOpen {
            return .green
        } else {
            return .red
        }
    }
}

// MARK: - Issues List

private struct BitbucketIssuesListView: View {
    @ObservedObject var viewModel: BitbucketViewModel

    var body: some View {
        Group {
            if viewModel.issues.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Issues",
                    systemImage: "exclamationmark.circle",
                    description: "No \(viewModel.stateFilter.displayName.lowercased()) issues"
                )
            } else {
                List(viewModel.issues) { issue in
                    BitbucketIssueRow(issue: issue)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.openIssueInBrowser(issue)
                        }
                        .contextMenu {
                            Button("Open in Browser") {
                                viewModel.openIssueInBrowser(issue)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.loadIssues()
        }
        .onChange(of: viewModel.stateFilter) { _ in
            Task { await viewModel.loadIssues() }
        }
    }
}

private struct BitbucketIssueRow: View {
    let issue: BitbucketIssue

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: issue.isOpen ? "exclamationmark.circle" : "checkmark.circle")
                .foregroundStyle(issue.isOpen ? .green : .purple)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("#\(issue.id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(issue.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let reporter = issue.reporter {
                        Text(reporter.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(issue.createdOn, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Priority badge
                    Text(issue.priority)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .cornerRadius(4)

                    // Kind badge
                    Text(issue.kind)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Assignee
            if let assignee = issue.assignee {
                AsyncImage(url: URL(string: assignee.avatarUrl ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color.secondary.opacity(0.3))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch issue.priority {
        case "critical": return .red
        case "major": return .orange
        case "minor": return .yellow
        case "trivial": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Credentials Sheet

private struct BitbucketCredentialsSheet: View {
    @Binding var username: String
    @Binding var appPassword: String
    @Binding var isPresented: Bool

    @State private var tempUsername: String = ""
    @State private var tempAppPassword: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bitbucket Credentials")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter your Bitbucket username and app password to access issues and pull requests.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Username", text: $tempUsername)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("App Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("App Password", text: $tempAppPassword)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Required permissions:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(["Repositories: Read", "Pull requests: Read/Write"], id: \.self) { perm in
                            Text(perm)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                Link("Create an app password", destination: URL(string: "https://bitbucket.org/account/settings/app-passwords/")!)
                    .font(.caption)
            }
            .padding()

            Divider()

            // Actions
            HStack {
                if !username.isEmpty {
                    Button("Remove Credentials", role: .destructive) {
                        username = ""
                        appPassword = ""
                        isPresented = false
                    }
                }

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    username = tempUsername
                    appPassword = tempAppPassword
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(tempUsername.isEmpty || tempAppPassword.isEmpty)
            }
            .padding()
        }
        .frame(width: 450)
        .onAppear {
            tempUsername = username
            tempAppPassword = appPassword
        }
    }
}

// MARK: - Preview

#Preview {
    BitbucketView(
        viewModel: BitbucketViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 500, height: 600)
}
