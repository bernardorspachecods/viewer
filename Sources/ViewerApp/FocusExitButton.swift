import ViewerCore
import SwiftUI

/// The way out of focus mode while the header is hidden. A small symbol in the
/// top-right corner of the content: faint until the pointer is over it, so the
/// document stays the focus. Esc does the same.
struct FocusExitButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.exitFocusMode()
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .symbolRenderingMode(.monochrome)
                .frame(width: BPTokens.Size.control, height: BPTokens.Size.control)
        }
        .buttonStyle(QuietButtonStyle(restingOpacity: 0.3, symbolSize: BPTokens.Size.controlSymbol))
        .focusable(false)
        .help("\(AppShortcuts.exitFocusMode.title) (\(AppShortcuts.exitFocusMode.display))")
        .accessibilityLabel(AppShortcuts.exitFocusMode.title)
        .padding(BPTokens.Spacing.sm)
    }
}
