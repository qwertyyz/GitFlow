import Foundation

/// Represents an external tool configuration.
struct ExternalTool: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var arguments: String
    var type: ToolType

    enum ToolType: String, Codable, CaseIterable {
        case diff = "Diff"
        case merge = "Merge"
        case editor = "Editor"
    }

    init(id: UUID = UUID(), name: String, path: String, arguments: String = "", type: ToolType) {
        self.id = id
        self.name = name
        self.path = path
        self.arguments = arguments
        self.type = type
    }

    /// Builds the command arguments with placeholders replaced.
    /// Placeholders:
    /// - $LOCAL: Local file path
    /// - $REMOTE: Remote file path
    /// - $BASE: Base file path (for 3-way merge)
    /// - $MERGED: Output file path (for merge)
    func buildArguments(local: String? = nil, remote: String? = nil, base: String? = nil, merged: String? = nil) -> [String] {
        var args = arguments

        if let local = local {
            args = args.replacingOccurrences(of: "$LOCAL", with: local)
        }
        if let remote = remote {
            args = args.replacingOccurrences(of: "$REMOTE", with: remote)
        }
        if let base = base {
            args = args.replacingOccurrences(of: "$BASE", with: base)
        }
        if let merged = merged {
            args = args.replacingOccurrences(of: "$MERGED", with: merged)
        }

        return args.components(separatedBy: " ").filter { !$0.isEmpty }
    }
}

/// Preset external tool configurations for common applications.
enum ExternalToolPresets {
    static let diffTools: [ExternalTool] = [
        ExternalTool(
            name: "Visual Studio Code",
            path: "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            arguments: "--diff $LOCAL $REMOTE",
            type: .diff
        ),
        ExternalTool(
            name: "Kaleidoscope",
            path: "/Applications/Kaleidoscope.app/Contents/MacOS/ksdiff",
            arguments: "$LOCAL $REMOTE",
            type: .diff
        ),
        ExternalTool(
            name: "Beyond Compare",
            path: "/Applications/Beyond Compare.app/Contents/MacOS/bcomp",
            arguments: "$LOCAL $REMOTE",
            type: .diff
        ),
        ExternalTool(
            name: "FileMerge",
            path: "/Applications/Xcode.app/Contents/Applications/FileMerge.app/Contents/MacOS/FileMerge",
            arguments: "-left $LOCAL -right $REMOTE",
            type: .diff
        ),
        ExternalTool(
            name: "DiffMerge",
            path: "/Applications/DiffMerge.app/Contents/MacOS/DiffMerge",
            arguments: "$LOCAL $REMOTE",
            type: .diff
        ),
        ExternalTool(
            name: "Meld",
            path: "/Applications/Meld.app/Contents/MacOS/Meld",
            arguments: "$LOCAL $REMOTE",
            type: .diff
        ),
    ]

    static let mergeTools: [ExternalTool] = [
        ExternalTool(
            name: "Visual Studio Code",
            path: "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            arguments: "--merge $LOCAL $REMOTE $BASE $MERGED",
            type: .merge
        ),
        ExternalTool(
            name: "Kaleidoscope",
            path: "/Applications/Kaleidoscope.app/Contents/MacOS/ksdiff",
            arguments: "--merge --output $MERGED --base $BASE $LOCAL $REMOTE",
            type: .merge
        ),
        ExternalTool(
            name: "Beyond Compare",
            path: "/Applications/Beyond Compare.app/Contents/MacOS/bcomp",
            arguments: "$LOCAL $REMOTE $BASE $MERGED",
            type: .merge
        ),
        ExternalTool(
            name: "FileMerge",
            path: "/Applications/Xcode.app/Contents/Applications/FileMerge.app/Contents/MacOS/FileMerge",
            arguments: "-left $LOCAL -right $REMOTE -ancestor $BASE -merge $MERGED",
            type: .merge
        ),
        ExternalTool(
            name: "DiffMerge",
            path: "/Applications/DiffMerge.app/Contents/MacOS/DiffMerge",
            arguments: "--merge --result=$MERGED $LOCAL $BASE $REMOTE",
            type: .merge
        ),
        ExternalTool(
            name: "Meld",
            path: "/Applications/Meld.app/Contents/MacOS/Meld",
            arguments: "$LOCAL $BASE $REMOTE --output $MERGED",
            type: .merge
        ),
    ]

    static let editors: [ExternalTool] = [
        ExternalTool(
            name: "Visual Studio Code",
            path: "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            arguments: "$LOCAL",
            type: .editor
        ),
        ExternalTool(
            name: "Sublime Text",
            path: "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
            arguments: "$LOCAL",
            type: .editor
        ),
        ExternalTool(
            name: "Atom",
            path: "/Applications/Atom.app/Contents/MacOS/Atom",
            arguments: "$LOCAL",
            type: .editor
        ),
        ExternalTool(
            name: "TextMate",
            path: "/Applications/TextMate.app/Contents/MacOS/TextMate",
            arguments: "$LOCAL",
            type: .editor
        ),
        ExternalTool(
            name: "BBEdit",
            path: "/Applications/BBEdit.app/Contents/Helpers/bbedit_tool",
            arguments: "$LOCAL",
            type: .editor
        ),
        ExternalTool(
            name: "Nova",
            path: "/Applications/Nova.app/Contents/SharedSupport/nova",
            arguments: "$LOCAL",
            type: .editor
        ),
    ]

    /// Returns all presets for a given tool type.
    static func presets(for type: ExternalTool.ToolType) -> [ExternalTool] {
        switch type {
        case .diff:
            return diffTools
        case .merge:
            return mergeTools
        case .editor:
            return editors
        }
    }

    /// Returns installed presets by checking if the application exists.
    static func installedPresets(for type: ExternalTool.ToolType) -> [ExternalTool] {
        presets(for: type).filter { tool in
            FileManager.default.fileExists(atPath: tool.path)
        }
    }
}
