import Foundation

/// Represents a segment of text with its change type.
struct WordDiffSegment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: SegmentType

    enum SegmentType: Equatable {
        case unchanged
        case added
        case removed
    }
}

/// Utilities for computing word-level differences between lines.
enum WordDiff {
    /// Computes word-level differences between two strings.
    /// - Parameters:
    ///   - oldLine: The original line (deleted line content).
    ///   - newLine: The new line (added line content).
    /// - Returns: A tuple of segments for the old and new lines.
    static func compute(oldLine: String, newLine: String) -> (old: [WordDiffSegment], new: [WordDiffSegment]) {
        let oldWords = tokenize(oldLine)
        let newWords = tokenize(newLine)

        // Use longest common subsequence to find matching tokens
        let lcs = longestCommonSubsequence(oldWords, newWords)

        var oldSegments: [WordDiffSegment] = []
        var newSegments: [WordDiffSegment] = []

        var oldIndex = 0
        var newIndex = 0
        var lcsIndex = 0

        while oldIndex < oldWords.count || newIndex < newWords.count {
            if lcsIndex < lcs.count {
                // Add removed tokens from old
                while oldIndex < oldWords.count && oldWords[oldIndex] != lcs[lcsIndex] {
                    oldSegments.append(WordDiffSegment(text: oldWords[oldIndex], type: .removed))
                    oldIndex += 1
                }

                // Add added tokens from new
                while newIndex < newWords.count && newWords[newIndex] != lcs[lcsIndex] {
                    newSegments.append(WordDiffSegment(text: newWords[newIndex], type: .added))
                    newIndex += 1
                }

                // Add matching token
                if oldIndex < oldWords.count && newIndex < newWords.count {
                    oldSegments.append(WordDiffSegment(text: oldWords[oldIndex], type: .unchanged))
                    newSegments.append(WordDiffSegment(text: newWords[newIndex], type: .unchanged))
                    oldIndex += 1
                    newIndex += 1
                    lcsIndex += 1
                }
            } else {
                // Add remaining removed tokens
                while oldIndex < oldWords.count {
                    oldSegments.append(WordDiffSegment(text: oldWords[oldIndex], type: .removed))
                    oldIndex += 1
                }

                // Add remaining added tokens
                while newIndex < newWords.count {
                    newSegments.append(WordDiffSegment(text: newWords[newIndex], type: .added))
                    newIndex += 1
                }
            }
        }

        return (oldSegments, newSegments)
    }

    /// Tokenizes a string into words and whitespace tokens.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inWhitespace = false

        for char in text {
            let isWhitespace = char.isWhitespace

            if isWhitespace != inWhitespace && !currentToken.isEmpty {
                tokens.append(currentToken)
                currentToken = ""
            }

            currentToken.append(char)
            inWhitespace = isWhitespace
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    /// Computes the longest common subsequence of two arrays.
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count

        // Build LCS table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to find LCS
        var lcs: [String] = []
        var i = m
        var j = n

        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                lcs.insert(a[i - 1], at: 0)
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return lcs
    }

    /// Computes word-level diff for a single line.
    /// - Parameters:
    ///   - content: The line content.
    ///   - pairContent: The content of the paired line (deletion for addition, addition for deletion).
    ///   - isAddition: Whether this is an addition line.
    /// - Returns: Array of word diff segments.
    static func computeForLine(content: String, pairContent: String?, isAddition: Bool) -> [WordDiffSegment] {
        guard let pairContent = pairContent else {
            // No pair, entire line is changed
            return [WordDiffSegment(text: content, type: isAddition ? .added : .removed)]
        }

        let (oldSegments, newSegments) = compute(oldLine: pairContent, newLine: content)
        return isAddition ? newSegments : oldSegments
    }
}

/// Extension to find adjacent line pairs in a diff hunk.
extension DiffHunk {
    /// Finds pairs of adjacent deletion/addition lines for word-level diffing.
    /// - Returns: Dictionary mapping line IDs to their pair's content.
    func findLinePairs() -> [String: String] {
        var pairs: [String: String] = [:]
        var i = 0

        while i < lines.count {
            // Look for deletion followed by addition
            if lines[i].type == .deletion {
                var deletions: [DiffLine] = []
                var j = i

                // Collect consecutive deletions
                while j < lines.count && lines[j].type == .deletion {
                    deletions.append(lines[j])
                    j += 1
                }

                // Collect consecutive additions
                var additions: [DiffLine] = []
                while j < lines.count && lines[j].type == .addition {
                    additions.append(lines[j])
                    j += 1
                }

                // Pair up deletions and additions
                let pairCount = min(deletions.count, additions.count)
                for k in 0..<pairCount {
                    pairs[deletions[k].id] = additions[k].content
                    pairs[additions[k].id] = deletions[k].content
                }

                i = j
            } else {
                i += 1
            }
        }

        return pairs
    }
}
