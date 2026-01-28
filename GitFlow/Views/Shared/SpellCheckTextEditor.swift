import SwiftUI
import AppKit

/// A TextEditor wrapper that enables macOS spell checking.
struct SpellCheckTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Enable spell checking
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = false // Don't auto-correct, just highlight
        textView.isAutomaticTextReplacementEnabled = false

        // Configure appearance
        textView.font = font
        textView.textColor = .textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.isRichText = false
        textView.allowsUndo = true

        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        // Set delegate
        textView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update text only if different (avoid cursor jump)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Update placeholder
        context.coordinator.placeholder = placeholder
        context.coordinator.updatePlaceholder(textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var placeholder: String
        private var placeholderTextView: NSTextField?

        init(text: Binding<String>, placeholder: String) {
            self.text = text
            self.placeholder = placeholder
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            updatePlaceholder(textView)
        }

        func updatePlaceholder(_ textView: NSTextView) {
            // Remove existing placeholder if any
            placeholderTextView?.removeFromSuperview()

            if textView.string.isEmpty && !placeholder.isEmpty {
                let placeholderView = NSTextField(labelWithString: placeholder)
                placeholderView.font = textView.font
                placeholderView.textColor = NSColor.placeholderTextColor
                placeholderView.backgroundColor = .clear
                placeholderView.isBordered = false
                placeholderView.isEditable = false
                placeholderView.isSelectable = false
                placeholderView.frame = NSRect(
                    x: textView.textContainerInset.width + 5,
                    y: textView.textContainerInset.height,
                    width: textView.bounds.width - 10,
                    height: 20
                )
                textView.addSubview(placeholderView)
                placeholderTextView = placeholderView
            }
        }
    }
}

#Preview {
    VStack {
        SpellCheckTextEditor(
            text: .constant(""),
            placeholder: "Enter commit message..."
        )
        .frame(height: 100)
        .padding()
    }
    .frame(width: 400, height: 200)
}
