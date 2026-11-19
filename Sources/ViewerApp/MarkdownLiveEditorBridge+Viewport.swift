import AppKit
import ViewerCore

/// What the editor bridge remembers about the scroll position: the position to restore when the
/// editor appears, and the debounced reporting of where it is scrolled.
@MainActor
final class MarkdownLiveEditorViewportState {
    var source = ""
    var zoom = 1.0
    var entryHandled = false
    var entry: MarkdownReadingPosition?
    var blockStartsSource: String?
    var blockStarts: [Int] = []
    var blockKinds: [Int: MarkdownBlockKind] = [:]
    var paragraphStarts: [Int] = []
    var scrollObserver: NSObjectProtocol?
    var reportTask: DispatchWorkItem?
    /// Where the last restore left the scroll view; a different position means the user scrolled.
    var restoredY: CGFloat?
}

extension MarkdownLiveEditorBridge.Coordinator {
    /// Called on every SwiftUI update: remembers the source and zoom, and starts restoring the
    /// entry position the first time the editor is shown.
    func updateViewport(source: String, zoom: Double, entryPosition: MarkdownReadingPosition?) {
        let previousSource = viewport.source
        viewport.source = source
        viewport.zoom = zoom
        if !viewport.entryHandled {
            if let entryPosition, entryPosition.sourceOffset != nil {
                viewport.entry = entryPosition
                applyEntryPosition(attempt: 0)
            }
            viewport.entryHandled = true
        } else if source != previousSource {
            scheduleViewportReport()
        }
    }

    // MARK: Restoring

    private func applyEntryPosition(attempt: Int) {
        let delay = attempt == 0 ? 0.02 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let entry = self.viewport.entry else { return }
            guard let textView = self.locateTextView(),
                  textView.window != nil,
                  textView.string == self.viewport.source,
                  textView.enclosingScrollView != nil else {
                if attempt < 40 {
                    self.applyEntryPosition(attempt: attempt + 1)
                } else {
                    self.onEntryApplied()
                }
                return
            }
            self.observeScrolling(of: textView)
            self.restoreEntryPosition(entry, in: textView)
            self.refreshBlocks()
            if let caret = MarkdownLiveEditorViewport.entryCaretOffset(
                in: textView,
                source: self.viewport.source,
                paragraphStarts: self.viewport.paragraphStarts,
                from: entry.sourceOffset ?? 0
            ) {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: caret, length: 0))
            }
            self.restoreEntryPosition(entry, in: textView)
            self.onEntryApplied()
            // Tables and formulas settle their height a moment after the text appears; keep the
            // same block at the same height until the user scrolls.
            for pass in [0.15, 0.4, 0.9] {
                DispatchQueue.main.asyncAfter(deadline: .now() + pass) { [weak self, weak textView] in
                    guard let self, let textView, let entry = self.viewport.entry else { return }
                    let current = textView.enclosingScrollView?.contentView.bounds.origin.y
                    guard let restored = self.viewport.restoredY, let current, abs(current - restored) < 1 else {
                        self.viewport.entry = nil
                        return
                    }
                    self.restoreEntryPosition(entry, in: textView)
                }
            }
        }
    }

    /// The block structure of the current source, built when the source changes.
    private func refreshBlocks() {
        guard viewport.blockStartsSource != viewport.source else { return }
        let blocks = MarkdownBlockDocument(source: viewport.source).blocks
        viewport.blockStarts = blocks.map(\.sourceRange.startOffset).sorted()
        viewport.blockKinds = Dictionary(blocks.map { ($0.sourceRange.startOffset, $0.kind) }, uniquingKeysWith: { first, _ in first })
        viewport.paragraphStarts = blocks.filter { $0.kind == .paragraph }.map(\.sourceRange.startOffset).sorted()
        viewport.blockStartsSource = viewport.source
    }

    private func textDrop(forBlockAt offset: Int) -> CGFloat {
        refreshBlocks()
        return MarkdownLiveEditorStyle.textDrop(kind: viewport.blockKinds[offset], tokens: .shared, zoom: viewport.zoom)
    }

    private func restoreEntryPosition(_ entry: MarkdownReadingPosition, in textView: NSTextView) {
        MarkdownLiveEditorViewport.restore(
            entry,
            in: textView,
            source: viewport.source,
            zoom: viewport.zoom,
            textDrop: textDrop(forBlockAt:)
        )
        viewport.restoredY = textView.enclosingScrollView?.contentView.bounds.origin.y
    }

    // MARK: Reporting

    private func observeScrolling(of textView: NSTextView) {
        guard viewport.scrollObserver == nil, let clip = textView.enclosingScrollView?.contentView else { return }
        clip.postsBoundsChangedNotifications = true
        viewport.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clip,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleViewportReport() }
        }
    }

    func stopObservingScrolling() {
        if let observer = viewport.scrollObserver { NotificationCenter.default.removeObserver(observer) }
        viewport.scrollObserver = nil
        viewport.reportTask?.cancel()
    }

    private func scheduleViewportReport() {
        viewport.reportTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.reportViewport() }
        }
        viewport.reportTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: task)
    }

    private func reportViewport() {
        guard let textView = locateTextView(), textView.string == viewport.source else { return }
        refreshBlocks()
        guard let position = MarkdownLiveEditorViewport.position(
            in: textView,
            source: viewport.source,
            blockStarts: viewport.blockStarts,
            zoom: viewport.zoom,
            textDrop: textDrop(forBlockAt:)
        ) else { return }
        onViewportChanged(position)
    }
}
