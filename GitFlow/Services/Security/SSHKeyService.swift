import Foundation

/// Service for managing SSH keys.
actor SSHKeyService {
    private let fileManager = FileManager.default

    /// The default SSH directory.
    var sshDirectory: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
    }

    // MARK: - Key Discovery

    /// Lists all SSH keys in the user's .ssh directory.
    func listKeys() async throws -> [SSHKey] {
        guard fileManager.fileExists(atPath: sshDirectory.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(
            at: sshDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey]
        )

        var keys: [SSHKey] = []

        // Find private keys (files without .pub extension that have a matching .pub file)
        for file in contents {
            let filename = file.lastPathComponent

            // Skip .pub files, config, known_hosts, etc.
            guard !filename.hasSuffix(".pub"),
                  !filename.starts(with: "."),
                  filename != "config",
                  filename != "known_hosts",
                  filename != "authorized_keys" else {
                continue
            }

            let publicKeyPath = file.appendingPathExtension("pub")
            guard fileManager.fileExists(atPath: publicKeyPath.path) else {
                continue
            }

            // Determine key type from public key content
            if let publicKeyContent = try? String(contentsOf: publicKeyPath, encoding: .utf8) {
                let keyType = determineKeyType(from: publicKeyContent)
                let fingerprint = await getKeyFingerprint(publicKeyPath.path)
                let comment = extractComment(from: publicKeyContent)
                let createdDate = try? fileManager.attributesOfItem(atPath: file.path)[.creationDate] as? Date

                let key = SSHKey(
                    id: filename,
                    name: filename,
                    publicKeyPath: publicKeyPath.path,
                    privateKeyPath: file.path,
                    type: keyType,
                    fingerprint: fingerprint,
                    comment: comment,
                    createdDate: createdDate
                )
                keys.append(key)
            }
        }

        return keys.sorted { $0.name < $1.name }
    }

    // MARK: - Key Generation

    /// Generates a new SSH key pair.
    /// - Parameters:
    ///   - name: The name for the key file.
    ///   - type: The key type (RSA, ED25519, etc.).
    ///   - comment: Optional comment (usually email).
    ///   - passphrase: Optional passphrase for the private key.
    /// - Returns: The generated SSH key.
    func generateKey(
        name: String,
        type: SSHKey.KeyType,
        comment: String?,
        passphrase: String?
    ) async throws -> SSHKey {
        let privateKeyPath = sshDirectory.appendingPathComponent(name).path
        let publicKeyPath = "\(privateKeyPath).pub"

        // Check if key already exists
        guard !fileManager.fileExists(atPath: privateKeyPath) else {
            throw SSHKeyError.keyAlreadyExists(name: name)
        }

        // Build ssh-keygen command
        var args = ["-t", type.keygen, "-f", privateKeyPath]

        if type == .rsa {
            args.append(contentsOf: ["-b", "4096"])
        }

        if let comment = comment, !comment.isEmpty {
            args.append(contentsOf: ["-C", comment])
        }

        // Passphrase (empty string for no passphrase)
        args.append(contentsOf: ["-N", passphrase ?? ""])

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SSHKeyError.generationFailed(message: errorMessage)
        }

        // Get the key fingerprint
        let fingerprint = await getKeyFingerprint(publicKeyPath)

        return SSHKey(
            id: name,
            name: name,
            publicKeyPath: publicKeyPath,
            privateKeyPath: privateKeyPath,
            type: type,
            fingerprint: fingerprint,
            comment: comment,
            createdDate: Date()
        )
    }

    // MARK: - Key Import

    /// Imports an existing SSH key.
    /// - Parameters:
    ///   - privateKeyURL: URL to the private key file.
    ///   - name: Optional new name for the key.
    /// - Returns: The imported SSH key.
    func importKey(from privateKeyURL: URL, name: String? = nil) async throws -> SSHKey {
        let keyName = name ?? privateKeyURL.lastPathComponent
        let publicKeyURL = privateKeyURL.appendingPathExtension("pub")

        // Check if public key exists
        guard fileManager.fileExists(atPath: publicKeyURL.path) else {
            throw SSHKeyError.publicKeyNotFound
        }

        let destPrivatePath = sshDirectory.appendingPathComponent(keyName)
        let destPublicPath = destPrivatePath.appendingPathExtension("pub")

        // Check if key already exists
        guard !fileManager.fileExists(atPath: destPrivatePath.path) else {
            throw SSHKeyError.keyAlreadyExists(name: keyName)
        }

        // Copy files
        try fileManager.copyItem(at: privateKeyURL, to: destPrivatePath)
        try fileManager.copyItem(at: publicKeyURL, to: destPublicPath)

        // Set permissions
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destPrivatePath.path)
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destPublicPath.path)

        // Read key info
        let publicKeyContent = try String(contentsOf: destPublicPath, encoding: .utf8)
        let keyType = determineKeyType(from: publicKeyContent)
        let fingerprint = await getKeyFingerprint(destPublicPath.path)
        let comment = extractComment(from: publicKeyContent)

        return SSHKey(
            id: keyName,
            name: keyName,
            publicKeyPath: destPublicPath.path,
            privateKeyPath: destPrivatePath.path,
            type: keyType,
            fingerprint: fingerprint,
            comment: comment,
            createdDate: Date()
        )
    }

    // MARK: - Key Deletion

    /// Deletes an SSH key pair.
    func deleteKey(_ key: SSHKey) throws {
        try fileManager.removeItem(atPath: key.privateKeyPath)
        try fileManager.removeItem(atPath: key.publicKeyPath)
    }

    // MARK: - Helpers

    private func determineKeyType(from publicKey: String) -> SSHKey.KeyType {
        if publicKey.contains("ssh-rsa") {
            return .rsa
        } else if publicKey.contains("ssh-ed25519") {
            return .ed25519
        } else if publicKey.contains("ecdsa-sha2") {
            return .ecdsa
        } else if publicKey.contains("ssh-dss") {
            return .dsa
        }
        return .rsa
    }

    private func extractComment(from publicKey: String) -> String? {
        let parts = publicKey.split(separator: " ")
        guard parts.count >= 3 else { return nil }
        return String(parts[2...].joined(separator: " "))
    }

    private func getKeyFingerprint(_ publicKeyPath: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = ["-lf", publicKeyPath]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // Output format: 256 SHA256:xxxx comment (ED25519)
            let parts = output.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[1])
            }
        } catch {
            return nil
        }

        return nil
    }
}

// MARK: - Errors

enum SSHKeyError: LocalizedError {
    case keyAlreadyExists(name: String)
    case publicKeyNotFound
    case generationFailed(message: String)
    case importFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .keyAlreadyExists(let name):
            return "A key named '\(name)' already exists"
        case .publicKeyNotFound:
            return "Public key file not found. Make sure both private and public key files exist."
        case .generationFailed(let message):
            return "Failed to generate key: \(message)"
        case .importFailed(let message):
            return "Failed to import key: \(message)"
        }
    }
}
