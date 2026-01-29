import SwiftUI
import AppKit

/// Manager for Touch Bar integration on MacBook Pro.
@MainActor
class TouchBarManager: NSObject, ObservableObject, NSTouchBarDelegate {
    static let shared = TouchBarManager()

    // Touch Bar item identifiers
    private enum TouchBarItemIdentifier {
        static let commitGroup = NSTouchBarItem.Identifier("com.gitflow.touchbar.commit")
        static let branchGroup = NSTouchBarItem.Identifier("com.gitflow.touchbar.branch")
        static let syncGroup = NSTouchBarItem.Identifier("com.gitflow.touchbar.sync")
        static let stashButton = NSTouchBarItem.Identifier("com.gitflow.touchbar.stash")
        static let statusLabel = NSTouchBarItem.Identifier("com.gitflow.touchbar.status")
    }

    // Current state
    @Published var currentBranch: String = ""
    @Published var hasUncommittedChanges: Bool = false
    @Published var uncommittedCount: Int = 0
    @Published var canPush: Bool = false
    @Published var canPull: Bool = false
    @Published var aheadCount: Int = 0
    @Published var behindCount: Int = 0

    // Callbacks
    var onCommit: (() -> Void)?
    var onPush: (() -> Void)?
    var onPull: (() -> Void)?
    var onFetch: (() -> Void)?
    var onStash: (() -> Void)?
    var onSwitchBranch: (() -> Void)?
    var onCreateBranch: (() -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Touch Bar Creation

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [
            TouchBarItemIdentifier.statusLabel,
            .flexibleSpace,
            TouchBarItemIdentifier.commitGroup,
            TouchBarItemIdentifier.branchGroup,
            TouchBarItemIdentifier.syncGroup,
            TouchBarItemIdentifier.stashButton,
        ]
        return touchBar
    }

    // MARK: - NSTouchBarDelegate

    nonisolated func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        Task { @MainActor in
            return self.makeItem(for: identifier)
        }
        return nil
    }

    private func makeItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case TouchBarItemIdentifier.statusLabel:
            return makeStatusItem()

        case TouchBarItemIdentifier.commitGroup:
            return makeCommitGroup()

        case TouchBarItemIdentifier.branchGroup:
            return makeBranchGroup()

        case TouchBarItemIdentifier.syncGroup:
            return makeSyncGroup()

        case TouchBarItemIdentifier.stashButton:
            return makeStashButton()

        default:
            return nil
        }
    }

    // MARK: - Touch Bar Items

    private func makeStatusItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: TouchBarItemIdentifier.statusLabel)

        let label = NSTextField(labelWithString: statusText)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor

        item.view = label
        return item
    }

    private var statusText: String {
        if hasUncommittedChanges {
            return "\(uncommittedCount) change\(uncommittedCount == 1 ? "" : "s")"
        }
        return "Clean"
    }

    private func makeCommitGroup() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: TouchBarItemIdentifier.commitGroup)

        let button = NSButton(
            title: "Commit",
            target: self,
            action: #selector(commitTapped)
        )
        button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Commit")
        button.imagePosition = .imageLeading
        button.bezelColor = hasUncommittedChanges ? NSColor.systemGreen : nil
        button.isEnabled = hasUncommittedChanges

        item.view = button
        return item
    }

    private func makeBranchGroup() -> NSTouchBarItem {
        let groupItem = NSGroupTouchBarItem(identifier: TouchBarItemIdentifier.branchGroup)

        let branchTouchBar = NSTouchBar()
        branchTouchBar.defaultItemIdentifiers = [
            NSTouchBarItem.Identifier("branch.current"),
            NSTouchBarItem.Identifier("branch.switch"),
            NSTouchBarItem.Identifier("branch.create"),
        ]

        branchTouchBar.templateItems = [
            makeBranchCurrentItem(),
            makeBranchSwitchItem(),
            makeBranchCreateItem(),
        ]

        groupItem.groupTouchBar = branchTouchBar
        return groupItem
    }

    private func makeBranchCurrentItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("branch.current"))

        let button = NSButton(
            title: currentBranch.isEmpty ? "main" : currentBranch,
            target: self,
            action: #selector(switchBranchTapped)
        )
        button.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Branch")
        button.imagePosition = .imageLeading

        item.view = button
        return item
    }

    private func makeBranchSwitchItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("branch.switch"))

        let button = NSButton(
            image: NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Switch")!,
            target: self,
            action: #selector(switchBranchTapped)
        )

        item.view = button
        return item
    }

    private func makeBranchCreateItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("branch.create"))

        let button = NSButton(
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Create Branch")!,
            target: self,
            action: #selector(createBranchTapped)
        )

        item.view = button
        return item
    }

    private func makeSyncGroup() -> NSTouchBarItem {
        let groupItem = NSGroupTouchBarItem(identifier: TouchBarItemIdentifier.syncGroup)

        let syncTouchBar = NSTouchBar()
        syncTouchBar.defaultItemIdentifiers = [
            NSTouchBarItem.Identifier("sync.fetch"),
            NSTouchBarItem.Identifier("sync.pull"),
            NSTouchBarItem.Identifier("sync.push"),
        ]

        syncTouchBar.templateItems = [
            makeFetchItem(),
            makePullItem(),
            makePushItem(),
        ]

        groupItem.groupTouchBar = syncTouchBar
        return groupItem
    }

    private func makeFetchItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("sync.fetch"))

        let button = NSButton(
            title: "Fetch",
            target: self,
            action: #selector(fetchTapped)
        )
        button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Fetch")
        button.imagePosition = .imageLeading

        item.view = button
        return item
    }

    private func makePullItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("sync.pull"))

        var title = "Pull"
        if behindCount > 0 {
            title = "Pull ↓\(behindCount)"
        }

        let button = NSButton(
            title: title,
            target: self,
            action: #selector(pullTapped)
        )
        button.image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "Pull")
        button.imagePosition = .imageLeading
        button.bezelColor = behindCount > 0 ? NSColor.systemBlue : nil
        button.isEnabled = canPull

        item.view = button
        return item
    }

    private func makePushItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("sync.push"))

        var title = "Push"
        if aheadCount > 0 {
            title = "Push ↑\(aheadCount)"
        }

        let button = NSButton(
            title: title,
            target: self,
            action: #selector(pushTapped)
        )
        button.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Push")
        button.imagePosition = .imageLeading
        button.bezelColor = aheadCount > 0 ? NSColor.systemOrange : nil
        button.isEnabled = canPush

        item.view = button
        return item
    }

    private func makeStashButton() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: TouchBarItemIdentifier.stashButton)

        let button = NSButton(
            image: NSImage(systemSymbolName: "archivebox", accessibilityDescription: "Stash")!,
            target: self,
            action: #selector(stashTapped)
        )

        item.view = button
        return item
    }

    // MARK: - Actions

    @objc private func commitTapped() {
        onCommit?()
    }

    @objc private func pushTapped() {
        onPush?()
    }

    @objc private func pullTapped() {
        onPull?()
    }

    @objc private func fetchTapped() {
        onFetch?()
    }

    @objc private func stashTapped() {
        onStash?()
    }

    @objc private func switchBranchTapped() {
        onSwitchBranch?()
    }

    @objc private func createBranchTapped() {
        onCreateBranch?()
    }

    // MARK: - State Updates

    func updateState(
        branch: String,
        uncommittedChanges: Int,
        ahead: Int,
        behind: Int,
        hasRemote: Bool
    ) {
        currentBranch = branch
        uncommittedCount = uncommittedChanges
        hasUncommittedChanges = uncommittedChanges > 0
        aheadCount = ahead
        behindCount = behind
        canPush = hasRemote && ahead > 0
        canPull = hasRemote && behind > 0
    }
}

// MARK: - Touch Bar Settings

struct TouchBarSettings: Codable {
    var enabled: Bool = true
    var showCommitButton: Bool = true
    var showBranchButton: Bool = true
    var showSyncButtons: Bool = true
    var showStashButton: Bool = true
    var showStatusLabel: Bool = true

    private static let key = "touchBarSettings"

    static func load() -> TouchBarSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(TouchBarSettings.self, from: data) else {
            return TouchBarSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: TouchBarSettings.key)
        }
    }
}

// MARK: - Touch Bar Settings View

struct TouchBarSettingsView: View {
    @State private var settings = TouchBarSettings.load()

    var body: some View {
        Form {
            Section {
                Toggle("Enable Touch Bar", isOn: $settings.enabled)
                    .onChange(of: settings.enabled) { _ in
                        settings.save()
                    }

                Text("Customize which items appear in the Touch Bar when GitFlow is active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Touch Bar Items") {
                Toggle("Status Label", isOn: $settings.showStatusLabel)
                    .onChange(of: settings.showStatusLabel) { _ in settings.save() }

                Toggle("Commit Button", isOn: $settings.showCommitButton)
                    .onChange(of: settings.showCommitButton) { _ in settings.save() }

                Toggle("Branch Buttons", isOn: $settings.showBranchButton)
                    .onChange(of: settings.showBranchButton) { _ in settings.save() }

                Toggle("Sync Buttons (Fetch/Pull/Push)", isOn: $settings.showSyncButtons)
                    .onChange(of: settings.showSyncButtons) { _ in settings.save() }

                Toggle("Stash Button", isOn: $settings.showStashButton)
                    .onChange(of: settings.showStashButton) { _ in settings.save() }
            }
            .disabled(!settings.enabled)

            Section("Preview") {
                TouchBarPreviewView(settings: settings)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Touch Bar Preview

struct TouchBarPreviewView: View {
    let settings: TouchBarSettings

    var body: some View {
        HStack(spacing: 8) {
            if settings.showStatusLabel {
                Text("3 changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }

            Spacer()

            if settings.showCommitButton {
                previewButton("Commit", icon: "checkmark.circle", color: .green)
            }

            if settings.showBranchButton {
                previewButton("main", icon: "arrow.triangle.branch", color: nil)
            }

            if settings.showSyncButtons {
                HStack(spacing: 4) {
                    previewButton("Fetch", icon: "arrow.triangle.2.circlepath", color: nil)
                    previewButton("Pull", icon: "arrow.down", color: nil)
                    previewButton("Push ↑2", icon: "arrow.up", color: .orange)
                }
            }

            if settings.showStashButton {
                previewButton("", icon: "archivebox", color: nil)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func previewButton(_ title: String, icon: String, color: Color?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color?.opacity(0.3) ?? Color.gray.opacity(0.3))
        .cornerRadius(4)
        .foregroundColor(.white)
    }
}

#Preview {
    TouchBarSettingsView()
        .frame(width: 500)
}
