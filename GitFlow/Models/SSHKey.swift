import Foundation

/// Represents an SSH key.
struct SSHKey: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let publicKeyPath: String
    let privateKeyPath: String
    let type: KeyType
    let fingerprint: String?
    let comment: String?
    let createdDate: Date?

    enum KeyType: String, CaseIterable {
        case rsa = "RSA"
        case ed25519 = "ED25519"
        case ecdsa = "ECDSA"
        case dsa = "DSA"

        var defaultBits: Int {
            switch self {
            case .rsa: return 4096
            case .ed25519: return 256
            case .ecdsa: return 521
            case .dsa: return 1024
            }
        }

        var keygen: String {
            switch self {
            case .rsa: return "rsa"
            case .ed25519: return "ed25519"
            case .ecdsa: return "ecdsa"
            case .dsa: return "dsa"
            }
        }
    }

    /// The public key content.
    var publicKey: String? {
        try? String(contentsOfFile: publicKeyPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Short fingerprint for display.
    var shortFingerprint: String? {
        fingerprint?.prefix(16).description
    }
}

/// Represents a GPG key.
struct GPGKey: Identifiable, Equatable, Hashable {
    let id: String
    let keyId: String
    let fingerprint: String
    let userId: String
    let email: String?
    let createdDate: Date?
    let expirationDate: Date?
    let isExpired: Bool
    let isRevoked: Bool
    let canSign: Bool
    let canEncrypt: Bool
    let trustLevel: TrustLevel

    enum TrustLevel: String {
        case unknown = "Unknown"
        case never = "Never"
        case marginal = "Marginal"
        case full = "Full"
        case ultimate = "Ultimate"
    }

    /// Short key ID for display.
    var shortKeyId: String {
        String(keyId.suffix(8))
    }

    /// Whether the key is valid for signing.
    var isValidForSigning: Bool {
        canSign && !isExpired && !isRevoked
    }
}

/// Represents a commit signature verification result.
struct SignatureVerification: Equatable {
    let isVerified: Bool
    let signerName: String?
    let signerEmail: String?
    let keyId: String?
    let status: VerificationStatus
    let message: String?

    enum VerificationStatus: String {
        case good = "Good"
        case bad = "Bad"
        case unknown = "Unknown"
        case expired = "Expired"
        case revoked = "Revoked"
        case noSignature = "No Signature"
        case cannotVerify = "Cannot Verify"

        var icon: String {
            switch self {
            case .good: return "checkmark.seal.fill"
            case .bad: return "xmark.seal.fill"
            case .unknown: return "questionmark.circle"
            case .expired: return "clock.badge.exclamationmark"
            case .revoked: return "exclamationmark.triangle"
            case .noSignature: return "minus.circle"
            case .cannotVerify: return "questionmark.circle"
            }
        }

        var color: String {
            switch self {
            case .good: return "green"
            case .bad: return "red"
            case .unknown, .cannotVerify: return "gray"
            case .expired, .revoked: return "orange"
            case .noSignature: return "gray"
            }
        }
    }
}
