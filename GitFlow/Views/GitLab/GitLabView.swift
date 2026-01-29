import SwiftUI

/// Main view for GitLab integration.
struct GitLabView: View {
    @ObservedObject var viewModel: GitLabViewModel

    @State private var selectedTab: Tab = .mergeRequests
    @State private var showTokenSheet: Bool = false

    enum Tab: String, CaseIterable, Identifiable {
        case mergeRequests = "Merge Requests"
        case issues = "Issues"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .mergeRequests: return "arrow.triangle.pull"
            case .issues: return "exclamationmark.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            GitLabHeader(
                viewModel: viewModel,
                showTokenSheet: $showTokenSheet
            )

            Divider()

            // Content
            if !viewModel.isGitLabRepository {
                notGitLabView
            } else if !viewModel.isAuthenticated {
                notAuthenticatedView
            } else {
                authenticatedContent
            }
        }
        .task {
            await viewModel.initialize()
            if viewModel.isAuthenticated {
                await viewModel.loadProject()
            }
        }
        .sheet(isPresented: $showTokenSheet) {
            GitLabTokenSheet(
                token: $viewModel.gitlabToken,
                host: $viewModel.gitlabHost,
                isPresented: $showTokenSheet
            )
        }
        .alert("GitLab Error", isPresented: .init(
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

    private var notGitLabView: some View {
        EmptyStateView(
            "Not a GitLab Repository",
            systemImage: "xmark.octagon",
            description: "This repository is not hosted on GitLab"
        )
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("GitLab Access Token Required")
                .font(.headline)

            Text("Add a personal access token to view issues and merge requests.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showTokenSheet = true
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Add Access Token")
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
                ForEach(GitLabViewModel.StateFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // Content based on tab
            switch selectedTab {
            case .mergeRequests:
                MergeRequestsListView(viewModel: viewModel)
            case .issues:
                GitLabIssuesListView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Header

private struct GitLabHeader: View {
    @ObservedObject var viewModel: GitLabViewModel
    @Binding var showTokenSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "cube.box")
                    Text("GitLab")
                        .font(.headline)
                }

                if let info = viewModel.gitlabInfo {
                    Text(info.projectPath)
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
            if viewModel.isGitLabRepository {
                Menu {
                    Button(action: { viewModel.openProjectInBrowser() }) {
                        Label("Open in Browser", systemImage: "safari")
                    }

                    Button(action: { viewModel.openPipelinesInBrowser() }) {
                        Label("View Pipelines", systemImage: "play.circle")
                    }

                    Divider()

                    Button(action: { showTokenSheet = true }) {
                        Label(viewModel.isAuthenticated ? "Change Token" : "Add Token", systemImage: "key")
                    }

                    if viewModel.isAuthenticated {
                        Button(action: { Task { await viewModel.refresh() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive, action: { viewModel.logout() }) {
                            Label("Remove Token", systemImage: "trash")
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

// MARK: - Merge Requests List

private struct MergeRequestsListView: View {
    @ObservedObject var viewModel: GitLabViewModel

    @State private var selectedMR: GitLabMergeRequest?
    @State private var showMergeConfirmation: Bool = false
    @State private var showCloseConfirmation: Bool = false

    var body: some View {
        Group {
            if viewModel.mergeRequests.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Merge Requests",
                    systemImage: "arrow.triangle.pull",
                    description: "No \(viewModel.stateFilter.displayName.lowercased()) merge requests"
                )
            } else {
                List(viewModel.mergeRequests, selection: $selectedMR) { mr in
                    MergeRequestRow(mr: mr)
                        .tag(mr)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMR = mr
                        }
                        .contextMenu {
                            mrContextMenu(for: mr)
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.loadMergeRequests()
        }
        .onChange(of: viewModel.stateFilter) { _ in
            Task { await viewModel.loadMergeRequests() }
        }
        .confirmationDialog(
            "Merge Request",
            isPresented: $showMergeConfirmation,
            presenting: selectedMR
        ) { mr in
            Button("Merge") {
                Task { await mergeMR(mr) }
            }
            Button("Squash and Merge") {
                Task { await mergeMR(mr, squash: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { mr in
            Text("How would you like to merge !\(mr.iid) into \(mr.targetBranch)?")
        }
        .confirmationDialog(
            "Close Merge Request",
            isPresented: $showCloseConfirmation,
            presenting: selectedMR
        ) { mr in
            Button("Close", role: .destructive) {
                Task { await closeMR(mr) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { mr in
            Text("Are you sure you want to close !\(mr.iid) without merging?")
        }
    }

    @ViewBuilder
    private func mrContextMenu(for mr: GitLabMergeRequest) -> some View {
        Button("Open in Browser") {
            viewModel.openMergeRequestInBrowser(mr)
        }

        Divider()

        if mr.isOpen {
            if mr.mergeStatus == "can_be_merged" {
                Button {
                    selectedMR = mr
                    showMergeConfirmation = true
                } label: {
                    Label("Merge", systemImage: "arrow.triangle.merge")
                }
            }

            Button {
                selectedMR = mr
                showCloseConfirmation = true
            } label: {
                Label("Close", systemImage: "xmark.circle")
            }
        }
    }

    private func mergeMR(_ mr: GitLabMergeRequest, squash: Bool = false) async {
        do {
            try await viewModel.mergeMergeRequest(mr, squash: squash)
        } catch {
            viewModel.error = error as? GitLabError
        }
    }

    private func closeMR(_ mr: GitLabMergeRequest) async {
        do {
            try await viewModel.closeMergeRequest(mr)
        } catch {
            viewModel.error = error as? GitLabError
        }
    }
}

private struct MergeRequestRow: View {
    let mr: GitLabMergeRequest

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("!\(mr.iid)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(mr.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(mr.author.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(mr.sourceBranch)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(mr.targetBranch)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                // Labels
                if !mr.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(mr.labels.prefix(3), id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if mr.labels.count > 3 {
                            Text("+\(mr.labels.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Draft badge
            if mr.isDraft {
                Text("Draft")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if mr.isMerged {
            return "arrow.triangle.merge"
        } else if mr.isOpen {
            return "arrow.triangle.pull"
        } else {
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        if mr.isMerged {
            return .purple
        } else if mr.isOpen {
            return .green
        } else {
            return .red
        }
    }
}

// MARK: - Issues List

private struct GitLabIssuesListView: View {
    @ObservedObject var viewModel: GitLabViewModel

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
                    GitLabIssueRow(issue: issue)
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

private struct GitLabIssueRow: View {
    let issue: GitLabIssue

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: issue.isOpen ? "exclamationmark.circle" : "checkmark.circle")
                .foregroundStyle(issue.isOpen ? .green : .purple)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("#\(issue.iid)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(issue.title)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(issue.author.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(issue.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Labels
                if !issue.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(issue.labels.prefix(3), id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        if issue.labels.count > 3 {
                            Text("+\(issue.labels.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Assignees
            if let assignees = issue.assignees, !assignees.isEmpty {
                HStack(spacing: -8) {
                    ForEach(assignees.prefix(3)) { assignee in
                        AsyncImage(url: URL(string: assignee.avatarUrl ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(Color.secondary.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Token Sheet

private struct GitLabTokenSheet: View {
    @Binding var token: String
    @Binding var host: String
    @Binding var isPresented: Bool

    @State private var tempToken: String = ""
    @State private var tempHost: String = "gitlab.com"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GitLab Personal Access Token")
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
                Text("Enter your GitLab personal access token to access issues and merge requests.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("GitLab Host")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("gitlab.com", text: $tempHost)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Access Token")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Token", text: $tempToken)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Required scopes:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(["api", "read_user", "read_repository"], id: \.self) { scope in
                            Text(scope)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                Link("Create a new token on GitLab", destination: URL(string: "https://\(tempHost)/-/profile/personal_access_tokens")!)
                    .font(.caption)
            }
            .padding()

            Divider()

            // Actions
            HStack {
                if !token.isEmpty {
                    Button("Remove Token", role: .destructive) {
                        token = ""
                        host = "gitlab.com"
                        isPresented = false
                    }
                }

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    token = tempToken
                    host = tempHost
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(tempToken.isEmpty)
            }
            .padding()
        }
        .frame(width: 450)
        .onAppear {
            tempToken = token
            tempHost = host
        }
    }
}

// MARK: - Preview

#Preview {
    GitLabView(
        viewModel: GitLabViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 500, height: 600)
}
