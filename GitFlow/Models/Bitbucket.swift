import Foundation

/// Represents a Bitbucket repository.
struct BitbucketRepository: Codable, Identifiable, Equatable {
    let uuid: String
    let name: String
    let fullName: String
    let description: String?
    let isPrivate: Bool
    let scm: String
    let owner: BitbucketAccount
    let workspace: BitbucketWorkspace
    let mainBranch: MainBranch?
    let links: RepositoryLinks

    var id: String { uuid }

    var cloneUrl: String? {
        links.clone?.first(where: { $0.name == "https" })?.href
    }

    var sshUrl: String? {
        links.clone?.first(where: { $0.name == "ssh" })?.href
    }

    var webUrl: String? {
        links.html?.href
    }

    struct MainBranch: Codable, Equatable {
        let name: String
        let type: String
    }

    struct RepositoryLinks: Codable, Equatable {
        let html: Link?
        let clone: [CloneLink]?

        struct Link: Codable, Equatable {
            let href: String
        }

        struct CloneLink: Codable, Equatable {
            let href: String
            let name: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case uuid, name, description, scm, owner, workspace, links
        case fullName = "full_name"
        case isPrivate = "is_private"
        case mainBranch = "mainbranch"
    }
}

/// Represents a Bitbucket workspace.
struct BitbucketWorkspace: Codable, Identifiable, Equatable {
    let uuid: String
    let slug: String
    let name: String
    let type: String

    var id: String { uuid }
}

/// Represents a Bitbucket account (user or team).
struct BitbucketAccount: Codable, Identifiable, Equatable, Hashable {
    let uuid: String
    let username: String?
    let displayName: String
    let type: String
    let links: AccountLinks?

    var id: String { uuid }

    var isTeam: Bool {
        type == "team"
    }

    var avatarUrl: String? {
        links?.avatar?.href
    }

    struct AccountLinks: Codable, Equatable, Hashable {
        let avatar: Link?

        struct Link: Codable, Equatable, Hashable {
            let href: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case uuid, username, type, links
        case displayName = "display_name"
    }
}

/// Represents the authenticated Bitbucket user.
struct BitbucketUser: Codable, Identifiable, Equatable {
    let uuid: String
    let username: String
    let displayName: String
    let accountId: String
    let links: BitbucketAccount.AccountLinks?

    var id: String { uuid }

    var avatarUrl: String? {
        links?.avatar?.href
    }

    enum CodingKeys: String, CodingKey {
        case uuid, username, links
        case displayName = "display_name"
        case accountId = "account_id"
    }
}

/// Represents a Bitbucket pull request.
struct BitbucketPullRequest: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let state: PullRequestState
    let author: BitbucketAccount
    let source: BranchRef
    let destination: BranchRef
    let createdOn: Date
    let updatedOn: Date
    let closedBy: BitbucketAccount?
    let mergeCommit: MergeCommit?
    let commentCount: Int
    let taskCount: Int
    let links: PRLinks

    var isOpen: Bool {
        state == .open
    }

    var isMerged: Bool {
        state == .merged
    }

    var webUrl: String? {
        links.html?.href
    }

    enum PullRequestState: String, Codable, Hashable {
        case open = "OPEN"
        case merged = "MERGED"
        case declined = "DECLINED"
        case superseded = "SUPERSEDED"
    }

    struct BranchRef: Codable, Equatable, Hashable {
        let branch: Branch
        let commit: Commit?
        let repository: RepositoryRef?

        struct Branch: Codable, Equatable, Hashable {
            let name: String
        }

        struct Commit: Codable, Equatable, Hashable {
            let hash: String
        }

        struct RepositoryRef: Codable, Equatable, Hashable {
            let fullName: String
            let name: String
            let uuid: String

            enum CodingKeys: String, CodingKey {
                case name, uuid
                case fullName = "full_name"
            }
        }
    }

    struct MergeCommit: Codable, Equatable, Hashable {
        let hash: String
    }

    struct PRLinks: Codable, Equatable, Hashable {
        let html: Link?
        let diff: Link?
        let commits: Link?

        struct Link: Codable, Equatable, Hashable {
            let href: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, state, author, source, destination, links
        case createdOn = "created_on"
        case updatedOn = "updated_on"
        case closedBy = "closed_by"
        case mergeCommit = "merge_commit"
        case commentCount = "comment_count"
        case taskCount = "task_count"
    }
}

/// Represents a Bitbucket issue.
struct BitbucketIssue: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let content: IssueContent?
    let state: String
    let priority: String
    let kind: String
    let reporter: BitbucketAccount?
    let assignee: BitbucketAccount?
    let createdOn: Date
    let updatedOn: Date
    let links: IssueLinks

    var isOpen: Bool {
        state == "new" || state == "open"
    }

    var webUrl: String? {
        links.html?.href
    }

    struct IssueContent: Codable, Equatable {
        let raw: String?
        let markup: String?
        let html: String?
    }

    struct IssueLinks: Codable, Equatable {
        let html: Link?

        struct Link: Codable, Equatable {
            let href: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, state, priority, kind, reporter, assignee, links
        case createdOn = "created_on"
        case updatedOn = "updated_on"
    }
}

/// Represents a Bitbucket comment.
struct BitbucketComment: Codable, Identifiable, Equatable {
    let id: Int
    let content: CommentContent
    let user: BitbucketAccount
    let createdOn: Date
    let updatedOn: Date
    let deleted: Bool
    let links: CommentLinks?

    struct CommentContent: Codable, Equatable {
        let raw: String?
        let markup: String?
        let html: String?
    }

    struct CommentLinks: Codable, Equatable {
        let html: Link?

        struct Link: Codable, Equatable {
            let href: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, content, user, deleted, links
        case createdOn = "created_on"
        case updatedOn = "updated_on"
    }
}

/// Represents a Bitbucket branch.
struct BitbucketBranch: Codable, Identifiable, Equatable {
    let name: String
    let target: BranchTarget
    let type: String

    var id: String { name }

    struct BranchTarget: Codable, Equatable {
        let hash: String
        let date: Date?
        let message: String?
        let author: CommitAuthor?

        struct CommitAuthor: Codable, Equatable {
            let raw: String?
            let user: BitbucketAccount?
        }
    }
}

/// Represents a Bitbucket pipeline.
struct BitbucketPipeline: Codable, Identifiable, Equatable {
    let uuid: String
    let buildNumber: Int
    let state: PipelineState
    let target: PipelineTarget
    let createdOn: Date
    let completedOn: Date?

    var id: String { uuid }

    struct PipelineState: Codable, Equatable {
        let name: String
        let type: String
        let result: PipelineResult?

        struct PipelineResult: Codable, Equatable {
            let name: String
            let type: String
        }
    }

    struct PipelineTarget: Codable, Equatable {
        let refName: String?
        let refType: String?
        let commit: TargetCommit?

        struct TargetCommit: Codable, Equatable {
            let hash: String
        }

        enum CodingKeys: String, CodingKey {
            case commit
            case refName = "ref_name"
            case refType = "ref_type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case uuid, state, target
        case buildNumber = "build_number"
        case createdOn = "created_on"
        case completedOn = "completed_on"
    }
}

/// Information extracted from a Bitbucket remote URL.
struct BitbucketRemoteInfo: Equatable {
    let workspace: String
    let repoSlug: String

    var fullName: String {
        "\(workspace)/\(repoSlug)"
    }

    var webUrl: String {
        "https://bitbucket.org/\(workspace)/\(repoSlug)"
    }

    var apiUrl: String {
        "https://api.bitbucket.org/2.0/repositories/\(workspace)/\(repoSlug)"
    }

    /// Parses Bitbucket remote info from a URL.
    static func parse(from url: String) -> BitbucketRemoteInfo? {
        // Handle various URL formats:
        // https://bitbucket.org/workspace/repo.git
        // git@bitbucket.org:workspace/repo.git
        // https://user@bitbucket.org/workspace/repo.git

        var cleaned = url

        // Handle HTTPS URLs
        if cleaned.contains("bitbucket.org/") {
            // Remove protocol and potential username
            if let range = cleaned.range(of: "bitbucket.org/") {
                cleaned = String(cleaned[range.upperBound...])
            }
        }
        // Handle SSH URLs
        else if cleaned.hasPrefix("git@bitbucket.org:") {
            cleaned = String(cleaned.dropFirst(18))
        } else {
            return nil
        }

        // Remove .git suffix
        if cleaned.hasSuffix(".git") {
            cleaned = String(cleaned.dropLast(4))
        }

        // Remove trailing slash
        if cleaned.hasSuffix("/") {
            cleaned = String(cleaned.dropLast())
        }

        // Split into workspace/repo
        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        return BitbucketRemoteInfo(
            workspace: String(parts[0]),
            repoSlug: String(parts[1])
        )
    }
}

/// Paginated response wrapper for Bitbucket API.
struct BitbucketPaginatedResponse<T: Codable>: Codable {
    let values: [T]
    let page: Int?
    let size: Int?
    let pagelen: Int?
    let next: String?
    let previous: String?
}
