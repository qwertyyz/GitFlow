import SwiftUI

/// Main content area that displays the selected section.
struct ContentArea: View {
    let selectedSection: SidebarSection
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        switch selectedSection {
        case .changes:
            ChangesView(
                statusViewModel: viewModel.statusViewModel,
                diffViewModel: viewModel.diffViewModel,
                commitViewModel: viewModel.commitViewModel
            )
        case .history:
            HistoryView(
                historyViewModel: viewModel.historyViewModel,
                diffViewModel: viewModel.diffViewModel
            )
        case .branches:
            BranchesView(viewModel: viewModel.branchViewModel)
        case .branchesReview:
            BranchesReviewSectionView(viewModel: viewModel)
        case .archivedBranches:
            ArchivedBranchesSectionView(viewModel: viewModel)
        case .stashes:
            StashesView(viewModel: viewModel.stashViewModel)
        case .tags:
            TagsView(viewModel: viewModel.tagViewModel)
        case .reflog:
            ReflogSectionView(viewModel: viewModel)
        case .sync:
            SyncView(
                remoteViewModel: viewModel.remoteViewModel,
                branchViewModel: viewModel.branchViewModel
            )
        case .fileTree:
            FileTreeSectionView(viewModel: viewModel)
        case .submodules:
            SubmoduleSectionView(viewModel: viewModel)
        case .worktrees:
            WorktreesSectionView(viewModel: viewModel)
        case .remotes:
            RemotesSectionView(viewModel: viewModel)
        case .pullRequests:
            PullRequestsSectionView(viewModel: viewModel)
        case .github:
            GitHubSectionView(viewModel: viewModel)
        case .gitlab:
            GitLabSectionView(viewModel: viewModel)
        case .bitbucket:
            BitbucketSectionView(viewModel: viewModel)
        case .azureDevOps:
            AzureDevOpsSectionView(viewModel: viewModel)
        case .gitea:
            GiteaSectionView(viewModel: viewModel)
        case .beanstalk:
            BeanstalkSectionView(viewModel: viewModel)
        }
    }
}

/// Wrapper view for file tree browser.
struct FileTreeSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var fileTreeViewModel: FileTreeViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._fileTreeViewModel = StateObject(wrappedValue: FileTreeViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        FileTreeView(viewModel: fileTreeViewModel)
            .task {
                await fileTreeViewModel.loadTree()
            }
    }
}

/// Wrapper view for submodules.
struct SubmoduleSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var submoduleViewModel: SubmoduleViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._submoduleViewModel = StateObject(wrappedValue: SubmoduleViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        SubmoduleListView(viewModel: submoduleViewModel)
            .task {
                await submoduleViewModel.refresh()
            }
    }
}

/// Wrapper view for GitHub integration.
struct GitHubSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var githubViewModel: GitHubViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._githubViewModel = StateObject(wrappedValue: GitHubViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        GitHubView(viewModel: githubViewModel)
    }
}

/// Combined view for working tree changes, staging, and commit creation.
struct ChangesView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @ObservedObject var diffViewModel: DiffViewModel
    @ObservedObject var commitViewModel: CommitViewModel

    @State private var isDiffFullscreen: Bool = false

    var body: some View {
        HSplitView {
            // Left panel: File list and commit
            if !isDiffFullscreen {
                VStack(spacing: 0) {
                    FileStatusList(viewModel: statusViewModel)

                    Divider()

                    CommitCreationView(
                        viewModel: commitViewModel,
                        canCommit: statusViewModel.canCommit
                    )
                }
                .frame(minWidth: 250, maxWidth: 350)
            }

            // Right panel: Diff view
            DiffView(viewModel: diffViewModel, isFullscreen: $isDiffFullscreen)
                .frame(minWidth: 400)
        }
    }
}

/// View for commit history.
struct HistoryView: View {
    @ObservedObject var historyViewModel: HistoryViewModel
    @ObservedObject var diffViewModel: DiffViewModel

    @State private var isDiffFullscreen: Bool = false

    var body: some View {
        HSplitView {
            // Left: Commit list
            if !isDiffFullscreen {
                CommitHistoryView(viewModel: historyViewModel)
                    .frame(minWidth: 300, maxWidth: 400)
            }

            // Right: Commit diff or details
            VStack {
                if let commit = historyViewModel.selectedCommit {
                    if !isDiffFullscreen {
                        CommitDetailView(commit: commit)
                            .frame(height: 150)

                        Divider()
                    }

                    DiffView(viewModel: diffViewModel, isFullscreen: $isDiffFullscreen)
                } else {
                    EmptyStateView(
                        "Select a Commit",
                        systemImage: "clock",
                        description: "Select a commit from the list to view its changes"
                    )
                }
            }
            .frame(minWidth: 400)
            .task(id: historyViewModel.selectedCommit?.hash) {
                if let commit = historyViewModel.selectedCommit {
                    await diffViewModel.loadCommitDiff(for: commit.hash)
                }
            }
        }
    }
}

/// View for branch management.
struct BranchesView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        BranchListView(viewModel: viewModel)
    }
}

/// View for stash management.
struct StashesView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        StashListView(viewModel: viewModel)
    }
}

/// View for tag management.
struct TagsView: View {
    @ObservedObject var viewModel: TagViewModel

    var body: some View {
        TagListView(viewModel: viewModel)
    }
}

/// View for remote sync operations.
struct SyncView: View {
    @ObservedObject var remoteViewModel: RemoteViewModel
    @ObservedObject var branchViewModel: BranchViewModel

    var body: some View {
        RemoteView(viewModel: remoteViewModel, branchViewModel: branchViewModel)
    }
}

/// Wrapper view for reflog.
struct ReflogSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var reflogViewModel: ReflogViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._reflogViewModel = StateObject(wrappedValue: ReflogViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        ReflogView(viewModel: reflogViewModel)
            .task {
                await reflogViewModel.refresh()
            }
    }
}

/// Wrapper view for branches review.
struct BranchesReviewSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        BranchesReviewView(viewModel: viewModel.branchViewModel)
    }
}

/// Wrapper view for archived branches.
struct ArchivedBranchesSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        ArchivedBranchesView(viewModel: viewModel.branchViewModel)
    }
}

/// Wrapper view for worktrees.
struct WorktreesSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        WorktreeView(repository: viewModel.repository)
    }
}

/// Wrapper view for remotes management.
struct RemotesSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        RemoteManagementView(viewModel: viewModel.remoteViewModel)
    }
}

/// Wrapper view for pull requests (unified across services).
struct PullRequestsSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        UnifiedPullRequestsView(repository: viewModel.repository)
    }
}

/// Wrapper view for GitLab integration.
struct GitLabSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var gitLabViewModel: GitLabViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._gitLabViewModel = StateObject(wrappedValue: GitLabViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        GitLabView(viewModel: gitLabViewModel)
    }
}

/// Wrapper view for Bitbucket integration.
struct BitbucketSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @StateObject private var bitbucketViewModel: BitbucketViewModel

    init(viewModel: RepositoryViewModel) {
        self.viewModel = viewModel
        self._bitbucketViewModel = StateObject(wrappedValue: BitbucketViewModel(
            repository: viewModel.repository,
            gitService: viewModel.gitService
        ))
    }

    var body: some View {
        BitbucketView(viewModel: bitbucketViewModel)
    }
}

/// Wrapper view for Azure DevOps integration.
struct AzureDevOpsSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        AzureDevOpsView()
    }
}

/// Wrapper view for Gitea integration.
struct GiteaSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        GiteaView()
    }
}

/// Wrapper view for Beanstalk integration.
struct BeanstalkSectionView: View {
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        BeanstalkView()
    }
}

// MARK: - Placeholder Views for new sections

/// Branches review view showing stale branches, merge status, etc.
struct BranchesReviewView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        VStack {
            Text("Branches Review")
                .font(.title2)
                .padding()

            List {
                Section("Stale Branches") {
                    ForEach(viewModel.staleBranches, id: \.name) { branch in
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Text(branch.name)
                            Spacer()
                            Text("Last activity: \(branch.lastCommitDate?.formatted(.relative(presentation: .named)) ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Merged Branches") {
                    ForEach(viewModel.mergedBranches, id: \.name) { branch in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(branch.name)
                            Spacer()
                            Button("Delete") {
                                Task { await viewModel.deleteBranch(name: branch.name, force: false) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

/// Archived branches view.
struct ArchivedBranchesView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        VStack {
            if viewModel.archivedBranches.isEmpty {
                EmptyStateView(
                    "No Archived Branches",
                    systemImage: "archivebox",
                    description: "Archive branches you want to keep but hide from the main list"
                )
            } else {
                List(viewModel.archivedBranches, id: \.name) { branch in
                    HStack {
                        Image(systemName: "archivebox")
                            .foregroundColor(.secondary)
                        Text(branch.name)
                        Spacer()
                        Button("Unarchive") {
                            Task { await viewModel.unarchiveBranch(branch.name) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .contextMenu {
                        Button("Unarchive") {
                            Task { await viewModel.unarchiveBranch(branch.name) }
                        }
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteBranch(name: branch.name, force: true) }
                        }
                    }
                }
            }
        }
    }
}

/// Remote management view (detailed remotes).
struct RemoteManagementView: View {
    @ObservedObject var viewModel: RemoteViewModel

    var body: some View {
        VStack {
            HStack {
                Text("Remotes")
                    .font(.title2)
                Spacer()
                Button("Add Remote...") {
                    // Show add remote sheet
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            List(viewModel.remotes, id: \.name) { remote in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text(remote.name)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Fetch:")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(remote.fetchURL)
                                .fontDesign(.monospaced)
                                .font(.caption)
                        }
                        HStack {
                            Text("Push:")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(remote.pushURL)
                                .fontDesign(.monospaced)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button("Fetch") {
                        Task { await viewModel.fetch(remote: remote.name) }
                    }
                    Button("Prune") {
                        Task { await viewModel.prune(remote: remote.name) }
                    }
                    Divider()
                    Button("Rename...") {
                        // Show rename sheet
                    }
                    Button("Edit URL...") {
                        // Show edit URL sheet
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.removeRemote(name: remote.name) }
                    }
                }
            }
        }
    }
}

/// Unified pull requests view across all services.
struct UnifiedPullRequestsView: View {
    let repository: Repository

    var body: some View {
        VStack {
            Text("Pull Requests")
                .font(.title2)
                .padding()

            Text("Pull requests from all connected services will appear here.")
                .foregroundColor(.secondary)
                .padding()

            Spacer()
        }
    }
}
