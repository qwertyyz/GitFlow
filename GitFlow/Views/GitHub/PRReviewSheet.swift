import SwiftUI

/// Sheet for submitting a review on a pull request.
struct PRReviewSheet: View {
    @ObservedObject var viewModel: GitHubViewModel
    let pullRequest: GitHubPullRequest
    @Binding var isPresented: Bool

    @State private var selectedEvent: ReviewEventOption = .comment
    @State private var reviewBody: String = ""
    @State private var isSubmitting: Bool = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Submit Review")
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
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                // PR info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pull Request #\(pullRequest.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pullRequest.title)
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DSRadius.sm)

                // Review type selection
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Review Type")
                        .font(DSTypography.subsectionTitle())

                    ForEach(ReviewEventOption.allCases) { option in
                        ReviewOptionRow(
                            option: option,
                            isSelected: selectedEvent == option
                        ) {
                            selectedEvent = option
                        }
                    }
                }

                // Review comment
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Review Comment")
                        .font(DSTypography.subsectionTitle())

                    if selectedEvent == .requestChanges {
                        Text("A comment is required when requesting changes")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    TextEditor(text: $reviewBody)
                        .font(.body)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(DSRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.sm)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if reviewBody.isEmpty {
                                Text("Leave a comment about your review...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
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

            Spacer()

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(selectedEvent.submitButtonTitle) {
                    Task { await submitReview() }
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedEvent.buttonColor)
                .keyboardShortcut(.defaultAction)
                .disabled(isSubmitting || !canSubmit)
            }
            .padding()
        }
        .frame(width: 500, height: 520)
    }

    private var canSubmit: Bool {
        if selectedEvent == .requestChanges {
            return !reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func submitReview() async {
        guard let info = viewModel.remoteInfo else {
            error = "GitHub remote not found"
            return
        }

        isSubmitting = true
        error = nil

        do {
            _ = try await viewModel.githubService.submitReview(
                owner: info.owner,
                repo: info.repo,
                pullNumber: pullRequest.number,
                body: reviewBody.isEmpty ? nil : reviewBody,
                event: selectedEvent.apiEvent
            )

            await viewModel.refresh()
            isPresented = false
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}

/// Review event options.
enum ReviewEventOption: String, CaseIterable, Identifiable {
    case approve
    case requestChanges
    case comment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .approve: return "Approve"
        case .requestChanges: return "Request changes"
        case .comment: return "Comment"
        }
    }

    var description: String {
        switch self {
        case .approve: return "Submit feedback and approve merging these changes"
        case .requestChanges: return "Submit feedback that must be addressed before merging"
        case .comment: return "Submit general feedback without explicit approval"
        }
    }

    var icon: String {
        switch self {
        case .approve: return "checkmark.circle.fill"
        case .requestChanges: return "xmark.circle.fill"
        case .comment: return "text.bubble"
        }
    }

    var iconColor: Color {
        switch self {
        case .approve: return DSColors.addition
        case .requestChanges: return DSColors.deletion
        case .comment: return DSColors.info
        }
    }

    var buttonColor: Color {
        switch self {
        case .approve: return DSColors.addition
        case .requestChanges: return DSColors.deletion
        case .comment: return .accentColor
        }
    }

    var submitButtonTitle: String {
        switch self {
        case .approve: return "Approve"
        case .requestChanges: return "Request Changes"
        case .comment: return "Submit Review"
        }
    }

    var apiEvent: GitHubService.ReviewEvent {
        switch self {
        case .approve: return .approve
        case .requestChanges: return .requestChanges
        case .comment: return .comment
        }
    }
}

/// Row for a review option.
struct ReviewOptionRow: View {
    let option: ReviewEventOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Image(systemName: option.icon)
                    .foregroundStyle(option.iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .fontWeight(isSelected ? .medium : .regular)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, DSSpacing.sm)
            .padding(.horizontal, DSSpacing.md)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(DSRadius.sm)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PRReviewSheet(
        viewModel: GitHubViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        ),
        pullRequest: GitHubPullRequest(
            id: 1,
            number: 123,
            title: "Add new feature for user authentication",
            body: nil,
            state: "open",
            htmlUrl: "https://github.com",
            user: GitHubUser(id: 1, login: "test", avatarUrl: "", htmlUrl: "", type: "User"),
            labels: [],
            assignees: [],
            createdAt: Date(),
            updatedAt: Date(),
            closedAt: nil,
            mergedAt: nil,
            head: GitHubBranchRef(ref: "feature", sha: "abc", repo: nil),
            base: GitHubBranchRef(ref: "main", sha: "def", repo: nil),
            isDraft: false,
            mergeable: true,
            additions: nil,
            deletions: nil,
            changedFiles: nil
        ),
        isPresented: .constant(true)
    )
}
