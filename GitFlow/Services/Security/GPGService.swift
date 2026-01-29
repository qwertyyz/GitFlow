import Foundation

/// Service for managing GPG keys and verifying commit signatures.
actor GPGService {
    private let gpgPath: String

    init() {
        // Try to find gpg in common locations
        let possiblePaths = [
            "/usr/local/bin/gpg",
            "/opt/homebrew/bin/gpg",
            "/usr/bin/gpg"
        ]

        self.gpgPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "gpg"
    }

    // MARK: - GPG Availability

    /// Checks if GPG is installed.
    func isGPGInstalled() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--version"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Gets the GPG version.
    func getVersion() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--version"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: .newlines).first
        } catch {
            return nil
        }
    }

    // MARK: - Key Listing

    /// Lists all GPG keys.
    func listKeys() async throws -> [GPGKey] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--list-keys", "--with-colons", "--keyid-format", "long"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return parseKeyList(output)
    }

    /// Lists GPG secret keys (keys you can sign with).
    func listSecretKeys() async throws -> [GPGKey] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--list-secret-keys", "--with-colons", "--keyid-format", "long"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return parseKeyList(output)
    }

    // MARK: - Signature Verification

    /// Verifies a commit signature.
    func verifyCommitSignature(commitHash: String, in repositoryPath: URL) async -> SignatureVerification {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["verify-commit", "--raw", commitHash]
        process.currentDirectoryURL = repositoryPath

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            return parseVerificationOutput(errorOutput, exitCode: process.terminationStatus)
        } catch {
            return SignatureVerification(
                isVerified: false,
                signerName: nil,
                signerEmail: nil,
                keyId: nil,
                status: .cannotVerify,
                message: error.localizedDescription
            )
        }
    }

    /// Gets signature info for a commit using git log.
    func getCommitSignatureInfo(commitHash: String, in repositoryPath: URL) async -> SignatureVerification {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "log", "-1", "--format=%G?|%GS|%GK|%GG",
            commitHash
        ]
        process.currentDirectoryURL = repositoryPath

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return parseLogSignatureOutput(output)
        } catch {
            return SignatureVerification(
                isVerified: false,
                signerName: nil,
                signerEmail: nil,
                keyId: nil,
                status: .cannotVerify,
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Parsing

    private func parseKeyList(_ output: String) -> [GPGKey] {
        var keys: [GPGKey] = []
        var currentKey: (keyId: String, fingerprint: String, created: Date?, expires: Date?, trust: String, canSign: Bool, canEncrypt: Bool)?
        var currentUserId: String?
        var currentEmail: String?

        for line in output.components(separatedBy: .newlines) {
            let fields = line.components(separatedBy: ":")

            guard fields.count >= 2 else { continue }

            let recordType = fields[0]

            switch recordType {
            case "pub", "sec":
                // Save previous key if exists
                if let key = currentKey {
                    let gpgKey = GPGKey(
                        id: key.keyId,
                        keyId: key.keyId,
                        fingerprint: key.fingerprint,
                        userId: currentUserId ?? "",
                        email: currentEmail,
                        createdDate: key.created,
                        expirationDate: key.expires,
                        isExpired: key.expires.map { $0 < Date() } ?? false,
                        isRevoked: key.trust == "r",
                        canSign: key.canSign,
                        canEncrypt: key.canEncrypt,
                        trustLevel: parseTrustLevel(key.trust)
                    )
                    keys.append(gpgKey)
                }

                // Start new key
                guard fields.count >= 12 else { continue }

                let keyId = fields[4]
                let created = parseTimestamp(fields[5])
                let expires = fields[6].isEmpty ? nil : parseTimestamp(fields[6])
                let trust = fields[1]
                let capabilities = fields.count > 11 ? fields[11] : ""

                currentKey = (
                    keyId: keyId,
                    fingerprint: "",
                    created: created,
                    expires: expires,
                    trust: trust,
                    canSign: capabilities.contains("s") || capabilities.contains("S"),
                    canEncrypt: capabilities.contains("e") || capabilities.contains("E")
                )
                currentUserId = nil
                currentEmail = nil

            case "fpr":
                if fields.count >= 10, currentKey != nil {
                    currentKey?.fingerprint = fields[9]
                }

            case "uid":
                if fields.count >= 10, currentUserId == nil {
                    let uid = fields[9]
                    currentUserId = uid

                    // Extract email from uid (format: "Name <email>")
                    if let emailStart = uid.firstIndex(of: "<"),
                       let emailEnd = uid.firstIndex(of: ">") {
                        currentEmail = String(uid[uid.index(after: emailStart)..<emailEnd])
                    }
                }

            default:
                break
            }
        }

        // Don't forget the last key
        if let key = currentKey {
            let gpgKey = GPGKey(
                id: key.keyId,
                keyId: key.keyId,
                fingerprint: key.fingerprint,
                userId: currentUserId ?? "",
                email: currentEmail,
                createdDate: key.created,
                expirationDate: key.expires,
                isExpired: key.expires.map { $0 < Date() } ?? false,
                isRevoked: key.trust == "r",
                canSign: key.canSign,
                canEncrypt: key.canEncrypt,
                trustLevel: parseTrustLevel(key.trust)
            )
            keys.append(gpgKey)
        }

        return keys
    }

    private func parseTimestamp(_ timestamp: String) -> Date? {
        guard let seconds = TimeInterval(timestamp) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private func parseTrustLevel(_ trust: String) -> GPGKey.TrustLevel {
        switch trust {
        case "o", "-", "q": return .unknown
        case "n": return .never
        case "m": return .marginal
        case "f": return .full
        case "u": return .ultimate
        default: return .unknown
        }
    }

    private func parseVerificationOutput(_ output: String, exitCode: Int32) -> SignatureVerification {
        // Parse GPG status output
        var status: SignatureVerification.VerificationStatus = .unknown
        var signerName: String?
        var keyId: String?

        for line in output.components(separatedBy: .newlines) {
            if line.contains("GOODSIG") {
                status = .good
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    keyId = parts[2]
                    signerName = parts[3...].joined(separator: " ")
                }
            } else if line.contains("BADSIG") {
                status = .bad
            } else if line.contains("EXPSIG") {
                status = .expired
            } else if line.contains("REVKEYSIG") {
                status = .revoked
            } else if line.contains("ERRSIG") {
                status = .cannotVerify
            } else if line.contains("NO_PUBKEY") {
                status = .cannotVerify
            }
        }

        if exitCode != 0 && status == .unknown {
            status = output.isEmpty ? .noSignature : .cannotVerify
        }

        return SignatureVerification(
            isVerified: status == .good,
            signerName: signerName,
            signerEmail: nil,
            keyId: keyId,
            status: status,
            message: nil
        )
    }

    private func parseLogSignatureOutput(_ output: String) -> SignatureVerification {
        let parts = output.components(separatedBy: "|")
        guard parts.count >= 4 else {
            return SignatureVerification(
                isVerified: false,
                signerName: nil,
                signerEmail: nil,
                keyId: nil,
                status: .noSignature,
                message: nil
            )
        }

        let statusChar = parts[0]
        let signerName = parts[1].isEmpty ? nil : parts[1]
        let keyId = parts[2].isEmpty ? nil : parts[2]
        let message = parts[3].isEmpty ? nil : parts[3]

        let status: SignatureVerification.VerificationStatus
        switch statusChar {
        case "G": status = .good
        case "B": status = .bad
        case "U": status = .unknown
        case "X": status = .expired
        case "Y": status = .expired
        case "R": status = .revoked
        case "E": status = .cannotVerify
        case "N": status = .noSignature
        default: status = .noSignature
        }

        return SignatureVerification(
            isVerified: status == .good,
            signerName: signerName,
            signerEmail: nil,
            keyId: keyId,
            status: status,
            message: message
        )
    }
}
