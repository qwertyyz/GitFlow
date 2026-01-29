import SwiftUI

/// A picker view for selecting Gitmojis to insert into commit messages.
struct GitmojiPickerView: View {
    @Binding var isPresented: Bool
    let onSelect: (Gitmoji) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: Gitmoji.Category?

    private var filteredGitmojis: [Gitmoji] {
        var result = GitmojiProvider.all

        // Filter by search text
        if !searchText.isEmpty {
            result = GitmojiProvider.search(searchText)
        }

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Gitmoji")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search gitmojis...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryButton(title: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(Gitmoji.Category.allCases, id: \.self) { category in
                        CategoryButton(
                            title: category.rawValue,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            Divider()

            // Gitmoji Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    ForEach(filteredGitmojis) { gitmoji in
                        GitmojiCell(gitmoji: gitmoji) {
                            onSelect(gitmoji)
                            isPresented = false
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 350, height: 400)
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gitmoji Cell

private struct GitmojiCell: View {
    let gitmoji: Gitmoji
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(gitmoji.emoji)
                    .font(.title)
            }
            .frame(width: 50, height: 50)
            .background(isHovering ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(gitmoji.description)
    }
}

// MARK: - Gitmoji Button (for integration)

/// A button that shows the gitmoji picker popover.
struct GitmojiButton: View {
    let onSelect: (Gitmoji) -> Void

    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            Text("😀")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .help("Insert Gitmoji")
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            GitmojiPickerView(isPresented: $showingPicker, onSelect: onSelect)
        }
    }
}

// MARK: - Preview

#Preview("Picker") {
    GitmojiPickerView(isPresented: .constant(true)) { gitmoji in
        print("Selected: \(gitmoji.emoji)")
    }
}

#Preview("Button") {
    GitmojiButton { gitmoji in
        print("Selected: \(gitmoji.emoji)")
    }
    .padding()
}
