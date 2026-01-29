import SwiftUI

/// Sheet for creating a new pull request on GitHub.
struct CreatePullRequestSheet: View {
    @ObservedObject var viewModel: GitHubViewModel
    @Binding var isPresented: Bool

    /// The branch to create a PR from.
    let headBranch: String

    @State private var title: String = ""
    @State private var prBody: String = ""
    @State private var baseBranch: String = ""
    @State private var isDraft: Bool = false
    @State private var isCreating: Bool = false
    @State private var error: String?
    @State private var availableBranches: [GitHubBranch] = []
    @State private var isLoadingBranches: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Pull Request")
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

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    // Branch info
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Branches")
                            .font(DSTypography.subsectionTitle())

                        HStack(spacing: DSSpacing.md) {
                            // Base branch picker
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Base")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if isLoadingBranches {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(height: 28)
                                } else {
                                    Picker("", selection: $baseBranch) {
                                        ForEach(availableBranches) { branch in
                                            Text(branch.name).tag(branch.name)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 150)
                                }
                            }

                            Image(systemName: "arrow.left")
                                .foregroundStyle(.secondary)

                            // Head branch (fixed)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Compare")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(headBranch)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(DSRadius.sm)
                            }
                        }
                    }

                    Divider()

                    // Title
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Title")
                            .font(DSTypography.subsectionTitle())

                        TextField("Add a title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Description")
                            .font(DSTypography.subsectionTitle())

                        TextEditor(text: $prBody)
                            .font(.body)
                            .frame(minHeight: 150)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(DSRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DSRadius.sm)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )

                        Text("Supports Markdown formatting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Options
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Options")
                            .font(DSTypography.subsectionTitle())

                        Toggle("Create as draft", isOn: $isDraft)
                            .toggleStyle(.checkbox)

                        Text("Draft PRs cannot be merged until marked as ready for review")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Error message
                    if let error = error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                        .font(.callout)
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isDraft ? "Create Draft PR" : "Create Pull Request") {
                    Task {
                        await createPullRequest()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || baseBranch.isEmpty || isCreating)
            }
            .padding()
        }
        .frame(width: 550, height: 550)
        .task {
            await loadBranches()
            // Pre-fill title from branch name
            if title.isEmpty {
                title = headBranch
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "feature/", with: "")
                    .replacingOccurrences(of: "fix/", with: "Fix: ")
                    .replacingOccurrences(of: "bugfix/", with: "Bug fix: ")
                    .capitalized
            }
        }
    }

    private func loadBranches() async {
        isLoadingBranches = true
        defer { isLoadingBranches = false }

        do {
            if let info = viewModel.remoteInfo {
                availableBranches = try await viewModel.githubService.getBranches(
                    owner: info.owner,
                    repo: info.repo
                )

                // Set default base branch
                if baseBranch.isEmpty {
                    // Prefer main/master/develop
                    if let mainBranch = availableBranches.first(where: { $0.name == "main" }) {
                        baseBranch = mainBranch.name
                    } else if let masterBranch = availableBranches.first(where: { $0.name == "master" }) {
                        baseBranch = masterBranch.name
                    } else if let developBranch = availableBranches.first(where: { $0.name == "develop" }) {
                        baseBranch = developBranch.name
                    } else if let firstBranch = availableBranches.first {
                        baseBranch = firstBranch.name
                    }
                }
            }
        } catch {
            self.error = "Failed to load branches: \(error.localizedDescription)"
        }
    }

    private func createPullRequest() async {
        guard let info = viewModel.remoteInfo else {
            error = "GitHub remote not found"
            return
        }

        isCreating = true
        error = nil

        do {
            let pr = try await viewModel.githubService.createPullRequest(
                owner: info.owner,
                repo: info.repo,
                title: title,
                body: prBody.isEmpty ? nil : prBody,
                head: headBranch,
                base: baseBranch,
                draft: isDraft
            )

            // Refresh PR list and close sheet
            await viewModel.refresh()
            isPresented = false

            // Open the new PR in browser
            await viewModel.githubService.openPullRequestInBrowser(
                owner: info.owner,
                repo: info.repo,
                number: pr.number
            )
        } catch {
            self.error = error.localizedDescription
        }

        isCreating = false
    }
}

#Preview {
    CreatePullRequestSheet(
        viewModel: GitHubViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        isPresented: .constant(true),
        headBranch: "feature/new-feature"
    )
}
