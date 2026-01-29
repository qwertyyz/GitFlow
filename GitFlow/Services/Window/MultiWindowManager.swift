import SwiftUI
import AppKit

/// Manages multiple repository windows for side-by-side viewing.
@MainActor
class MultiWindowManager: ObservableObject {
    static let shared = MultiWindowManager()

    @Published var openWindows: [RepositoryWindow] = []
    @Published var activeWindowId: UUID?

    private init() {
        setupNotifications()
    }

    // MARK: - Window Management

    /// Open a repository in a new window
    func openInNewWindow(repository: Repository) {
        let window = RepositoryWindow(repository: repository)
        openWindows.append(window)
        activeWindowId = window.id

        createNSWindow(for: window)
    }

    /// Open a repository in a new tab within the current window
    func openInNewTab(repository: Repository) {
        guard let keyWindow = NSApp.keyWindow else {
            // No window exists, create one
            openInNewWindow(repository: repository)
            return
        }

        // Create a new window and add it as a tab
        let window = RepositoryWindow(repository: repository)
        openWindows.append(window)

        let nsWindow = createNSWindowForTab(for: window)
        keyWindow.addTabbedWindow(nsWindow, ordered: .above)
        nsWindow.makeKeyAndOrderFront(nil)
    }

    /// Close a specific repository window
    func closeWindow(id: UUID) {
        if let index = openWindows.firstIndex(where: { $0.id == id }) {
            let window = openWindows[index]
            window.nsWindow?.close()
            openWindows.remove(at: index)

            // Update active window
            if activeWindowId == id {
                activeWindowId = openWindows.last?.id
            }
        }
    }

    /// Close all windows for a repository
    func closeAllWindows(for repository: Repository) {
        let windowsToClose = openWindows.filter { $0.repository.path == repository.path }
        for window in windowsToClose {
            closeWindow(id: window.id)
        }
    }

    /// Bring a specific window to front
    func activateWindow(id: UUID) {
        if let window = openWindows.first(where: { $0.id == id }) {
            window.nsWindow?.makeKeyAndOrderFront(nil)
            activeWindowId = id
        }
    }

    /// Get all open repositories
    func openRepositories() -> [Repository] {
        return openWindows.map { $0.repository }
    }

    /// Check if a repository is already open
    func isRepositoryOpen(_ repository: Repository) -> Bool {
        return openWindows.contains { $0.repository.path == repository.path }
    }

    /// Get window for repository
    func window(for repository: Repository) -> RepositoryWindow? {
        return openWindows.first { $0.repository.path == repository.path }
    }

    // MARK: - NSWindow Creation

    @discardableResult
    private func createNSWindow(for window: RepositoryWindow) -> NSWindow {
        let contentView = RepositoryWindowContentView(window: window)

        let hostingController = NSHostingController(rootView: contentView)

        let nsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        nsWindow.contentViewController = hostingController
        nsWindow.title = window.repository.name
        nsWindow.subtitle = window.repository.path
        nsWindow.titlebarAppearsTransparent = false
        nsWindow.toolbarStyle = .unified
        nsWindow.tabbingMode = .preferred
        nsWindow.tabbingIdentifier = "GitFlowRepository"
        nsWindow.center()
        nsWindow.setFrameAutosaveName("RepositoryWindow-\(window.id)")

        // Set minimum size
        nsWindow.minSize = NSSize(width: 800, height: 600)

        // Store reference
        window.nsWindow = nsWindow

        // Set delegate for window events
        let delegate = WindowDelegate(windowId: window.id, manager: self)
        nsWindow.delegate = delegate
        window.windowDelegate = delegate

        nsWindow.makeKeyAndOrderFront(nil)

        return nsWindow
    }

    private func createNSWindowForTab(for window: RepositoryWindow) -> NSWindow {
        return createNSWindow(for: window)
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .openRepositoryInNewWindow,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let repository = notification.object as? Repository {
                Task { @MainActor in
                    self?.openInNewWindow(repository: repository)
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .openRepositoryInNewTab,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let repository = notification.object as? Repository {
                Task { @MainActor in
                    self?.openInNewTab(repository: repository)
                }
            }
        }
    }

    // MARK: - Window Arrangement

    /// Tile all windows horizontally
    func tileWindowsHorizontally() {
        guard openWindows.count > 1 else { return }

        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let windowWidth = visibleFrame.width / CGFloat(openWindows.count)

        for (index, window) in openWindows.enumerated() {
            let frame = NSRect(
                x: visibleFrame.origin.x + CGFloat(index) * windowWidth,
                y: visibleFrame.origin.y,
                width: windowWidth,
                height: visibleFrame.height
            )
            window.nsWindow?.setFrame(frame, display: true, animate: true)
        }
    }

    /// Tile all windows vertically
    func tileWindowsVertically() {
        guard openWindows.count > 1 else { return }

        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let windowHeight = visibleFrame.height / CGFloat(openWindows.count)

        for (index, window) in openWindows.enumerated() {
            let frame = NSRect(
                x: visibleFrame.origin.x,
                y: visibleFrame.origin.y + visibleFrame.height - CGFloat(index + 1) * windowHeight,
                width: visibleFrame.width,
                height: windowHeight
            )
            window.nsWindow?.setFrame(frame, display: true, animate: true)
        }
    }

    /// Cascade all windows
    func cascadeWindows() {
        var offset: CGFloat = 0
        for window in openWindows {
            if let nsWindow = window.nsWindow {
                var frame = nsWindow.frame
                frame.origin.x = 100 + offset
                frame.origin.y = NSScreen.main!.visibleFrame.maxY - frame.height - offset
                nsWindow.setFrame(frame, display: true, animate: true)
                offset += 30
            }
        }
    }
}

// MARK: - Repository Window Model

class RepositoryWindow: Identifiable, ObservableObject {
    let id = UUID()
    let repository: Repository
    let createdAt = Date()

    @Published var isActive: Bool = false

    weak var nsWindow: NSWindow?
    var windowDelegate: WindowDelegate?

    init(repository: Repository) {
        self.repository = repository
    }
}

// MARK: - Window Delegate

class WindowDelegate: NSObject, NSWindowDelegate {
    let windowId: UUID
    weak var manager: MultiWindowManager?

    init(windowId: UUID, manager: MultiWindowManager) {
        self.windowId = windowId
        self.manager = manager
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            if let index = manager?.openWindows.firstIndex(where: { $0.id == windowId }) {
                manager?.openWindows.remove(at: index)
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        Task { @MainActor in
            manager?.activeWindowId = windowId
            if let window = manager?.openWindows.first(where: { $0.id == windowId }) {
                window.isActive = true
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            if let window = manager?.openWindows.first(where: { $0.id == windowId }) {
                window.isActive = false
            }
        }
    }
}

// MARK: - Repository Window Content View

struct RepositoryWindowContentView: View {
    @ObservedObject var window: RepositoryWindow

    var body: some View {
        // This would contain the full repository view
        // For now, a placeholder that shows it's working
        VStack {
            Text(window.repository.name)
                .font(.title)
            Text(window.repository.path)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Placeholder for actual repository content
            Text("Repository content would go here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Window Menu Commands

struct WindowMenuCommands: Commands {
    @ObservedObject var windowManager: MultiWindowManager

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Divider()

            Button("Tile Windows Horizontally") {
                windowManager.tileWindowsHorizontally()
            }
            .keyboardShortcut("h", modifiers: [.command, .option, .control])
            .disabled(windowManager.openWindows.count < 2)

            Button("Tile Windows Vertically") {
                windowManager.tileWindowsVertically()
            }
            .keyboardShortcut("v", modifiers: [.command, .option, .control])
            .disabled(windowManager.openWindows.count < 2)

            Button("Cascade Windows") {
                windowManager.cascadeWindows()
            }
            .keyboardShortcut("c", modifiers: [.command, .option, .control])
            .disabled(windowManager.openWindows.count < 2)

            Divider()

            if windowManager.openWindows.count > 0 {
                Menu("Open Windows") {
                    ForEach(windowManager.openWindows) { window in
                        Button(window.repository.name) {
                            windowManager.activateWindow(id: window.id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openRepositoryInNewWindow = Notification.Name("openRepositoryInNewWindow")
    static let openRepositoryInNewTab = Notification.Name("openRepositoryInNewTab")
}

// MARK: - Repository Extension

extension Repository {
    /// Open this repository in a new window
    func openInNewWindow() {
        NotificationCenter.default.post(name: .openRepositoryInNewWindow, object: self)
    }

    /// Open this repository in a new tab
    func openInNewTab() {
        NotificationCenter.default.post(name: .openRepositoryInNewTab, object: self)
    }
}

// MARK: - Open Windows View (for Window menu)

struct OpenWindowsView: View {
    @ObservedObject var windowManager = MultiWindowManager.shared

    var body: some View {
        List(windowManager.openWindows) { window in
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text(window.repository.name)
                        .fontWeight(window.isActive ? .semibold : .regular)
                    Text(window.repository.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if window.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                windowManager.activateWindow(id: window.id)
            }
            .contextMenu {
                Button("Bring to Front") {
                    windowManager.activateWindow(id: window.id)
                }

                Divider()

                Button("Close Window") {
                    windowManager.closeWindow(id: window.id)
                }
            }
        }
    }
}

#Preview {
    OpenWindowsView()
        .frame(width: 300, height: 400)
}
