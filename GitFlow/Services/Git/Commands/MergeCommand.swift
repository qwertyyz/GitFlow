import Foundation

// Note: Basic MergeCommand, AbortMergeCommand, ContinueMergeCommand are in BranchCommand.swift
// This file contains additional merge-related commands for conflict resolution.

/// Command to get list of unmerged (conflicted) files.
struct GetUnmergedFilesCommand: GitCommand {
    typealias Result = [ConflictedFile]

    var arguments: [String] {
        ["diff", "--name-only", "--diff-filter=U"]
    }

    func parse(output: String) throws -> [ConflictedFile] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { ConflictedFile(path: $0, conflictType: .bothModified) }
    }
}

/// Command to get detailed status of unmerged files.
struct GetUnmergedStatusCommand: GitCommand {
    typealias Result = [ConflictedFile]

    var arguments: [String] {
        ["status", "--porcelain"]
    }

    func parse(output: String) throws -> [ConflictedFile] {
        var files: [ConflictedFile] = []

        for line in output.components(separatedBy: .newlines) {
            guard line.count >= 3 else { continue }

            let statusCode = String(line.prefix(2))
            let path = String(line.dropFirst(3))

            // Unmerged status codes
            let conflictType: ConflictType?
            switch statusCode {
            case "DD":
                conflictType = .bothModified // Both deleted - shouldn't normally happen
            case "AU":
                conflictType = .bothAdded // Added by us, unmerged
            case "UD":
                conflictType = .modifiedDeleted // Updated by us, deleted by them
            case "UA":
                conflictType = .bothAdded // Updated by us, added by them
            case "DU":
                conflictType = .deletedModified // Deleted by us, updated by them
            case "AA":
                conflictType = .bothAdded // Added by both
            case "UU":
                conflictType = .bothModified // Updated by both
            default:
                conflictType = nil
            }

            if let type = conflictType {
                files.append(ConflictedFile(path: path, conflictType: type))
            }
        }

        return files
    }
}

/// Command to get the content of a file at a specific stage during merge.
struct GetMergeStageContentCommand: GitCommand {
    typealias Result = String

    /// The merge stage: 1 = base, 2 = ours, 3 = theirs
    let stage: Int
    let filePath: String

    var arguments: [String] {
        ["show", ":\(stage):\(filePath)"]
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to mark a file as resolved (by staging it).
struct MarkConflictResolvedCommand: VoidGitCommand {
    let filePath: String

    var arguments: [String] {
        ["add", filePath]
    }
}

/// Command to use "ours" version for a conflicted file.
struct UseOursVersionCommand: VoidGitCommand {
    let filePath: String

    var arguments: [String] {
        ["checkout", "--ours", filePath]
    }
}

/// Command to use "theirs" version for a conflicted file.
struct UseTheirsVersionCommand: VoidGitCommand {
    let filePath: String

    var arguments: [String] {
        ["checkout", "--theirs", filePath]
    }
}

/// Command to get the merge message.
struct GetMergeMessageCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["log", "-1", "--format=%s", "MERGE_HEAD"]
    }

    func parse(output: String) throws -> String? {
        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }
}

/// Command to get the branch being merged (from MERGE_HEAD).
struct GetMergingBranchCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["name-rev", "--name-only", "MERGE_HEAD"]
    }

    func parse(output: String) throws -> String? {
        let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == "undefined" ? nil : name
    }
}

/// Command to check if we're in a merge state.
struct IsMergingCommand: GitCommand {
    typealias Result = Bool

    var arguments: [String] {
        ["rev-parse", "-q", "--verify", "MERGE_HEAD"]
    }

    func parse(output: String) throws -> Bool {
        !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Command to perform a dry-run merge preview.
/// This attempts to merge without committing and then aborts.
struct MergePreviewCommand: VoidGitCommand {
    let branchName: String

    var arguments: [String] {
        ["merge", "--no-commit", "--no-ff", branchName]
    }
}

/// Command to get merge base (common ancestor).
struct MergeBaseCommand: GitCommand {
    typealias Result = String?

    let branch1: String
    let branch2: String

    var arguments: [String] {
        ["merge-base", branch1, branch2]
    }

    func parse(output: String) throws -> String? {
        let hash = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? nil : hash
    }
}

/// Command to get the diff-tree summary between two commits.
struct DiffTreeSummaryCommand: GitCommand {
    typealias Result = [MergePreviewChange]

    let base: String
    let target: String

    var arguments: [String] {
        ["diff", "--stat", "--name-status", "\(base)...\(target)"]
    }

    func parse(output: String) throws -> [MergePreviewChange] {
        var changes: [MergePreviewChange] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse name-status format: <status>\t<path>
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }

            let status = parts[0]
            let path = parts[1]

            let changeType: MergePreviewChangeType
            switch status.first {
            case "A": changeType = .added
            case "D": changeType = .deleted
            case "M": changeType = .modified
            case "R": changeType = .renamed
            case "C": changeType = .copied
            default: changeType = .modified
            }

            changes.append(MergePreviewChange(
                path: path,
                changeType: changeType,
                oldPath: status.first == "R" && parts.count > 2 ? parts[1] : nil
            ))
        }

        return changes
    }
}

/// Represents a file change in merge preview.
struct MergePreviewChange: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let changeType: MergePreviewChangeType
    let oldPath: String?
}

/// Type of change in merge preview.
enum MergePreviewChangeType: String {
    case added = "Added"
    case deleted = "Deleted"
    case modified = "Modified"
    case renamed = "Renamed"
    case copied = "Copied"
}

/// Result of a merge preview.
struct MergePreviewResult: Equatable {
    let sourceBranch: String
    let targetBranch: String
    let mergeBase: String?
    let commitCount: Int
    let commits: [Commit]
    let fileChanges: [MergePreviewChange]
    let hasConflicts: Bool
    let conflictedFiles: [ConflictedFile]

    static let empty = MergePreviewResult(
        sourceBranch: "",
        targetBranch: "",
        mergeBase: nil,
        commitCount: 0,
        commits: [],
        fileChanges: [],
        hasConflicts: false,
        conflictedFiles: []
    )
}

/// Parser for conflict markers in file content.
enum ConflictMarkerParser {
    /// Parses conflict sections from file content.
    static func parseConflictSections(from content: String) -> [ConflictSection] {
        var sections: [ConflictSection] = []
        let lines = content.components(separatedBy: "\n")

        var currentStart: Int?
        var currentOursLabel: String?
        var oursLines: [String] = []
        var baseLines: [String] = []
        var theirsLines: [String] = []
        var currentTheirsLabel: String?
        var inOurs = false
        var inBase = false
        var inTheirs = false

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            if line.hasPrefix("<<<<<<<") {
                // Start of conflict
                currentStart = lineNumber
                currentOursLabel = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                inOurs = true
                inBase = false
                inTheirs = false
                oursLines = []
                baseLines = []
                theirsLines = []
            } else if line.hasPrefix("|||||||") && inOurs {
                // Base section (diff3 style)
                inOurs = false
                inBase = true
            } else if line.hasPrefix("=======") {
                // Separator between ours/base and theirs
                inOurs = false
                inBase = false
                inTheirs = true
            } else if line.hasPrefix(">>>>>>>") && inTheirs {
                // End of conflict
                currentTheirsLabel = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)

                if let start = currentStart {
                    let section = ConflictSection(
                        startLine: start,
                        endLine: lineNumber,
                        oursContent: oursLines.joined(separator: "\n"),
                        theirsContent: theirsLines.joined(separator: "\n"),
                        baseContent: baseLines.isEmpty ? nil : baseLines.joined(separator: "\n"),
                        oursLabel: currentOursLabel ?? "HEAD",
                        theirsLabel: currentTheirsLabel ?? "MERGE_HEAD"
                    )
                    sections.append(section)
                }

                inOurs = false
                inBase = false
                inTheirs = false
                currentStart = nil
            } else if inOurs {
                oursLines.append(line)
            } else if inBase {
                baseLines.append(line)
            } else if inTheirs {
                theirsLines.append(line)
            }
        }

        return sections
    }

    /// Resolves a conflict section with the given resolution.
    static func resolveSection(_ section: ConflictSection, with resolution: ConflictResolution) -> String {
        switch resolution {
        case .ours:
            return section.oursContent
        case .theirs:
            return section.theirsContent
        case .both:
            return section.oursContent + "\n" + section.theirsContent
        case .custom(let content):
            return content
        }
    }
}
