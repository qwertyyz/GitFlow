import Foundation

/// Represents a tree entry (file or directory) at a specific commit.
struct TreeEntry: Identifiable, Hashable {
    let id: String
    let mode: String
    let type: EntryType
    let hash: String
    let name: String
    let path: String

    enum EntryType: String {
        case blob = "blob"   // File
        case tree = "tree"   // Directory
        case commit = "commit" // Submodule

        var isDirectory: Bool {
            self == .tree
        }
    }

    var isDirectory: Bool {
        type.isDirectory
    }
}

/// Command to list tree contents at a specific ref.
struct ListTreeCommand: GitCommand {
    typealias Result = [TreeEntry]

    let ref: String
    let path: String?
    let recursive: Bool

    init(ref: String, path: String? = nil, recursive: Bool = false) {
        self.ref = ref
        self.path = path
        self.recursive = recursive
    }

    var arguments: [String] {
        var args = ["ls-tree"]

        if recursive {
            args.append("-r")
        }

        // Include directory entries
        args.append("-t")

        // Full tree ref
        if let path = path, !path.isEmpty {
            args.append("\(ref):\(path)")
        } else {
            args.append(ref)
        }

        return args
    }

    func parse(output: String) throws -> [TreeEntry] {
        var entries: [TreeEntry] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: <mode> <type> <hash>\t<name>
            // Example: 100644 blob abc123def456    README.md
            //          040000 tree def456abc123    src

            guard let tabIndex = trimmed.firstIndex(of: "\t") else { continue }

            let metaPart = String(trimmed[..<tabIndex])
            let namePart = String(trimmed[trimmed.index(after: tabIndex)...])

            let metaParts = metaPart.split(separator: " ")
            guard metaParts.count >= 3 else { continue }

            let mode = String(metaParts[0])
            let typeStr = String(metaParts[1])
            let hash = String(metaParts[2])

            guard let type = TreeEntry.EntryType(rawValue: typeStr) else { continue }

            let entryPath = path.map { $0.isEmpty ? namePart : "\($0)/\(namePart)" } ?? namePart

            entries.append(TreeEntry(
                id: hash,
                mode: mode,
                type: type,
                hash: hash,
                name: namePart,
                path: entryPath
            ))
        }

        // Sort: directories first, then files, alphabetically
        return entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

/// Command to get file contents at a specific ref.
struct ShowFileAtRefCommand: GitCommand {
    typealias Result = String

    let ref: String
    let path: String

    var arguments: [String] {
        ["show", "\(ref):\(path)"]
    }

    func parse(output: String) throws -> String {
        output
    }
}

/// Command to get file size at a specific ref.
struct FileSizeAtRefCommand: GitCommand {
    typealias Result = Int64?

    let hash: String

    var arguments: [String] {
        ["cat-file", "-s", hash]
    }

    func parse(output: String) throws -> Int64? {
        Int64(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
