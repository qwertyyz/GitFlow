import Foundation

/// View model for commit creation.
@MainActor
final class CommitViewModel: ObservableObject {
    // MARK: - Published State

    /// The commit message being composed.
    @Published var commitMessage: String = ""

    /// Whether a commit operation is in progress.
    @Published private(set) var isCommitting: Bool = false

    /// Current error, if any.
    @Published var error: GitError?

    /// Whether the last commit succeeded.
    @Published private(set) var lastCommitSucceeded: Bool = false

    /// Whether to amend the previous commit.
    @Published var isAmending: Bool = false

    /// Whether to sign the commit with GPG.
    @Published var signWithGPG: Bool = false

    /// Whether GPG signing is available.
    @Published private(set) var gpgSigningAvailable: Bool = false

    /// The GPG key ID if configured.
    @Published private(set) var gpgKeyId: String?

    /// Custom author override (format: "Name <email>").
    @Published var authorOverride: String?

    /// The last commit message (for amending).
    @Published private(set) var lastCommitMessage: String = ""

    /// The configured commit template.
    @Published private(set) var commitTemplate: String?

    /// The subject line (first line) of the commit message.
    var subject: String {
        let lines = commitMessage.components(separatedBy: .newlines)
        return lines.first ?? ""
    }

    /// The body of the commit message (everything after the first line).
    var body: String {
        let lines = commitMessage.components(separatedBy: .newlines)
        guard lines.count > 1 else { return "" }
        return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Dependencies

    private let repository: Repository
    private let gitService: GitService

    // MARK: - Initialization

    init(repository: Repository, gitService: GitService) {
        self.repository = repository
        self.gitService = gitService
    }

    // MARK: - Public Methods

    /// Loads initial data (GPG status, template, etc.)
    func loadInitialData() async {
        gpgSigningAvailable = await gitService.isGPGSigningConfigured(in: repository)
        gpgKeyId = await gitService.getGPGKeyId(in: repository)
        commitTemplate = await gitService.getCommitTemplate(in: repository)

        // Apply template if no message yet
        if commitMessage.isEmpty, let template = commitTemplate {
            commitMessage = template
        }
    }

    /// Creates a commit with the current message.
    func createCommit() async {
        await createCommit(message: commitMessage)
    }

    /// Creates a commit with the specified message.
    func createCommit(message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = .unknown(message: "Commit message cannot be empty")
            return
        }

        isCommitting = true
        lastCommitSucceeded = false
        defer { isCommitting = false }

        do {
            var options = CommitOptions(message: message)
            options.amend = isAmending
            options.gpgSign = signWithGPG
            options.author = authorOverride

            try await gitService.commitWithOptions(options, in: repository)
            commitMessage = ""
            isAmending = false
            authorOverride = nil
            lastCommitSucceeded = true
            error = nil
        } catch let gitError as GitError {
            error = gitError
            lastCommitSucceeded = false
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            lastCommitSucceeded = false
        }
    }

    /// Starts amending the last commit.
    func startAmending() async {
        isAmending = true

        do {
            lastCommitMessage = try await gitService.getLastCommitMessage(in: repository)
            commitMessage = lastCommitMessage
        } catch {
            // Silently fail - user can still type a new message
        }
    }

    /// Cancels amending and returns to normal commit mode.
    func cancelAmending() {
        isAmending = false
        commitMessage = ""
    }

    /// Amends the last commit without changing the message.
    func amendNoEdit() async {
        isCommitting = true
        lastCommitSucceeded = false
        defer { isCommitting = false }

        do {
            try await gitService.amendCommitNoEdit(in: repository)
            isAmending = false
            lastCommitSucceeded = true
            error = nil
        } catch let gitError as GitError {
            error = gitError
            lastCommitSucceeded = false
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            lastCommitSucceeded = false
        }
    }

    /// Clears the commit message.
    func clearMessage() {
        commitMessage = ""
    }

    /// Sets a template commit message.
    func setTemplate(_ template: String) {
        commitMessage = template
    }

    /// Loads the configured commit template.
    func loadTemplate() async {
        if let template = await gitService.getCommitTemplate(in: repository) {
            commitMessage = template
        }
    }

    /// Sets a custom author for the commit.
    func setAuthor(name: String, email: String) {
        authorOverride = "\(name) <\(email)>"
    }

    /// Clears the author override.
    func clearAuthorOverride() {
        authorOverride = nil
    }

    // MARK: - Computed Properties

    /// Whether the commit message is valid.
    var isMessageValid: Bool {
        !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The length of the subject line.
    var subjectLength: Int {
        subject.count
    }

    /// Whether the subject line is too long (over 50 characters).
    var isSubjectTooLong: Bool {
        subjectLength > 50
    }

    /// Whether the subject line is much too long (over 72 characters).
    var isSubjectWayTooLong: Bool {
        subjectLength > 72
    }

    /// A suggested subject line length indicator.
    var subjectLengthIndicator: String {
        if isSubjectWayTooLong {
            return "\(subjectLength) (way too long)"
        } else if isSubjectTooLong {
            return "\(subjectLength) (too long)"
        }
        return "\(subjectLength)"
    }

    /// The mode indicator text.
    var modeIndicator: String {
        if isAmending {
            return "Amending"
        }
        return "New Commit"
    }
}
