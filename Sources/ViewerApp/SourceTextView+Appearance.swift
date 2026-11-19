import AppKit

extension SourceTextView {
    func applyTypography(to textView: NSTextView) {
        let font = SourceEditorLayout.editorFont(monospaced: monospaced, zoom: zoom)
        let paragraphStyle = SourceEditorLayout.editorParagraphStyle(zoom: zoom)

        textView.font = font
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textView.textColor ?? NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]

        let textLength = (textView.string as NSString).length
        guard textLength > 0 else { return }
        let range = NSRange(location: 0, length: textLength)
        textView.textStorage?.addAttribute(.font, value: font, range: range)
        textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        applyLineSpacingBefore(
            to: textView,
            paragraphStyle: paragraphStyle
        )
    }

    private func applyLineSpacingBefore(
        to textView: NSTextView,
        paragraphStyle: NSParagraphStyle
    ) {
        guard !lineSpacingBefore.isEmpty else { return }

        let source = textView.string as NSString
        var lineStart = 0
        var lineNumber = 1
        for position in 0...source.length {
            let isEnd = position == source.length
            let isNewline = !isEnd && source.character(at: position) == 10
            guard isEnd || isNewline else { continue }

            let length = position - lineStart + (isNewline ? 1 : 0)
            guard length > 0 else {
                lineStart = position + 1
                lineNumber += 1
                continue
            }

            let style = (paragraphStyle.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            style.paragraphSpacingBefore = lineSpacingBefore[lineNumber] ?? 0
            textView.textStorage?.addAttribute(
                .paragraphStyle,
                value: style,
                range: NSRange(location: lineStart, length: length)
            )
            lineStart = position + 1
            lineNumber += 1
        }
    }

    func textContainerHorizontalInset(zoom: Double) -> CGFloat {
        // The gutter occupies the leading part of the editor's existing
        // padding. Keeping the text origin stable avoids shifting documents
        // when numbering is toggled and keeps the gutter inside the document.
        SourceEditorLayout.horizontalPadding * CGFloat(zoom)
    }

    func applyBaseColors(to textView: NSTextView) {
        guard let syntaxHighlighting else {
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .textColor
            return
        }
        textView.backgroundColor = .clear
        textView.textColor = NSColor(hex: syntaxHighlighting.foreground)
    }
}
