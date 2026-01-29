import SwiftUI

/// View for displaying Git learning resources and video tutorials.
struct LearningResourcesView: View {
    @State private var selectedCategory: ResourceCategory = .gettingStarted
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            List(ResourceCategory.allCases, selection: $selectedCategory) { category in
                Label(category.title, systemImage: category.icon)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .navigationTitle("Learn Git")
        } detail: {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search resources...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding()

                Divider()

                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredResources) { resource in
                            ResourceCard(resource: resource)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(selectedCategory.title)
        }
    }

    private var filteredResources: [LearningResource] {
        let categoryResources = LearningResource.resources(for: selectedCategory)
        if searchText.isEmpty {
            return categoryResources
        }
        return categoryResources.filter { resource in
            resource.title.localizedCaseInsensitiveContains(searchText) ||
            resource.description.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Resource Category

enum ResourceCategory: String, CaseIterable, Identifiable {
    case gettingStarted
    case videoTutorials
    case branching
    case merging
    case remotes
    case undoing
    case advanced
    case bestPractices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .videoTutorials: return "Video Tutorials"
        case .branching: return "Branching"
        case .merging: return "Merging & Rebasing"
        case .remotes: return "Remotes & Collaboration"
        case .undoing: return "Undoing Changes"
        case .advanced: return "Advanced Topics"
        case .bestPractices: return "Best Practices"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted: return "sparkles"
        case .videoTutorials: return "play.rectangle"
        case .branching: return "arrow.triangle.branch"
        case .merging: return "arrow.triangle.merge"
        case .remotes: return "cloud"
        case .undoing: return "arrow.uturn.backward"
        case .advanced: return "gearshape.2"
        case .bestPractices: return "checkmark.seal"
        }
    }
}

// MARK: - Learning Resource

struct LearningResource: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let type: ResourceType
    let url: URL?
    let duration: String?
    let difficulty: Difficulty
    let tags: [String]

    enum ResourceType {
        case article
        case video
        case interactive
        case documentation

        var icon: String {
            switch self {
            case .article: return "doc.text"
            case .video: return "play.rectangle.fill"
            case .interactive: return "hand.tap"
            case .documentation: return "book"
            }
        }

        var color: Color {
            switch self {
            case .article: return .blue
            case .video: return .red
            case .interactive: return .green
            case .documentation: return .orange
            }
        }
    }

    enum Difficulty: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"

        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }

    static func resources(for category: ResourceCategory) -> [LearningResource] {
        switch category {
        case .gettingStarted:
            return gettingStartedResources
        case .videoTutorials:
            return videoTutorialResources
        case .branching:
            return branchingResources
        case .merging:
            return mergingResources
        case .remotes:
            return remotesResources
        case .undoing:
            return undoingResources
        case .advanced:
            return advancedResources
        case .bestPractices:
            return bestPracticesResources
        }
    }

    // MARK: - Getting Started Resources

    static let gettingStartedResources: [LearningResource] = [
        LearningResource(
            title: "What is Git?",
            description: "Learn the fundamentals of version control and why Git has become the industry standard for tracking code changes.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Getting-Started-What-is-Git%3F"),
            duration: "10 min read",
            difficulty: .beginner,
            tags: ["basics", "introduction", "version control"]
        ),
        LearningResource(
            title: "Git Handbook",
            description: "GitHub's comprehensive guide to Git basics, covering commits, branches, and collaboration workflows.",
            type: .documentation,
            url: URL(string: "https://guides.github.com/introduction/git-handbook/"),
            duration: "15 min read",
            difficulty: .beginner,
            tags: ["basics", "github", "workflow"]
        ),
        LearningResource(
            title: "First Time Git Setup",
            description: "Configure your Git installation with your identity, editor preferences, and other essential settings.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup"),
            duration: "5 min read",
            difficulty: .beginner,
            tags: ["setup", "configuration", "basics"]
        ),
        LearningResource(
            title: "Learn Git Branching (Interactive)",
            description: "An interactive visualization tool for learning Git branching concepts through hands-on exercises.",
            type: .interactive,
            url: URL(string: "https://learngitbranching.js.org/"),
            duration: "1-2 hours",
            difficulty: .beginner,
            tags: ["interactive", "branching", "visualization"]
        ),
        LearningResource(
            title: "Pro Git Book",
            description: "The definitive guide to Git, available for free online. Covers everything from basics to advanced topics.",
            type: .documentation,
            url: URL(string: "https://git-scm.com/book/en/v2"),
            duration: "Book",
            difficulty: .beginner,
            tags: ["comprehensive", "reference", "book"]
        )
    ]

    // MARK: - Video Tutorial Resources

    static let videoTutorialResources: [LearningResource] = [
        LearningResource(
            title: "Git and GitHub for Beginners",
            description: "A comprehensive crash course covering Git fundamentals and GitHub workflows for complete beginners.",
            type: .video,
            url: URL(string: "https://www.youtube.com/watch?v=RGOj5yH7evk"),
            duration: "1 hour",
            difficulty: .beginner,
            tags: ["youtube", "beginner", "github"]
        ),
        LearningResource(
            title: "Git Tutorial for Beginners",
            description: "Learn the basics of Git version control in this beginner-friendly video tutorial.",
            type: .video,
            url: URL(string: "https://www.youtube.com/watch?v=8JJ101D3knE"),
            duration: "1 hour 10 min",
            difficulty: .beginner,
            tags: ["youtube", "beginner", "basics"]
        ),
        LearningResource(
            title: "Advanced Git Tutorial",
            description: "Deep dive into advanced Git concepts including interactive rebase, bisect, and custom hooks.",
            type: .video,
            url: URL(string: "https://www.youtube.com/watch?v=qsTthZi23VE"),
            duration: "30 min",
            difficulty: .advanced,
            tags: ["youtube", "advanced", "rebase"]
        ),
        LearningResource(
            title: "Git Branching Strategies",
            description: "Learn about different branching strategies including Git Flow, GitHub Flow, and trunk-based development.",
            type: .video,
            url: URL(string: "https://www.youtube.com/watch?v=U_IFGpJDbeU"),
            duration: "20 min",
            difficulty: .intermediate,
            tags: ["youtube", "branching", "workflow"]
        ),
        LearningResource(
            title: "Git Rebase vs Merge",
            description: "Understand the differences between rebase and merge, and when to use each approach.",
            type: .video,
            url: URL(string: "https://www.youtube.com/watch?v=CRlGDDprdOQ"),
            duration: "15 min",
            difficulty: .intermediate,
            tags: ["youtube", "rebase", "merge"]
        ),
        LearningResource(
            title: "Git Hooks Tutorial",
            description: "Automate your workflow with Git hooks. Learn to run scripts before commits, pushes, and more.",
            type: .video,
            url: URL(string: "https://www.youtube.com/watch?v=egfuwOe8nXc"),
            duration: "25 min",
            difficulty: .advanced,
            tags: ["youtube", "hooks", "automation"]
        )
    ]

    // MARK: - Branching Resources

    static let branchingResources: [LearningResource] = [
        LearningResource(
            title: "Git Branching - Basic Branching and Merging",
            description: "Learn the fundamentals of creating, switching, and merging branches in Git.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging"),
            duration: "15 min read",
            difficulty: .beginner,
            tags: ["branching", "merging", "basics"]
        ),
        LearningResource(
            title: "Git Flow Workflow",
            description: "A detailed explanation of the Git Flow branching model for release management.",
            type: .article,
            url: URL(string: "https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow"),
            duration: "20 min read",
            difficulty: .intermediate,
            tags: ["git-flow", "workflow", "branching"]
        ),
        LearningResource(
            title: "GitHub Flow",
            description: "A simpler alternative to Git Flow, ideal for continuous deployment workflows.",
            type: .article,
            url: URL(string: "https://docs.github.com/en/get-started/quickstart/github-flow"),
            duration: "10 min read",
            difficulty: .beginner,
            tags: ["github", "workflow", "branching"]
        ),
        LearningResource(
            title: "Remote Branches",
            description: "Understanding how remote-tracking branches work and how to collaborate with others.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches"),
            duration: "15 min read",
            difficulty: .intermediate,
            tags: ["remote", "branching", "collaboration"]
        )
    ]

    // MARK: - Merging Resources

    static let mergingResources: [LearningResource] = [
        LearningResource(
            title: "Git Merge",
            description: "Comprehensive guide to merging branches, including fast-forward and three-way merges.",
            type: .article,
            url: URL(string: "https://www.atlassian.com/git/tutorials/using-branches/git-merge"),
            duration: "15 min read",
            difficulty: .beginner,
            tags: ["merge", "basics", "branches"]
        ),
        LearningResource(
            title: "Git Rebase",
            description: "Learn how to use rebase to maintain a clean, linear commit history.",
            type: .article,
            url: URL(string: "https://www.atlassian.com/git/tutorials/rewriting-history/git-rebase"),
            duration: "20 min read",
            difficulty: .intermediate,
            tags: ["rebase", "history", "workflow"]
        ),
        LearningResource(
            title: "Resolving Merge Conflicts",
            description: "Step-by-step guide to understanding and resolving merge conflicts in Git.",
            type: .article,
            url: URL(string: "https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/addressing-merge-conflicts/resolving-a-merge-conflict-using-the-command-line"),
            duration: "10 min read",
            difficulty: .intermediate,
            tags: ["conflicts", "merge", "troubleshooting"]
        ),
        LearningResource(
            title: "Interactive Rebase",
            description: "Master interactive rebase to squash, reorder, and edit commits before sharing your work.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History"),
            duration: "25 min read",
            difficulty: .advanced,
            tags: ["rebase", "interactive", "history"]
        )
    ]

    // MARK: - Remotes Resources

    static let remotesResources: [LearningResource] = [
        LearningResource(
            title: "Working with Remotes",
            description: "Learn how to manage remote repositories, fetch, pull, and push changes.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes"),
            duration: "15 min read",
            difficulty: .beginner,
            tags: ["remote", "collaboration", "basics"]
        ),
        LearningResource(
            title: "Forking a Repository",
            description: "Understand how to fork repositories and contribute to open source projects.",
            type: .article,
            url: URL(string: "https://docs.github.com/en/get-started/quickstart/fork-a-repo"),
            duration: "10 min read",
            difficulty: .beginner,
            tags: ["fork", "github", "open source"]
        ),
        LearningResource(
            title: "Pull Request Best Practices",
            description: "Learn how to create effective pull requests that are easy to review and merge.",
            type: .article,
            url: URL(string: "https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests"),
            duration: "15 min read",
            difficulty: .intermediate,
            tags: ["pull request", "collaboration", "review"]
        ),
        LearningResource(
            title: "SSH Keys for GitHub",
            description: "Set up SSH authentication for secure, password-free access to GitHub.",
            type: .documentation,
            url: URL(string: "https://docs.github.com/en/authentication/connecting-to-github-with-ssh"),
            duration: "20 min read",
            difficulty: .intermediate,
            tags: ["ssh", "authentication", "security"]
        )
    ]

    // MARK: - Undoing Resources

    static let undoingResources: [LearningResource] = [
        LearningResource(
            title: "Undoing Things",
            description: "Learn various ways to undo changes in Git, from uncommitting to resetting.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Basics-Undoing-Things"),
            duration: "15 min read",
            difficulty: .beginner,
            tags: ["undo", "reset", "basics"]
        ),
        LearningResource(
            title: "Git Reset Demystified",
            description: "Deep dive into the reset command and its soft, mixed, and hard modes.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified"),
            duration: "25 min read",
            difficulty: .intermediate,
            tags: ["reset", "undo", "advanced"]
        ),
        LearningResource(
            title: "Git Revert",
            description: "Safely undo commits by creating new commits that reverse previous changes.",
            type: .article,
            url: URL(string: "https://www.atlassian.com/git/tutorials/undoing-changes/git-revert"),
            duration: "10 min read",
            difficulty: .beginner,
            tags: ["revert", "undo", "safe"]
        ),
        LearningResource(
            title: "Recovering Lost Commits",
            description: "Use reflog to find and recover lost commits and branches.",
            type: .article,
            url: URL(string: "https://www.atlassian.com/git/tutorials/rewriting-history/git-reflog"),
            duration: "15 min read",
            difficulty: .intermediate,
            tags: ["reflog", "recovery", "troubleshooting"]
        )
    ]

    // MARK: - Advanced Resources

    static let advancedResources: [LearningResource] = [
        LearningResource(
            title: "Git Internals",
            description: "Understand how Git works under the hood - objects, refs, and the pack file format.",
            type: .documentation,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain"),
            duration: "1 hour read",
            difficulty: .advanced,
            tags: ["internals", "deep dive", "architecture"]
        ),
        LearningResource(
            title: "Git Hooks",
            description: "Automate your workflow with client-side and server-side Git hooks.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks"),
            duration: "20 min read",
            difficulty: .advanced,
            tags: ["hooks", "automation", "customization"]
        ),
        LearningResource(
            title: "Git Submodules",
            description: "Manage external dependencies and nested repositories with submodules.",
            type: .article,
            url: URL(string: "https://git-scm.com/book/en/v2/Git-Tools-Submodules"),
            duration: "25 min read",
            difficulty: .advanced,
            tags: ["submodules", "dependencies", "nested"]
        ),
        LearningResource(
            title: "Git Worktrees",
            description: "Work on multiple branches simultaneously using separate working directories.",
            type: .article,
            url: URL(string: "https://git-scm.com/docs/git-worktree"),
            duration: "15 min read",
            difficulty: .advanced,
            tags: ["worktree", "branches", "parallel"]
        ),
        LearningResource(
            title: "Git Bisect",
            description: "Binary search through your commit history to find the commit that introduced a bug.",
            type: .article,
            url: URL(string: "https://git-scm.com/docs/git-bisect"),
            duration: "15 min read",
            difficulty: .advanced,
            tags: ["bisect", "debugging", "binary search"]
        )
    ]

    // MARK: - Best Practices Resources

    static let bestPracticesResources: [LearningResource] = [
        LearningResource(
            title: "Conventional Commits",
            description: "A specification for adding human and machine readable meaning to commit messages.",
            type: .documentation,
            url: URL(string: "https://www.conventionalcommits.org/"),
            duration: "15 min read",
            difficulty: .beginner,
            tags: ["commits", "convention", "messages"]
        ),
        LearningResource(
            title: "How to Write a Git Commit Message",
            description: "The seven rules of a great Git commit message that make history readable.",
            type: .article,
            url: URL(string: "https://cbea.ms/git-commit/"),
            duration: "10 min read",
            difficulty: .beginner,
            tags: ["commits", "messages", "best practices"]
        ),
        LearningResource(
            title: "Git Best Practices",
            description: "Collection of best practices for working with Git in teams.",
            type: .article,
            url: URL(string: "https://sethrobertson.github.io/GitBestPractices/"),
            duration: "20 min read",
            difficulty: .intermediate,
            tags: ["best practices", "team", "workflow"]
        ),
        LearningResource(
            title: ".gitignore Templates",
            description: "Collection of useful .gitignore templates for various programming languages.",
            type: .documentation,
            url: URL(string: "https://github.com/github/gitignore"),
            duration: "Reference",
            difficulty: .beginner,
            tags: ["gitignore", "templates", "configuration"]
        ),
        LearningResource(
            title: "Keep a Changelog",
            description: "Guidelines for maintaining a clear and helpful changelog for your projects.",
            type: .documentation,
            url: URL(string: "https://keepachangelog.com/"),
            duration: "10 min read",
            difficulty: .beginner,
            tags: ["changelog", "documentation", "releases"]
        )
    ]
}

// MARK: - Resource Card

struct ResourceCard: View {
    let resource: LearningResource
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: resource.type.icon)
                    .font(.title2)
                    .foregroundColor(resource.type.color)
                    .frame(width: 40, height: 40)
                    .background(resource.type.color.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        // Difficulty badge
                        Text(resource.difficulty.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(resource.difficulty.color.opacity(0.2))
                            .foregroundColor(resource.difficulty.color)
                            .cornerRadius(4)

                        // Duration
                        if let duration = resource.duration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Open button
                if let url = resource.url {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Description
            Text(resource.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isHovering ? nil : 2)

            // Tags
            FlowLayout(spacing: 4) {
                ForEach(resource.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(isHovering ? 0.1 : 0.05), radius: isHovering ? 8 : 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func calculateLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Video Tutorials View

struct VideoTutorialsView: View {
    var body: some View {
        LearningResourcesView()
    }
}

// MARK: - Git Learning View

struct GitLearningView: View {
    var body: some View {
        LearningResourcesView()
    }
}

#Preview {
    LearningResourcesView()
        .frame(width: 800, height: 600)
}
