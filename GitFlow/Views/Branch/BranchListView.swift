import SwiftUI

/// View displaying all branches.
struct BranchListView: View {
    @ObservedObject var viewModel: BranchViewModel

    @State private var showCreateBranch: Bool = false
    @State private var branchToDelete: Branch?
    @State private var branchToRename: Branch?
    @State private var branchToMerge: Branch?
    @State private var branchToRebase: Branch?
    @State private var branchToCompare: Branch?
    @State private var branchToSetUpstream: Branch?

    // Local selection state to avoid "Publishing changes from within view updates" warning
    @State private var localSelectedBranch: Branch?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Branches")
                    .font(.headline)

                Spacer()

                // Show merge/rebase in progress indicator
                if viewModel.repositoryState.isMerging {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.merge")
                            .foregroundStyle(.orange)
                        Text("Merging")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else if viewModel.repositoryState.isRebasing {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundStyle(.orange)
                        Text("Rebasing")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Toggle("Remote", isOn: $viewModel.showRemoteBranches)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                Button(action: { showCreateBranch = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new branch")

                if viewModel.isLoading || viewModel.isOperationInProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Merge/Rebase in progress actions
            if viewModel.repositoryState.isMerging || viewModel.repositoryState.isRebasing {
                MergeRebaseActionsView(viewModel: viewModel)
            }

            // Branch list
            if viewModel.displayBranches.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    "No Branches",
                    systemImage: "arrow.triangle.branch",
                    description: "No branches found in this repository"
                )
            } else {
                List(selection: $localSelectedBranch) {
                    // Local branches
                    Section("Local") {
                        ForEach(viewModel.localBranches) { branch in
                            BranchRow(branch: branch)
                                .tag(branch)
                                .contextMenu {
                                    localBranchContextMenu(for: branch)
                                }
                        }
                    }

                    // Remote branches
                    if viewModel.showRemoteBranches && !viewModel.remoteBranches.isEmpty {
                        Section("Remote") {
                            ForEach(viewModel.remoteBranches) { branch in
                                BranchRow(branch: branch)
                                    .tag(branch)
                                    .contextMenu {
                                        remoteBranchContextMenu(for: branch)
                                    }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .onChange(of: localSelectedBranch) { newValue in
                    // Defer sync to view model to avoid "Publishing changes from within view updates"
                    Task { @MainActor in
                        viewModel.selectedBranch = newValue
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateBranch) {
            BranchCreationSheet(viewModel: viewModel, isPresented: $showCreateBranch)
        }
        .sheet(item: $branchToRename) { branch in
            BranchRenameSheet(viewModel: viewModel, branch: branch, isPresented: .init(
                get: { branchToRename != nil },
                set: { if !$0 { branchToRename = nil } }
            ))
        }
        .sheet(item: $branchToMerge) { branch in
            MergeBranchSheet(viewModel: viewModel, sourceBranch: branch, isPresented: .init(
                get: { branchToMerge != nil },
                set: { if !$0 { branchToMerge = nil } }
            ))
        }
        .sheet(item: $branchToRebase) { branch in
            RebaseBranchSheet(viewModel: viewModel, ontoBranch: branch, isPresented: .init(
                get: { branchToRebase != nil },
                set: { if !$0 { branchToRebase = nil } }
            ))
        }
        .sheet(item: $branchToCompare) { branch in
            BranchCompareSheet(viewModel: viewModel, compareBranch: branch, isPresented: .init(
                get: { branchToCompare != nil },
                set: { if !$0 { branchToCompare = nil } }
            ))
        }
        .sheet(item: $branchToSetUpstream) { branch in
            SetUpstreamSheet(viewModel: viewModel, branch: branch, isPresented: .init(
                get: { branchToSetUpstream != nil },
                set: { if !$0 { branchToSetUpstream = nil } }
            ))
        }
        .confirmationDialog(
            "Delete Branch",
            isPresented: .init(
                get: { branchToDelete != nil },
                set: { if !$0 { branchToDelete = nil } }
            ),
            presenting: branchToDelete
        ) { branch in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteBranch(name: branch.name) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { branch in
            Text("Are you sure you want to delete the branch '\(branch.name)'?")
        }
        .alert("Something went wrong", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .task {
            await viewModel.refreshRepositoryState()
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func localBranchContextMenu(for branch: Branch) -> some View {
        if !branch.isCurrent {
            Button("Checkout") {
                Task { await viewModel.checkout(branch: branch) }
            }

            Divider()

            Button("Merge into Current Branch...") {
                branchToMerge = branch
            }

            Button("Rebase Current Branch onto This...") {
                branchToRebase = branch
            }

            Divider()

            Button("Compare with Current Branch...") {
                branchToCompare = branch
            }

            Divider()
        }

        Button("Rename...") {
            branchToRename = branch
        }

        if branch.upstream != nil {
            Button("Unset Upstream") {
                Task { await viewModel.unsetUpstream(branchName: branch.name) }
            }
        } else {
            Button("Set Upstream...") {
                branchToSetUpstream = branch
            }
        }

        if !branch.isCurrent {
            Divider()

            Button("Delete", role: .destructive) {
                branchToDelete = branch
            }
        }
    }

    @ViewBuilder
    private func remoteBranchContextMenu(for branch: Branch) -> some View {
        Button("Checkout") {
            Task { await viewModel.checkout(branchName: branch.name) }
        }

        Divider()

        Button("Merge into Current Branch...") {
            branchToMerge = branch
        }

        Button("Rebase Current Branch onto This...") {
            branchToRebase = branch
        }

        Divider()

        Button("Compare with Current Branch...") {
            branchToCompare = branch
        }
    }
}

// MARK: - Merge/Rebase Actions View

/// Actions shown when a merge or rebase is in progress.
private struct MergeRebaseActionsView: View {
    @ObservedObject var viewModel: BranchViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.repositoryState.isMerging {
                Button("Abort Merge") {
                    Task { await viewModel.abortMerge() }
                }
                .buttonStyle(.bordered)

                Button("Continue Merge") {
                    Task { await viewModel.continueMerge() }
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.repositoryState.isRebasing {
                Button("Abort Rebase") {
                    Task { await viewModel.abortRebase() }
                }
                .buttonStyle(.bordered)

                Button("Skip") {
                    Task { await viewModel.skipRebase() }
                }
                .buttonStyle(.bordered)

                Button("Continue Rebase") {
                    Task { await viewModel.continueRebase() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))

        Divider()
    }
}

#Preview {
    BranchListView(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 300, height: 400)
}
