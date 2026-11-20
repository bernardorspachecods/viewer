import AppKit
import MarkdownEngine
import ViewerCore

/// Configures the Markdown editor engine from `MarkdownStyleTokens`, the one style definition the
/// rendered preview also reads. No style number lives in the editor code: change a token and both
/// the preview and the editor change.
enum MarkdownLiveEditorStyle {
    @MainActor
    static func configuration(
        base: MarkdownEditorConfiguration,
        tokens: MarkdownStyleTokens,
        limitsTextWidth: Bool
    ) -> MarkdownEditorConfiguration {
        var configuration = base
        let fontSize = CGFloat(tokens.bodyFontSize)

        // Without insets the text touches the pane edge when the pane is narrower than the
        // reading column (split view).
        configuration.textInsets = TextInsets(
            horizontal: CGFloat(tokens.horizontalInset),
            vertical: CGFloat(tokens.verticalInset)
        )
        configuration.readingWidth = limitsTextWidth ? CGFloat(tokens.readingWidth) : nil

        configuration.theme.bodyText = tokens.textColor.nsColor
        configuration.theme.mutedText = tokens.mutedColor.nsColor
        configuration.theme.link = tokens.linkColor.nsColor
        configuration.theme.incompleteLink = tokens.linkColor.nsColor
        // Links show at the full theme color, as in the preview, instead of the engine's faded default.
        configuration.link.activeLinkAlpha = 1

        configuration.headings = HeadingStyle(
            fontMultipliers: tokens.headingScales.map { CGFloat($0) },
            topSpacingEm: tokens.headingTopSpacingEm.map { CGFloat($0) }
        )
        configuration.inlineCode.fontSizeScale = CGFloat(tokens.codeFontScale)
        configuration.codeBlock.fontSizeScale = CGFloat(tokens.codeFontScale)
        configuration.lists.indentPerLevel = CGFloat(tokens.listIndentPerLevel)
        configuration.table = TableStyle(
            cellHorizontalPadding: CGFloat(tokens.tableCellHorizontalPadding),
            cellVerticalPadding: CGFloat(tokens.tableCellVerticalPadding),
            borderWidth: CGFloat(tokens.tableBorderWidth),
            borderColor: tokens.tableBorderColor.nsColor,
            headerFillColor: tokens.tableHeaderBackground.alpha == 0 ? .clear : tokens.tableHeaderBackground.nsColor,
            fillsAvailableWidth: tokens.tableFillsWidth,
            lineHeight: CGFloat(tokens.tableLineHeight * tokens.bodyFontSize)
        )

        configuration.frontMatter = FrontMatterStyle(
            isEnabled: true,
            fontSizeScale: CGFloat(tokens.frontMatterFontScale),
            lineHeightMultiple: CGFloat(tokens.frontMatterLineHeight),
            backgroundColor: tokens.frontMatterBackground.nsColor,
            textColor: tokens.frontMatterTextColor.nsColor,
            keyColor: tokens.frontMatterKeyColor.nsColor,
            horizontalPadding: CGFloat(tokens.frontMatterHorizontalPadding),
            verticalPadding: CGFloat(tokens.frontMatterVerticalPadding),
            cornerRadius: CGFloat(tokens.frontMatterCornerRadius),
            rowGap: CGFloat(tokens.frontMatterRowGap),
            bottomSpacing: CGFloat(tokens.frontMatterBottomSpacing)
        )

        // The engine adds this many points on top of the font's natural line height.
        // The blank source line between blocks already is the gap; the engine adds none on top.
        configuration.paragraph.spacingFactor = 0
        let extraLineHeight = Self.extraLineHeight(tokens: tokens)
        configuration.paragraph.lineHeightExtraSpacing = extraLineHeight
        configuration.lists.extraLineHeight = extraLineHeight
        configuration.blockquote.extraLineHeight = extraLineHeight

        configuration.services.syntaxHighlighter = TokenSyntaxHighlighter(
            base: base.services.syntaxHighlighter,
            tokens: tokens
        )
        configuration.extensions = [StrikethroughExtension(), MarkdownHTMLCommentExtension(tokens: tokens)]
        return configuration
    }

    /// What the engine adds to a line to reach the shared line height. It puts all of it above the
    /// text, where CSS splits it above and below, so editor text sits half of it lower.
    static func extraLineHeight(tokens: MarkdownStyleTokens) -> CGFloat {
        let fontSize = CGFloat(tokens.bodyFontSize)
        let natural = NSLayoutManager().defaultLineHeight(for: NSFont.systemFont(ofSize: fontSize))
        return max(0, CGFloat(tokens.lineHeight) * fontSize - natural)
    }

    /// How far lower the editor draws a block's text than the preview, in points at this zoom.
    /// A table is one image the engine draws without the extra line height, so it has no drop.
    static func textDrop(kind: MarkdownBlockKind?, tokens: MarkdownStyleTokens, zoom: Double) -> CGFloat {
        kind == .table ? 0 : extraLineHeight(tokens: tokens.scaled(by: zoom)) / 2
    }
}

/// Forwards everything to the base highlighter except the code-block background, which comes from
/// the tokens so the editor's code blocks match the preview's.
struct TokenSyntaxHighlighter: SyntaxHighlighter {
    let base: any SyntaxHighlighter
    let tokens: MarkdownStyleTokens

    func codeFont(size: CGFloat) -> NSFont {
        base.codeFont(size: size)
    }

    func backgroundColor() -> NSColor {
        tokens.codeBackground.nsColor
    }

    func highlight(code: String, language: String?) -> NSAttributedString? {
        base.highlight(code: code, language: language)
    }

    var appearanceDidChangeNotification: Notification.Name? {
        base.appearanceDidChangeNotification
    }
}

extension MarkdownStyleColor {
    /// The AppKit color for this role and alpha. With alpha below 1 the color is built as a dynamic
    /// color that resolves the system color under each appearance first, so light and dark mode
    /// keep switching (`withAlphaComponent` on a dynamic color would freeze it to one appearance).
    var nsColor: NSColor {
        let base: NSColor
        switch role {
        case .text: base = .labelColor
        case .muted: base = .secondaryLabelColor
        case .link: base = .linkColor
        }
        guard alpha < 1 else { return base }
        let alpha = CGFloat(self.alpha)
        return NSColor(name: nil) { appearance in
            var resolved = base
            appearance.performAsCurrentDrawingAppearance {
                resolved = (base.usingColorSpace(.sRGB) ?? base).withAlphaComponent(alpha)
            }
            return resolved
        }
    }
}
