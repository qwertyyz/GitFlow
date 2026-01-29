import SwiftUI

/// Getting Started guide for new users.
struct GettingStartedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [GettingStartedStep] = [
        GettingStartedStep(
            title: "Welcome to GitFlow",
            subtitle: "The free, open-source Git client for Mac",
            description: "GitFlow provides a powerful yet intuitive interface for all your Git needs. Let's get you started with the basics.",
            icon: "hand.wave.fill",
            color: .blue,
            tips: []
        ),
        GettingStartedStep(
            title: "Open a Repository",
            subtitle: "Get started with your code",
            description: "Open an existing repository, clone from a remote, or create a new one.",
            icon: "folder.badge.plus",
            color: .green,
            tips: [
                Tip(icon: "folder", text: "Use File → Open to open a local repository"),
                Tip(icon: "arrow.down.doc", text: "Use File → Clone to clone from GitHub, GitLab, or any URL"),
                Tip(icon: "plus.app", text: "Use File → New Repository to create a fresh repo"),
                Tip(icon: "hand.draw", text: "Drag and drop a folder onto the app to open it"),
            ]
        ),
        GettingStartedStep(
            title: "The Sidebar",
            subtitle: "Navigate your repository",
            description: "The sidebar gives you quick access to all parts of your repository.",
            icon: "sidebar.left",
            color: .purple,
            tips: [
                Tip(icon: "doc.text", text: "Working Copy: View and stage your changes"),
                Tip(icon: "clock", text: "History: Browse commit history"),
                Tip(icon: "archivebox", text: "Stashes: Manage saved work-in-progress"),
                Tip(icon: "arrow.triangle.branch", text: "Branches: Create and switch branches"),
                Tip(icon: "tag", text: "Tags: Manage version tags"),
                Tip(icon: "network", text: "Remotes: Configure remote repositories"),
            ]
        ),
        GettingStartedStep(
            title: "Making Changes",
            subtitle: "Stage and commit your work",
            description: "GitFlow makes it easy to review changes and create commits.",
            icon: "pencil.and.list.clipboard",
            color: .orange,
            tips: [
                Tip(icon: "eye", text: "Review changes in the diff viewer"),
                Tip(icon: "checklist", text: "Click checkboxes to stage/unstage files"),
                Tip(icon: "text.alignleft", text: "Click individual lines in the diff to stage specific changes"),
                Tip(icon: "checkmark.circle", text: "Write a commit message and press Commit"),
            ]
        ),
        GettingStartedStep(
            title: "Syncing with Remote",
            subtitle: "Push and pull changes",
            description: "Keep your local repository in sync with remotes.",
            icon: "arrow.triangle.2.circlepath",
            color: .teal,
            tips: [
                Tip(icon: "arrow.down", text: "Pull: Download changes from remote"),
                Tip(icon: "arrow.up", text: "Push: Upload your commits to remote"),
                Tip(icon: "arrow.triangle.2.circlepath", text: "Fetch: Check for new changes without merging"),
            ]
        ),
        GettingStartedStep(
            title: "Keyboard Shortcuts",
            subtitle: "Work faster with shortcuts",
            description: "GitFlow has extensive keyboard support for power users.",
            icon: "keyboard",
            color: .pink,
            tips: [
                Tip(icon: "command", text: "⌘K: Open Command Palette"),
                Tip(icon: "1.circle", text: "⌘1-5: Switch between views"),
                Tip(icon: "arrow.left", text: "⌘[ / ⌘]: Navigate back/forward"),
                Tip(icon: "checkmark", text: "⌘⏎: Commit"),
                Tip(icon: "arrow.triangle.branch", text: "⌘B: Create branch"),
            ]
        ),
        GettingStartedStep(
            title: "You're All Set!",
            subtitle: "Start using GitFlow",
            description: "You're ready to start managing your Git repositories with GitFlow. Happy coding!",
            icon: "checkmark.seal.fill",
            color: .green,
            tips: [
                Tip(icon: "questionmark.circle", text: "Access Help → Documentation for detailed guides"),
                Tip(icon: "keyboard", text: "View Help → Keyboard Shortcuts for all shortcuts"),
                Tip(icon: "star", text: "Help → What's New shows the latest features"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepView(step)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation
            HStack {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .onTapGesture {
                                withAnimation {
                                    currentStep = index
                                }
                            }
                    }
                }

                Spacer()

                // Buttons
                if currentStep > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }

    @ViewBuilder
    private func stepView(_ step: GettingStartedStep) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 64))
                .foregroundColor(step.color)

            // Title
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(step.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Description
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            // Tips
            if !step.tips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(step.tips) { tip in
                        HStack(spacing: 12) {
                            Image(systemName: tip.icon)
                                .frame(width: 24)
                                .foregroundColor(step.color)

                            Text(tip.text)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Data Models

struct GettingStartedStep {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let tips: [Tip]
}

struct Tip: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

// MARK: - Helper to show Getting Started on first launch

class GettingStartedManager: ObservableObject {
    @Published var shouldShowGettingStarted = false

    private let hasSeenGettingStartedKey = "hasSeenGettingStarted"

    init() {
        checkIfShouldShow()
    }

    func checkIfShouldShow() {
        let hasSeen = UserDefaults.standard.bool(forKey: hasSeenGettingStartedKey)
        shouldShowGettingStarted = !hasSeen
    }

    func markAsSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenGettingStartedKey)
        shouldShowGettingStarted = false
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: hasSeenGettingStartedKey)
        shouldShowGettingStarted = true
    }
}

#Preview {
    GettingStartedView()
}
