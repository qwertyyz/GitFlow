import SwiftUI

/// Settings view for syntax highlighting themes and customization.
struct SyntaxHighlightingSettingsView: View {
    @StateObject private var viewModel = SyntaxHighlightingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Syntax Highlighting")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            HSplitView {
                // Theme list
                themeListSection
                    .frame(minWidth: 200, maxWidth: 250)

                // Preview
                previewSection
            }
        }
    }

    @ViewBuilder
    private var themeListSection: some View {
        VStack(spacing: 0) {
            // Theme category picker
            Picker("", selection: $viewModel.selectedCategory) {
                Text("All").tag(ThemeCategory?.none)
                ForEach(ThemeCategory.allCases) { category in
                    Text(category.rawValue).tag(category as ThemeCategory?)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Theme list
            List(viewModel.filteredThemes, selection: $viewModel.selectedThemeId) { theme in
                ThemeRow(theme: theme, isSelected: theme.id == viewModel.selectedThemeId)
            }
            .listStyle(.plain)

            Divider()

            // Actions
            HStack {
                Button(action: { viewModel.importTheme() }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Import theme")

                Button(action: { viewModel.exportTheme() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export theme")
                .disabled(viewModel.selectedTheme == nil)

                Spacer()

                Button("Apply") {
                    viewModel.applySelectedTheme()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedTheme == nil)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Language", selection: $viewModel.previewLanguage) {
                    ForEach(PreviewLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .frame(width: 120)
            }
            .padding()

            Divider()

            // Code preview
            if let theme = viewModel.selectedTheme {
                ScrollView {
                    CodePreviewView(theme: theme, language: viewModel.previewLanguage)
                        .padding()
                }
            } else {
                VStack {
                    Text("Select a theme to preview")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Theme Row

struct ThemeRow: View {
    let theme: SyntaxTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Color preview
            HStack(spacing: 2) {
                Rectangle().fill(Color(hex: theme.colors.background) ?? .black)
                Rectangle().fill(Color(hex: theme.colors.keyword) ?? .purple)
                Rectangle().fill(Color(hex: theme.colors.string) ?? .green)
                Rectangle().fill(Color(hex: theme.colors.comment) ?? .gray)
            }
            .frame(width: 48, height: 24)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(.body)

                Text(theme.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if theme.isBuiltIn {
                Text("Built-in")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Code Preview View

struct CodePreviewView: View {
    let theme: SyntaxTheme
    let language: PreviewLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(previewLines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 12) {
                    // Line number
                    Text("\(index + 1)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color(hex: theme.colors.lineNumber) ?? .secondary)
                        .frame(width: 30, alignment: .trailing)

                    // Code line
                    Text(attributedString(for: line))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color(hex: theme.colors.background) ?? .black)
        .cornerRadius(8)
    }

    private var previewLines: [String] {
        language.sampleCode.components(separatedBy: "\n")
    }

    private func attributedString(for line: String) -> AttributedString {
        var result = AttributedString(line)
        result.foregroundColor = Color(hex: theme.colors.text) ?? .primary

        // Simple syntax highlighting (in a real app, use a proper lexer)
        highlightPattern(in: &result, pattern: "//.*", color: theme.colors.comment)
        highlightPattern(in: &result, pattern: "\"[^\"]*\"", color: theme.colors.string)
        highlightPattern(in: &result, pattern: "'[^']*'", color: theme.colors.string)
        highlightKeywords(in: &result)
        highlightPattern(in: &result, pattern: "\\b\\d+\\b", color: theme.colors.number)

        return result
    }

    private func highlightPattern(in string: inout AttributedString, pattern: String, color: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let swiftString = String(string.characters[...]) as NSString? else { return }

        let matches = regex.matches(in: String(swiftString), range: NSRange(location: 0, length: swiftString.length))

        for match in matches.reversed() {
            if let range = Range(match.range, in: string) {
                string[range].foregroundColor = Color(hex: color)
            }
        }
    }

    private func highlightKeywords(in string: inout AttributedString) {
        let keywords = language.keywords
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            highlightPattern(in: &string, pattern: pattern, color: theme.colors.keyword)
        }
    }
}

// MARK: - Data Models

enum ThemeCategory: String, CaseIterable, Identifiable, Codable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

struct SyntaxTheme: Identifiable, Codable {
    let id: String
    let name: String
    let category: ThemeCategory
    let isBuiltIn: Bool
    let colors: ThemeColors

    struct ThemeColors: Codable {
        let background: String
        let text: String
        let keyword: String
        let string: String
        let comment: String
        let number: String
        let function: String
        let type: String
        let variable: String
        let lineNumber: String
        let selection: String
        let cursor: String
        let added: String
        let removed: String
        let modified: String
    }
}

enum PreviewLanguage: String, CaseIterable, Identifiable {
    case swift = "Swift"
    case javascript = "JavaScript"
    case python = "Python"

    var id: String { rawValue }

    var keywords: [String] {
        switch self {
        case .swift:
            return ["func", "let", "var", "if", "else", "for", "while", "return", "import", "struct", "class", "enum", "protocol", "extension", "guard", "switch", "case", "default", "break", "continue", "public", "private", "internal", "static", "final", "override", "init", "deinit", "self", "super", "nil", "true", "false", "async", "await", "throws", "try", "catch"]
        case .javascript:
            return ["function", "const", "let", "var", "if", "else", "for", "while", "return", "import", "export", "class", "extends", "new", "this", "async", "await", "try", "catch", "throw", "true", "false", "null", "undefined"]
        case .python:
            return ["def", "class", "if", "else", "elif", "for", "while", "return", "import", "from", "as", "try", "except", "finally", "with", "pass", "break", "continue", "True", "False", "None", "and", "or", "not", "in", "is", "lambda", "yield", "async", "await"]
        }
    }

    var sampleCode: String {
        switch self {
        case .swift:
            return """
            import Foundation

            /// A simple greeting function
            func greet(name: String) -> String {
                let greeting = "Hello, \\(name)!"
                return greeting
            }

            // Main execution
            let message = greet(name: "World")
            print(message)  // Output: Hello, World!
            """
        case .javascript:
            return """
            import { useState } from 'react';

            // A simple counter component
            function Counter() {
                const [count, setCount] = useState(0);

                return (
                    <button onClick={() => setCount(count + 1)}>
                        Count: {count}
                    </button>
                );
            }

            export default Counter;
            """
        case .python:
            return """
            from typing import List

            def quicksort(arr: List[int]) -> List[int]:
                \"\"\"Sort array using quicksort algorithm.\"\"\"
                if len(arr) <= 1:
                    return arr

                pivot = arr[len(arr) // 2]
                left = [x for x in arr if x < pivot]
                middle = [x for x in arr if x == pivot]
                right = [x for x in arr if x > pivot]

                return quicksort(left) + middle + quicksort(right)

            # Example usage
            numbers = [3, 6, 8, 10, 1, 2, 1]
            print(quicksort(numbers))  # [1, 1, 2, 3, 6, 8, 10]
            """
        }
    }
}

// MARK: - View Model

@MainActor
class SyntaxHighlightingViewModel: ObservableObject {
    @Published var themes: [SyntaxTheme] = []
    @Published var selectedThemeId: String?
    @Published var selectedCategory: ThemeCategory?
    @Published var previewLanguage: PreviewLanguage = .swift

    private let currentThemeKey = "currentSyntaxTheme"

    init() {
        loadThemes()
        selectedThemeId = UserDefaults.standard.string(forKey: currentThemeKey) ?? themes.first?.id
    }

    var selectedTheme: SyntaxTheme? {
        themes.first { $0.id == selectedThemeId }
    }

    var filteredThemes: [SyntaxTheme] {
        if let category = selectedCategory {
            return themes.filter { $0.category == category }
        }
        return themes
    }

    func applySelectedTheme() {
        if let id = selectedThemeId {
            UserDefaults.standard.set(id, forKey: currentThemeKey)
            NotificationCenter.default.post(name: .syntaxThemeChanged, object: nil)
        }
    }

    func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let theme = try JSONDecoder().decode(SyntaxTheme.self, from: data)
                themes.append(theme)
                saveCustomThemes()
            } catch {
                print("Failed to import theme: \(error)")
            }
        }
    }

    func exportTheme() {
        guard let theme = selectedTheme else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(theme.name).json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try JSONEncoder().encode(theme)
                try data.write(to: url)
            } catch {
                print("Failed to export theme: \(error)")
            }
        }
    }

    private func loadThemes() {
        // Built-in themes
        themes = [
            // Light themes
            SyntaxTheme(
                id: "github-light",
                name: "GitHub Light",
                category: .light,
                isBuiltIn: true,
                colors: SyntaxTheme.ThemeColors(
                    background: "#ffffff",
                    text: "#24292f",
                    keyword: "#cf222e",
                    string: "#0a3069",
                    comment: "#6e7781",
                    number: "#0550ae",
                    function: "#8250df",
                    type: "#953800",
                    variable: "#24292f",
                    lineNumber: "#8c959f",
                    selection: "#b6e3ff",
                    cursor: "#24292f",
                    added: "#d4f8db",
                    removed: "#ffcecb",
                    modified: "#fff8c5"
                )
            ),
            SyntaxTheme(
                id: "xcode-light",
                name: "Xcode Light",
                category: .light,
                isBuiltIn: true,
                colors: SyntaxTheme.ThemeColors(
                    background: "#ffffff",
                    text: "#000000",
                    keyword: "#9b2393",
                    string: "#c41a16",
                    comment: "#5d6c79",
                    number: "#1c00cf",
                    function: "#326d74",
                    type: "#3900a0",
                    variable: "#000000",
                    lineNumber: "#8e8e93",
                    selection: "#b4d8fd",
                    cursor: "#000000",
                    added: "#dcf8c6",
                    removed: "#ffc6c6",
                    modified: "#fff5b1"
                )
            ),
            // Dark themes
            SyntaxTheme(
                id: "github-dark",
                name: "GitHub Dark",
                category: .dark,
                isBuiltIn: true,
                colors: SyntaxTheme.ThemeColors(
                    background: "#0d1117",
                    text: "#c9d1d9",
                    keyword: "#ff7b72",
                    string: "#a5d6ff",
                    comment: "#8b949e",
                    number: "#79c0ff",
                    function: "#d2a8ff",
                    type: "#ffa657",
                    variable: "#c9d1d9",
                    lineNumber: "#6e7681",
                    selection: "#264f78",
                    cursor: "#c9d1d9",
                    added: "#2ea04326",
                    removed: "#f8514926",
                    modified: "#d29922"
                )
            ),
            SyntaxTheme(
                id: "one-dark",
                name: "One Dark",
                category: .dark,
                isBuiltIn: true,
                colors: SyntaxTheme.ThemeColors(
                    background: "#282c34",
                    text: "#abb2bf",
                    keyword: "#c678dd",
                    string: "#98c379",
                    comment: "#5c6370",
                    number: "#d19a66",
                    function: "#61afef",
                    type: "#e5c07b",
                    variable: "#e06c75",
                    lineNumber: "#495162",
                    selection: "#3e4451",
                    cursor: "#528bff",
                    added: "#109868",
                    removed: "#e06c75",
                    modified: "#e5c07b"
                )
            ),
            SyntaxTheme(
                id: "monokai",
                name: "Monokai",
                category: .dark,
                isBuiltIn: true,
                colors: SyntaxTheme.ThemeColors(
                    background: "#272822",
                    text: "#f8f8f2",
                    keyword: "#f92672",
                    string: "#e6db74",
                    comment: "#75715e",
                    number: "#ae81ff",
                    function: "#a6e22e",
                    type: "#66d9ef",
                    variable: "#f8f8f2",
                    lineNumber: "#90908a",
                    selection: "#49483e",
                    cursor: "#f8f8f2",
                    added: "#a6e22e",
                    removed: "#f92672",
                    modified: "#e6db74"
                )
            ),
            SyntaxTheme(
                id: "dracula",
                name: "Dracula",
                category: .dark,
                isBuiltIn: true,
                colors: SyntaxTheme.ThemeColors(
                    background: "#282a36",
                    text: "#f8f8f2",
                    keyword: "#ff79c6",
                    string: "#f1fa8c",
                    comment: "#6272a4",
                    number: "#bd93f9",
                    function: "#50fa7b",
                    type: "#8be9fd",
                    variable: "#f8f8f2",
                    lineNumber: "#6272a4",
                    selection: "#44475a",
                    cursor: "#f8f8f2",
                    added: "#50fa7b",
                    removed: "#ff5555",
                    modified: "#ffb86c"
                )
            ),
        ]

        // Load custom themes
        loadCustomThemes()
    }

    private func loadCustomThemes() {
        if let data = UserDefaults.standard.data(forKey: "customSyntaxThemes"),
           let customThemes = try? JSONDecoder().decode([SyntaxTheme].self, from: data) {
            themes.append(contentsOf: customThemes)
        }
    }

    private func saveCustomThemes() {
        let customThemes = themes.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(data, forKey: "customSyntaxThemes")
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let syntaxThemeChanged = Notification.Name("syntaxThemeChanged")
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

#Preview {
    SyntaxHighlightingSettingsView()
        .frame(width: 700, height: 500)
}
