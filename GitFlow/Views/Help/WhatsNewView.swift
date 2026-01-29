import SwiftUI

/// View displaying what's new in the current version.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersion: AppVersion?

    var body: some View {
        NavigationSplitView {
            // Version list
            List(AppVersion.allVersions, selection: $selectedVersion) { version in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Version \(version.number)")
                            .font(.headline)
                        if version == AppVersion.current {
                            Text("Current")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    Text(version.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .tag(version)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            if let version = selectedVersion {
                versionDetailView(version)
            } else {
                versionDetailView(AppVersion.current)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .navigationTitle("What's New in GitFlow")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            selectedVersion = AppVersion.current
        }
    }

    @ViewBuilder
    private func versionDetailView(_ version: AppVersion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Version \(version.number)")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(version.date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let tagline = version.tagline {
                        Text(tagline)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }

                Divider()

                // Feature sections
                ForEach(version.sections) { section in
                    featureSection(section)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func featureSection(_ section: FeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(section.color)
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.features) { feature in
                    featureRow(feature)
                }
            }
            .padding(.leading, 8)
        }
    }

    @ViewBuilder
    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)

                if let description = feature.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models

struct AppVersion: Identifiable, Hashable {
    let id = UUID()
    let number: String
    let date: String
    let tagline: String?
    let sections: [FeatureSection]

    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.number == rhs.number
    }

    static let current = AppVersion(
        number: "1.0.0",
        date: "January 2026",
        tagline: "The free, open-source Git client for Mac",
        sections: [
            FeatureSection(
                title: "Complete Git Workflow",
                icon: "arrow.triangle.branch",
                color: .blue,
                features: [
                    Feature(title: "Full Git Operations", description: "Clone, commit, push, pull, merge, rebase, and more", icon: "checkmark.circle"),
                    Feature(title: "Interactive Rebase", description: "Reorder, squash, edit, and drop commits visually", icon: "arrow.up.arrow.down"),
                    Feature(title: "Branch Management", description: "Create, delete, rename, and compare branches", icon: "arrow.triangle.branch"),
                    Feature(title: "Stash Support", description: "Save and restore work in progress with named stashes", icon: "archivebox"),
                ]
            ),
            FeatureSection(
                title: "Visual Diff & Staging",
                icon: "doc.text.magnifyingglass",
                color: .green,
                features: [
                    Feature(title: "Side-by-Side Diff", description: "Compare changes with syntax highlighting", icon: "rectangle.split.2x1"),
                    Feature(title: "Hunk & Line Staging", description: "Stage individual changes with precision", icon: "checklist"),
                    Feature(title: "Image Diffing", description: "Visual comparison for images with multiple modes", icon: "photo.stack"),
                    Feature(title: "Conflict Resolution", description: "Three-way merge editor for resolving conflicts", icon: "exclamationmark.triangle"),
                ]
            ),
            FeatureSection(
                title: "Service Integrations",
                icon: "cloud",
                color: .purple,
                features: [
                    Feature(title: "GitHub Integration", description: "Browse repos, manage pull requests", icon: "link"),
                    Feature(title: "GitLab Integration", description: "Connect to GitLab for merge requests", icon: "link"),
                    Feature(title: "Bitbucket Integration", description: "Manage Bitbucket repositories", icon: "link"),
                    Feature(title: "Pull Request Management", description: "Create, review, and merge PRs from the app", icon: "arrow.triangle.pull"),
                ]
            ),
            FeatureSection(
                title: "Advanced Features",
                icon: "gearshape.2",
                color: .orange,
                features: [
                    Feature(title: "git-flow Support", description: "Feature, release, and hotfix workflows", icon: "arrow.triangle.branch"),
                    Feature(title: "Git LFS", description: "Large file storage integration", icon: "doc.zipper"),
                    Feature(title: "Submodules", description: "Manage nested repositories", icon: "folder.badge.gearshape"),
                    Feature(title: "Worktrees", description: "Work on multiple branches simultaneously", icon: "square.stack.3d.up"),
                    Feature(title: "Reflog", description: "Recover lost commits and branches", icon: "clock.arrow.circlepath"),
                ]
            ),
            FeatureSection(
                title: "Productivity",
                icon: "bolt",
                color: .yellow,
                features: [
                    Feature(title: "Command Palette", description: "Quick access to any action with ⌘K", icon: "command"),
                    Feature(title: "Drag & Drop", description: "Merge, rebase, cherry-pick with drag gestures", icon: "hand.draw"),
                    Feature(title: "Keyboard Shortcuts", description: "Full keyboard navigation support", icon: "keyboard"),
                    Feature(title: "Gitmoji Support", description: "Add emojis to commits easily", icon: "face.smiling"),
                    Feature(title: "Commit Templates", description: "Reusable templates for commit messages", icon: "doc.text"),
                ]
            ),
            FeatureSection(
                title: "Security",
                icon: "lock.shield",
                color: .red,
                features: [
                    Feature(title: "SSH Key Management", description: "Generate, import, and manage SSH keys", icon: "key"),
                    Feature(title: "GPG Signing", description: "Sign commits with GPG keys", icon: "signature"),
                    Feature(title: "Credential Management", description: "Secure storage for authentication", icon: "person.badge.key"),
                ]
            ),
        ]
    )

    static let allVersions: [AppVersion] = [
        current,
        AppVersion(
            number: "0.9.0",
            date: "December 2025",
            tagline: "Beta Release",
            sections: [
                FeatureSection(
                    title: "Initial Features",
                    icon: "star",
                    color: .blue,
                    features: [
                        Feature(title: "Core Git Operations", description: "Basic git functionality", icon: "checkmark"),
                        Feature(title: "Repository Management", description: "Open and manage repositories", icon: "folder"),
                        Feature(title: "Branch Operations", description: "Create and switch branches", icon: "arrow.triangle.branch"),
                    ]
                )
            ]
        )
    ]
}

struct FeatureSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let features: [Feature]
}

struct Feature: Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let icon: String
}

// MARK: - Helper to show What's New on first launch of new version

class WhatsNewManager: ObservableObject {
    @Published var shouldShowWhatsNew = false

    private let lastSeenVersionKey = "lastSeenWhatsNewVersion"

    init() {
        checkIfShouldShow()
    }

    func checkIfShouldShow() {
        let lastSeenVersion = UserDefaults.standard.string(forKey: lastSeenVersionKey) ?? ""
        let currentVersion = AppVersion.current.number

        if lastSeenVersion != currentVersion {
            shouldShowWhatsNew = true
        }
    }

    func markAsSeen() {
        UserDefaults.standard.set(AppVersion.current.number, forKey: lastSeenVersionKey)
        shouldShowWhatsNew = false
    }
}

#Preview {
    WhatsNewView()
}
