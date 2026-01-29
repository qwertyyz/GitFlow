import Foundation

/// Command to list remotes.
struct ListRemotesCommand: GitCommand {
    typealias Result = [Remote]

    var arguments: [String] {
        ["remote", "-v"]
    }

    func parse(output: String) throws -> [Remote] {
        RemoteParser.parse(output)
    }
}

/// Command to fetch from remote.
struct FetchCommand: VoidGitCommand {
    let remote: String?
    let prune: Bool

    init(remote: String? = nil, prune: Bool = false) {
        self.remote = remote
        self.prune = prune
    }

    var arguments: [String] {
        var args = ["fetch"]
        if prune {
            args.append("--prune")
        }
        if let remote {
            args.append(remote)
        } else {
            args.append("--all")
        }
        return args
    }
}

/// Command to pull from remote.
struct PullCommand: VoidGitCommand {
    let remote: String?
    let branch: String?
    let rebase: Bool

    init(remote: String? = nil, branch: String? = nil, rebase: Bool = false) {
        self.remote = remote
        self.branch = branch
        self.rebase = rebase
    }

    var arguments: [String] {
        var args = ["pull"]
        if rebase {
            args.append("--rebase")
        }
        if let remote {
            args.append(remote)
            if let branch {
                args.append(branch)
            }
        }
        return args
    }
}

/// Force mode options for git push.
enum PushForceMode {
    /// No force push - standard behavior.
    case none
    /// Force push with lease - safer, fails if remote has new commits.
    case withLease
    /// Full force push - dangerous, overwrites remote unconditionally.
    case force
}

/// Command to push to remote.
struct PushCommand: VoidGitCommand {
    let remote: String?
    let branch: String?
    let setUpstream: Bool
    let forceMode: PushForceMode

    init(remote: String? = nil, branch: String? = nil, setUpstream: Bool = false, force: Bool = false) {
        self.remote = remote
        self.branch = branch
        self.setUpstream = setUpstream
        // For backwards compatibility, force: true maps to force-with-lease
        self.forceMode = force ? .withLease : .none
    }

    init(remote: String? = nil, branch: String? = nil, setUpstream: Bool = false, forceMode: PushForceMode = .none) {
        self.remote = remote
        self.branch = branch
        self.setUpstream = setUpstream
        self.forceMode = forceMode
    }

    var arguments: [String] {
        var args = ["push"]
        if setUpstream {
            args.append("-u")
        }
        switch forceMode {
        case .none:
            break
        case .withLease:
            args.append("--force-with-lease")
        case .force:
            args.append("--force")
        }
        if let remote {
            args.append(remote)
            if let branch {
                args.append(branch)
            }
        }
        return args
    }
}

/// Command to add a remote.
struct AddRemoteCommand: VoidGitCommand {
    let name: String
    let url: String

    var arguments: [String] {
        ["remote", "add", name, url]
    }
}

/// Command to remove a remote.
struct RemoveRemoteCommand: VoidGitCommand {
    let name: String

    var arguments: [String] {
        ["remote", "remove", name]
    }
}

/// Command to rename a remote.
struct RenameRemoteCommand: VoidGitCommand {
    let oldName: String
    let newName: String

    var arguments: [String] {
        ["remote", "rename", oldName, newName]
    }
}

/// Command to set the URL of a remote.
struct SetRemoteURLCommand: VoidGitCommand {
    let name: String
    let url: String
    let pushURL: Bool

    init(name: String, url: String, pushURL: Bool = false) {
        self.name = name
        self.url = url
        self.pushURL = pushURL
    }

    var arguments: [String] {
        var args = ["remote", "set-url"]
        if pushURL {
            args.append("--push")
        }
        args.append(name)
        args.append(url)
        return args
    }
}

/// Command to clone a repository.
struct CloneCommand: VoidGitCommand {
    let url: String
    let branch: String?
    let depth: Int?

    init(url: String, branch: String? = nil, depth: Int? = nil) {
        self.url = url
        self.branch = branch
        self.depth = depth
    }

    var arguments: [String] {
        var args = ["clone"]
        if let branch {
            args.append("-b")
            args.append(branch)
        }
        if let depth {
            args.append("--depth")
            args.append(String(depth))
        }
        args.append(url)
        return args
    }
}
