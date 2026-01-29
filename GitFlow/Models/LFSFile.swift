import Foundation

/// Represents a file tracked by Git LFS.
struct LFSFile: Identifiable, Equatable, Hashable {
    /// The file path relative to repository root.
    let path: String

    /// The LFS object ID (OID/SHA256 hash).
    let oid: String?

    /// The file size in bytes.
    let size: Int64?

    /// The LFS status of the file.
    let status: LFSStatus

    /// Whether the file content is downloaded locally.
    let isDownloaded: Bool

    var id: String { path }

    /// Human-readable file size.
    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// The file name without path.
    var fileName: String {
        (path as NSString).lastPathComponent
    }

    /// The file extension.
    var fileExtension: String {
        (path as NSString).pathExtension.lowercased()
    }
}

/// Status of an LFS tracked file.
enum LFSStatus: String, CaseIterable {
    /// File is tracked by LFS and content is available.
    case tracked = "tracked"

    /// File is tracked but content is not downloaded (pointer only).
    case pointer = "pointer"

    /// File matches an LFS pattern but is not yet tracked.
    case untracked = "untracked"

    /// File was modified locally.
    case modified = "modified"

    var displayName: String {
        switch self {
        case .tracked: return "Tracked"
        case .pointer: return "Pointer Only"
        case .untracked: return "Not Tracked"
        case .modified: return "Modified"
        }
    }

    var icon: String {
        switch self {
        case .tracked: return "checkmark.circle.fill"
        case .pointer: return "arrow.down.circle"
        case .untracked: return "circle.dashed"
        case .modified: return "pencil.circle"
        }
    }
}

/// Represents an LFS tracking pattern from .gitattributes.
struct LFSTrackingPattern: Identifiable, Equatable, Hashable {
    /// The glob pattern (e.g., "*.psd", "assets/**/*.png").
    let pattern: String

    /// The filter attribute value (should be "lfs").
    let filter: String

    /// Whether diff is disabled for this pattern.
    let diffDisabled: Bool

    /// Whether merge is disabled for this pattern.
    let mergeDisabled: Bool

    var id: String { pattern }

    /// Whether this is a valid LFS pattern.
    var isValid: Bool {
        filter == "lfs"
    }
}

/// LFS repository status information.
struct LFSStatus2: Equatable {
    /// Whether Git LFS is installed on the system.
    let isInstalled: Bool

    /// Whether the repository has LFS initialized.
    let isInitialized: Bool

    /// The LFS version if installed.
    let version: String?

    /// Current tracking patterns.
    let trackingPatterns: [LFSTrackingPattern]

    /// LFS endpoint URL if configured.
    let endpoint: String?

    /// Number of LFS objects in the repository.
    let objectCount: Int

    /// Total size of LFS objects.
    let totalSize: Int64

    /// Human-readable total size.
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

/// Information about an LFS fetch/pull/push operation.
struct LFSTransferProgress: Equatable {
    /// Total number of objects to transfer.
    let totalObjects: Int

    /// Number of objects transferred so far.
    let transferredObjects: Int

    /// Total bytes to transfer.
    let totalBytes: Int64

    /// Bytes transferred so far.
    let transferredBytes: Int64

    /// Current file being transferred.
    let currentFile: String?

    /// Progress percentage (0-100).
    var percentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes) * 100
    }

    /// Human-readable progress string.
    var progressString: String {
        let transferred = ByteCountFormatter.string(fromByteCount: transferredBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(transferred) / \(total) (\(transferredObjects)/\(totalObjects) objects)"
    }
}

/// Common LFS file type categories for quick tracking.
enum LFSFileCategory: String, CaseIterable, Identifiable {
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    case archives = "Archives"
    case binaries = "Binaries"
    case documents = "Documents"
    case models3d = "3D Models"
    case fonts = "Fonts"

    var id: String { rawValue }

    var patterns: [String] {
        switch self {
        case .images:
            return ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.tiff", "*.tif", "*.psd", "*.ai", "*.eps", "*.svg", "*.ico", "*.webp", "*.heic", "*.raw"]
        case .videos:
            return ["*.mp4", "*.mov", "*.avi", "*.mkv", "*.wmv", "*.flv", "*.webm", "*.m4v", "*.mpeg", "*.mpg"]
        case .audio:
            return ["*.mp3", "*.wav", "*.flac", "*.aac", "*.ogg", "*.wma", "*.m4a", "*.aiff"]
        case .archives:
            return ["*.zip", "*.tar", "*.gz", "*.rar", "*.7z", "*.bz2", "*.xz", "*.tar.gz", "*.tgz"]
        case .binaries:
            return ["*.exe", "*.dll", "*.so", "*.dylib", "*.a", "*.lib", "*.bin", "*.dat"]
        case .documents:
            return ["*.pdf", "*.doc", "*.docx", "*.xls", "*.xlsx", "*.ppt", "*.pptx"]
        case .models3d:
            return ["*.fbx", "*.obj", "*.blend", "*.3ds", "*.dae", "*.stl", "*.gltf", "*.glb"]
        case .fonts:
            return ["*.ttf", "*.otf", "*.woff", "*.woff2", "*.eot"]
        }
    }

    var icon: String {
        switch self {
        case .images: return "photo"
        case .videos: return "video"
        case .audio: return "waveform"
        case .archives: return "archivebox"
        case .binaries: return "gearshape.2"
        case .documents: return "doc"
        case .models3d: return "cube"
        case .fonts: return "textformat"
        }
    }
}
