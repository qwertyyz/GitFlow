import SwiftUI

/// Menu view for git-flow operations.
/// This can be used in the menu bar or as a contextual menu.
struct GitFlowMenuContent: View {
    @ObservedObject var viewModel: GitFlowViewModel

    @State private var showInitSheet: Bool = false
    @State private var showStartFeature: Bool = false
    @State private var showFinishFeature: Bool = false
    @State private var showStartRelease: Bool = false
    @State private var showFinishRelease: Bool = false
    @State private var showStartHotfix: Bool = false
    @State private var showFinishHotfix: Bool = false

    var body: some View {
        Group {
            if viewModel.isInitialized {
                initializedMenu
            } else {
                Button("Initialize Git Flow...") {
                    showInitSheet = true
                }
            }
        }
        .sheet(isPresented: $showInitSheet) {
            GitFlowInitSheet(viewModel: viewModel, isPresented: $showInitSheet)
        }
        .sheet(isPresented: $showStartFeature) {
            GitFlowStartBranchSheet(
                viewModel: viewModel,
                branchType: .feature,
                isPresented: $showStartFeature
            )
        }
        .sheet(isPresented: $showFinishFeature) {
            GitFlowFinishBranchSheet(
                viewModel: viewModel,
                branchType: .feature,
                isPresented: $showFinishFeature
            )
        }
        .sheet(isPresented: $showStartRelease) {
            GitFlowStartBranchSheet(
                viewModel: viewModel,
                branchType: .release,
                isPresented: $showStartRelease
            )
        }
        .sheet(isPresented: $showFinishRelease) {
            GitFlowFinishBranchSheet(
                viewModel: viewModel,
                branchType: .release,
                isPresented: $showFinishRelease
            )
        }
        .sheet(isPresented: $showStartHotfix) {
            GitFlowStartBranchSheet(
                viewModel: viewModel,
                branchType: .hotfix,
                isPresented: $showStartHotfix
            )
        }
        .sheet(isPresented: $showFinishHotfix) {
            GitFlowFinishBranchSheet(
                viewModel: viewModel,
                branchType: .hotfix,
                isPresented: $showFinishHotfix
            )
        }
    }

    @ViewBuilder
    private var initializedMenu: some View {
        // Feature submenu
        Menu("Feature") {
            Button("Start New Feature...") {
                showStartFeature = true
            }

            if viewModel.hasActiveFeatures {
                Divider()
                Button("Finish Feature...") {
                    showFinishFeature = true
                }
            }
        }

        // Release submenu
        Menu("Release") {
            Button("Start New Release...") {
                showStartRelease = true
            }

            if viewModel.hasActiveReleases {
                Divider()
                Button("Finish Release...") {
                    showFinishRelease = true
                }
            }
        }

        // Hotfix submenu
        Menu("Hotfix") {
            Button("Start New Hotfix...") {
                showStartHotfix = true
            }

            if viewModel.hasActiveHotfixes {
                Divider()
                Button("Finish Hotfix...") {
                    showFinishHotfix = true
                }
            }
        }

        Divider()

        // Show config info
        if let config = viewModel.config {
            Text("Main: \(config.mainBranch)")
                .foregroundStyle(.secondary)
            Text("Develop: \(config.developBranch)")
                .foregroundStyle(.secondary)
        }
    }
}

/// Sheet for starting a new git-flow branch.
struct GitFlowStartBranchSheet: View {
    @ObservedObject var viewModel: GitFlowViewModel
    let branchType: GitFlowBranchType
    @Binding var isPresented: Bool

    @State private var name: String = ""

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("Start \(branchType.displayName)")
                .font(.headline)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(branchType.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(prefix)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)

                    TextField(placeholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                if let config = viewModel.config {
                    Text("Will branch from: \(baseBranch(config))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Start \(branchType.displayName)") {
                    Task { await startBranch() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private var prefix: String {
        guard let config = viewModel.config else { return "" }
        switch branchType {
        case .feature: return config.featurePrefix
        case .release: return config.releasePrefix
        case .hotfix: return config.hotfixPrefix
        case .support: return config.supportPrefix
        }
    }

    private var placeholder: String {
        switch branchType {
        case .feature: return "feature-name"
        case .release: return "1.0.0"
        case .hotfix: return "1.0.1"
        case .support: return "1.x"
        }
    }

    private func baseBranch(_ config: GitFlowConfig) -> String {
        switch branchType {
        case .feature, .release: return config.developBranch
        case .hotfix, .support: return config.mainBranch
        }
    }

    private func startBranch() async {
        switch branchType {
        case .feature:
            await viewModel.startFeature(name: name)
        case .release:
            await viewModel.startRelease(version: name)
        case .hotfix:
            await viewModel.startHotfix(version: name)
        case .support:
            // Support not fully implemented
            break
        }

        if viewModel.error == nil {
            isPresented = false
        }
    }
}

/// Sheet for finishing a git-flow branch.
struct GitFlowFinishBranchSheet: View {
    @ObservedObject var viewModel: GitFlowViewModel
    let branchType: GitFlowBranchType
    @Binding var isPresented: Bool

    @State private var selectedBranch: String = ""
    @State private var tagMessage: String = ""
    @State private var deleteBranch: Bool = true

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("Finish \(branchType.displayName)")
                .font(.headline)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Select the \(branchType.rawValue) to finish:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Picker("Branch", selection: $selectedBranch) {
                    ForEach(activeBranches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .pickerStyle(.menu)

                if branchType == .release || branchType == .hotfix {
                    TextField("Tag message (optional)", text: $tagMessage)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Delete branch after finishing", isOn: $deleteBranch)
                    .toggleStyle(.checkbox)

                if let config = viewModel.config {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This will:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("• Merge into \(config.mainBranch)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if branchType == .release || branchType == .hotfix {
                            Text("• Merge into \(config.developBranch)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("• Create a version tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, DSSpacing.sm)
                }
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Finish \(branchType.displayName)") {
                    Task { await finishBranch() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedBranch.isEmpty || viewModel.isOperationInProgress)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            if let first = activeBranches.first {
                selectedBranch = first
            }
        }
    }

    private var activeBranches: [String] {
        switch branchType {
        case .feature:
            return viewModel.state.activeFeatures
        case .release:
            return viewModel.state.activeReleases
        case .hotfix:
            return viewModel.state.activeHotfixes
        case .support:
            return []
        }
    }

    private func finishBranch() async {
        guard let config = viewModel.config else { return }

        // Extract the name without prefix
        let name: String
        switch branchType {
        case .feature:
            name = config.featureName(from: selectedBranch) ?? selectedBranch
            await viewModel.finishFeature(name: name, deleteBranch: deleteBranch)
        case .release:
            name = config.releaseVersion(from: selectedBranch) ?? selectedBranch
            await viewModel.finishRelease(
                version: name,
                tagMessage: tagMessage.isEmpty ? nil : tagMessage,
                deleteBranch: deleteBranch
            )
        case .hotfix:
            name = config.hotfixVersion(from: selectedBranch) ?? selectedBranch
            await viewModel.finishHotfix(
                version: name,
                tagMessage: tagMessage.isEmpty ? nil : tagMessage,
                deleteBranch: deleteBranch
            )
        case .support:
            break
        }

        if viewModel.error == nil {
            isPresented = false
        }
    }
}

#Preview {
    GitFlowMenuContent(
        viewModel: GitFlowViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
}
