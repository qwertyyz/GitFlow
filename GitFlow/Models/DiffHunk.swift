import Foundation

/// Represents a single hunk in a diff.
/// A hunk is a contiguous block of changes with context lines.
struct DiffHunk: Identifiable, Equatable {
    /// Unique identifier for this hunk.
    let id: String

    /// The starting line number in the old file.
    let oldStart: Int

    /// The number of lines from the old file in this hunk.
    let oldCount: Int

    /// The starting line number in the new file.
    let newStart: Int

    /// The number of lines from the new file in this hunk.
    let newCount: Int

    /// The hunk header text (e.g., function name context).
    let header: String

    /// The lines in this hunk.
    let lines: [DiffLine]

    /// The raw hunk header line from Git.
    let rawHeader: String

    /// Number of additions in this hunk.
    var additionCount: Int {
        lines.filter { $0.type == .addition }.count
    }

    /// Number of deletions in this hunk.
    var deletionCount: Int {
        lines.filter { $0.type == .deletion }.count
    }

    /// Creates a DiffHunk.
    init(
        id: String = UUID().uuidString,
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        header: String = "",
        lines: [DiffLine] = [],
        rawHeader: String = ""
    ) {
        self.id = id
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.header = header
        self.lines = lines
        self.rawHeader = rawHeader
    }

    /// Parses a hunk header line.
    /// Format: @@ -old_start,old_count +new_start,new_count @@ optional_header
    static func parseHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, header: String)? {
        // Pattern: @@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)
        let pattern = #"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func captureGroup(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: line) else { return nil }
            return String(line[range])
        }

        guard let oldStartStr = captureGroup(1),
              let oldStart = Int(oldStartStr),
              let newStartStr = captureGroup(3),
              let newStart = Int(newStartStr) else {
            return nil
        }

        let oldCount = captureGroup(2).flatMap { Int($0) } ?? 1
        let newCount = captureGroup(4).flatMap { Int($0) } ?? 1
        let header = captureGroup(5)?.trimmingCharacters(in: .whitespaces) ?? ""

        return (oldStart, oldCount, newStart, newCount, header)
    }

    /// Generates a patch representation of this hunk.
    /// - Parameter filePath: The path of the file this hunk belongs to.
    /// - Returns: A patch string that can be used with `git apply`.
    func toPatchString(filePath: String) -> String {
        var patch = """
        --- a/\(filePath)
        +++ b/\(filePath)
        \(rawHeader)

        """
        for line in lines {
            patch += line.prefix + line.content + "\n"
        }
        return patch
    }

    /// Generates a patch for selected lines only.
    /// - Parameters:
    ///   - filePath: The path of the file this hunk belongs to.
    ///   - selectedLineIds: The IDs of lines to include in the patch.
    ///   - forStaging: If true, creates patch for staging; if false, for unstaging.
    /// - Returns: A patch string that can be used with `git apply`, or nil if no valid patch.
    func toPatchString(filePath: String, selectedLineIds: Set<String>, forStaging: Bool = true) -> String? {
        // Build the patch with selected lines
        var patchLines: [DiffLine] = []
        var selectedAdditions = 0
        var selectedDeletions = 0

        for line in lines {
            switch line.type {
            case .context:
                // Context lines are always included
                patchLines.append(line)
            case .addition:
                if selectedLineIds.contains(line.id) {
                    patchLines.append(line)
                    selectedAdditions += 1
                } else {
                    // Convert unselected additions to context for staging
                    // (they don't exist in working tree yet relative to index)
                    // For staging: skip unselected additions
                    // Actually, we need to handle this differently
                    continue
                }
            case .deletion:
                if selectedLineIds.contains(line.id) {
                    patchLines.append(line)
                    selectedDeletions += 1
                } else {
                    // Convert unselected deletions to context
                    let contextLine = DiffLine(
                        id: line.id,
                        content: line.content,
                        type: .context,
                        oldLineNumber: line.oldLineNumber,
                        newLineNumber: line.newLineNumber,
                        hasNewline: line.hasNewline,
                        rawLine: " " + line.content
                    )
                    patchLines.append(contextLine)
                }
            default:
                continue
            }
        }

        // Must have at least one change
        guard selectedAdditions > 0 || selectedDeletions > 0 else {
            return nil
        }

        // Calculate new hunk header values
        let newOldCount = patchLines.filter { $0.type == .context || $0.type == .deletion }.count
        let newNewCount = patchLines.filter { $0.type == .context || $0.type == .addition }.count

        let header = "@@ -\(oldStart),\(newOldCount) +\(newStart),\(newNewCount) @@ \(self.header)"

        var patch = """
        --- a/\(filePath)
        +++ b/\(filePath)
        \(header)

        """
        for line in patchLines {
            patch += line.prefix + line.content + "\n"
        }
        return patch
    }

    /// Creates a sub-hunk containing only the specified lines.
    /// - Parameter lineIds: The IDs of lines to include.
    /// - Returns: A new DiffHunk with only the specified lines and adjusted counts.
    func subHunk(withLineIds lineIds: Set<String>) -> DiffHunk? {
        var newLines: [DiffLine] = []
        var addCount = 0
        var delCount = 0

        for line in lines {
            switch line.type {
            case .context:
                newLines.append(line)
            case .addition:
                if lineIds.contains(line.id) {
                    newLines.append(line)
                    addCount += 1
                }
            case .deletion:
                if lineIds.contains(line.id) {
                    newLines.append(line)
                    delCount += 1
                } else {
                    // Keep as context
                    let contextLine = DiffLine(
                        id: line.id,
                        content: line.content,
                        type: .context,
                        oldLineNumber: line.oldLineNumber,
                        newLineNumber: line.newLineNumber,
                        hasNewline: line.hasNewline
                    )
                    newLines.append(contextLine)
                }
            default:
                break
            }
        }

        guard addCount > 0 || delCount > 0 else { return nil }

        let newOldCount = newLines.filter { $0.type == .context || $0.type == .deletion }.count
        let newNewCount = newLines.filter { $0.type == .context || $0.type == .addition }.count

        return DiffHunk(
            oldStart: oldStart,
            oldCount: newOldCount,
            newStart: newStart,
            newCount: newNewCount,
            header: header,
            lines: newLines,
            rawHeader: "@@ -\(oldStart),\(newOldCount) +\(newStart),\(newNewCount) @@ \(header)"
        )
    }
}
