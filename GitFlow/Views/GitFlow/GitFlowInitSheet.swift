import SwiftUI

/// Sheet for initializing git-flow in a repository.
struct GitFlowInitSheet: View {
    @ObservedObject var viewModel: GitFlowViewModel
    @Binding var isPresented: Bool

    @State private var mainBranch: String = "main"
    @State private var developBranch: String = "develop"
    @State private var featurePrefix: String = "feature/"
    @State private var releasePrefix: String = "release/"
    @State private var hotfixPrefix: String = "hotfix/"
    @State private var supportPrefix: String = "support/"
    @State private var versionTagPrefix: String = "v"
    @State private var useDefaults: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Initialize Git Flow")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    // Description
                    Text("Git-flow is a branching model that helps teams manage feature development, releases, and hotfixes in a structured way.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    // Quick setup toggle
                    Toggle("Use recommended defaults", isOn: $useDefaults)
                        .onChange(of: useDefaults) { newValue in
                            if newValue {
                                resetToDefaults()
                            }
                        }

                    Divider()

                    // Branch configuration
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text("Branch Configuration")
                            .font(DSTypography.subsectionTitle())

                        LabeledTextField(label: "Main branch", text: $mainBranch)
                            .disabled(useDefaults)

                        LabeledTextField(label: "Develop branch", text: $developBranch)
                            .disabled(useDefaults)
                    }

                    // Prefix configuration
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text("Branch Prefixes")
                            .font(DSTypography.subsectionTitle())

                        LabeledTextField(label: "Feature prefix", text: $featurePrefix)
                            .disabled(useDefaults)

                        LabeledTextField(label: "Release prefix", text: $releasePrefix)
                            .disabled(useDefaults)

                        LabeledTextField(label: "Hotfix prefix", text: $hotfixPrefix)
                            .disabled(useDefaults)

                        LabeledTextField(label: "Support prefix", text: $supportPrefix)
                            .disabled(useDefaults)

                        LabeledTextField(label: "Version tag prefix", text: $versionTagPrefix)
                            .disabled(useDefaults)
                    }

                    // Info box
                    VStack(alignment: .leading, spacing: 4) {
                        Label("What happens when you initialize:", systemImage: "info.circle")
                            .font(.caption)
                            .fontWeight(.medium)

                        Text("• Git config values will be set for git-flow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("• A '\(developBranch)' branch will be created if it doesn't exist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(DSRadius.md)
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Initialize Git Flow") {
                    Task {
                        await initialize()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isOperationInProgress || !isValid)
            }
            .padding()
        }
        .frame(width: 450, height: 580)
    }

    private var isValid: Bool {
        !mainBranch.isEmpty &&
        !developBranch.isEmpty &&
        !featurePrefix.isEmpty &&
        !releasePrefix.isEmpty &&
        !hotfixPrefix.isEmpty
    }

    private func resetToDefaults() {
        mainBranch = "main"
        developBranch = "develop"
        featurePrefix = "feature/"
        releasePrefix = "release/"
        hotfixPrefix = "hotfix/"
        supportPrefix = "support/"
        versionTagPrefix = "v"
    }

    private func initialize() async {
        let config = GitFlowConfig(
            mainBranch: mainBranch,
            developBranch: developBranch,
            featurePrefix: featurePrefix,
            releasePrefix: releasePrefix,
            hotfixPrefix: hotfixPrefix,
            supportPrefix: supportPrefix,
            versionTagPrefix: versionTagPrefix
        )

        await viewModel.initialize(with: config)

        if viewModel.error == nil {
            isPresented = false
        }
    }
}

/// A labeled text field for the form.
private struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)

            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    GitFlowInitSheet(
        viewModel: GitFlowViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        isPresented: .constant(true)
    )
}
