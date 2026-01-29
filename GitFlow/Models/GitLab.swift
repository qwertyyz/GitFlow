import Foundation

/// Represents a GitLab project (repository).
struct GitLabProject: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let nameWithNamespace: String
    let description: String?
    let webUrl: String
    let httpUrlToRepo: String
    let sshUrlToRepo: String
    let defaultBranch: String?
    let visibility: String
    let starCount: Int
    let forksCount: Int
    let openIssuesCount: Int?
    let namespace: GitLabNamespace
    let avatarUrl: String?

    var isPrivate: Bool {
        visibility == "private"
    }

    var isFork: Bool {
        // GitLab doesn't have a direct fork indicator in this response
        false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, visibility, namespace
        case nameWithNamespace = "name_with_namespace"
        case webUrl = "web_url"
        case httpUrlToRepo = "http_url_to_repo"
        case sshUrlToRepo = "ssh_url_to_repo"
        case defaultBranch = "default_branch"
        case starCount = "star_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case avatarUrl = "avatar_url"
    }
}

/// Represents a GitLab namespace (user or group).
struct GitLabNamespace: Codable, Equatable {
    let id: Int
    let name: String
    let path: String
    let kind: String
    let fullPath: String
    let avatarUrl: String?

    var isGroup: Bool {
        kind == "group"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, kind
        case fullPath = "full_path"
        case avatarUrl = "avatar_url"
    }
}

/// Represents a GitLab user.
struct GitLabUser: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let username: String
    let name: String
    let avatarUrl: String?
    let webUrl: String
    let state: String?

    var isActive: Bool {
        state == "active"
    }

    enum CodingKeys: String, CodingKey {
        case id, username, name, state
        case avatarUrl = "avatar_url"
        case webUrl = "web_url"
    }
}

/// Represents a GitLab merge request.
struct GitLabMergeRequest: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let iid: Int
    let title: String
    let description: String?
    let state: MergeRequestState
    let webUrl: String
    let author: GitLabUser
    let labels: [String]
    let assignees: [GitLabUser]?
    let createdAt: Date
    let updatedAt: Date
    let closedAt: Date?
    let mergedAt: Date?
    let sourceBranch: String
    let targetBranch: String
    let isDraft: Bool
    let mergeStatus: String?
    let diffRefs: DiffRefs?

    var isOpen: Bool {
        state == .opened
    }

    var isMerged: Bool {
        state == .merged
    }

    enum MergeRequestState: String, Codable, Hashable {
        case opened
        case closed
        case merged
        case locked
    }

    struct DiffRefs: Codable, Equatable, Hashable {
        let baseSha: String?
        let headSha: String?
        let startSha: String?

        enum CodingKeys: String, CodingKey {
            case baseSha = "base_sha"
            case headSha = "head_sha"
            case startSha = "start_sha"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, author, labels, assignees
        case webUrl = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case mergedAt = "merged_at"
        case sourceBranch = "source_branch"
        case targetBranch = "target_branch"
        case isDraft = "draft"
        case mergeStatus = "merge_status"
        case diffRefs = "diff_refs"
    }
}

/// Represents a GitLab issue.
struct GitLabIssue: Codable, Identifiable, Equatable {
    let id: Int
    let iid: Int
    let title: String
    let description: String?
    let state: String
    let webUrl: String
    let author: GitLabUser
    let labels: [String]
    let assignees: [GitLabUser]?
    let createdAt: Date
    let updatedAt: Date
    let closedAt: Date?

    var isOpen: Bool {
        state == "opened"
    }

    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, author, labels, assignees
        case webUrl = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
    }
}

/// Represents a GitLab note (comment).
struct GitLabNote: Codable, Identifiable, Equatable {
    let id: Int
    let body: String
    let author: GitLabUser
    let createdAt: Date
    let updatedAt: Date
    let system: Bool
    let resolvable: Bool
    let resolved: Bool?
    let resolvedBy: GitLabUser?

    var isUserComment: Bool {
        !system
    }

    enum CodingKeys: String, CodingKey {
        case id, body, author, system, resolvable, resolved
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedBy = "resolved_by"
    }
}

/// Represents a GitLab branch.
struct GitLabBranch: Codable, Identifiable, Equatable {
    let name: String
    let protected: Bool
    let developersCanPush: Bool
    let developersCanMerge: Bool
    let canPush: Bool
    let isDefault: Bool
    let commit: BranchCommit?

    var id: String { name }

    struct BranchCommit: Codable, Equatable {
        let id: String
        let shortId: String
        let title: String?
        let authorName: String?
        let authoredDate: Date?

        enum CodingKeys: String, CodingKey {
            case id, title
            case shortId = "short_id"
            case authorName = "author_name"
            case authoredDate = "authored_date"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, protected, commit
        case developersCanPush = "developers_can_push"
        case developersCanMerge = "developers_can_merge"
        case canPush = "can_push"
        case isDefault = "default"
    }
}

/// Represents a GitLab pipeline.
struct GitLabPipeline: Codable, Identifiable, Equatable {
    let id: Int
    let iid: Int
    let status: PipelineStatus
    let ref: String
    let sha: String
    let webUrl: String
    let createdAt: Date
    let updatedAt: Date

    enum PipelineStatus: String, Codable {
        case created
        case waitingForResource = "waiting_for_resource"
        case preparing
        case pending
        case running
        case success
        case failed
        case canceled
        case skipped
        case manual
        case scheduled
    }

    enum CodingKeys: String, CodingKey {
        case id, iid, status, ref, sha
        case webUrl = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Information extracted from a GitLab remote URL.
struct GitLabRemoteInfo: Equatable {
    let host: String
    let projectPath: String

    var webUrl: String {
        "https://\(host)/\(projectPath)"
    }

    var apiUrl: String {
        "https://\(host)/api/v4/projects/\(encodedPath)"
    }

    var encodedPath: String {
        projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
    }

    /// Parses GitLab remote info from a URL.
    /// Supports gitlab.com and self-hosted GitLab instances.
    static func parse(from url: String) -> GitLabRemoteInfo? {
        // Handle various URL formats:
        // https://gitlab.com/owner/repo.git
        // git@gitlab.com:owner/repo.git
        // https://gitlab.example.com/group/subgroup/repo.git

        var cleaned = url

        // Extract host and path for HTTPS URLs
        if let httpsMatch = cleaned.range(of: "https://") {
            cleaned = String(cleaned[httpsMatch.upperBound...])
            let parts = cleaned.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return nil }

            let host = String(parts[0])
            var path = String(parts[1])

            // Remove .git suffix
            if path.hasSuffix(".git") {
                path = String(path.dropLast(4))
            }
            // Remove trailing slash
            if path.hasSuffix("/") {
                path = String(path.dropLast())
            }

            // Check if this is GitLab (gitlab.com or contains gitlab in hostname)
            if host == "gitlab.com" || host.contains("gitlab") {
                return GitLabRemoteInfo(host: host, projectPath: path)
            }
        }

        // Handle SSH URLs: git@gitlab.com:owner/repo.git
        if let sshMatch = cleaned.range(of: "git@") {
            cleaned = String(cleaned[sshMatch.upperBound...])

            guard let colonIndex = cleaned.firstIndex(of: ":") else { return nil }

            let host = String(cleaned[..<colonIndex])
            var path = String(cleaned[cleaned.index(after: colonIndex)...])

            // Remove .git suffix
            if path.hasSuffix(".git") {
                path = String(path.dropLast(4))
            }
            // Remove trailing slash
            if path.hasSuffix("/") {
                path = String(path.dropLast())
            }

            if host == "gitlab.com" || host.contains("gitlab") {
                return GitLabRemoteInfo(host: host, projectPath: path)
            }
        }

        return nil
    }
}
