import SwiftUI

/// A borderless control whose foreground provides pointer feedback.
struct QuietButtonStyle: ButtonStyle {
    static let text = Self(horizontalPadding: BPTokens.Spacing.xs, minimumHeight: BPTokens.Size.control)

    var isSelected = false
    var restingOpacity = 1.0
    var horizontalPadding: CGFloat = 0
    var minimumHeight: CGFloat? = nil
    var symbolSize: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minimumHeight)
            .modifier(QuietControlFeedback(
                isPressed: configuration.isPressed,
                isSelected: isSelected,
                isDestructive: configuration.role == .destructive,
                restingOpacity: restingOpacity,
                symbolSize: symbolSize
            ))
    }
}

/// Menu labels need the same feedback without taking over the native menu.
struct QuietControlFeedback: ViewModifier {
    @Environment(\.font) private var inheritedFont
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var isPressed = false
    var isSelected = false
    var isDestructive = false
    var restingOpacity = 1.0
    var symbolSize: CGFloat? = nil

    private var hasPointerEmphasis: Bool {
        isEnabled && (isHovered || isPressed)
    }

    private var foreground: Color {
        if isDestructive {
            return BPTokens.Color.danger.opacity(hasPointerEmphasis ? 1 : 0.85)
        }
        return hasPointerEmphasis || isSelected ? .primary : BPTokens.Color.muted
    }

    func body(content: Content) -> some View {
        content
            .font(symbolSize.map { .system(size: $0) } ?? inheritedFont)
            .foregroundStyle(foreground)
            .opacity(isEnabled ? (hasPointerEmphasis ? 1 : restingOpacity) : 0.55)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}
