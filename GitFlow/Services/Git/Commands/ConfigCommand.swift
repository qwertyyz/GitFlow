import Foundation

/// Command to get a git config value.
struct GetConfigCommand: GitCommand {
    typealias Result = String?

    let key: String
    let scope: ConfigScope?

    init(key: String, scope: ConfigScope? = nil) {
        self.key = key
        self.scope = scope
    }

    var arguments: [String] {
        var args = ["config"]
        if let scope = scope {
            args.append(scope.flag)
        }
        args.append("--get")
        args.append(key)
        return args
    }

    func parse(output: String) throws -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Command to set a git config value.
struct SetConfigCommand: VoidGitCommand {
    let key: String
    let value: String
    let scope: ConfigScope

    var arguments: [String] {
        ["config", scope.flag, key, value]
    }
}

/// Command to unset a git config value.
struct UnsetConfigCommand: VoidGitCommand {
    let key: String
    let scope: ConfigScope

    var arguments: [String] {
        ["config", scope.flag, "--unset", key]
    }
}

/// Command to list all git config values.
struct ListConfigCommand: GitCommand {
    typealias Result = [GitConfigEntry]

    let scope: ConfigScope?
    let showOrigin: Bool

    init(scope: ConfigScope? = nil, showOrigin: Bool = true) {
        self.scope = scope
        self.showOrigin = showOrigin
    }

    var arguments: [String] {
        var args = ["config", "--list"]
        if let scope = scope {
            args.append(scope.flag)
        }
        if showOrigin {
            args.append("--show-origin")
        }
        return args
    }

    func parse(output: String) throws -> [GitConfigEntry] {
        var entries: [GitConfigEntry] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if showOrigin {
                // Format: file:/path/to/config<tab>key=value
                let parts = trimmed.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let originPart = String(parts[0])
                let keyValuePart = String(parts[1])

                let scope = parseScope(from: originPart)

                if let equalsIndex = keyValuePart.firstIndex(of: "=") {
                    let key = String(keyValuePart[..<equalsIndex])
                    let value = String(keyValuePart[keyValuePart.index(after: equalsIndex)...])

                    entries.append(GitConfigEntry(
                        key: key,
                        value: value,
                        scope: scope,
                        isDefault: false
                    ))
                }
            } else {
                // Format: key=value
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[..<equalsIndex])
                    let value = String(trimmed[trimmed.index(after: equalsIndex)...])

                    entries.append(GitConfigEntry(
                        key: key,
                        value: value,
                        scope: self.scope ?? .local,
                        isDefault: false
                    ))
                }
            }
        }

        return entries
    }

    private func parseScope(from origin: String) -> ConfigScope {
        if origin.contains(".git/config") {
            return .local
        } else if origin.contains(".gitconfig") || origin.contains("config.d/") {
            return .global
        } else if origin.contains("/etc/") {
            return .system
        } else {
            return .local
        }
    }
}

/// Command to get config entries for a specific section.
struct GetConfigSectionCommand: GitCommand {
    typealias Result = [GitConfigEntry]

    let section: String
    let scope: ConfigScope?

    init(section: String, scope: ConfigScope? = nil) {
        self.section = section
        self.scope = scope
    }

    var arguments: [String] {
        var args = ["config", "--list"]
        if let scope = scope {
            args.append(scope.flag)
        }
        args.append("--get-regexp")
        args.append("^\(section)\\.")
        return args
    }

    func parse(output: String) throws -> [GitConfigEntry] {
        var entries: [GitConfigEntry] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: key value (space separated)
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count >= 1 else { continue }

            let key = String(parts[0])
            let value = parts.count > 1 ? String(parts[1]) : ""

            entries.append(GitConfigEntry(
                key: key,
                value: value,
                scope: scope ?? .local,
                isDefault: false
            ))
        }

        return entries
    }
}

/// Command to add a value to a multi-valued key.
struct AddConfigCommand: VoidGitCommand {
    let key: String
    let value: String
    let scope: ConfigScope

    var arguments: [String] {
        ["config", scope.flag, "--add", key, value]
    }
}

/// Command to unset all values for a key.
struct UnsetAllConfigCommand: VoidGitCommand {
    let key: String
    let scope: ConfigScope

    var arguments: [String] {
        ["config", scope.flag, "--unset-all", key]
    }
}

/// Command to get all values for a multi-valued key.
struct GetAllConfigCommand: GitCommand {
    typealias Result = [String]

    let key: String
    let scope: ConfigScope?

    init(key: String, scope: ConfigScope? = nil) {
        self.key = key
        self.scope = scope
    }

    var arguments: [String] {
        var args = ["config"]
        if let scope = scope {
            args.append(scope.flag)
        }
        args.append("--get-all")
        args.append(key)
        return args
    }

    func parse(output: String) throws -> [String] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Command to edit config in editor.
struct EditConfigCommand: VoidGitCommand {
    let scope: ConfigScope

    var arguments: [String] {
        ["config", scope.flag, "--edit"]
    }
}

/// Command to check if a config value exists.
struct ConfigExistsCommand: GitCommand {
    typealias Result = Bool

    let key: String
    let scope: ConfigScope?

    init(key: String, scope: ConfigScope? = nil) {
        self.key = key
        self.scope = scope
    }

    var arguments: [String] {
        var args = ["config"]
        if let scope = scope {
            args.append(scope.flag)
        }
        args.append("--get")
        args.append(key)
        return args
    }

    func parse(output: String) throws -> Bool {
        !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
