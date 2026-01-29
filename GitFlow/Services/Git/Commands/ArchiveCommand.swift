import Foundation

/// Command to create a ZIP archive of a tree (commit, branch, tag).
struct ArchiveCommand: GitCommand {
    typealias Result = Bool

    let ref: String
    let outputPath: String
    let prefix: String?
    let format: ArchiveFormat

    enum ArchiveFormat: String {
        case zip
        case tar
        case tarGz = "tar.gz"
    }

    init(ref: String, outputPath: String, prefix: String? = nil, format: ArchiveFormat = .zip) {
        self.ref = ref
        self.outputPath = outputPath
        self.prefix = prefix
        self.format = format
    }

    var arguments: [String] {
        var args = ["archive"]

        args.append("--format=\(format.rawValue)")
        args.append("--output=\(outputPath)")

        if let prefix = prefix {
            args.append("--prefix=\(prefix)/")
        }

        args.append(ref)

        return args
    }

    func parse(output: String) throws -> Bool {
        // Archive succeeds if no error
        !output.contains("fatal:")
    }
}

/// Command to create a ZIP archive of specific paths within a tree.
struct ArchivePathsCommand: GitCommand {
    typealias Result = Bool

    let ref: String
    let paths: [String]
    let outputPath: String
    let prefix: String?

    init(ref: String, paths: [String], outputPath: String, prefix: String? = nil) {
        self.ref = ref
        self.paths = paths
        self.outputPath = outputPath
        self.prefix = prefix
    }

    var arguments: [String] {
        var args = ["archive"]

        args.append("--format=zip")
        args.append("--output=\(outputPath)")

        if let prefix = prefix {
            args.append("--prefix=\(prefix)/")
        }

        args.append(ref)
        args.append("--")
        args.append(contentsOf: paths)

        return args
    }

    func parse(output: String) throws -> Bool {
        !output.contains("fatal:")
    }
}
