import SwiftUI

/// In-app help documentation view.
struct HelpDocumentationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTopic: HelpTopic?

    var body: some View {
        NavigationSplitView {
            // Topics sidebar
            List(selection: $selectedTopic) {
                ForEach(HelpCategory.allCases) { category in
                    Section(category.rawValue) {
                        ForEach(HelpTopic.topics(for: category)) { topic in
                            Label(topic.title, systemImage: topic.icon)
                                .tag(topic)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
            .searchable(text: $searchText, prompt: "Search Help")
        } detail: {
            if let topic = selectedTopic {
                topicDetailView(topic)
            } else {
                welcomeView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("GitFlow Help")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("GitFlow Help")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select a topic from the sidebar to learn more about GitFlow features.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Divider()
                .frame(maxWidth: 300)

            // Quick links
            VStack(spacing: 16) {
                Text("Quick Links")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    quickLinkButton("Getting Started", icon: "play.circle", topic: .gettingStarted)
                    quickLinkButton("Making Commits", icon: "checkmark.circle", topic: .committing)
                    quickLinkButton("Working with Branches", icon: "arrow.triangle.branch", topic: .branches)
                    quickLinkButton("Keyboard Shortcuts", icon: "keyboard", topic: .shortcuts)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func quickLinkButton(_ title: String, icon: String, topic: HelpTopic) -> some View {
        Button(action: { selectedTopic = topic }) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func topicDetailView(_ topic: HelpTopic) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: topic.icon)
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(topic.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                Divider()

                // Content
                ForEach(topic.sections) { section in
                    sectionView(section)
                }

                // Related topics
                if !topic.relatedTopics.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Related Topics")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(topic.relatedTopics, id: \.self) { relatedId in
                                if let related = HelpTopic.all.first(where: { $0.id == relatedId }) {
                                    Button(action: { selectedTopic = related }) {
                                        Label(related.title, systemImage: related.icon)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func sectionView(_ section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text(section.content)
                .font(.body)

            if !section.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            Text(step)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            if let tip = section.tip {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(tip)
                        .font(.callout)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }

            if let warning = section.warning {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.callout)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Data Models

enum HelpCategory: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case workingCopy = "Working Copy"
    case commitHistory = "Commit History"
    case branches = "Branches"
    case remotes = "Remotes"
    case advanced = "Advanced"

    var id: String { rawValue }
}

struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let category: HelpCategory
    let sections: [HelpSection]
    let relatedTopics: [String]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: HelpTopic, rhs: HelpTopic) -> Bool {
        lhs.id == rhs.id
    }

    static func topics(for category: HelpCategory) -> [HelpTopic] {
        all.filter { $0.category == category }
    }

    // MARK: - All Topics

    static let gettingStarted = HelpTopic(
        id: "getting-started",
        title: "Getting Started",
        icon: "play.circle",
        category: .gettingStarted,
        sections: [
            HelpSection(
                title: nil,
                content: "GitFlow is a powerful Git client that makes version control intuitive and efficient. This guide will help you get started with the basics."
            ),
            HelpSection(
                title: "Opening a Repository",
                content: "There are several ways to open a repository in GitFlow:",
                steps: [
                    "Use File → Open (⌘O) to browse for an existing repository",
                    "Drag and drop a folder onto the GitFlow window",
                    "Use File → Clone (⌘⇧O) to clone from a remote URL",
                    "Select a recent repository from the welcome screen"
                ]
            ),
            HelpSection(
                title: "The Interface",
                content: "The GitFlow interface is divided into three main areas: the sidebar for navigation, the main content area, and the detail panel. The sidebar shows your branches, tags, remotes, and other repository elements."
            )
        ],
        relatedTopics: ["committing", "branches"]
    )

    static let committing = HelpTopic(
        id: "committing",
        title: "Making Commits",
        icon: "checkmark.circle",
        category: .workingCopy,
        sections: [
            HelpSection(
                title: nil,
                content: "Commits are snapshots of your project at a specific point in time. GitFlow makes it easy to review changes and create meaningful commits."
            ),
            HelpSection(
                title: "Staging Changes",
                content: "Before committing, you need to stage the changes you want to include:",
                steps: [
                    "Go to the Working Copy view (⌘1)",
                    "Review your changes in the file list",
                    "Click the checkbox next to a file to stage it",
                    "Use the diff viewer to stage individual hunks or lines"
                ],
                tip: "Press Space to quickly stage/unstage the selected file."
            ),
            HelpSection(
                title: "Writing Commit Messages",
                content: "A good commit message explains what changes were made and why. The commit message has two parts: a short subject line (50 characters) and an optional longer description.",
                tip: "Start with a capital letter and use imperative mood (e.g., 'Add feature' not 'Added feature')."
            ),
            HelpSection(
                title: "Amending Commits",
                content: "If you need to modify your last commit, check the 'Amend' checkbox before committing. This replaces the last commit with your new changes.",
                warning: "Only amend commits that haven't been pushed to a shared remote."
            )
        ],
        relatedTopics: ["staging", "diff-viewer"]
    )

    static let staging = HelpTopic(
        id: "staging",
        title: "Staging Changes",
        icon: "tray.and.arrow.down",
        category: .workingCopy,
        sections: [
            HelpSection(
                title: nil,
                content: "The staging area (also called the index) is where you prepare changes for your next commit. GitFlow gives you fine-grained control over what gets staged."
            ),
            HelpSection(
                title: "File-Level Staging",
                content: "Click the checkbox next to any file to stage all changes in that file. A half-filled checkbox indicates partial staging."
            ),
            HelpSection(
                title: "Hunk Staging",
                content: "In the diff viewer, click 'Stage Hunk' to stage a specific block of changes. This is useful when you want to commit only some changes in a file."
            ),
            HelpSection(
                title: "Line Staging",
                content: "For even more precision, select specific lines in the diff and click 'Stage Lines' to stage only those lines.",
                tip: "Hold Shift and click to select multiple lines."
            )
        ],
        relatedTopics: ["committing", "diff-viewer"]
    )

    static let diffViewer = HelpTopic(
        id: "diff-viewer",
        title: "Using the Diff Viewer",
        icon: "doc.text.magnifyingglass",
        category: .workingCopy,
        sections: [
            HelpSection(
                title: nil,
                content: "The diff viewer shows you exactly what changed in your files. GitFlow provides multiple ways to view and interact with diffs."
            ),
            HelpSection(
                title: "View Modes",
                content: "Switch between unified (single column) and split (side-by-side) view using the toggle in the toolbar. Split view is great for reviewing large changes."
            ),
            HelpSection(
                title: "Syntax Highlighting",
                content: "GitFlow automatically detects the file type and applies appropriate syntax highlighting to make code easier to read."
            ),
            HelpSection(
                title: "Whitespace Options",
                content: "Use the whitespace dropdown to show/hide whitespace characters or ignore whitespace-only changes."
            )
        ],
        relatedTopics: ["staging", "committing"]
    )

    static let branches = HelpTopic(
        id: "branches",
        title: "Working with Branches",
        icon: "arrow.triangle.branch",
        category: .branches,
        sections: [
            HelpSection(
                title: nil,
                content: "Branches let you work on different features or fixes in isolation. GitFlow makes branch management intuitive with visual tools."
            ),
            HelpSection(
                title: "Creating a Branch",
                content: "To create a new branch:",
                steps: [
                    "Press ⌘B or right-click in the branch list",
                    "Enter a name for the branch",
                    "Choose the starting point (HEAD, a commit, or another branch)",
                    "Click Create"
                ],
                tip: "Use descriptive names like 'feature/user-auth' or 'fix/login-bug'."
            ),
            HelpSection(
                title: "Switching Branches",
                content: "Double-click a branch in the sidebar to switch to it, or right-click and choose 'Checkout'.",
                warning: "Make sure to commit or stash your changes before switching branches."
            ),
            HelpSection(
                title: "Merging Branches",
                content: "To merge a branch into your current branch, drag it onto HEAD or right-click and choose 'Merge Into Current Branch'."
            )
        ],
        relatedTopics: ["merging", "rebasing"]
    )

    static let merging = HelpTopic(
        id: "merging",
        title: "Merging Branches",
        icon: "arrow.triangle.merge",
        category: .branches,
        sections: [
            HelpSection(
                title: nil,
                content: "Merging combines changes from one branch into another. GitFlow provides a visual preview and handles conflicts gracefully."
            ),
            HelpSection(
                title: "How to Merge",
                content: "To merge a branch:",
                steps: [
                    "Switch to the target branch (the one you want to merge into)",
                    "Right-click the source branch and choose 'Merge Into...'",
                    "Review the preview of changes",
                    "Click Merge to complete"
                ]
            ),
            HelpSection(
                title: "Handling Conflicts",
                content: "If Git can't automatically merge changes, you'll see conflicts. GitFlow provides a visual conflict editor to help resolve them.",
                tip: "Use the 'Accept Ours', 'Accept Theirs', or manually edit to resolve each conflict."
            )
        ],
        relatedTopics: ["branches", "conflicts"]
    )

    static let rebasing = HelpTopic(
        id: "rebasing",
        title: "Rebasing",
        icon: "arrow.triangle.swap",
        category: .branches,
        sections: [
            HelpSection(
                title: nil,
                content: "Rebasing moves or combines commits onto a new base. It's useful for keeping a clean, linear history."
            ),
            HelpSection(
                title: "Simple Rebase",
                content: "To rebase your current branch onto another:",
                steps: [
                    "Right-click the target branch",
                    "Choose 'Rebase Current Branch Onto...'",
                    "Resolve any conflicts if they occur",
                    "Continue or abort as needed"
                ],
                warning: "Never rebase commits that have been pushed to a shared branch."
            ),
            HelpSection(
                title: "Interactive Rebase",
                content: "Interactive rebase lets you modify commit history. Right-click a commit and choose 'Interactive Rebase' to reorder, squash, edit, or drop commits."
            )
        ],
        relatedTopics: ["branches", "interactive-rebase"]
    )

    static let shortcuts = HelpTopic(
        id: "shortcuts",
        title: "Keyboard Shortcuts",
        icon: "keyboard",
        category: .gettingStarted,
        sections: [
            HelpSection(
                title: nil,
                content: "GitFlow supports extensive keyboard shortcuts for efficient navigation and actions. Here are the most important ones:"
            ),
            HelpSection(
                title: "Navigation",
                content: "⌘1-5 switch between main views. ⌘[ and ⌘] navigate back and forward. ⌘0 jumps to HEAD."
            ),
            HelpSection(
                title: "Common Actions",
                content: "⌘⏎ commits staged changes. ⌘B creates a new branch. ⌘K opens the command palette for quick access to any action."
            ),
            HelpSection(
                title: "View All Shortcuts",
                content: "Open Help → Keyboard Shortcuts to see the complete list of available shortcuts."
            )
        ],
        relatedTopics: ["getting-started"]
    )

    static let conflicts = HelpTopic(
        id: "conflicts",
        title: "Resolving Conflicts",
        icon: "exclamationmark.triangle",
        category: .workingCopy,
        sections: [
            HelpSection(
                title: nil,
                content: "Conflicts occur when Git can't automatically merge changes. GitFlow provides tools to help you resolve them visually."
            ),
            HelpSection(
                title: "Understanding Conflicts",
                content: "A conflict shows two versions of the same code: your changes (ours) and the incoming changes (theirs). You need to decide which to keep or combine them."
            ),
            HelpSection(
                title: "Resolving Conflicts",
                content: "For each conflicted file:",
                steps: [
                    "Open the conflict resolver (click the file or choose 'Resolve')",
                    "Review both versions side by side",
                    "Choose 'Accept Ours', 'Accept Theirs', or edit manually",
                    "Mark as resolved when done"
                ]
            )
        ],
        relatedTopics: ["merging", "rebasing"]
    )

    static let all: [HelpTopic] = [
        gettingStarted,
        committing,
        staging,
        diffViewer,
        branches,
        merging,
        rebasing,
        shortcuts,
        conflicts
    ]
}

struct HelpSection: Identifiable {
    let id = UUID()
    let title: String?
    let content: String
    var steps: [String] = []
    var tip: String?
    var warning: String?
}

#Preview {
    HelpDocumentationView()
}
