import ViewerCore
import SwiftUI

/// The way out of focus mode while the header is hidden. A small symbol in the
/// top-right corner of the content: faint until the pointer is over it, so the
/// document stays the focus. Esc does the same.
struct FocusExitButton: View {
    @EnvironmentObject private var model: AppModel
    @State private var isHovered = false

    var body: some View {
        Button {
            model.exitFocusMode()
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BPTokens.Color.muted)
                .frame(width: 28, height: 28)
                .background(BPTokens.Color.surface.opacity(isHovered ? 0.95 : 0.6), in: Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .opacity(isHovered ? 1 : 0.3)
        .onHover { isHovered = $0 }
        .help("\(AppShortcuts.exitFocusMode.title) (\(AppShortcuts.exitFocusMode.display))")
        .accessibilityLabel(AppShortcuts.exitFocusMode.title)
        .padding(BPTokens.Spacing.sm)
    }
}
