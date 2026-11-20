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
    @EnvironmentObject private var model: AppModel
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    /// Two panes are too narrow for labels (they wrap), so a split keeps only the icons; the title
    /// stays as the accessibility label and the tooltip.
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(BPTokens.Typography.caption)
                .lineLimit(1)
                .labelStyle(DocumentEditModeLabelStyle(iconOnly: model.isSplit))
        }
        .help(title)
        .accessibilityLabel(title)
        .buttonStyle(QuietButtonStyle(
            isSelected: isActive,
            horizontalPadding: BPTokens.Spacing.sm,
            minimumHeight: BPTokens.Size.control
        ))
        .focusable(false)
        .accessibilityValue(isActive ? "Active" : "Inactive")
    }
}

/// Shows a mode button's icon and title, or only the icon (the title remains its accessibility label).
struct DocumentEditModeLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            Label(configuration)
        }
    }
}
