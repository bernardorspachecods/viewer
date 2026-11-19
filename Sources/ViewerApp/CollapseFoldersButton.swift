import SwiftUI

/// A chevron button that collapses or expands a folder or the workspace root.
/// The symbol shows the direction of the press: up closes, down opens.
struct CollapseFoldersButton: View {
    let systemName: String
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 22, height: 22)
                .iconButtonHitArea()
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(helpText)
    }
}
