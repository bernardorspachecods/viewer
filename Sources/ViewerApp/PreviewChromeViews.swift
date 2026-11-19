import AppKit
import SwiftUI

struct PreviewFindBar: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: BPTokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BPTokens.Color.muted)

            TextField(
                "Find in Document",
                text: Binding(
                    get: { model.findQuery },
                    set: {
                        model.findQuery = $0
                        model.findBackwards = false
                        model.findMatchCount = nil
                    }
                )
            )
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onKeyPress(phases: .down) { keyPress in
                    guard keyPress.key == .return else { return .ignored }
                    if keyPress.modifiers.contains(.shift) {
                        model.findPrevious()
                    } else {
                        model.findNext()
                    }
                    return .handled
                }

            if let matchCount = model.findMatchCount,
               !model.findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(matchCount == 1 ? "1 encontrado" : "\(matchCount) encontrados")
                    .font(BPTokens.Typography.caption)
                    .foregroundStyle(BPTokens.Color.muted)
                    .fixedSize()
            }

            ToolbarIconButton(systemName: "chevron.up", help: "Previous Result") {
                model.findPrevious()
            }
            ToolbarIconButton(systemName: "chevron.down", help: "Next Result") {
                model.findNext()
            }
            ToolbarIconButton(systemName: "xmark", help: "Close Search") {
                model.hideFindBar()
            }
        }
        .padding(.horizontal, BPTokens.Spacing.md)
        .padding(.vertical, BPTokens.Spacing.xs)
        .background(BPTokens.Color.surface)
        .onAppear { isSearchFocused = true }
        .onExitCommand { model.hideFindBar() }
    }
}

struct PreviewErrorBanner: View {
    let message: String
    let showingStalePreview: Bool
    let title: String?
    let onRetry: (() -> Void)?
    @State private var didCopy = false

    init(
        message: String,
        showingStalePreview: Bool,
        title: String? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.message = message
        self.showingStalePreview = showingStalePreview
        self.title = title
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BPTokens.Spacing.xs) {
            HStack(alignment: .center, spacing: BPTokens.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(BPTokens.Color.warning)
                VStack(alignment: .leading, spacing: BPTokens.Spacing.xxs) {
                    Text(title ?? (showingStalePreview ? "Error — Showing Last Preview" : "Error Generating Preview"))
                        .font(BPTokens.Typography.caption.weight(.semibold))
                }
                Text(message)
                    .font(BPTokens.Typography.caption)
                    .foregroundStyle(BPTokens.Color.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                    didCopy = true
                } label: {
                    Image(systemName: didCopy ? "checkmark.circle" : "doc.on.doc")
                        .iconButtonHitArea()
                }
                .buttonStyle(.borderless)
                .help(didCopy ? "Copied" : "Copy Message")
                Spacer()
                if let onRetry {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, BPTokens.Spacing.md)
        .padding(.vertical, BPTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BPTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: BPTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BPTokens.Radius.md)
                .stroke(BPTokens.Color.warning.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
