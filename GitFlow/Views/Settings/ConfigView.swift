import SwiftUI

/// Main view for git configuration and app settings.
struct ConfigView: View {
    @ObservedObject var viewModel: ConfigViewModel

    @State private var selectedTab: Tab = .identity
    @State private var showAddEntry: Bool = false
    @State private var entryToEdit: GitConfigEntry?

    enum Tab: String, CaseIterable, Identifiable {
        case identity = "Identity"
        case gitConfig = "Git Config"
        case preferences = "Preferences"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .identity: return "person.circle"
            case .gitConfig: return "gearshape.2"
            case .preferences: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ConfigHeader(viewModel: viewModel)

            Divider()

            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            switch selectedTab {
            case .identity:
                IdentitySettingsView(viewModel: viewModel)
            case .gitConfig:
                GitConfigListView(
                    viewModel: viewModel,
                    onEdit: { entryToEdit = $0 },
                    onAdd: { showAddEntry = true }
                )
            case .preferences:
                AppPreferencesView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadConfig()
        }
        .sheet(isPresented: $showAddEntry) {
            ConfigEntrySheet(
                entry: nil,
                isPresented: $showAddEntry
            ) { key, value, scope in
                Task {
                    await viewModel.setValue(value, for: key, scope: scope)
                }
            }
        }
        .sheet(item: $entryToEdit) { entry in
            ConfigEntrySheet(
                entry: entry,
                isPresented: .init(
                    get: { entryToEdit != nil },
                    set: { if !$0 { entryToEdit = nil } }
                )
            ) { key, value, scope in
                Task {
                    await viewModel.setValue(value, for: key, scope: scope)
                }
            }
        }
        .alert("Configuration Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Dismiss") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Header

private struct ConfigHeader: View {
    @ObservedObject var viewModel: ConfigViewModel

    var body: some View {
        HStack {
            Text("Settings")
                .font(.headline)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }

            Button(action: { Task { await viewModel.loadConfig() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload configuration")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Identity Settings

private struct IdentitySettingsView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var hasChanges: Bool = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Your Name", text: $viewModel.userName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.userName) { _ in hasChanges = true }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("your.email@example.com", text: $viewModel.userEmail)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.userEmail) { _ in hasChanges = true }
                }
            } header: {
                Label("Git Identity", systemImage: "person.circle")
            } footer: {
                Text("This information will be used for commit authorship.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save Identity") {
                        Task {
                            await viewModel.saveUserIdentity()
                            hasChanges = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges || viewModel.userName.isEmpty || viewModel.userEmail.isEmpty)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GPG Signing")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Configure GPG key for commit signing in the Git Config tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Git Config List

private struct GitConfigListView: View {
    @ObservedObject var viewModel: ConfigViewModel
    let onEdit: (GitConfigEntry) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search config...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

                // Scope filter
                Picker("Scope", selection: $viewModel.scopeFilter) {
                    Text("All Scopes").tag(nil as ConfigScope?)
                    ForEach(ConfigScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope as ConfigScope?)
                    }
                }
                .frame(width: 120)

                // Section filter
                Picker("Section", selection: $viewModel.sectionFilter) {
                    Text("All Sections").tag(nil as String?)
                    ForEach(viewModel.sections, id: \.self) { section in
                        Text(section).tag(section as String?)
                    }
                }
                .frame(width: 120)

                Spacer()

                Button(action: onAdd) {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            // Config entries
            if viewModel.filteredEntries.isEmpty {
                if viewModel.isLoading {
                    ProgressView("Loading configuration...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyStateView(
                        "No Configuration",
                        systemImage: "gearshape",
                        description: "No configuration entries match your filters"
                    )
                }
            } else {
                List {
                    ForEach(viewModel.entriesBySection, id: \.section) { section, entries in
                        Section(section) {
                            ForEach(entries) { entry in
                                ConfigEntryRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onEdit(entry)
                                    }
                                    .contextMenu {
                                        Button("Edit") { onEdit(entry) }

                                        Button("Copy Key") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(entry.key, forType: .string)
                                        }

                                        Button("Copy Value") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(entry.value, forType: .string)
                                        }

                                        Divider()

                                        Button("Delete", role: .destructive) {
                                            Task {
                                                await viewModel.unsetValue(for: entry.key, scope: entry.scope)
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct ConfigEntryRow: View {
    let entry: GitConfigEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.key)
                    .font(.body.monospaced())

                Text(entry.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Scope badge
            Text(entry.scope.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(scopeColor.opacity(0.1))
                .foregroundStyle(scopeColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var scopeColor: Color {
        switch entry.scope {
        case .system: return .red
        case .global: return .blue
        case .local: return .green
        case .worktree: return .orange
        }
    }
}

// MARK: - App Preferences

private struct AppPreferencesView: View {
    @ObservedObject var viewModel: ConfigViewModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("External Editor")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("/Applications/...", text: $viewModel.appPreferences.externalEditor)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            selectApplication { url in
                                viewModel.appPreferences.externalEditor = url.path
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Clone Directory")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("~/Developer", text: $viewModel.appPreferences.defaultCloneDirectory)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            selectDirectory { url in
                                viewModel.appPreferences.defaultCloneDirectory = url.path
                            }
                        }
                    }
                }
            } header: {
                Label("File Handling", systemImage: "doc")
            }

            Section {
                Toggle("Show Hidden Files", isOn: $viewModel.appPreferences.showHiddenFiles)

                Toggle("Confirm Destructive Operations", isOn: $viewModel.appPreferences.confirmDestructiveOperations)

                Picker("Auto-Fetch Interval", selection: $viewModel.appPreferences.autoFetchInterval) {
                    Text("Disabled").tag(0)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                    Text("15 minutes").tag(900)
                    Text("30 minutes").tag(1800)
                }
            } header: {
                Label("Behavior", systemImage: "gearshape")
            }

            Section {
                Picker("Theme", selection: $viewModel.appPreferences.theme) {
                    ForEach(AppPreferences.ThemePreference.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
            } header: {
                Label("Appearance", systemImage: "paintbrush")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save Preferences") {
                        viewModel.saveAppPreferences()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func selectApplication(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    private func selectDirectory(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }
}

// MARK: - Config Entry Sheet

private struct ConfigEntrySheet: View {
    let entry: GitConfigEntry?
    @Binding var isPresented: Bool
    let onSave: (String, String, ConfigScope) -> Void

    @State private var key: String = ""
    @State private var value: String = ""
    @State private var scope: ConfigScope = .local

    var isEditing: Bool { entry != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Configuration" : "Add Configuration")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("section.name", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isEditing)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("value", text: $value)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Scope")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Scope", selection: $scope) {
                        ForEach(ConfigScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing)

                    Text(scope.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add") {
                    onSave(key, value, scope)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(key.isEmpty || value.isEmpty)
            }
            .padding()
        }
        .frame(width: 400)
        .onAppear {
            if let entry = entry {
                key = entry.key
                value = entry.value
                scope = entry.scope
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConfigView(
        viewModel: ConfigViewModel(
            repository: Repository(rootURL: URL(fileURLWithPath: "/tmp")),
            gitService: GitService()
        )
    )
    .frame(width: 600, height: 700)
}
