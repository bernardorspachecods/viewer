import ViewerCore
import SwiftUI

struct DocumentEditActionBar: View {
    let saveState: MarkdownSaveState
    let onDiscard: () -> Void
    let onSave: () -> Void

    var showsStatus: Bool {
        saveState != .saved
    }

    var showsDiscardChanges: Bool {
        saveState != .saved
    }

    var isSaveDisabled: Bool {
        saveState == .saved
    }

    var body: some View {
        HStack(spacing: BPTokens.Spacing.sm) {
            if showsStatus {
                Text(saveState.label)
                    .font(BPTokens.Typography.caption)
                    .foregroundStyle(saveState == .conflict ? BPTokens.Color.warning : BPTokens.Color.muted)
            }

            if showsDiscardChanges {
                Button("Discard Changes", role: .destructive, action: onDiscard)
                    .buttonStyle(QuietButtonStyle.text)
            }

            Button("Save", action: onSave)
                .buttonStyle(QuietButtonStyle.text)
                .disabled(isSaveDisabled)
        }
    }
}

struct DocumentEditModeButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BPTokens.Typography.caption)
        }
        .buttonStyle(QuietButtonStyle(
            isSelected: isActive,
            horizontalPadding: BPTokens.Spacing.sm,
            minimumHeight: BPTokens.Size.control
        ))
        .focusable(false)
        .accessibilityValue(isActive ? "Active" : "Inactive")
    }
}
