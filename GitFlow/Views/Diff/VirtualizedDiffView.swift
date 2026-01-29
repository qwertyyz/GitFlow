import SwiftUI

/// Threshold for switching to virtualized rendering (lowered for better performance).
private let largeFileLinesThreshold = 1000

/// A virtualized diff view for handling extremely large files.
/// Uses a windowing technique to only render lines that are visible.
struct VirtualizedDiffView: View {
    let diff: FileDiff
    let showLineNumbers: Bool
    var wrapLines: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("com.gitflow.fontSize") private var fontSize: Double = 12.0

    /// All lines flattened for virtualization.
    private var allLines: [(hunkIndex: Int, line: DiffLine)] {
        diff.hunks.enumerated().flatMap { hunkIndex, hunk in
            hunk.lines.map { (hunkIndex, $0) }
        }
    }

    /// Whether this diff is large enough to need virtualization.
    var needsVirtualization: Bool {
        allLines.count > largeFileLinesThreshold
    }

    private let lineHeight: CGFloat = 20
    private let overscan: Int = 50 // Extra lines to render above/below viewport

    @State private var visibleRange: Range<Int> = 0..<100
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Spacer to maintain scroll height
                    Color.clear
                        .frame(height: CGFloat(allLines.count) * lineHeight)

                    // Only render visible lines
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(visibleLines.enumerated()), id: \.element.line.id) { index, item in
                            VirtualizedLineView(
                                line: item.line,
                                hunkIndex: item.hunkIndex,
                                showLineNumbers: showLineNumbers,
                                wrapLines: wrapLines,
                                colorScheme: colorScheme
                            )
                            .frame(height: lineHeight)
                        }
                    }
                    .padding(.top, CGFloat(visibleRange.lowerBound) * lineHeight)
                }
                .background(
                    GeometryReader { innerGeo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: innerGeo.frame(in: .named("scroll")).origin.y
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                updateVisibleRange(scrollOffset: -offset, viewportHeight: geometry.size.height)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .font(DSTypography.code(size: fontSize))
    }

    private var visibleLines: [(hunkIndex: Int, line: DiffLine)] {
        guard !allLines.isEmpty else { return [] }
        let safeStart = max(0, visibleRange.lowerBound)
        let safeEnd = min(allLines.count, visibleRange.upperBound)
        return Array(allLines[safeStart..<safeEnd])
    }

    private func updateVisibleRange(scrollOffset: CGFloat, viewportHeight: CGFloat) {
        let firstVisibleLine = max(0, Int(scrollOffset / lineHeight) - overscan)
        let visibleLineCount = Int(viewportHeight / lineHeight) + overscan * 2
        let lastVisibleLine = min(allLines.count, firstVisibleLine + visibleLineCount)

        visibleRange = firstVisibleLine..<lastVisibleLine
    }
}

/// Preference key for scroll offset tracking.
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A single line in the virtualized diff view.
private struct VirtualizedLineView: View {
    let line: DiffLine
    let hunkIndex: Int
    let showLineNumbers: Bool
    var wrapLines: Bool = false
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showLineNumbers {
                HStack(spacing: 0) {
                    typeIndicator
                        .frame(width: 12)

                    Text(line.oldLineNumber.map { String($0) } ?? "")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }

                Text(line.newLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, DSSpacing.sm)
            } else {
                typeIndicator
                    .frame(width: 16)
            }

            Text(line.prefix)
                .foregroundStyle(prefixColor)
                .frame(width: 14)

            Text(line.content)
                .foregroundStyle(.primary)
                .lineLimit(wrapLines ? nil : 1)
                .fixedSize(horizontal: !wrapLines, vertical: false)

            if !wrapLines {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .background(backgroundColor)
    }

    @ViewBuilder
    private var typeIndicator: some View {
        switch line.type {
        case .addition:
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DSColors.addition)
        case .deletion:
            Image(systemName: "minus")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DSColors.deletion)
        default:
            Color.clear
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return DSColors.addition
        case .deletion: return DSColors.deletion
        default: return .secondary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return DSColors.diffAdditionBackground(for: colorScheme)
        case .deletion:
            return DSColors.diffDeletionBackground(for: colorScheme)
        case .hunkHeader:
            return DSColors.diffHunkBackground(for: colorScheme)
        default:
            return .clear
        }
    }
}

/// Extension to DiffViewModel to check if virtualization is needed.
extension DiffViewModel {
    /// Whether the current diff needs virtualized rendering.
    var needsVirtualizedRendering: Bool {
        guard let diff = currentDiff else { return false }
        let totalLines = diff.hunks.reduce(0) { $0 + $1.lines.count }
        return totalLines > largeFileLinesThreshold
    }
}

#Preview {
    // Use simple inline initialization to avoid ViewBuilder control flow issues
    let lines: [DiffLine] = (0..<1000).map { i in
        DiffLine(
            content: "Line \(i): Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            type: i % 10 == 0 ? .addition : (i % 7 == 0 ? .deletion : .context),
            oldLineNumber: i % 10 == 0 ? nil : i,
            newLineNumber: i % 7 == 0 ? nil : i
        )
    }

    let hunk = DiffHunk(
        oldStart: 1,
        oldCount: lines.count,
        newStart: 1,
        newCount: lines.count,
        lines: lines,
        rawHeader: "@@ -1,\(lines.count) +1,\(lines.count) @@"
    )

    let diff = FileDiff(path: "large_file.txt", hunks: [hunk])

    return VirtualizedDiffView(diff: diff, showLineNumbers: true)
        .frame(width: 800, height: 600)
}
