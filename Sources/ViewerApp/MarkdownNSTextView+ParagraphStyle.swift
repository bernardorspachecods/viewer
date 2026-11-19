import AppKit

extension MarkdownNSTextView {
    func normalizeEditedParagraphs(_ edit: (range: NSRange, replacement: String)) {
        guard let fixedEditorParagraphStyle,
              let textStorage,
              textStorage.length > 0 else {
            if let fixedEditorParagraphStyle {
                var attributes = typingAttributes
                attributes[.paragraphStyle] = fixedEditorParagraphStyle
                typingAttributes = attributes
            }
            return
        }

        let source = string as NSString
        let start = min(max(edit.range.location, 0), source.length)
        let insertedLength = (edit.replacement as NSString).length
        let caret = min(start + insertedLength, source.length)
        let changedLength = min(insertedLength, source.length - start)
        let changedRange = source.paragraphRange(for: NSRange(
            location: start,
            length: changedLength
        ))
        let caretRange = source.paragraphRange(for: NSRange(location: caret, length: 0))
        let paragraphRanges = [changedRange, caretRange].filter { $0.length > 0 }

        textStorage.beginEditing()
        for range in paragraphRanges {
            let currentStyle = textStorage.attribute(
                .paragraphStyle,
                at: range.location,
                effectiveRange: nil
            ) as? NSParagraphStyle
            let needsNormalization = currentStyle.map {
                $0.minimumLineHeight != fixedEditorParagraphStyle.minimumLineHeight
                    || $0.maximumLineHeight != fixedEditorParagraphStyle.maximumLineHeight
                    || $0.lineHeightMultiple != fixedEditorParagraphStyle.lineHeightMultiple
                    || $0.lineSpacing != 0
                    || $0.paragraphSpacing != 0
            } ?? true
            guard needsNormalization else { continue }

            let normalizedStyle = (fixedEditorParagraphStyle.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            normalizedStyle.paragraphSpacingBefore = currentStyle?.paragraphSpacingBefore ?? 0
            textStorage.addAttribute(.paragraphStyle, value: normalizedStyle, range: range)
        }
        textStorage.endEditing()

        var attributes = typingAttributes
        attributes[.paragraphStyle] = fixedEditorParagraphStyle
        typingAttributes = attributes
    }
}
