import Foundation

/// Represents a Gitmoji - an emoji with semantic meaning for commits.
struct Gitmoji: Identifiable, Equatable, Hashable {
    let id: String
    let emoji: String
    let code: String
    let description: String
    let category: Category

    enum Category: String, CaseIterable {
        case improvement = "Improvement"
        case bugfix = "Bug Fix"
        case documentation = "Documentation"
        case testing = "Testing"
        case security = "Security"
        case dependencies = "Dependencies"
        case configuration = "Configuration"
        case release = "Release"
        case other = "Other"
    }

    /// Returns the formatted string for insertion into commit message.
    var formatted: String {
        emoji
    }
}

/// Provides access to the standard Gitmoji set.
enum GitmojiProvider {
    /// All standard Gitmojis organized by category.
    static let all: [Gitmoji] = [
        // Improvement
        Gitmoji(id: "sparkles", emoji: "✨", code: ":sparkles:", description: "Introduce new features", category: .improvement),
        Gitmoji(id: "art", emoji: "🎨", code: ":art:", description: "Improve structure/format of the code", category: .improvement),
        Gitmoji(id: "zap", emoji: "⚡️", code: ":zap:", description: "Improve performance", category: .improvement),
        Gitmoji(id: "lipstick", emoji: "💄", code: ":lipstick:", description: "Add or update the UI and style files", category: .improvement),
        Gitmoji(id: "recycle", emoji: "♻️", code: ":recycle:", description: "Refactor code", category: .improvement),
        Gitmoji(id: "truck", emoji: "🚚", code: ":truck:", description: "Move or rename resources", category: .improvement),
        Gitmoji(id: "building_construction", emoji: "🏗️", code: ":building_construction:", description: "Make architectural changes", category: .improvement),
        Gitmoji(id: "wheelchair", emoji: "♿️", code: ":wheelchair:", description: "Improve accessibility", category: .improvement),
        Gitmoji(id: "goal_net", emoji: "🥅", code: ":goal_net:", description: "Catch errors", category: .improvement),
        Gitmoji(id: "dizzy", emoji: "💫", code: ":dizzy:", description: "Add or update animations and transitions", category: .improvement),
        Gitmoji(id: "bento", emoji: "🍱", code: ":bento:", description: "Add or update assets", category: .improvement),
        Gitmoji(id: "iphone", emoji: "📱", code: ":iphone:", description: "Work on responsive design", category: .improvement),
        Gitmoji(id: "children_crossing", emoji: "🚸", code: ":children_crossing:", description: "Improve user experience/usability", category: .improvement),
        Gitmoji(id: "speech_balloon", emoji: "💬", code: ":speech_balloon:", description: "Add or update text and literals", category: .improvement),
        Gitmoji(id: "necktie", emoji: "👔", code: ":necktie:", description: "Add or update business logic", category: .improvement),
        Gitmoji(id: "stethoscope", emoji: "🩺", code: ":stethoscope:", description: "Add or update healthcheck", category: .improvement),
        Gitmoji(id: "thread", emoji: "🧵", code: ":thread:", description: "Add or update code related to multithreading", category: .improvement),

        // Bug Fix
        Gitmoji(id: "bug", emoji: "🐛", code: ":bug:", description: "Fix a bug", category: .bugfix),
        Gitmoji(id: "ambulance", emoji: "🚑️", code: ":ambulance:", description: "Critical hotfix", category: .bugfix),
        Gitmoji(id: "adhesive_bandage", emoji: "🩹", code: ":adhesive_bandage:", description: "Simple fix for a non-critical issue", category: .bugfix),
        Gitmoji(id: "pencil2", emoji: "✏️", code: ":pencil2:", description: "Fix typos", category: .bugfix),

        // Documentation
        Gitmoji(id: "memo", emoji: "📝", code: ":memo:", description: "Add or update documentation", category: .documentation),
        Gitmoji(id: "bulb", emoji: "💡", code: ":bulb:", description: "Add or update comments in source code", category: .documentation),
        Gitmoji(id: "page_facing_up", emoji: "📄", code: ":page_facing_up:", description: "Add or update license", category: .documentation),

        // Testing
        Gitmoji(id: "white_check_mark", emoji: "✅", code: ":white_check_mark:", description: "Add, update, or pass tests", category: .testing),
        Gitmoji(id: "test_tube", emoji: "🧪", code: ":test_tube:", description: "Add a failing test", category: .testing),
        Gitmoji(id: "camera_flash", emoji: "📸", code: ":camera_flash:", description: "Add or update snapshots", category: .testing),
        Gitmoji(id: "monocle_face", emoji: "🧐", code: ":monocle_face:", description: "Data exploration/inspection", category: .testing),

        // Security
        Gitmoji(id: "lock", emoji: "🔒️", code: ":lock:", description: "Fix security issues", category: .security),
        Gitmoji(id: "closed_lock_with_key", emoji: "🔐", code: ":closed_lock_with_key:", description: "Add or update secrets", category: .security),
        Gitmoji(id: "passport_control", emoji: "🛂", code: ":passport_control:", description: "Work on code related to authorization", category: .security),

        // Dependencies
        Gitmoji(id: "arrow_up", emoji: "⬆️", code: ":arrow_up:", description: "Upgrade dependencies", category: .dependencies),
        Gitmoji(id: "arrow_down", emoji: "⬇️", code: ":arrow_down:", description: "Downgrade dependencies", category: .dependencies),
        Gitmoji(id: "pushpin", emoji: "📌", code: ":pushpin:", description: "Pin dependencies to specific versions", category: .dependencies),
        Gitmoji(id: "heavy_plus_sign", emoji: "➕", code: ":heavy_plus_sign:", description: "Add a dependency", category: .dependencies),
        Gitmoji(id: "heavy_minus_sign", emoji: "➖", code: ":heavy_minus_sign:", description: "Remove a dependency", category: .dependencies),

        // Configuration
        Gitmoji(id: "wrench", emoji: "🔧", code: ":wrench:", description: "Add or update configuration files", category: .configuration),
        Gitmoji(id: "hammer", emoji: "🔨", code: ":hammer:", description: "Add or update development scripts", category: .configuration),
        Gitmoji(id: "construction_worker", emoji: "👷", code: ":construction_worker:", description: "Add or update CI build system", category: .configuration),
        Gitmoji(id: "green_heart", emoji: "💚", code: ":green_heart:", description: "Fix CI Build", category: .configuration),
        Gitmoji(id: "rocket", emoji: "🚀", code: ":rocket:", description: "Deploy stuff", category: .configuration),
        Gitmoji(id: "package", emoji: "📦️", code: ":package:", description: "Add or update compiled files or packages", category: .configuration),
        Gitmoji(id: "whale", emoji: "🐳", code: ":whale:", description: "Work on Docker", category: .configuration),
        Gitmoji(id: "see_no_evil", emoji: "🙈", code: ":see_no_evil:", description: "Add or update a .gitignore file", category: .configuration),

        // Release
        Gitmoji(id: "tada", emoji: "🎉", code: ":tada:", description: "Begin a project", category: .release),
        Gitmoji(id: "bookmark", emoji: "🔖", code: ":bookmark:", description: "Release / Version tags", category: .release),
        Gitmoji(id: "rewind", emoji: "⏪️", code: ":rewind:", description: "Revert changes", category: .release),
        Gitmoji(id: "twisted_rightwards_arrows", emoji: "🔀", code: ":twisted_rightwards_arrows:", description: "Merge branches", category: .release),

        // Other
        Gitmoji(id: "construction", emoji: "🚧", code: ":construction:", description: "Work in progress", category: .other),
        Gitmoji(id: "fire", emoji: "🔥", code: ":fire:", description: "Remove code or files", category: .other),
        Gitmoji(id: "poop", emoji: "💩", code: ":poop:", description: "Write bad code that needs to be improved", category: .other),
        Gitmoji(id: "coffin", emoji: "⚰️", code: ":coffin:", description: "Remove dead code", category: .other),
        Gitmoji(id: "wastebasket", emoji: "🗑️", code: ":wastebasket:", description: "Deprecate code that needs to be cleaned up", category: .other),
        Gitmoji(id: "beers", emoji: "🍻", code: ":beers:", description: "Write code drunkenly", category: .other),
        Gitmoji(id: "clown_face", emoji: "🤡", code: ":clown_face:", description: "Mock things", category: .other),
        Gitmoji(id: "egg", emoji: "🥚", code: ":egg:", description: "Add or update an easter egg", category: .other),
        Gitmoji(id: "alembic", emoji: "⚗️", code: ":alembic:", description: "Perform experiments", category: .other),
        Gitmoji(id: "mag", emoji: "🔍️", code: ":mag:", description: "Improve SEO", category: .other),
        Gitmoji(id: "label", emoji: "🏷️", code: ":label:", description: "Add or update types", category: .other),
        Gitmoji(id: "seedling", emoji: "🌱", code: ":seedling:", description: "Add or update seed files", category: .other),
        Gitmoji(id: "triangular_flag_on_post", emoji: "🚩", code: ":triangular_flag_on_post:", description: "Add, update, or remove feature flags", category: .other),
        Gitmoji(id: "loud_sound", emoji: "🔊", code: ":loud_sound:", description: "Add or update logs", category: .other),
        Gitmoji(id: "mute", emoji: "🔇", code: ":mute:", description: "Remove logs", category: .other),
        Gitmoji(id: "busts_in_silhouette", emoji: "👥", code: ":busts_in_silhouette:", description: "Add or update contributor(s)", category: .other),
        Gitmoji(id: "money_with_wings", emoji: "💸", code: ":money_with_wings:", description: "Add sponsorships or money related infrastructure", category: .other),
        Gitmoji(id: "globe_with_meridians", emoji: "🌐", code: ":globe_with_meridians:", description: "Internationalization and localization", category: .other),
        Gitmoji(id: "card_file_box", emoji: "🗃️", code: ":card_file_box:", description: "Perform database related changes", category: .other),
        Gitmoji(id: "technologist", emoji: "🧑‍💻", code: ":technologist:", description: "Improve developer experience", category: .other),
    ]

    /// Gitmojis grouped by category.
    static var byCategory: [Gitmoji.Category: [Gitmoji]] {
        Dictionary(grouping: all, by: { $0.category })
    }

    /// Searches Gitmojis by description or code.
    static func search(_ query: String) -> [Gitmoji] {
        guard !query.isEmpty else { return all }
        let lowercased = query.lowercased()
        return all.filter {
            $0.description.lowercased().contains(lowercased) ||
            $0.code.lowercased().contains(lowercased) ||
            $0.emoji.contains(lowercased)
        }
    }
}
