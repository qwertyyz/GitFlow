import SwiftUI

/// Settings view for managing commit templates.
struct CommitTemplatesView: View {
    @StateObject private var viewModel = CommitTemplatesViewModel()
    @State private var showCreateSheet: Bool = false
    @State private var showImportPanel: Bool = false
    @State private var editingTemplate: CommitTemplate?
    @State private var templateToDelete: CommitTemplate?
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("All").tag(CommitTemplate.Category?.none)
                    ForEach(CommitTemplate.Category.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(CommitTemplate.Category?.some(category))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Spacer()

                Button {
                    showImportPanel = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import template")

                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create new template")
            }
            .padding(DSSpacing.md)

            Divider()

            // Template list
            if viewModel.filteredTemplates.isEmpty {
                emptyState
            } else {
                List(selection: $viewModel.selectedTemplateId) {
                    ForEach(viewModel.filteredTemplates) { template in
                        TemplateRow(
                            template: template,
                            onEdit: { editingTemplate = template },
                            onDelete: {
                                templateToDelete = template
                                showDeleteConfirmation = true
                            },
                            onExport: { exportTemplate(template) }
                        )
                        .tag(template.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            TemplateEditorSheet(
                mode: .create,
                onSave: { template in
                    viewModel.create(template)
                }
            )
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorSheet(
                mode: .edit(template),
                onSave: { updated in
                    viewModel.update(updated)
                }
            )
        }
        .confirmationDialog(
            "Delete Template",
            isPresented: $showDeleteConfirmation,
            presenting: templateToDelete
        ) { template in
            Button("Delete", role: .destructive) {
                viewModel.delete(template)
            }
            Button("Cancel", role: .cancel) {}
        } message: { template in
            Text("Are you sure you want to delete \"\(template.name)\"? This cannot be undone.")
        }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importTemplate(from: url)
                }
            case .failure(let error):
                viewModel.error = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "An unknown error occurred")
        }
        .onAppear {
            viewModel.loadTemplates()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Templates")
                .font(.headline)

            Text("Create a template to speed up your commit workflow.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Create Template") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func exportTemplate(_ template: CommitTemplate) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(template.name).\(CommitTemplate.fileExtension)"
        panel.message = "Export template"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.exportTemplate(template, to: url)
        }
    }
}

// MARK: - Template Row

private struct TemplateRow: View {
    let template: CommitTemplate
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: template.category.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(template.name)
                        .fontWeight(.medium)

                    if template.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(template.content.prefix(50) + (template.content.count > 50 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if template.hasPlaceholders {
                    HStack(spacing: 4) {
                        ForEach(template.placeholderNames.prefix(3), id: \.self) { name in
                            Text("{{\(name)}}")
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(3)
                        }
                        if template.placeholderNames.count > 3 {
                            Text("+\(template.placeholderNames.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Text(template.category.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit...") { onEdit() }
                .disabled(template.isBuiltIn)

            Button("Export...") { onExport() }

            Divider()

            Button("Delete", role: .destructive) { onDelete() }
                .disabled(template.isBuiltIn)
        }
    }
}

// MARK: - Template Editor Sheet

private struct TemplateEditorSheet: View {
    enum Mode {
        case create
        case edit(CommitTemplate)

        var title: String {
            switch self {
            case .create: return "New Template"
            case .edit: return "Edit Template"
            }
        }

        var template: CommitTemplate? {
            switch self {
            case .create: return nil
            case .edit(let template): return template
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSave: (CommitTemplate) -> Void

    @State private var name: String = ""
    @State private var content: String = ""
    @State private var category: CommitTemplate.Category = .custom

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode.title)
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(CommitTemplate.Category.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }

                Section {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                } header: {
                    Text("Template Content")
                } footer: {
                    Text("Use {{placeholder}} syntax for variables. Example: {{summary}}, {{description}}")
                }

                if !content.isEmpty {
                    Section {
                        let placeholders = extractPlaceholders(from: content)
                        if placeholders.isEmpty {
                            Text("No placeholders detected")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(placeholders, id: \.self) { placeholder in
                                HStack {
                                    Text("{{\(placeholder)}}")
                                        .fontDesign(.monospaced)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    } header: {
                        Text("Detected Placeholders")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveTemplate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || content.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            if let template = mode.template {
                name = template.name
                content = template.content
                category = template.category
            }
        }
    }

    private func extractPlaceholders(from text: String) -> [String] {
        let pattern = #"\{\{(\w+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        var placeholders: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let placeholder = String(text[range])
                if !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }
        return placeholders
    }

    private func saveTemplate() {
        let template: CommitTemplate

        if case .edit(let existing) = mode {
            template = CommitTemplate(
                id: existing.id,
                name: name,
                content: content,
                category: category,
                createdAt: existing.createdAt,
                modifiedAt: Date(),
                isBuiltIn: false
            )
        } else {
            template = CommitTemplate(
                name: name,
                content: content,
                category: category
            )
        }

        onSave(template)
        dismiss()
    }
}

// MARK: - View Model

@MainActor
final class CommitTemplatesViewModel: ObservableObject {
    @Published var templates: [CommitTemplate] = []
    @Published var selectedTemplateId: UUID?
    @Published var selectedCategory: CommitTemplate.Category?
    @Published var error: String?

    private let store = CommitTemplateStore()

    var filteredTemplates: [CommitTemplate] {
        if let category = selectedCategory {
            return templates.filter { $0.category == category }
        }
        return templates
    }

    func loadTemplates() {
        templates = store.loadAll()
    }

    func create(_ template: CommitTemplate) {
        do {
            try store.save(template)
            loadTemplates()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func update(_ template: CommitTemplate) {
        do {
            try store.update(template)
            loadTemplates()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ template: CommitTemplate) {
        do {
            try store.delete(template)
            loadTemplates()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func importTemplate(from url: URL) {
        do {
            _ = try store.importTemplate(from: url)
            loadTemplates()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func exportTemplate(_ template: CommitTemplate, to url: URL) {
        do {
            try store.exportTemplate(template, to: url)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    CommitTemplatesView()
        .frame(width: 500, height: 400)
}
