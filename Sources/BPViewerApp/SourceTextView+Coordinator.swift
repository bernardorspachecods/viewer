import AppKit
import BPViewerCore

extension SourceTextView {
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var onSourceChanged: @MainActor @Sendable (String) -> Void
        var onEndEditing: @MainActor @Sendable (String) -> Void
        var onFindMatchCount: @MainActor @Sendable (Int) -> Void
        var appliedCursorUTF8Offset: Int?
        var appliedCursorRequestID = 0
        var didRequestInitialFocus = false
        var appliedZoom: Double?
        var appliedMonospaced: Bool?
        var appliedLineSpacingBefore: [Int: CGFloat] = [:]
        var appliedBaseColors: SourceSyntaxHighlighting?
        var hasAppliedBaseColors = false
        var syntaxHighlightingGate = SourceSyntaxHighlightingGate()
        let defersSourceChangeUpdates: Bool
        var requiresTypographyRefresh = true
        var requiresSyntaxRefresh = true
        var requiresInitialSyntaxRefresh = true
        var lastModelSource: String?
        var syntaxHighlightTask: Task<Void, Never>?
        private var sourceChangeTask: Task<Void, Never>?
        var inlineCompletionTask: Task<Void, Never>?
        var inlineCompletionGeneration = 0
        private var pendingSource: String?
        var syntaxHighlightGeneration = 0
        var findSource = ""
        var findQuery = ""
        var findRequestID = -1
        var findMatches: [TextSearchMatch] = []
        var currentFindIndex: Int?
        var hasFindHighlights = false

        init(
            onSourceChanged: @escaping @MainActor @Sendable (String) -> Void,
            onEndEditing: @escaping @MainActor @Sendable (String) -> Void,
            onFindMatchCount: @escaping @MainActor @Sendable (Int) -> Void,
            defersSourceChangeUpdates: Bool
        ) {
            self.onSourceChanged = onSourceChanged
            self.onEndEditing = onEndEditing
            self.onFindMatchCount = onFindMatchCount
            self.defersSourceChangeUpdates = defersSourceChangeUpdates
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            requiresSyntaxRefresh = true
            if let markdownTextView = textView as? MarkdownNSTextView {
                scheduleInlineCompletion(for: markdownTextView)
            }
            let source = textView.string
            guard defersSourceChangeUpdates else {
                onSourceChanged(source)
                return
            }

            // NSTextView already owns the live draft. Coalesce model updates so
            // each keystroke can return to AppKit without synchronously
            // rebuilding the observed SwiftUI workspace.
            pendingSource = source
            sourceChangeTask?.cancel()
            sourceChangeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                self?.flushPendingSourceChange()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? MarkdownNSTextView else { return }
            if let completion = textView.inlineCompletion,
               completion.wordRange.location + completion.wordRange.length
                != textView.selectedRange().location {
                cancelInlineCompletion(for: textView)
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            flushPendingSourceChange()
        }

        func flushPendingSourceChange() {
            guard let pendingSource else { return }
            self.pendingSource = nil
            sourceChangeTask?.cancel()
            sourceChangeTask = nil
            onSourceChanged(pendingSource)
        }
    }
}
