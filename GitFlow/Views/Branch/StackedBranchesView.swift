import SwiftUI

/// View for managing stacked branches workflow.
/// Stacked branches allow developing multiple dependent features in sequence,
/// where each branch builds on the previous one.
struct StackedBranchesView: View {
    @StateObject private var viewModel: StackedBranchesViewModel

    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: StackedBranchesViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Stacked Branches")
                    .font(.headline)

                Spacer()

                Button(action: { viewModel.showingCreateStackSheet = true }) {
                    Label("New Stack", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if viewModel.stacks.isEmpty {
                emptyStateView
            } else {
                List(viewModel.stacks) { stack in
                    StackRow(
                        stack: stack,
                        viewModel: viewModel,
                        onSelect: { viewModel.selectedStack = stack }
                    )
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $viewModel.showingCreateStackSheet) {
            CreateStackSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedStack) { stack in
            StackDetailSheet(stack: stack, viewModel: viewModel)
        }
        .task {
            await viewModel.loadStacks()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Branch Stacks")
                .font(.headline)

            Text("Stacked branches let you work on multiple dependent features. Each branch in a stack builds on the one below it.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Create Your First Stack") {
                viewModel.showingCreateStackSheet = true
            }
            .buttonStyle(.borderedProminent)

            // Benefits section
            VStack(alignment: .leading, spacing: 12) {
                Text("Benefits of Stacked Branches:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                StackBenefitRow(icon: "arrow.triangle.branch", title: "Keep PRs small", description: "Split large features into reviewable chunks")
                StackBenefitRow(icon: "clock", title: "Don't wait for reviews", description: "Continue working while PRs are pending")
                StackBenefitRow(icon: "arrow.triangle.swap", title: "Easy rebasing", description: "Rebase entire stacks with one click")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct StackBenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Stack Row

struct StackRow: View {
    let stack: BranchStack
    @ObservedObject var viewModel: StackedBranchesViewModel
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundColor(.blue)

                Text(stack.name)
                    .font(.headline)

                Spacer()

                Text("\(stack.branches.count) branches")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: onSelect) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            // Branch visualization
            HStack(spacing: 4) {
                ForEach(Array(stack.branches.enumerated()), id: \.element.name) { index, branch in
                    HStack(spacing: 4) {
                        if index > 0 {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        branchChip(branch)
                    }
                }
            }

            // Status
            HStack(spacing: 12) {
                if let current = stack.currentBranch {
                    Label("On: \(current)", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if stack.hasConflicts {
                    Label("Conflicts", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if stack.needsRebase {
                    Label("Needs rebase", systemImage: "arrow.triangle.swap")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func branchChip(_ branch: StackBranch) -> some View {
        let isCurrentBranch = branch.name == stack.currentBranch

        HStack(spacing: 4) {
            if isCurrentBranch {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
            }

            Text(branch.shortName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isCurrentBranch ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
        .foregroundColor(isCurrentBranch ? .blue : .secondary)
        .cornerRadius(4)
    }
}

// MARK: - Create Stack Sheet

struct CreateStackSheet: View {
    @ObservedObject var viewModel: StackedBranchesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var stackName: String = ""
    @State private var baseBranch: String = ""
    @State private var firstBranchName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Branch Stack")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section("Stack Name") {
                    TextField("e.g., feature-auth-system", text: $stackName)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Base Branch") {
                    Picker("Build on", selection: $baseBranch) {
                        ForEach(viewModel.availableBranches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }

                    Text("This is the branch your stack will be based on (usually main or develop)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("First Branch") {
                    TextField("e.g., auth/user-model", text: $firstBranchName)
                        .textFieldStyle(.roundedBorder)

                    Text("The first branch in your stack. You can add more branches later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Create Stack") {
                    createStack()
                }
                .buttonStyle(.borderedProminent)
                .disabled(stackName.isEmpty || baseBranch.isEmpty || firstBranchName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
        .onAppear {
            baseBranch = viewModel.availableBranches.first ?? "main"
        }
    }

    private func createStack() {
        Task {
            await viewModel.createStack(
                name: stackName,
                baseBranch: baseBranch,
                firstBranch: firstBranchName
            )
            dismiss()
        }
    }
}

// MARK: - Stack Detail Sheet

struct StackDetailSheet: View {
    let stack: BranchStack
    @ObservedObject var viewModel: StackedBranchesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddBranchSheet = false
    @State private var newBranchName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stack.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Based on \(stack.baseBranch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            // Stack visualization
            ScrollView {
                VStack(spacing: 0) {
                    // Base branch
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.secondary)

                        Text(stack.baseBranch)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("Base")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))

                    // Branches in stack
                    ForEach(Array(stack.branches.enumerated()), id: \.element.name) { index, branch in
                        VStack(spacing: 0) {
                            // Connector line
                            HStack {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 2, height: 20)
                                    .padding(.leading, 20)
                                Spacer()
                            }

                            // Branch row
                            StackBranchRow(
                                branch: branch,
                                isCurrentBranch: branch.name == stack.currentBranch,
                                onCheckout: { viewModel.checkout(branch: branch.name) },
                                onCreatePR: { viewModel.createPR(for: branch, in: stack) }
                            )
                        }
                    }

                    // Add branch button
                    Button(action: { showingAddBranchSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Branch to Stack")
                        }
                        .padding()
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                Button("Rebase Stack") {
                    Task {
                        await viewModel.rebaseStack(stack)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isOperationInProgress)

                Button("Submit All PRs") {
                    Task {
                        await viewModel.submitAllPRs(for: stack)
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Delete Stack", role: .destructive) {
                    viewModel.deleteStack(stack)
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .sheet(isPresented: $showingAddBranchSheet) {
            AddBranchToStackSheet(
                stackName: stack.name,
                onAdd: { name in
                    Task {
                        await viewModel.addBranch(name: name, to: stack)
                    }
                }
            )
        }
    }
}

struct StackBranchRow: View {
    let branch: StackBranch
    let isCurrentBranch: Bool
    let onCheckout: () -> Void
    let onCreatePR: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Branch icon
            Image(systemName: isCurrentBranch ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCurrentBranch ? .green : .blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(branch.name)
                    .font(.subheadline)
                    .fontWeight(isCurrentBranch ? .semibold : .regular)

                HStack(spacing: 8) {
                    if let prState = branch.prState {
                        PRStateBadge(state: prState)
                    }

                    if branch.aheadCount > 0 {
                        Text("↑\(branch.aheadCount)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if branch.behindCount > 0 {
                        Text("↓\(branch.behindCount)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    if !isCurrentBranch {
                        Button("Checkout") {
                            onCheckout()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if branch.prState == nil {
                        Button("Create PR") {
                            onCreatePR()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .background(isCurrentBranch ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct PRStateBadge: View {
    let state: PRState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.icon)
            Text(state.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(state.color.opacity(0.2))
        .foregroundColor(state.color)
        .cornerRadius(4)
    }
}

struct AddBranchToStackSheet: View {
    let stackName: String
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var branchName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Branch to Stack")
                .font(.headline)

            TextField("Branch name", text: $branchName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Add") {
                    onAdd(branchName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(branchName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Data Models

struct BranchStack: Identifiable {
    let id: UUID
    let name: String
    let baseBranch: String
    var branches: [StackBranch]
    var currentBranch: String?

    var hasConflicts: Bool {
        branches.contains { $0.hasConflicts }
    }

    var needsRebase: Bool {
        branches.contains { $0.behindCount > 0 }
    }
}

struct StackBranch: Identifiable {
    let id: UUID
    let name: String
    var aheadCount: Int
    var behindCount: Int
    var hasConflicts: Bool
    var prState: PRState?

    var shortName: String {
        if let lastSlash = name.lastIndex(of: "/") {
            return String(name[name.index(after: lastSlash)...])
        }
        return name
    }
}

enum PRState: String {
    case draft
    case open
    case approved
    case merged
    case closed

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .open: return "Open"
        case .approved: return "Approved"
        case .merged: return "Merged"
        case .closed: return "Closed"
        }
    }

    var icon: String {
        switch self {
        case .draft: return "doc"
        case .open: return "arrow.triangle.pull"
        case .approved: return "checkmark.circle"
        case .merged: return "arrow.triangle.merge"
        case .closed: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .draft: return .secondary
        case .open: return .green
        case .approved: return .green
        case .merged: return .purple
        case .closed: return .red
        }
    }
}

// MARK: - View Model

@MainActor
class StackedBranchesViewModel: ObservableObject {
    @Published var stacks: [BranchStack] = []
    @Published var availableBranches: [String] = []
    @Published var selectedStack: BranchStack?
    @Published var showingCreateStackSheet = false
    @Published var isOperationInProgress = false
    @Published var error: String?

    let repository: Repository
    private let storageKey: String

    init(repository: Repository) {
        self.repository = repository
        self.storageKey = "stacks_\(repository.path.hashValue)"
        Task {
            await loadStacks()
        }
        
    }

    func loadStacks() async {
        // Load stacks from storage
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([StackData].self, from: data) {
            stacks = decoded.map { data in
                BranchStack(
                    id: data.id,
                    name: data.name,
                    baseBranch: data.baseBranch,
                    branches: data.branches.map { branchData in
                        StackBranch(
                            id: branchData.id,
                            name: branchData.name,
                            aheadCount: 0,
                            behindCount: 0,
                            hasConflicts: false,
                            prState: nil
                        )
                    },
                    currentBranch: data.currentBranch
                )
            }
        }

        // Load available branches (placeholder)
        availableBranches = ["main", "develop"]
    }

    func createStack(name: String, baseBranch: String, firstBranch: String) async {
        let newStack = BranchStack(
            id: UUID(),
            name: name,
            baseBranch: baseBranch,
            branches: [
                StackBranch(
                    id: UUID(),
                    name: firstBranch,
                    aheadCount: 0,
                    behindCount: 0,
                    hasConflicts: false,
                    prState: nil
                )
            ],
            currentBranch: firstBranch
        )

        stacks.append(newStack)
        saveStacks()
    }

    func addBranch(name: String, to stack: BranchStack) async {
        guard let index = stacks.firstIndex(where: { $0.id == stack.id }) else { return }

        let newBranch = StackBranch(
            id: UUID(),
            name: name,
            aheadCount: 0,
            behindCount: 0,
            hasConflicts: false,
            prState: nil
        )

        stacks[index].branches.append(newBranch)
        saveStacks()
    }

    func checkout(branch: String) {
        // Would run git checkout
        if let stackIndex = stacks.firstIndex(where: { $0.branches.contains { $0.name == branch } }) {
            stacks[stackIndex].currentBranch = branch
            saveStacks()
        }
    }

    func createPR(for branch: StackBranch, in stack: BranchStack) {
        // Would create a PR for the branch
    }

    func rebaseStack(_ stack: BranchStack) async {
        isOperationInProgress = true

        // Would rebase each branch in the stack
        // git rebase baseBranch firstBranch
        // git rebase firstBranch secondBranch
        // etc.

        isOperationInProgress = false
    }

    func submitAllPRs(for stack: BranchStack) async {
        // Would create PRs for all branches in the stack
    }

    func deleteStack(_ stack: BranchStack) {
        stacks.removeAll { $0.id == stack.id }
        saveStacks()
    }

    private func saveStacks() {
        let data = stacks.map { stack in
            StackData(
                id: stack.id,
                name: stack.name,
                baseBranch: stack.baseBranch,
                branches: stack.branches.map { StackBranchData(id: $0.id, name: $0.name) },
                currentBranch: stack.currentBranch
            )
        }

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Storage Models

struct StackData: Codable {
    let id: UUID
    let name: String
    let baseBranch: String
    let branches: [StackBranchData]
    let currentBranch: String?
}

struct StackBranchData: Codable {
    let id: UUID
    let name: String
}

#Preview {
    StackedBranchesView(repository: Repository(rootURL: URL(fileURLWithPath: "/tmp/test")))
        .frame(width: 600, height: 500)
}
