import Foundation

/// Parses git reflog output into ReflogEntry objects.
enum ReflogParser {
    /// The format string for git reflog --format.
    /// Fields are separated by ASCII record separator (0x1E).
    /// Records are separated by ASCII unit separator (0x1F).
    /// Format: hash, short hash, reflog selector, action, message, date, author name, author email
    static let formatString = "%H\u{1E}%h\u{1E}%gD\u{1E}%gs\u{1E}%aI\u{1E}%an\u{1E}%ae\u{1F}"

    /// Field separator (record separator character).
    private static let fieldSeparator = "\u{1E}"

    /// Record separator (unit separator character).
    private static let recordSeparator = "\u{1F}"

    /// Parses git reflog output.
    /// - Parameter output: The raw reflog output using the custom format.
    /// - Returns: An array of ReflogEntry objects.
    /// - Throws: GitError if parsing fails.
    static func parse(_ output: String) throws -> [ReflogEntry] {
        guard !output.isEmpty else { return [] }

        var entries: [ReflogEntry] = []
        let records = output.components(separatedBy: recordSeparator)

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fields = trimmed.components(separatedBy: fieldSeparator)
            guard fields.count >= 7 else {
                throw GitError.parseError(context: "Invalid reflog record", raw: record)
            }

            let hash = fields[0]
            let shortHash = fields[1]
            let selector = fields[2]
            let gsField = fields[3] // This contains both action and message

            // Parse the gs field which has format: "action: message" or just "action"
            let (actionRaw, message) = parseGsField(gsField)

            let dateStr = fields[4]
            let authorName = fields[5]
            let authorEmail = fields[6]

            guard let date = parseISO8601Date(dateStr) else {
                throw GitError.parseError(context: "Invalid reflog date", raw: dateStr)
            }

            let action = ReflogAction.parse(actionRaw)

            let entry = ReflogEntry(
                hash: hash,
                shortHash: shortHash,
                selector: selector,
                action: action,
                actionRaw: actionRaw,
                message: message,
                date: date,
                authorName: authorName,
                authorEmail: authorEmail
            )

            entries.append(entry)
        }

        return entries
    }

    /// Parses the %gs field which contains "action: message".
    /// - Parameter gsField: The raw %gs output.
    /// - Returns: A tuple of (action, message).
    private static func parseGsField(_ gsField: String) -> (action: String, message: String) {
        // The format is typically "action: message" or "action (detail): message"
        // Examples:
        // - "commit: Add new feature"
        // - "commit (amend): Fix typo"
        // - "checkout: moving from main to feature"
        // - "rebase (finish): refs/heads/feature onto abc123"

        // First, try to find the action part which ends with a colon
        if let colonIndex = gsField.firstIndex(of: ":") {
            let actionPart = String(gsField[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let messagePart = String(gsField[gsField.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            return (actionPart, messagePart.isEmpty ? gsField : messagePart)
        }

        // No colon found - the whole thing is the action/message
        return (gsField, gsField)
    }

    /// Parses an ISO 8601 date string.
    private static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
