import AppKit

extension SourceTextView {
    static func applySyntaxHighlighting(
        to textView: NSTextView,
        source: String,
        syntaxHighlighting: SourceSyntaxHighlighting?
    ) {
        applySyntaxHighlighting(
            to: textView,
            source: source,
            syntaxHighlighting: syntaxHighlighting,
            tokens: syntaxHighlighting.map {
                SourceSyntaxTokenizer.tokens(in: source, for: $0)
            } ?? []
        )
    }

    static func applySyntaxHighlighting(
        to textView: NSTextView,
        source: String,
        syntaxHighlighting: SourceSyntaxHighlighting?,
        tokens: [SourceSyntaxToken]
    ) {
        let textLength = (textView.string as NSString).length
        guard textLength > 0 else { return }
        let range = NSRange(location: 0, length: textLength)
        guard let textStorage = textView.textStorage else { return }
        let utf16Offsets = Self.utf16Offsets(in: source)
        let foregroundColor = syntaxHighlighting.map {
            NSColor(hex: $0.foreground)
        } ?? textView.textColor ?? NSColor.textColor
        textStorage.beginEditing()
        textStorage.addAttribute(
            .foregroundColor,
            value: foregroundColor,
            range: range
        )
        for token in tokens {
            let start = utf16Offsets[min(max(token.utf8Offset, 0), utf16Offsets.count - 1)]
            let end = utf16Offsets[min(max(token.utf8End, 0), utf16Offsets.count - 1)]
            guard end > start else { continue }
            textStorage.addAttribute(
                .foregroundColor,
                value: NSColor(hex: token.color),
                range: NSRange(location: start, length: end - start)
            )
        }
        textStorage.endEditing()
    }
}
