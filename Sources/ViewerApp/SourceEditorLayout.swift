import AppKit

enum SourceEditorLayout {
    static let contentMaxWidth: CGFloat = 860
    static let horizontalPadding: CGFloat = 52
    static let verticalPadding: CGFloat = 40
    static let lineNumberGutterWidth: CGFloat = 44
    static let lineNumberFontSize: CGFloat = 11
    static let lineNumberTrailingPadding: CGFloat = 12
    static let lineMarkerLeadingPadding: CGFloat = 5
    static let lineNumberVerticalPadding: CGFloat = 4
    static let editorFontSize: CGFloat = 13
    static let codeFontFamily = "SFMono-Regular"
    static let codeFontSize: CGFloat = 13
    static let codeLineHeight: CGFloat = 18

    static func editorFont(monospaced: Bool, zoom: Double) -> NSFont {
        let baseFont = monospaced
            ? (NSFont(
                name: codeFontFamily,
                size: codeFontSize
            ) ?? NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .regular))
            : NSFont.systemFont(ofSize: editorFontSize)
        return baseFont.withSize(baseFont.pointSize * zoom)
    }

    static func editorParagraphStyle(zoom: Double) -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        let lineHeight = codeLineHeight * zoom
        paragraphStyle.lineHeightMultiple = 1
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.lineSpacing = 0
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.paragraphSpacingBefore = 0
        return paragraphStyle
    }

    static func lineBaselineY(
        lineFragmentRect: CGRect,
        glyphLocationY: CGFloat
    ) -> CGFloat {
        lineFragmentRect.minY + glyphLocationY
    }

    static func extraLineBaselineOffset(
        lineHeight: CGFloat,
        defaultBaselineOffset: CGFloat,
        defaultLineHeight: CGFloat
    ) -> CGFloat {
        defaultBaselineOffset + max(0, lineHeight - defaultLineHeight)
    }

    static func normalizedLineHeight(
        extraLineHeight: CGFloat,
        configuredLineHeight: CGFloat
    ) -> CGFloat {
        max(extraLineHeight, configuredLineHeight)
    }

    static func lineHeightForExtraFragment(
        textStorageLength: Int,
        paragraphStyleMinimumLineHeight: CGFloat?,
        fallback: CGFloat
    ) -> CGFloat {
        guard textStorageLength > 0 else { return fallback }
        return paragraphStyleMinimumLineHeight ?? fallback
    }

    static func normalizedExtraLineRect(
        extraLineRect: CGRect,
        previousLineMaxY: CGFloat?,
        configuredLineHeight: CGFloat
    ) -> CGRect {
        var rect = extraLineRect
        if let previousLineMaxY {
            rect.origin.y = max(rect.origin.y, previousLineMaxY)
        }
        rect.size.height = normalizedLineHeight(
            extraLineHeight: extraLineRect.height,
            configuredLineHeight: configuredLineHeight
        )
        return rect
    }

    static func lineHighlightRect(
        lineFragmentRect: CGRect,
        textContainerOrigin: CGPoint,
        viewWidth: CGFloat
    ) -> CGRect {
        var rect = lineFragmentRect.offsetBy(
            dx: textContainerOrigin.x,
            dy: textContainerOrigin.y
        )
        rect.origin.x = 0
        rect.size.width = viewWidth
        return rect
    }

    static func textContainerWidth(panelWidth: CGFloat, zoom: Double) -> CGFloat {
        max(1, panelWidth - (horizontalPadding * 2 * zoom))
    }

    static func measuredLineHeight(
        for text: String?,
        panelWidth: CGFloat,
        zoom: Double,
        monospaced: Bool
    ) -> CGFloat {
        let minimum = codeLineHeight * zoom
        guard let text, !text.isEmpty else { return minimum }

        let storage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: textContainerWidth(panelWidth: panelWidth, zoom: zoom),
                height: .greatestFiniteMagnitude
            )
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)

        let range = NSRange(location: 0, length: storage.length)
        storage.addAttribute(.font, value: editorFont(monospaced: monospaced, zoom: zoom), range: range)
        storage.addAttribute(
            .paragraphStyle,
            value: editorParagraphStyle(zoom: zoom),
            range: range
        )
        layoutManager.ensureLayout(for: textContainer)

        return max(minimum, ceil(layoutManager.usedRect(for: textContainer).height))
    }
}
