import SwiftUI

// MARK: - Conditional View Modifiers

extension View {
    /// Applies a transformation to a view if a condition is true.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transformation to apply if the condition is true.
    /// - Returns: The transformed view if the condition is true, otherwise the original view.
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a transformation to a view if a value is non-nil.
    /// - Parameters:
    ///   - value: The optional value to check.
    ///   - transform: The transformation to apply if the value is non-nil.
    /// - Returns: The transformed view if the value is non-nil, otherwise the original view.
    @ViewBuilder
    func applyIfLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

