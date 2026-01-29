import Foundation

// MARK: - Navigation State

/// Represents a navigation state in the app.
struct NavigationState: Equatable {
    /// The selected sidebar section.
    let section: String

    /// Optional selection within the section (commit hash, branch name, etc.).
    let selection: String?

    /// Timestamp when this state was visited.
    let timestamp: Date

    init(section: String, selection: String? = nil) {
        self.section = section
        self.selection = selection
        self.timestamp = Date()
    }

    /// Returns true if this state represents the same location (ignoring timestamp).
    func isSameLocation(as other: NavigationState) -> Bool {
        section == other.section && selection == other.selection
    }
}

// MARK: - Navigation History

/// Manages browser-style navigation history (back/forward).
@MainActor
final class NavigationHistory: ObservableObject {
    // MARK: - Published State

    /// Whether the back button should be enabled.
    @Published private(set) var canGoBack: Bool = false

    /// Whether the forward button should be enabled.
    @Published private(set) var canGoForward: Bool = false

    /// The current navigation state.
    @Published private(set) var currentState: NavigationState?

    // MARK: - Private State

    /// Stack of past navigation states (for going back).
    private var backStack: [NavigationState] = []

    /// Stack of forward navigation states (for going forward after going back).
    private var forwardStack: [NavigationState] = []

    /// Maximum number of items to keep in history.
    private let maxHistorySize: Int = 50

    /// Flag to prevent recording navigation while navigating.
    private var isNavigating: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Records a new navigation state.
    /// Call this when the user navigates to a new view or selection.
    func push(_ state: NavigationState) {
        // Don't record if we're in the middle of a programmatic navigation
        guard !isNavigating else { return }

        // Don't record if it's the same location as current
        if let current = currentState, current.isSameLocation(as: state) {
            return
        }

        // If we have a current state, push it to back stack
        if let current = currentState {
            backStack.append(current)

            // Trim back stack if too large
            if backStack.count > maxHistorySize {
                backStack.removeFirst()
            }
        }

        // Clear forward stack when navigating to a new location
        forwardStack.removeAll()

        // Set new current state
        currentState = state

        updateNavigationFlags()
    }

    /// Records a navigation to a section.
    func push(section: String, selection: String? = nil) {
        push(NavigationState(section: section, selection: selection))
    }

    /// Goes back to the previous navigation state.
    /// Returns the state to navigate to, or nil if can't go back.
    func goBack() -> NavigationState? {
        guard canGoBack, let previousState = backStack.popLast() else {
            return nil
        }

        isNavigating = true
        defer {
            isNavigating = false
            updateNavigationFlags()
        }

        // Push current state to forward stack
        if let current = currentState {
            forwardStack.append(current)
        }

        currentState = previousState
        return previousState
    }

    /// Goes forward to the next navigation state.
    /// Returns the state to navigate to, or nil if can't go forward.
    func goForward() -> NavigationState? {
        guard canGoForward, let nextState = forwardStack.popLast() else {
            return nil
        }

        isNavigating = true
        defer {
            isNavigating = false
            updateNavigationFlags()
        }

        // Push current state to back stack
        if let current = currentState {
            backStack.append(current)
        }

        currentState = nextState
        return nextState
    }

    /// Clears all navigation history.
    func clear() {
        backStack.removeAll()
        forwardStack.removeAll()
        currentState = nil
        updateNavigationFlags()
    }

    /// Clears forward history only.
    func clearForward() {
        forwardStack.removeAll()
        updateNavigationFlags()
    }

    // MARK: - Debug

    /// Returns the current history for debugging.
    var debugDescription: String {
        var lines: [String] = []
        lines.append("Back Stack (\(backStack.count)):")
        for state in backStack {
            lines.append("  - \(state.section)\(state.selection.map { " (\($0))" } ?? "")")
        }
        lines.append("Current: \(currentState?.section ?? "nil")\(currentState?.selection.map { " (\($0))" } ?? "")")
        lines.append("Forward Stack (\(forwardStack.count)):")
        for state in forwardStack {
            lines.append("  - \(state.section)\(state.selection.map { " (\($0))" } ?? "")")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private Methods

    private func updateNavigationFlags() {
        canGoBack = !backStack.isEmpty
        canGoForward = !forwardStack.isEmpty
    }
}
