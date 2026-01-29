import Foundation
import AppKit

/// Service for managing and launching external tools.
actor ExternalToolService {
    private let userDefaults = UserDefaults.standard
    private let diffToolKey = "externalDiffTool"
    private let mergeToolKey = "externalMergeTool"
    private let editorToolKey = "externalEditorTool"

    // MARK: - Tool Configuration

    /// Gets the configured diff tool.
    func getDiffTool() -> ExternalTool? {
        guard let data = userDefaults.data(forKey: diffToolKey) else { return nil }
        return try? JSONDecoder().decode(ExternalTool.self, from: data)
    }

    /// Sets the diff tool configuration.
    func setDiffTool(_ tool: ExternalTool?) {
        if let tool = tool {
            if let data = try? JSONEncoder().encode(tool) {
                userDefaults.set(data, forKey: diffToolKey)
            }
        } else {
            userDefaults.removeObject(forKey: diffToolKey)
        }
    }

    /// Gets the configured merge tool.
    func getMergeTool() -> ExternalTool? {
        guard let data = userDefaults.data(forKey: mergeToolKey) else { return nil }
        return try? JSONDecoder().decode(ExternalTool.self, from: data)
    }

    /// Sets the merge tool configuration.
    func setMergeTool(_ tool: ExternalTool?) {
        if let tool = tool {
            if let data = try? JSONEncoder().encode(tool) {
                userDefaults.set(data, forKey: mergeToolKey)
            }
        } else {
            userDefaults.removeObject(forKey: mergeToolKey)
        }
    }

    /// Gets the configured editor tool.
    func getEditorTool() -> ExternalTool? {
        guard let data = userDefaults.data(forKey: editorToolKey) else { return nil }
        return try? JSONDecoder().decode(ExternalTool.self, from: data)
    }

    /// Sets the editor tool configuration.
    func setEditorTool(_ tool: ExternalTool?) {
        if let tool = tool {
            if let data = try? JSONEncoder().encode(tool) {
                userDefaults.set(data, forKey: editorToolKey)
            }
        } else {
            userDefaults.removeObject(forKey: editorToolKey)
        }
    }

    // MARK: - Tool Execution

    /// Opens a diff in the configured external diff tool.
    /// - Parameters:
    ///   - localPath: Path to the local/old file.
    ///   - remotePath: Path to the remote/new file.
    func openDiff(localPath: String, remotePath: String) async throws {
        guard let tool = getDiffTool() else {
            throw ExternalToolError.noToolConfigured(type: .diff)
        }

        try await launchTool(tool, local: localPath, remote: remotePath)
    }

    /// Opens a merge in the configured external merge tool.
    /// - Parameters:
    ///   - localPath: Path to the local file.
    ///   - remotePath: Path to the remote file.
    ///   - basePath: Path to the base/ancestor file.
    ///   - mergedPath: Path for the merged output.
    func openMerge(localPath: String, remotePath: String, basePath: String, mergedPath: String) async throws {
        guard let tool = getMergeTool() else {
            throw ExternalToolError.noToolConfigured(type: .merge)
        }

        try await launchTool(tool, local: localPath, remote: remotePath, base: basePath, merged: mergedPath)
    }

    /// Opens a file in the configured external editor.
    /// - Parameter filePath: Path to the file to open.
    func openInEditor(filePath: String) async throws {
        guard let tool = getEditorTool() else {
            throw ExternalToolError.noToolConfigured(type: .editor)
        }

        try await launchTool(tool, local: filePath)
    }

    /// Opens a file in the system default application.
    @MainActor
    func openWithSystemDefault(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    private func launchTool(_ tool: ExternalTool, local: String? = nil, remote: String? = nil, base: String? = nil, merged: String? = nil) async throws {
        guard FileManager.default.fileExists(atPath: tool.path) else {
            throw ExternalToolError.toolNotFound(path: tool.path)
        }

        let arguments = tool.buildArguments(local: local, remote: remote, base: base, merged: merged)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path)
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            throw ExternalToolError.launchFailed(error: error.localizedDescription)
        }
    }

    // MARK: - Tool Detection

    /// Checks if a tool is installed at the specified path.
    func isToolInstalled(path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Gets all installed diff tools from presets.
    func getInstalledDiffTools() -> [ExternalTool] {
        ExternalToolPresets.installedPresets(for: .diff)
    }

    /// Gets all installed merge tools from presets.
    func getInstalledMergeTools() -> [ExternalTool] {
        ExternalToolPresets.installedPresets(for: .merge)
    }

    /// Gets all installed editor tools from presets.
    func getInstalledEditorTools() -> [ExternalTool] {
        ExternalToolPresets.installedPresets(for: .editor)
    }
}

// MARK: - Errors

enum ExternalToolError: LocalizedError {
    case noToolConfigured(type: ExternalTool.ToolType)
    case toolNotFound(path: String)
    case launchFailed(error: String)

    var errorDescription: String? {
        switch self {
        case .noToolConfigured(let type):
            return "No \(type.rawValue.lowercased()) tool configured. Please configure one in Settings."
        case .toolNotFound(let path):
            return "Tool not found at path: \(path)"
        case .launchFailed(let error):
            return "Failed to launch tool: \(error)"
        }
    }
}
