import Foundation

/// Options for creating a commit.
struct CommitOptions {
    /// The commit message.
    var message: String?

    /// Whether to amend the previous commit.
    var amend: Bool = false

    /// Whether to keep the previous commit message when amending (--no-edit).
    var noEdit: Bool = false

    /// Whether to sign the commit with GPG.
    var gpgSign: Bool = false

    /// The GPG key ID to use for signing (uses default if nil).
    var gpgKeyId: String?

    /// Override the author (format: "Name <email>").
    var author: String?

    /// Override the commit date.
    var date: Date?

    /// Whether to allow an empty commit.
    var allowEmpty: Bool = false

    /// Whether to allow an empty message.
    var allowEmptyMessage: Bool = false

    init(message: String? = nil) {
        self.message = message
    }
}

/// Command to create a commit.
struct CreateCommitCommand: VoidGitCommand {
    let message: String
    let amend: Bool

    init(message: String, amend: Bool = false) {
        self.message = message
        self.amend = amend
    }

    var arguments: [String] {
        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }
        return args
    }
}

/// Command to create a commit with full options.
struct CreateCommitWithOptionsCommand: VoidGitCommand {
    let options: CommitOptions

    var arguments: [String] {
        var args = ["commit"]

        // Message
        if let message = options.message {
            args.append("-m")
            args.append(message)
        }

        // Amend
        if options.amend {
            args.append("--amend")
        }

        // No edit (keep previous message when amending)
        if options.noEdit {
            args.append("--no-edit")
        }

        // GPG signing
        if options.gpgSign {
            if let keyId = options.gpgKeyId {
                args.append("-S\(keyId)")
            } else {
                args.append("-S")
            }
        }

        // Author override
        if let author = options.author {
            args.append("--author=\(author)")
        }

        // Date override
        if let date = options.date {
            let formatter = ISO8601DateFormatter()
            args.append("--date=\(formatter.string(from: date))")
        }

        // Allow empty
        if options.allowEmpty {
            args.append("--allow-empty")
        }

        // Allow empty message
        if options.allowEmptyMessage {
            args.append("--allow-empty-message")
        }

        return args
    }
}

/// Command to create a commit with a message from a file.
struct CreateCommitFromFileCommand: VoidGitCommand {
    let messageFilePath: String
    let amend: Bool

    init(messageFilePath: String, amend: Bool = false) {
        self.messageFilePath = messageFilePath
        self.amend = amend
    }

    var arguments: [String] {
        var args = ["commit", "-F", messageFilePath]
        if amend {
            args.append("--amend")
        }
        return args
    }
}

/// Command to get the last commit message (for amending).
struct GetLastCommitMessageCommand: GitCommand {
    typealias Result = String

    var arguments: [String] {
        ["log", "-1", "--format=%B"]
    }

    func parse(output: String) throws -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Command to check if GPG signing is configured.
struct CheckGPGSigningCommand: GitCommand {
    typealias Result = Bool

    var arguments: [String] {
        ["config", "--get", "user.signingkey"]
    }

    func parse(output: String) throws -> Bool {
        !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Command to get the configured GPG key ID.
struct GetGPGKeyIdCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["config", "--get", "user.signingkey"]
    }

    func parse(output: String) throws -> String? {
        let keyId = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyId.isEmpty ? nil : keyId
    }
}

/// Command to get commit templates from git config.
struct GetCommitTemplateCommand: GitCommand {
    typealias Result = String?

    var arguments: [String] {
        ["config", "--get", "commit.template"]
    }

    func parse(output: String) throws -> String? {
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }

        // Expand ~ if present
        let expandedPath = NSString(string: path).expandingTildeInPath

        // Read the template file
        if let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) {
            return content
        }
        return nil
    }
}
