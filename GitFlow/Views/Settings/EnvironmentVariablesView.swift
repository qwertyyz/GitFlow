import SwiftUI

/// Settings view for managing environment variables used in Git operations.
struct EnvironmentVariablesView: View {
    @StateObject private var viewModel = EnvironmentVariablesViewModel()
    @State private var showingAddSheet = false
    @State private var editingVariable: EnvironmentVariable?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Environment Variables")
                    .font(.headline)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add Variable", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Environment variables are passed to Git commands and hooks. Use them to configure Git behavior or pass secrets securely.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Label("Global variables apply to all repositories", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("Repository variables override global ones", systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Variables list
            if viewModel.globalVariables.isEmpty && viewModel.repositoryVariables.isEmpty {
                emptyStateView
            } else {
                List {
                    // Global variables
                    Section("Global Variables") {
                        ForEach(viewModel.globalVariables) { variable in
                            EnvironmentVariableRow(
                                variable: variable,
                                onEdit: { editingVariable = variable },
                                onDelete: { viewModel.deleteVariable(variable) },
                                onToggle: { viewModel.toggleVariable(variable) }
                            )
                        }

                        if viewModel.globalVariables.isEmpty {
                            Text("No global variables defined")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Repository-specific variables
                    if !viewModel.repositoryVariables.isEmpty {
                        Section("Repository Variables") {
                            ForEach(viewModel.repositoryVariables) { variable in
                                EnvironmentVariableRow(
                                    variable: variable,
                                    onEdit: { editingVariable = variable },
                                    onDelete: { viewModel.deleteVariable(variable) },
                                    onToggle: { viewModel.toggleVariable(variable) }
                                )
                            }
                        }
                    }

                    // Common Git environment variables
                    Section("Common Git Variables") {
                        ForEach(CommonGitVariable.allCases) { gitVar in
                            CommonVariableRow(
                                gitVariable: gitVar,
                                isSet: viewModel.isVariableSet(gitVar.name),
                                onAdd: { showAddSheet(for: gitVar) }
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEnvironmentVariableSheet(viewModel: viewModel)
        }
        .sheet(item: $editingVariable) { variable in
            EditEnvironmentVariableSheet(viewModel: viewModel, variable: variable)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Environment Variables")
                .font(.headline)

            Text("Add environment variables to customize Git behavior.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Add Variable") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func showAddSheet(for gitVar: CommonGitVariable) {
        viewModel.prepopulatedName = gitVar.name
        viewModel.prepopulatedDescription = gitVar.description
        showingAddSheet = true
    }
}

// MARK: - Environment Variable Row

struct EnvironmentVariableRow: View {
    let variable: EnvironmentVariable
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Enable toggle
            Toggle("", isOn: Binding(
                get: { variable.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()

            // Variable info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(variable.name)
                        .font(.headline)
                        .foregroundColor(variable.isEnabled ? .primary : .secondary)

                    if variable.isSecret {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if variable.scope == .repository {
                        Text("Repository")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(variable.isSecret ? "••••••••" : variable.value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let description = variable.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit variable")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete variable")
            }
        }
        .padding(.vertical, 4)
        .opacity(variable.isEnabled ? 1 : 0.6)
    }
}

// MARK: - Common Variable Row

struct CommonVariableRow: View {
    let gitVariable: CommonGitVariable
    let isSet: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(gitVariable.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isSet {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Text(gitVariable.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isSet {
                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Variable Sheet

struct AddEnvironmentVariableSheet: View {
    @ObservedObject var viewModel: EnvironmentVariablesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var value: String = ""
    @State private var description: String = ""
    @State private var isSecret: Bool = false
    @State private var scope: VariableScope = .global

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Environment Variable")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)

                    if isSecret {
                        SecureField("Value", text: $value)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("Value", text: $value)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Description (optional)", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Toggle("Secret Value", isOn: $isSecret)

                    Picker("Scope", selection: $scope) {
                        Text("Global").tag(VariableScope.global)
                        Text("Current Repository").tag(VariableScope.repository)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Add") {
                    addVariable()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || value.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
        .onAppear {
            if let prepopName = viewModel.prepopulatedName {
                name = prepopName
                viewModel.prepopulatedName = nil
            }
            if let prepopDesc = viewModel.prepopulatedDescription {
                description = prepopDesc
                viewModel.prepopulatedDescription = nil
            }
        }
    }

    private func addVariable() {
        let variable = EnvironmentVariable(
            name: name.uppercased(),
            value: value,
            description: description.isEmpty ? nil : description,
            isSecret: isSecret,
            scope: scope,
            isEnabled: true
        )
        viewModel.addVariable(variable)
        dismiss()
    }
}

// MARK: - Edit Variable Sheet

struct EditEnvironmentVariableSheet: View {
    @ObservedObject var viewModel: EnvironmentVariablesViewModel
    let variable: EnvironmentVariable
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var value: String = ""
    @State private var description: String = ""
    @State private var isSecret: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Environment Variable")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    if isSecret {
                        SecureField("Value", text: $value)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("Value", text: $value)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Description (optional)", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Toggle("Secret Value", isOn: $isSecret)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Save") {
                    saveVariable()
                }
                .buttonStyle(.borderedProminent)
                .disabled(value.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 320)
        .onAppear {
            name = variable.name
            value = variable.value
            description = variable.description ?? ""
            isSecret = variable.isSecret
        }
    }

    private func saveVariable() {
        var updated = variable
        updated.value = value
        updated.description = description.isEmpty ? nil : description
        updated.isSecret = isSecret
        viewModel.updateVariable(updated)
        dismiss()
    }
}

// MARK: - Data Models

struct EnvironmentVariable: Identifiable, Codable {
    let id: UUID
    var name: String
    var value: String
    var description: String?
    var isSecret: Bool
    var scope: VariableScope
    var isEnabled: Bool
    var repositoryPath: String?

    init(
        id: UUID = UUID(),
        name: String,
        value: String,
        description: String? = nil,
        isSecret: Bool = false,
        scope: VariableScope = .global,
        isEnabled: Bool = true,
        repositoryPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.description = description
        self.isSecret = isSecret
        self.scope = scope
        self.isEnabled = isEnabled
        self.repositoryPath = repositoryPath
    }
}

enum VariableScope: String, Codable {
    case global
    case repository
}

enum CommonGitVariable: String, CaseIterable, Identifiable {
    case gitAuthorName = "GIT_AUTHOR_NAME"
    case gitAuthorEmail = "GIT_AUTHOR_EMAIL"
    case gitCommitterName = "GIT_COMMITTER_NAME"
    case gitCommitterEmail = "GIT_COMMITTER_EMAIL"
    case gitEditor = "GIT_EDITOR"
    case gitSshCommand = "GIT_SSH_COMMAND"
    case gitProxy = "HTTPS_PROXY"
    case gitTerminalPrompt = "GIT_TERMINAL_PROMPT"

    var id: String { rawValue }

    var name: String { rawValue }

    var description: String {
        switch self {
        case .gitAuthorName:
            return "Override the author name for commits"
        case .gitAuthorEmail:
            return "Override the author email for commits"
        case .gitCommitterName:
            return "Override the committer name"
        case .gitCommitterEmail:
            return "Override the committer email"
        case .gitEditor:
            return "Editor to use for commit messages"
        case .gitSshCommand:
            return "Custom SSH command (e.g., for specific keys)"
        case .gitProxy:
            return "HTTPS proxy server for Git operations"
        case .gitTerminalPrompt:
            return "Disable terminal prompts (set to 0)"
        }
    }
}

// MARK: - View Model

@MainActor
class EnvironmentVariablesViewModel: ObservableObject {
    @Published var globalVariables: [EnvironmentVariable] = []
    @Published var repositoryVariables: [EnvironmentVariable] = []
    @Published var prepopulatedName: String?
    @Published var prepopulatedDescription: String?

    private let storageKey = "environmentVariables"
    var currentRepositoryPath: String?

    init() {
        loadVariables()
    }

    var allVariables: [EnvironmentVariable] {
        globalVariables + repositoryVariables
    }

    func isVariableSet(_ name: String) -> Bool {
        allVariables.contains { $0.name == name && $0.isEnabled }
    }

    func addVariable(_ variable: EnvironmentVariable) {
        if variable.scope == .global {
            globalVariables.append(variable)
        } else {
            repositoryVariables.append(variable)
        }
        saveVariables()
    }

    func updateVariable(_ variable: EnvironmentVariable) {
        if let index = globalVariables.firstIndex(where: { $0.id == variable.id }) {
            globalVariables[index] = variable
        } else if let index = repositoryVariables.firstIndex(where: { $0.id == variable.id }) {
            repositoryVariables[index] = variable
        }
        saveVariables()
    }

    func deleteVariable(_ variable: EnvironmentVariable) {
        globalVariables.removeAll { $0.id == variable.id }
        repositoryVariables.removeAll { $0.id == variable.id }
        saveVariables()
    }

    func toggleVariable(_ variable: EnvironmentVariable) {
        var updated = variable
        updated.isEnabled.toggle()
        updateVariable(updated)
    }

    /// Returns environment variables dictionary for use in Git commands.
    func environmentDictionary() -> [String: String] {
        var env: [String: String] = [:]

        // Add global variables
        for variable in globalVariables where variable.isEnabled {
            env[variable.name] = variable.value
        }

        // Override with repository-specific variables
        for variable in repositoryVariables where variable.isEnabled {
            if variable.repositoryPath == currentRepositoryPath || variable.repositoryPath == nil {
                env[variable.name] = variable.value
            }
        }

        return env
    }

    private func loadVariables() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let variables = try? JSONDecoder().decode([EnvironmentVariable].self, from: data) {
            globalVariables = variables.filter { $0.scope == .global }
            repositoryVariables = variables.filter { $0.scope == .repository }
        }
    }

    private func saveVariables() {
        let allVars = globalVariables + repositoryVariables
        if let data = try? JSONEncoder().encode(allVars) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

#Preview {
    EnvironmentVariablesView()
        .frame(width: 600, height: 500)
}
