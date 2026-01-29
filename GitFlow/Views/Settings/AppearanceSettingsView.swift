import SwiftUI

/// Settings view for appearance customization including compact mode.
struct AppearanceSettingsView: View {
    @StateObject private var viewModel = AppearanceSettingsViewModel()

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $viewModel.settings.theme) {
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                    Text("System").tag(AppTheme.system)
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.settings.theme) { _ in
                    viewModel.applyTheme()
                }
            }

            Section("Toolbar") {
                Toggle("Compact Top Bar", isOn: $viewModel.settings.compactTopBar)
                    .onChange(of: viewModel.settings.compactTopBar) { _ in
                        viewModel.saveSettings()
                    }

                Text("Reduces the height of the toolbar and uses smaller icons.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Show Labels in Toolbar", isOn: $viewModel.settings.showToolbarLabels)
                    .onChange(of: viewModel.settings.showToolbarLabels) { _ in
                        viewModel.saveSettings()
                    }
                    .disabled(viewModel.settings.compactTopBar)

                Toggle("Show Branch in Toolbar", isOn: $viewModel.settings.showBranchInToolbar)
                    .onChange(of: viewModel.settings.showBranchInToolbar) { _ in
                        viewModel.saveSettings()
                    }
            }

            Section("Sidebar") {
                Picker("Sidebar Width", selection: $viewModel.settings.sidebarWidth) {
                    Text("Narrow").tag(SidebarWidth.narrow)
                    Text("Standard").tag(SidebarWidth.standard)
                    Text("Wide").tag(SidebarWidth.wide)
                }
                .onChange(of: viewModel.settings.sidebarWidth) { _ in
                    viewModel.saveSettings()
                }

                Toggle("Show Icons in Sidebar", isOn: $viewModel.settings.showSidebarIcons)
                    .onChange(of: viewModel.settings.showSidebarIcons) { _ in
                        viewModel.saveSettings()
                    }

                Toggle("Show Counts in Sidebar", isOn: $viewModel.settings.showSidebarCounts)
                    .onChange(of: viewModel.settings.showSidebarCounts) { _ in
                        viewModel.saveSettings()
                    }
            }

            Section("Diff View") {
                Toggle("Line Numbers", isOn: $viewModel.settings.showLineNumbers)
                    .onChange(of: viewModel.settings.showLineNumbers) { _ in
                        viewModel.saveSettings()
                    }

                Toggle("Word Wrap", isOn: $viewModel.settings.wordWrap)
                    .onChange(of: viewModel.settings.wordWrap) { _ in
                        viewModel.saveSettings()
                    }

                Stepper("Context Lines: \(viewModel.settings.contextLines)", value: $viewModel.settings.contextLines, in: 1...10)
                    .onChange(of: viewModel.settings.contextLines) { _ in
                        viewModel.saveSettings()
                    }
            }

            Section("Fonts") {
                HStack {
                    Text("Editor Font")
                    Spacer()
                    Text(viewModel.settings.editorFont)
                        .foregroundColor(.secondary)
                    Button("Change...") {
                        viewModel.showFontPicker()
                    }
                }

                Stepper("Font Size: \(viewModel.settings.fontSize)pt", value: $viewModel.settings.fontSize, in: 9...24)
                    .onChange(of: viewModel.settings.fontSize) { _ in
                        viewModel.saveSettings()
                    }
            }

            Section("Animations") {
                Toggle("Enable Animations", isOn: $viewModel.settings.enableAnimations)
                    .onChange(of: viewModel.settings.enableAnimations) { _ in
                        viewModel.saveSettings()
                    }

                Toggle("Smooth Scrolling", isOn: $viewModel.settings.smoothScrolling)
                    .onChange(of: viewModel.settings.smoothScrolling) { _ in
                        viewModel.saveSettings()
                    }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data Models

enum SidebarWidth: String, Codable {
    case narrow
    case standard
    case wide

    var points: CGFloat {
        switch self {
        case .narrow: return 180
        case .standard: return 220
        case .wide: return 280
        }
    }
}

struct AppearanceSettings: Codable {
    var theme: AppTheme = .system
    var compactTopBar: Bool = false
    var showToolbarLabels: Bool = true
    var showBranchInToolbar: Bool = true
    var sidebarWidth: SidebarWidth = .standard
    var showSidebarIcons: Bool = true
    var showSidebarCounts: Bool = true
    var showLineNumbers: Bool = true
    var wordWrap: Bool = false
    var contextLines: Int = 3
    var editorFont: String = "SF Mono"
    var fontSize: Int = 12
    var enableAnimations: Bool = true
    var smoothScrolling: Bool = true

    private static let key = "appearanceSettings"

    static func load() -> AppearanceSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppearanceSettings.self, from: data) else {
            return AppearanceSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppearanceSettings.key)
        }
    }
}

// MARK: - View Model

@MainActor
class AppearanceSettingsViewModel: ObservableObject {
    @Published var settings: AppearanceSettings

    init() {
        settings = AppearanceSettings.load()
    }

    func saveSettings() {
        settings.save()
        NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
    }

    func applyTheme() {
        let appearance: NSAppearance?
        switch settings.theme {
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        case .system:
            appearance = nil
        }
        NSApp.appearance = appearance
        saveSettings()
    }

    func showFontPicker() {
        let fontManager = NSFontManager.shared
        let panel = fontManager.fontPanel(true)

        if let font = NSFont(name: settings.editorFont, size: CGFloat(settings.fontSize)) {
            fontManager.setSelectedFont(font, isMultiple: false)
        }

        panel?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let appearanceSettingsChanged = Notification.Name("appearanceSettingsChanged")
}

// MARK: - Compact Toolbar View

struct CompactToolbarView: View {
    let settings: AppearanceSettings
    let repositoryName: String
    let branchName: String
    let onFetch: () -> Void
    let onPull: () -> Void
    let onPush: () -> Void
    let onStash: () -> Void

    var body: some View {
        HStack(spacing: settings.compactTopBar ? 8 : 12) {
            // Navigation
            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Button(action: {}) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            Divider()
                .frame(height: settings.compactTopBar ? 16 : 20)

            // Repository info
            if settings.showBranchInToolbar {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(settings.compactTopBar ? .caption : .body)
                    Text(branchName)
                        .font(settings.compactTopBar ? .caption : .body)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }

            Spacer()

            // Actions
            HStack(spacing: settings.compactTopBar ? 4 : 8) {
                toolbarButton("arrow.triangle.2.circlepath", label: "Fetch", action: onFetch)
                toolbarButton("arrow.down", label: "Pull", action: onPull)
                toolbarButton("arrow.up", label: "Push", action: onPush)

                Divider()
                    .frame(height: settings.compactTopBar ? 16 : 20)

                toolbarButton("archivebox", label: "Stash", action: onStash)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, settings.compactTopBar ? 4 : 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func toolbarButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if settings.showToolbarLabels && !settings.compactTopBar {
                Label(label, systemImage: icon)
            } else {
                Image(systemName: icon)
            }
        }
        .buttonStyle(.borderless)
        .font(settings.compactTopBar ? .caption : .body)
        .help(label)
    }
}

#Preview("Appearance Settings") {
    AppearanceSettingsView()
        .frame(width: 500, height: 600)
}

#Preview("Compact Toolbar") {
    VStack(spacing: 0) {
        CompactToolbarView(
            settings: AppearanceSettings(compactTopBar: true, showToolbarLabels: false),
            repositoryName: "MyProject",
            branchName: "main",
            onFetch: {},
            onPull: {},
            onPush: {},
            onStash: {}
        )

        Divider()

        CompactToolbarView(
            settings: AppearanceSettings(compactTopBar: false, showToolbarLabels: true),
            repositoryName: "MyProject",
            branchName: "feature/new-feature",
            onFetch: {},
            onPull: {},
            onPush: {},
            onStash: {}
        )
    }
}
