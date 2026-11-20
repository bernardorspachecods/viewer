import AppKit
import ViewerCore

/// Where the Markdown editor is scrolled, in the terms the preview uses: the block at the top of
/// the view (by where it starts in the source) and the height of its top edge below the top of
/// the view. Reporting and restoring it makes switching between preview and editor keep the same
/// text at the same height. `textDrop` says, for the block starting at an offset, how much lower
/// the editor draws its text than the preview does (see `MarkdownLiveEditorStyle.textDrop`).
@MainActor
enum MarkdownLiveEditorViewport {
    /// The block at the top of the view, or nil when the editor has not laid out text yet.
    static func position(
        in textView: NSTextView,
        source: String,
        blockStarts: [Int],
        zoom: Double,
        textDrop: (Int) -> CGFloat
    ) -> MarkdownReadingPosition? {
        guard let scrollView = textView.enclosingScrollView,
              textView.string == source,
              let topLine = lineStart(atVisibleTopOf: textView, scrollView: scrollView),
              let topOffset = sourceUTF8Offset(ofUTF16: topLine, in: source),
              let blockStart = blockStarts.last(where: { $0 <= topOffset }) ?? blockStarts.first,
              let blockUTF16 = utf16Offset(ofSourceUTF8: blockStart, in: source),
              let blockY = lineTop(ofUTF16: blockUTF16, in: textView, scrollView: scrollView) else { return nil }
        let visibleTop = scrollView.contentView.bounds.origin.y
        return MarkdownReadingPosition(
            scrollY: max(Double(visibleTop), 0) / zoom,
            anchorID: nil,
            anchorOffset: 0,
            sourceOffset: blockStart,
            blockTop: Double(blockY + textDrop(blockStart) - visibleTop) / zoom
        )
    }

    /// Scrolls so the block that starts at `position.sourceOffset` has its top edge
    /// `position.blockTop` below the top of the view. Returns false when the text is not laid out
    /// yet or the position has no block.
    @discardableResult
    static func restore(
        _ position: MarkdownReadingPosition,
        in textView: NSTextView,
        source: String,
        zoom: Double,
        textDrop: (Int) -> CGFloat
    ) -> Bool {
        guard let sourceOffset = position.sourceOffset,
              let scrollView = textView.enclosingScrollView,
              textView.string == source,
              let utf16 = utf16Offset(ofSourceUTF8: sourceOffset, in: source),
              let blockY = lineTop(ofUTF16: utf16, in: textView, scrollView: scrollView) else { return false }
        let clip = scrollView.contentView
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let maxScroll = max(documentHeight - clip.bounds.height, 0)
        let target = min(max(blockY + textDrop(sourceOffset) - CGFloat(position.blockTop * zoom), 0), maxScroll)
        guard abs(clip.bounds.origin.y - target) > 0.01 else { return true }
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: target))
        scrollView.reflectScrolledClipView(clip)
        return true
    }

    /// Where the caret goes when the editor opens: the start of the first paragraph that is on
    /// screen below the anchor. A paragraph shows no syntax when the caret is in it, so nothing
    /// on screen changes; a heading, table, formula or code block would open its source.
    static func entryCaretOffset(
        in textView: NSTextView,
        source: String,
        paragraphStarts: [Int],
        from anchor: Int
    ) -> Int? {
        guard let scrollView = textView.enclosingScrollView else { return nil }
        let clip = scrollView.contentView.bounds
        for start in paragraphStarts where start >= anchor {
            guard let utf16 = utf16Offset(ofSourceUTF8: start, in: source),
                  let top = lineTop(ofUTF16: utf16, in: textView, scrollView: scrollView) else { continue }
            if top > clip.maxY { return nil }
            if top >= clip.minY { return utf16 }
        }
        return nil
    }

    // MARK: Geometry

    /// The UTF-16 start of the paragraph at the top edge of the view.
    private static func lineStart(atVisibleTopOf textView: NSTextView, scrollView: NSScrollView) -> Int? {
        guard let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager else { return nil }
        let origin = textView.textContainerOrigin
        let top = textView.convert(
            NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y),
            from: scrollView.contentView
        ).y
        let point = CGPoint(x: origin.x + 1, y: max(top - origin.y, 0))
        guard let fragment = layoutManager.textLayoutFragment(for: point) else { return nil }
        return contentManager.offset(
            from: contentManager.documentRange.location,
            to: fragment.rangeInElement.location
        )
    }

    /// The top of the paragraph holding `offset`, in the scroll view's document coordinates.
    private static func lineTop(
        ofUTF16 offset: Int,
        in textView: NSTextView,
        scrollView: NSScrollView
    ) -> CGFloat? {
        guard let layoutManager = textView.textLayoutManager,
              let contentManager = layoutManager.textContentManager,
              let location = contentManager.location(contentManager.documentRange.location, offsetBy: offset) else {
            return nil
        }
        // Everything above the block must be laid out for its position to be real.
        if let range = NSTextRange(location: contentManager.documentRange.location, end: location) {
            layoutManager.ensureLayout(for: range)
        }
        guard let fragment = layoutManager.textLayoutFragment(for: location) else { return nil }
        let origin = textView.textContainerOrigin
        let frame = fragment.layoutFragmentFrame
        let inTextView = NSRect(x: frame.minX + origin.x, y: frame.minY + origin.y, width: frame.width, height: frame.height)
        return textView.convert(inTextView, to: scrollView.contentView).minY
    }

    private static func sourceUTF8Offset(ofUTF16 offset: Int, in source: String) -> Int? {
        let utf16 = source.utf16
        guard let index = utf16.index(utf16.startIndex, offsetBy: offset, limitedBy: utf16.endIndex),
              let stringIndex = index.samePosition(in: source) else { return nil }
        return source.utf8.distance(from: source.utf8.startIndex, to: stringIndex)
    }

    private static func utf16Offset(ofSourceUTF8 offset: Int, in source: String) -> Int? {
        let utf8 = source.utf8
        guard offset >= 0,
              let index = utf8.index(utf8.startIndex, offsetBy: offset, limitedBy: utf8.endIndex),
              let stringIndex = index.samePosition(in: source) else { return nil }
        return source.utf16.distance(from: source.startIndex, to: stringIndex)
    }
}
