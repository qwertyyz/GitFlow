import SwiftUI

/// Sheet for setting the upstream tracking branch.
struct SetUpstreamSheet: View {
    @ObservedObject var viewModel: BranchViewModel
    let branch: Branch
    @Binding var isPresented: Bool

    @State private var selectedRemoteBranch: Branch?
    @State private var isSetting: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Set Upstream")
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.green)
                        Text(branch.name)
                            .font(.body.monospaced())
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upstream Branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.remoteBranches.isEmpty {
                        Text("No remote branches available")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    } else {
                        Picker("Upstream Branch", selection: $selectedRemoteBranch) {
                            Text("Select a branch...").tag(nil as Branch?)
                            ForEach(viewModel.remoteBranches) { remoteBranch in
                                Text(remoteBranch.name).tag(remoteBranch as Branch?)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setting an upstream branch allows you to:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Label("Use git pull/push without specifying a branch", systemImage: "arrow.up.arrow.down")
                        Label("See ahead/behind status", systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Set Upstream") {
                    setUpstream()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedRemoteBranch == nil || isSetting)
            }
            .padding()
        }
        .frame(width: 400)
        .onAppear {
            // Pre-select matching remote branch if exists
            let matchingName = "origin/\(branch.name)"
            selectedRemoteBranch = viewModel.remoteBranches.first { $0.name == matchingName }
        }
    }

    private func setUpstream() {
        guard let remoteBranch = selectedRemoteBranch else { return }

        isSetting = true

        Task {
            await viewModel.setUpstream(branchName: branch.name, upstreamRef: remoteBranch.name)

            isSetting = false
            if viewModel.error == nil {
                isPresented = false
            }
        }
    }
}

#Preview {
    SetUpstreamSheet(
        viewModel: BranchViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        branch: .local(name: "feature/test", commitHash: "abc123"),
        isPresented: .constant(true)
    )
}
