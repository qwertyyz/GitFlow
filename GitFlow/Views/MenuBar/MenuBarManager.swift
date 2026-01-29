import SwiftUI
import AppKit

/// Manager for the menu bar status item and quick access menu.
@MainActor
class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "menuBarEnabled")
            updateMenuBarItem()
        }
    }

    @Published var recentRepositories: [RecentRepository] = []
    @Published var currentRepository: Repository?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "menuBarEnabled")
        updateMenuBarItem()
    }

    // MARK: - Menu Bar Item

    private func updateMenuBarItem() {
        if isEnabled {
            createMenuBarItem()
        } else {
            removeMenuBarItem()
        }
    }

    private func createMenuBarItem() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "GitFlow")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func removeMenuBarItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    // MARK: - Popover

    private func togglePopover(_ sender: NSStatusBarButton) {
        if let popover = popover, popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: NSStatusBarButton) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView())

        self.popover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        // Recent repositories
        if !recentRepositories.isEmpty {
            menu.addItem(NSMenuItem(title: "Recent Repositories", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            for repo in recentRepositories.prefix(5) {
                let item = NSMenuItem(title: repo.name, action: #selector(openRepository(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = repo.path
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Quick actions
        let openItem = NSMenuItem(title: "Open Repository...", action: #selector(openRepositoryAction), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let cloneItem = NSMenuItem(title: "Clone Repository...", action: #selector(cloneRepositoryAction), keyEquivalent: "")
        cloneItem.target = self
        menu.addItem(cloneItem)

        menu.addItem(NSMenuItem.separator())

        // Current repository actions
        if currentRepository != nil {
            let fetchItem = NSMenuItem(title: "Fetch", action: #selector(fetchAction), keyEquivalent: "")
            fetchItem.target = self
            menu.addItem(fetchItem)

            let pullItem = NSMenuItem(title: "Pull", action: #selector(pullAction), keyEquivalent: "")
            pullItem.target = self
            menu.addItem(pullItem)

            let pushItem = NSMenuItem(title: "Push", action: #selector(pushAction), keyEquivalent: "")
            pushItem.target = self
            menu.addItem(pushItem)

            menu.addItem(NSMenuItem.separator())
        }

        // Show main window
        let showItem = NSMenuItem(title: "Show GitFlow", action: #selector(showMainWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit GitFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Actions

    @objc private func openRepository(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NotificationCenter.default.post(
            name: .openRepository,
            object: nil,
            userInfo: ["path": path]
        )
        showMainWindow()
    }

    @objc private func openRepositoryAction() {
        NotificationCenter.default.post(name: .showOpenPanel, object: nil)
        showMainWindow()
    }

    @objc private func cloneRepositoryAction() {
        NotificationCenter.default.post(name: .showCloneSheet, object: nil)
        showMainWindow()
    }

    @objc private func fetchAction() {
        NotificationCenter.default.post(name: .performFetch, object: nil)
    }

    @objc private func pullAction() {
        NotificationCenter.default.post(name: .performPull, object: nil)
    }

    @objc private func pushAction() {
        NotificationCenter.default.post(name: .performPush, object: nil)
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - State Updates

    func updateCurrentRepository(_ repository: Repository?) {
        currentRepository = repository
        updateBadge()
    }

    func updateRecentRepositories(_ repositories: [RecentRepository]) {
        recentRepositories = repositories
    }

    func updateBadge(uncommittedChanges: Int = 0) {
        guard let button = statusItem?.button else { return }

        if uncommittedChanges > 0 {
            // Add a badge indicator
            button.image = NSImage(systemSymbolName: "arrow.triangle.branch.badge.clock", accessibilityDescription: "GitFlow - Changes")
        } else {
            button.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "GitFlow")
        }
    }
}

// MARK: - Menu Bar Popover View

struct MenuBarPopoverView: View {
    @StateObject private var menuBarManager = MenuBarManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                Text("GitFlow")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))

            Divider()

            // Current repository
            if let repo = menuBarManager.currentRepository {
                currentRepoSection(repo)
                Divider()
            }

            // Recent repositories
            recentReposSection

            Divider()

            // Quick actions
            quickActionsSection

            Spacer()
        }
        .frame(width: 300, height: 400)
    }

    @ViewBuilder
    private func currentRepoSection(_ repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Repository")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.headline)
                    Text(repo.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 12) {
                Button("Fetch") {
                    NotificationCenter.default.post(name: .performFetch, object: nil)
                }
                .buttonStyle(.bordered)

                Button("Pull") {
                    NotificationCenter.default.post(name: .performPull, object: nil)
                }
                .buttonStyle(.bordered)

                Button("Push") {
                    NotificationCenter.default.post(name: .performPush, object: nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var recentReposSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Repositories")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            if menuBarManager.recentRepositories.isEmpty {
                Text("No recent repositories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(menuBarManager.recentRepositories.prefix(5)) { repo in
                    Button(action: { openRepo(repo) }) {
                        HStack {
                            Image(systemName: "folder")
                            Text(repo.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: 8) {
            Button(action: { NotificationCenter.default.post(name: .showOpenPanel, object: nil) }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Open Repository...")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: { NotificationCenter.default.post(name: .showCloneSheet, object: nil) }) {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text("Clone Repository...")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private func openRepo(_ repo: RecentRepository) {
        NotificationCenter.default.post(
            name: .openRepository,
            object: nil,
            userInfo: ["path": repo.path]
        )
    }
}

// MARK: - Recent Repository Model

struct RecentRepository: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let lastOpened: Date

    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.lastOpened = Date()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openRepository = Notification.Name("openRepository")
    static let showOpenPanel = Notification.Name("showOpenPanel")
    static let showCloneSheet = Notification.Name("showCloneSheet")
    static let performFetch = Notification.Name("performFetch")
    static let performPull = Notification.Name("performPull")
    static let performPush = Notification.Name("performPush")
}

#Preview {
    MenuBarPopoverView()
}
