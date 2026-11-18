import AppKit

extension MarkdownNSTextView {
    func invalidateLineNumberCache() {
        cachedLineStarts = nil
        pendingLineStartEdit = nil
    }

    func updatedLineStarts(
        _ starts: [Int],
        replacing range: NSRange,
        with replacement: String
    ) -> [Int] {
        let replacementString = replacement as NSString
        let delta = replacementString.length - range.length
        let end = NSMaxRange(range)
        var updated = starts.filter { start in
            if start <= range.location { return true }
            if start < end { return false }
            if start == end, range.length == 0 { return true }
            return true
        }.map { start in
            let followsReplacedText = range.length == 0
                ? start > end
                : start >= end
            return followsReplacedText ? start + delta : start
        }

        if replacementString.length > 0 {
            for offset in 0..<replacementString.length
            where replacementString.character(at: offset) == 10 {
                updated.append(range.location + offset + 1)
            }
        }
        updated.sort()
        var unique: [Int] = []
        unique.reserveCapacity(updated.count)
        for start in updated where unique.last != start {
            unique.append(start)
        }
        return unique
    }

    func lineFragments(in requestedRect: NSRect) -> [LineFragment] {
        guard let layoutManager,
              let textContainer else { return [] }

        let origin = textContainerOrigin
        let textContainerRect = requestedRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: textContainerRect,
            in: textContainer
        )
        layoutManager.ensureLayout(forGlyphRange: glyphRange)
        let sourceFont = font ?? NSFont.systemFont(ofSize: SourceEditorLayout.editorFontSize)
        var fragments: [LineFragment] = []

        // Both the gutter and the diff background consume this exact list.
        // In particular, a logical line can produce several visual fragments
        // when it wraps, while the gutter still draws its number only once.
        if glyphRange.length > 0 {
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
                [weak self] lineFragmentRect, _, _, glyphRange, _ in
                guard let self,
                      glyphRange.location < layoutManager.numberOfGlyphs else { return }

                let rect = lineFragmentRect.offsetBy(dx: origin.x, dy: origin.y)
                let physicalLine = lineNumber(
                    atUTF16Offset: layoutManager.characterIndexForGlyph(at: glyphRange.location)
                )
                // A glyph's vertical location can vary with the text on the
                // line (for example, fallback glyphs or marked text). Use the
                // font's baseline within the fixed-height line fragment so
                // line numbers stay aligned when a blank line gets content.
                let baselineY = rect.minY + SourceEditorLayout.extraLineBaselineOffset(
                    lineHeight: rect.height,
                    defaultBaselineOffset: layoutManager.defaultBaselineOffset(for: sourceFont),
                    defaultLineHeight: layoutManager.defaultLineHeight(for: sourceFont)
                )
                fragments.append(LineFragment(
                    physicalLine: physicalLine,
                    rect: rect,
                    baselineY: baselineY
                ))
            }
        }

        let extraLineRect = layoutManager.extraLineFragmentRect.offsetBy(
            dx: origin.x,
            dy: origin.y
        )
        if extraLineRect.height > 0 && extraLineRect.intersects(requestedRect) {
            let paragraphStyleMinimumLineHeight: CGFloat?
            if let textStorage, textStorage.length > 0 {
                paragraphStyleMinimumLineHeight = (textStorage.attribute(
                    .paragraphStyle,
                    at: 0,
                    effectiveRange: nil
                ) as? NSParagraphStyle)?.minimumLineHeight
            } else {
                paragraphStyleMinimumLineHeight = nil
            }
            let configuredLineHeight = fragments.first?.rect.height
                ?? SourceEditorLayout.lineHeightForExtraFragment(
                    textStorageLength: textStorage?.length ?? 0,
                    paragraphStyleMinimumLineHeight: paragraphStyleMinimumLineHeight,
                    fallback: SourceEditorLayout.codeLineHeight
                )
            let normalizedExtraLineRect = SourceEditorLayout.normalizedExtraLineRect(
                extraLineRect: extraLineRect,
                previousLineMaxY: fragments.last?.rect.maxY,
                configuredLineHeight: configuredLineHeight
            )
            let extraLineBaselineOffset = SourceEditorLayout.extraLineBaselineOffset(
                lineHeight: normalizedExtraLineRect.height,
                defaultBaselineOffset: layoutManager.defaultBaselineOffset(for: sourceFont),
                defaultLineHeight: layoutManager.defaultLineHeight(for: sourceFont)
            )
            fragments.append(LineFragment(
                physicalLine: lineNumber(atUTF16Offset: (string as NSString).length),
                rect: normalizedExtraLineRect,
                baselineY: normalizedExtraLineRect.minY + extraLineBaselineOffset
            ))
        }

        return fragments
    }

    private func lineNumber(atUTF16Offset offset: Int) -> Int {
        let starts: [Int]
        if let cachedLineStarts {
            starts = cachedLineStarts
        } else {
            let source = string as NSString
            var computed = [0]
            computed.reserveCapacity(max(1, source.length / 32))
            for position in 0..<source.length where source.character(at: position) == 10 {
                computed.append(position + 1)
            }
            cachedLineStarts = computed
            starts = computed
        }

        let clampedOffset = min(max(offset, 0), (string as NSString).length)
        var lower = 0
        var upper = starts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if starts[middle] <= clampedOffset {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return max(lower, 1)
    }
}
