import SwiftUI
import ViewerCore
import AppKit

private enum MarkdownOutlineLayout {
    static let animation = Animation.easeInOut(duration: 0.24)
}

struct MarkdownPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(TextWidthPreference.key) private var limitsTextWidth = TextWidthPreference.defaultLimitsTextWidth
    @EnvironmentObject private var model: AppModel
    let html: String
    let baseURL: URL
    let documentID: String
    let previewRevision: Date?
    let outline: [MarkdownOutlineEntry]
    let editingSession: MarkdownEditSession?
    let diffSession: DocumentDiffSession?
    let presentationMode: DocumentPresentationMode
    let onNavigate: (URL) -> Void
    let onMarkdownTextChanged: @MainActor @Sendable (String) -> Void
    let onToggleMarkdownEditor: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onToggleDiff: (DocumentDiffMode) -> Void
    let onEndMarkdownEditing: () -> Void
    let onDiscardMarkdownEditing: () -> Void
    let onDiscardGitChanges: @MainActor @Sendable () -> Void
    let onKeepLocalMarkdownEdit: () -> Void
    let onUseExternalMarkdownEdit: () -> Void
    let zoom: Double
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let findTarget: FindTarget
    let onFindTargetChanged: (FindTarget) -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let anchorRequest: MarkdownAnchorRequest?
    let onAnchorRequestApplied: (UUID) -> Void
    @Binding var isOutlineVisible: Bool
    let outlineWidth: Double
    let onOutlineWidthChanged: (Double) -> Void
    let onOutlineWidthChangeEnded: () -> Void
    let readingPosition: MarkdownReadingPosition?
    let onReadingPositionChanged: (MarkdownReadingPosition) -> Void
    let isSnapshotCaptureActive: Bool
    let onSnapshotCancel: () -> Void
    let onSnapshotCapture: (NSImage) -> Void
    @State private var selectedHeadingID: String?
    @State private var outlineRequestID = 0
    @State private var pendingCursorUTF8Offset: Int?

    private var outlineItems: [DocumentOutlineItem] {
        outline.map {
            DocumentOutlineItem(
                id: $0.id,
                title: $0.title,
                level: max($0.level - 1, 0),
                isSelectable: true
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // The toolbar is the only way into editing, so reader windows show it too.
            // Focus mode hides it (`DocumentInteractionToolbar` checks `isFocusMode`).
            DocumentInteractionToolbar(
                isOutlineAvailable: !outlineItems.isEmpty,
                isOutlineVisible: isOutlineVisible,
                onToggleOutline: { isOutlineVisible.toggle() },
                editingSession: editingSession,
                presentationMode: presentationMode,
                diffSession: diffSession,
                onToggleDiff: onToggleDiff,
                onToggleMarkdownEditor: diffSession != nil
                    ? nil
                    : onToggleMarkdownEditor,
                isMarkdownEditorActive: isMarkdownEditorActive,
                onUndo: onUndo,
                onRedo: onRedo,
                onDiscardEditing: onDiscardMarkdownEditing,
                onSave: onEndMarkdownEditing
            )

            if let editingSession, let conflict = editingSession.conflict {
                MarkdownConflictView(
                    conflict: conflict,
                    onKeepLocal: onKeepLocalMarkdownEdit,
                    onUseExternal: onUseExternalMarkdownEdit
                )
            }

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    outlineSurface(paneWidth: model.isSplit ? Double(proxy.size.width) : nil)
                    documentSurface
                }
                .animation(MarkdownOutlineLayout.animation, value: isOutlineVisible)
            }
        }
        .id(documentID)
        .onChange(of: editingSession?.caretRequest) { _, request in
            // Undo and redo replace the whole draft; keep the caret where the change was.
            guard let request else { return }
            pendingCursorUTF8Offset = request.utf8Offset
            outlineRequestID += 1
        }
        .onExitCommand(perform: exitEditing)
    }

    private var isMarkdownEditorActive: Bool {
        editingSession != nil
    }

    private var exitEditing: () -> Void {
        if let diffSession {
            return { onToggleDiff(diffSession.mode) }
        }
        return onEndMarkdownEditing
    }

    private func outlineSurface(paneWidth: Double?) -> some View {
        ResizableDocumentOutlineView(
            isVisible: isOutlineVisible,
            width: outlineWidth,
            entries: outlineItems,
            selectedID: selectedHeadingID,
            onSelect: { item in
                selectedHeadingID = item.id
                outlineRequestID += 1
                if editingSession != nil {
                    pendingCursorUTF8Offset = outline.first {
                        $0.id == item.id
                    }?.sourceUTF8Offset
                }
            },
            onChanged: onOutlineWidthChanged,
            onEnded: { _ in onOutlineWidthChangeEnded() },
            paneWidth: paneWidth
        )
    }

    // The preview is the reading surface; editing replaces it with the Markdown editor.
    // Diffs keep their own raw editor (`DocumentDiffView`).
    @ViewBuilder
    private var documentSurface: some View {
        if let editingSession, let diffSession {
            DocumentDiffView(
                baseline: diffSession.baseline,
                unavailableMessage: diffSession.unavailableMessage,
                editedSource: editingSession.currentSource,
                cursorUTF8Offset: pendingCursorUTF8Offset,
                cursorRequestID: outlineRequestID,
                zoom: zoom,
                syntaxHighlighting: .markdown(
                    MarkdownSyntaxColorPalette(isDark: colorScheme == .dark)
                ),
                monospaced: false,
                markdownShortcutsEnabled: true,
                findQuery: findQuery,
                findRequestID: findRequestID,
                findBackwards: findBackwards,
                isFindTarget: findTarget == .source,
                onFindFocus: { onFindTargetChanged(.source) },
                onFindMatchCount: onFindMatchCount,
                onSourceChanged: onMarkdownTextChanged,
                onEndEditing: { text in
                    onMarkdownTextChanged(text)
                    exitEditing()
                },
                onDiscardGitChanges: onDiscardGitChanges
            )
        } else if let editingSession {
            markdownEditor(editingSession: editingSession)
        } else {
            previewSurface
        }
    }

    private func markdownEditor(editingSession: MarkdownEditSession) -> some View {
        MarkdownLiveEditor(
            source: editingSession.currentSource,
            documentID: documentID,
            zoom: zoom,
            limitsTextWidth: limitsTextWidth,
            cursorUTF8Offset: pendingCursorUTF8Offset,
            cursorRequestID: outlineRequestID,
            findQuery: findQuery,
            findRequestID: findRequestID,
            findBackwards: findBackwards,
            isFindTarget: findTarget == .source,
            onFindFocus: { onFindTargetChanged(.source) },
            onFindMatchCount: onFindMatchCount,
            onSourceChanged: onMarkdownTextChanged,
            onEndEditing: onEndMarkdownEditing,
            entryPosition: readingPosition,
            onViewportChanged: onReadingPositionChanged
        )
    }

    private var previewSurface: some View {
        ZStack {
            MarkdownWebView(
                html: html,
                baseURL: baseURL,
                documentID: documentID,
                previewRevision: previewRevision,
                onNavigate: onNavigate,
                limitsTextWidth: limitsTextWidth,
                zoom: zoom,
                findQuery: findQuery,
                findRequestID: findRequestID,
                findBackwards: findBackwards,
                isFindTarget: findTarget == .preview,
                onFindFocus: { onFindTargetChanged(.preview) },
                onFindMatchCount: onFindMatchCount,
                requestedHeadingID: selectedHeadingID,
                outlineRequestID: outlineRequestID,
                anchorRequest: anchorRequest,
                onAnchorRequestApplied: onAnchorRequestApplied,
                readingPosition: readingPosition,
                onReadingPositionChanged: onReadingPositionChanged
            )
            if isSnapshotCaptureActive {
                SnapshotSelectionOverlay(
                    onCancel: onSnapshotCancel,
                    onCapture: onSnapshotCapture
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct MarkdownConflictView: View {
    let conflict: MarkdownConflict
    let onKeepLocal: () -> Void
    let onUseExternal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BPTokens.Spacing.xs) {
            Text("This document was also changed outside Viewer.")
                .font(BPTokens.Typography.caption.weight(.medium))
            HStack(spacing: BPTokens.Spacing.sm) {
                conflictColumn(title: "My Changes", source: conflict.localSource)
                conflictColumn(title: "External Version", source: conflict.externalSource)
            }
            HStack {
                Spacer()
                Button("Use External Version", action: onUseExternal)
                    .buttonStyle(QuietButtonStyle.text)
                Button("Keep My Changes", action: onKeepLocal)
                    .buttonStyle(QuietButtonStyle.text)
            }
        }
        .padding(.horizontal, BPTokens.Spacing.md)
        .padding(.vertical, BPTokens.Spacing.sm)
        .background(BPTokens.Color.warning.opacity(0.1))
    }

    private func conflictColumn(title: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: BPTokens.Spacing.xxs) {
            Text(title)
                .font(BPTokens.Typography.caption.weight(.medium))
            ScrollView {
                Text(source)
                    .font(BPTokens.Typography.code)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BPTokens.Spacing.xs)
            }
            .frame(maxHeight: 100)
            .background(BPTokens.Color.elevated)
            .clipShape(RoundedRectangle(cornerRadius: BPTokens.Radius.sm))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
