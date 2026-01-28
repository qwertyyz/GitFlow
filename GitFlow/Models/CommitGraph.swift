import Foundation
import SwiftUI

/// Represents a node in the commit graph.
struct CommitGraphNode: Identifiable, Equatable {
    let id: String // commit hash
    let column: Int
    let parents: [String]
    let isMerge: Bool
    let isBranchTip: Bool

    /// The connections to draw for this node.
    var connections: [GraphConnection] = []
}

/// Represents a connection line in the graph.
struct GraphConnection: Identifiable, Equatable {
    let id = UUID()
    let fromColumn: Int
    let toColumn: Int
    let type: ConnectionType

    enum ConnectionType: Equatable {
        case straight  // Vertical line in same column
        case merge     // Diagonal line coming from another column
        case branch    // Diagonal line going to another column
    }
}

/// Builds a visual graph representation from a list of commits.
final class CommitGraphBuilder {
    /// The maximum number of columns in the graph.
    private let maxColumns = 8

    /// Maps commit hashes to their assigned columns.
    private var columnAssignments: [String: Int] = [:]

    /// The current active branches in each column.
    private var activeColumns: [String?] = []

    /// Builds graph nodes for a list of commits.
    /// - Parameter commits: The commits to build the graph for, in chronological order (newest first).
    /// - Returns: An array of graph nodes corresponding to each commit.
    func buildGraph(from commits: [Commit]) -> [CommitGraphNode] {
        columnAssignments.removeAll()
        activeColumns = Array(repeating: nil, count: maxColumns)

        var nodes: [CommitGraphNode] = []

        for commit in commits {
            let node = processCommit(commit)
            nodes.append(node)
        }

        return nodes
    }

    private func processCommit(_ commit: Commit) -> CommitGraphNode {
        let commitHash = commit.hash
        let parentHashes = commit.parentHashes

        // Find or assign column for this commit
        let column: Int
        if let existingColumn = columnAssignments[commitHash] {
            column = existingColumn
        } else {
            column = findAvailableColumn()
            columnAssignments[commitHash] = column
            if column < maxColumns {
                activeColumns[column] = commitHash
            }
        }

        // Build connections
        var connections: [GraphConnection] = []

        // Process parents
        for (index, parentHash) in parentHashes.enumerated() {
            if let parentColumn = columnAssignments[parentHash] {
                // Parent already has a column assigned
                if parentColumn == column {
                    connections.append(GraphConnection(
                        fromColumn: column,
                        toColumn: column,
                        type: .straight
                    ))
                } else {
                    connections.append(GraphConnection(
                        fromColumn: column,
                        toColumn: parentColumn,
                        type: index == 0 ? .straight : .merge
                    ))
                }
            } else {
                // Assign column to parent
                let parentColumn: Int
                if index == 0 {
                    // First parent continues in same column
                    parentColumn = column
                } else {
                    // Merge parent gets a new column
                    parentColumn = findAvailableColumn(excluding: column)
                }

                columnAssignments[parentHash] = parentColumn
                if parentColumn < maxColumns {
                    activeColumns[parentColumn] = parentHash
                }

                let connectionType: GraphConnection.ConnectionType
                if parentColumn == column {
                    connectionType = .straight
                } else {
                    connectionType = .merge
                }

                connections.append(GraphConnection(
                    fromColumn: column,
                    toColumn: parentColumn,
                    type: connectionType
                ))
            }
        }

        // Free up this column if no more commits use it
        if column < maxColumns && activeColumns[column] == commitHash {
            activeColumns[column] = parentHashes.first
        }

        return CommitGraphNode(
            id: commitHash,
            column: min(column, maxColumns - 1),
            parents: parentHashes,
            isMerge: parentHashes.count > 1,
            isBranchTip: columnAssignments.values.filter { $0 == column }.count == 1,
            connections: connections
        )
    }

    private func findAvailableColumn(excluding: Int? = nil) -> Int {
        for i in 0..<maxColumns {
            if i != excluding && activeColumns[i] == nil {
                return i
            }
        }
        // All columns full, reuse one
        return 0
    }
}

/// View that draws the commit graph column.
struct CommitGraphView: View {
    let nodes: [CommitGraphNode]
    let selectedCommitId: String?
    let rowHeight: CGFloat
    let columnWidth: CGFloat = 14

    /// Colors for different graph lanes.
    private let laneColors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .red,
        .cyan,
        .pink,
        .yellow
    ]

    var body: some View {
        Canvas { context, size in
            for (index, node) in nodes.enumerated() {
                let y = CGFloat(index) * rowHeight + rowHeight / 2

                // Draw connections first (behind the node)
                for connection in node.connections {
                    drawConnection(
                        context: context,
                        connection: connection,
                        fromY: y,
                        toY: y + rowHeight
                    )
                }

                // Draw the commit node
                let x = CGFloat(node.column) * columnWidth + columnWidth / 2
                let color = laneColors[node.column % laneColors.count]

                let nodeRect = CGRect(
                    x: x - 4,
                    y: y - 4,
                    width: 8,
                    height: 8
                )

                if node.isMerge {
                    // Draw diamond for merge commits
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y - 5))
                    path.addLine(to: CGPoint(x: x + 5, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + 5))
                    path.addLine(to: CGPoint(x: x - 5, y: y))
                    path.closeSubpath()
                    context.fill(path, with: .color(color))
                } else {
                    // Draw circle for regular commits
                    context.fill(
                        Path(ellipseIn: nodeRect),
                        with: .color(color)
                    )
                }

                // Highlight selected commit
                if node.id == selectedCommitId {
                    context.stroke(
                        Path(ellipseIn: nodeRect.insetBy(dx: -2, dy: -2)),
                        with: .color(.primary),
                        lineWidth: 2
                    )
                }
            }
        }
        .frame(width: columnWidth * CGFloat(maxColumnUsed + 1))
    }

    private var maxColumnUsed: Int {
        nodes.map(\.column).max() ?? 0
    }

    private func drawConnection(
        context: GraphicsContext,
        connection: GraphConnection,
        fromY: CGFloat,
        toY: CGFloat
    ) {
        let fromX = CGFloat(connection.fromColumn) * columnWidth + columnWidth / 2
        let toX = CGFloat(connection.toColumn) * columnWidth + columnWidth / 2
        let color = laneColors[connection.toColumn % laneColors.count]

        var path = Path()

        switch connection.type {
        case .straight:
            path.move(to: CGPoint(x: fromX, y: fromY))
            path.addLine(to: CGPoint(x: toX, y: toY))

        case .merge, .branch:
            // Draw a curved line
            path.move(to: CGPoint(x: fromX, y: fromY))
            path.addCurve(
                to: CGPoint(x: toX, y: toY),
                control1: CGPoint(x: fromX, y: fromY + rowHeight * 0.5),
                control2: CGPoint(x: toX, y: toY - rowHeight * 0.5)
            )
        }

        context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1.5)
    }
}

#Preview {
    let commits = [
        Commit(hash: "a1", shortHash: "a1", subject: "Latest commit", authorName: "Test", authorEmail: "test@test.com", authorDate: Date(), parentHashes: ["b1"]),
        Commit(hash: "b1", shortHash: "b1", subject: "Merge branch", authorName: "Test", authorEmail: "test@test.com", authorDate: Date(), parentHashes: ["c1", "d1"]),
        Commit(hash: "c1", shortHash: "c1", subject: "Main line", authorName: "Test", authorEmail: "test@test.com", authorDate: Date(), parentHashes: ["e1"]),
        Commit(hash: "d1", shortHash: "d1", subject: "Feature commit", authorName: "Test", authorEmail: "test@test.com", authorDate: Date(), parentHashes: ["e1"]),
        Commit(hash: "e1", shortHash: "e1", subject: "Base commit", authorName: "Test", authorEmail: "test@test.com", authorDate: Date(), parentHashes: []),
    ]

    let builder = CommitGraphBuilder()
    let nodes = builder.buildGraph(from: commits)

    HStack(alignment: .top, spacing: 0) {
        CommitGraphView(nodes: nodes, selectedCommitId: "b1", rowHeight: 40)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(commits, id: \.hash) { commit in
                Text(commit.subject)
                    .frame(height: 40)
            }
        }
    }
    .padding()
}
