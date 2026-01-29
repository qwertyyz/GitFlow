import SwiftUI

/// Settings view for configuring external diff, merge, and editor tools.
struct ExternalToolsSettingsView: View {
    @State private var diffTool: ExternalTool?
    @State private var mergeTool: ExternalTool?
    @State private var editorTool: ExternalTool?

    @State private var showingDiffToolPicker = false
    @State private var showingMergeToolPicker = false
    @State private var showingEditorToolPicker = false

    @State private var customDiffPath = ""
    @State private var customDiffArgs = ""
    @State private var customMergePath = ""
    @State private var customMergeArgs = ""
    @State private var customEditorPath = ""
    @State private var customEditorArgs = ""

    private let toolService = ExternalToolService()

    var body: some View {
        Form {
            // Diff Tool Section
            Section("Diff Tool") {
                toolConfigRow(
                    tool: diffTool,
                    toolType: .diff,
                    showingPicker: $showingDiffToolPicker,
                    onClear: { diffTool = nil; saveTools() }
                )
            }

            // Merge Tool Section
            Section("Merge Tool") {
                toolConfigRow(
                    tool: mergeTool,
                    toolType: .merge,
                    showingPicker: $showingMergeToolPicker,
                    onClear: { mergeTool = nil; saveTools() }
                )
            }

            // Editor Tool Section
            Section("Editor") {
                toolConfigRow(
                    tool: editorTool,
                    toolType: .editor,
                    showingPicker: $showingEditorToolPicker,
                    onClear: { editorTool = nil; saveTools() }
                )
            }

            // Help Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Placeholders for custom arguments:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("$LOCAL - Local/old file path")
                        Text("$REMOTE - Remote/new file path")
                        Text("$BASE - Base file path (3-way merge)")
                        Text("$MERGED - Output file path (merge)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadTools()
        }
        .sheet(isPresented: $showingDiffToolPicker) {
            ToolPickerSheet(
                toolType: .diff,
                selectedTool: $diffTool,
                onSave: saveTools
            )
        }
        .sheet(isPresented: $showingMergeToolPicker) {
            ToolPickerSheet(
                toolType: .merge,
                selectedTool: $mergeTool,
                onSave: saveTools
            )
        }
        .sheet(isPresented: $showingEditorToolPicker) {
            ToolPickerSheet(
                toolType: .editor,
                selectedTool: $editorTool,
                onSave: saveTools
            )
        }
    }

    // MARK: - Tool Config Row

    @ViewBuilder
    private func toolConfigRow(
        tool: ExternalTool?,
        toolType: ExternalTool.ToolType,
        showingPicker: Binding<Bool>,
        onClear: @escaping () -> Void
    ) -> some View {
        if let tool = tool {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.name)
                            .font(.body)
                        Text(tool.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button("Change") {
                        showingPicker.wrappedValue = true
                    }

                    Button(role: .destructive) {
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack {
                Text("No \(toolType.rawValue.lowercased()) tool configured")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Configure...") {
                    showingPicker.wrappedValue = true
                }
            }
        }
    }

    // MARK: - Load/Save

    private func loadTools() {
        Task {
            diffTool = await toolService.getDiffTool()
            mergeTool = await toolService.getMergeTool()
            editorTool = await toolService.getEditorTool()
        }
    }

    private func saveTools() {
        Task {
            await toolService.setDiffTool(diffTool)
            await toolService.setMergeTool(mergeTool)
            await toolService.setEditorTool(editorTool)
        }
    }
}

// MARK: - Tool Picker Sheet

struct ToolPickerSheet: View {
    let toolType: ExternalTool.ToolType
    @Binding var selectedTool: ExternalTool?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var presetSelection: ExternalTool?
    @State private var useCustom = false
    @State private var customName = ""
    @State private var customPath = ""
    @State private var customArgs = ""

    private var installedPresets: [ExternalTool] {
        ExternalToolPresets.installedPresets(for: toolType)
    }

    private var allPresets: [ExternalTool] {
        ExternalToolPresets.presets(for: toolType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Configure \(toolType.rawValue) Tool")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Preset Selection
                if !installedPresets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installed Applications")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(installedPresets) { preset in
                            PresetRow(
                                preset: preset,
                                isSelected: presetSelection?.id == preset.id && !useCustom,
                                onSelect: {
                                    presetSelection = preset
                                    useCustom = false
                                }
                            )
                        }
                    }
                }

                Divider()

                // Custom Configuration
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Use custom tool", isOn: $useCustom)

                    if useCustom {
                        TextField("Name", text: $customName)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            TextField("Path", text: $customPath)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse...") {
                                browseForTool()
                            }
                        }

                        TextField("Arguments", text: $customArgs)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()

            Spacer()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveTool()
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            if let current = selectedTool {
                // Check if it matches a preset
                if let matching = allPresets.first(where: { $0.path == current.path }) {
                    presetSelection = matching
                    useCustom = false
                } else {
                    useCustom = true
                    customName = current.name
                    customPath = current.path
                    customArgs = current.arguments
                }
            }
        }
    }

    private var canSave: Bool {
        if useCustom {
            return !customName.isEmpty && !customPath.isEmpty
        } else {
            return presetSelection != nil
        }
    }

    private func saveTool() {
        if useCustom {
            selectedTool = ExternalTool(
                name: customName,
                path: customPath,
                arguments: customArgs,
                type: toolType
            )
        } else {
            selectedTool = presetSelection
        }
    }

    private func browseForTool() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.unixExecutable, .application]
        panel.message = "Select the executable for the \(toolType.rawValue.lowercased()) tool"

        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
            if customName.isEmpty {
                customName = url.deletingPathExtension().lastPathComponent
            }
        }
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    let preset: ExternalTool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .foregroundColor(.primary)
                    Text(preset.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ExternalToolsSettingsView()
        .frame(width: 500, height: 400)
}
