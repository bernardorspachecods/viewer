import Foundation

/// A color as a system role plus an opacity, so the preview (CSS) and the editor (`NSColor`)
/// can each express the same color in their own language.
public struct MarkdownStyleColor: Equatable, Sendable {
    public enum Role: Equatable, Sendable {
        /// `labelColor`: body text.
        case text
        /// `secondaryLabelColor`: quotes, markers, table chrome.
        case muted
        /// `linkColor`: links (the color AppKit draws a clickable link with).
        case link
    }

    public let role: Role
    public let alpha: Double

    public init(_ role: Role, alpha: Double = 1) {
        self.role = role
        self.alpha = alpha
    }

    /// The CSS keyword WebKit maps to the matching AppKit color.
    public var cssKeyword: String {
        switch role {
        case .text: "-apple-system-label"
        case .muted: "-apple-system-secondary-label"
        case .link: "light-dark(#0068DA, #419CFF)" // AppKit linkColor; WebKit has no keyword for it
        }
    }

    /// A CSS color value, with the alpha applied when it is below 1.
    public var css: String {
        alpha >= 1
            ? cssKeyword
            : "color-mix(in srgb, \(cssKeyword) \(Int((alpha * 100).rounded()))%, transparent)"
    }
}

/// The one definition of how Markdown looks in Viewer. The rendered preview (CSS built from these
/// values) and the Markdown editor (swift-markdown-engine configured from these values) both read
/// it, so a change here changes both. To restyle Markdown, change a value here and nowhere else.
///
/// Values the engine fixes itself and cannot be configured (table geometry, blockquote bar and
/// indent, list marker glyphs) are copied here from the engine so the preview can match them.
public struct MarkdownStyleTokens: Equatable, Sendable {
    public static let shared = MarkdownStyleTokens()

    // MARK: Page

    /// Body font size in points (CSS px). Scaled by the document zoom.
    public var bodyFontSize = 15.0
    /// Line height as a multiple of the body font size.
    public var lineHeight = 1.6
    /// Side padding of the text, in points.
    public var horizontalInset = 56.0
    /// Padding above the first block, in points.
    public var verticalInset = 32.0
    /// Width of the centered reading column when the user asks for one.
    public var readingWidth = 760.0

    // MARK: Text

    public var textColor = MarkdownStyleColor(.text)
    public var mutedColor = MarkdownStyleColor(.muted)
    public var linkColor = MarkdownStyleColor(.link)

    // MARK: Blocks

    /// Empty space between two blocks, as a multiple of the body font size. The editor shows the
    /// blank source line between blocks as one full line, so the preview leaves the same gap.
    public var blockSpacingEm: Double { lineHeight }

    /// Font size of heading levels 1...6, as a multiple of the body font size.
    public var headingScales = [1.8, 1.45, 1.2, 1.05, 1.0, 0.9]
    /// Space above heading levels 1...6, as a multiple of the heading's own font size.
    public var headingTopSpacingEm = [0.9, 0.8, 0.7, 0.6, 0.5, 0.5]

    /// The engine sets a heading this many points lower in its line than the preview would, so the
    /// preview moves that much space from above a heading to below it (measured), in points.
    public var headingBaselineShift = 2.0

    // MARK: Code

    /// Code font size (inline and block) as a multiple of the body font size.
    public var codeFontScale = 0.9
    /// Background of inline code and of code blocks.
    public var codeBackground = MarkdownStyleColor(.text, alpha: 0.08)
    /// The engine draws a code block square, with the fence lines left as empty padding lines.
    public var codeBlockCornerRadius = 0.0
    public var codeBlockHorizontalPadding = 12.0
    /// Height of the empty line above and below a code block's text, in points.
    public var codeFenceLineHeight: Double { lineHeight * bodyFontSize * codeFontScale }

    /// Space the engine leaves around a few blocks beyond the blank source line (measured), in
    /// points: below a code block, below a horizontal rule, and (negative: less) above a display
    /// formula.
    public var codeSpaceAfter = 3.0
    public var ruleSpaceAfter = 10.5
    public var mathSpaceBefore = -10.5

    // MARK: Quotes

    public var quoteBarWidth = 3.0
    /// Distance from the text column's left edge to the quoted text (engine-fixed).
    public var quoteIndent = 27.0
    /// Distance from the left edge to the bar (engine-fixed).
    public var quoteBarInset = 5.0
    public var quoteBarColor = MarkdownStyleColor(.muted, alpha: 0.5)
    public var quoteTextColor = MarkdownStyleColor(.muted)

    // MARK: Tables

    // The table look is the one the preview had before the editor shared it: full-width columns,
    // thin text-colored grid, no header fill. The editor draws the same geometry through the
    // engine's `TableStyle`, so both views match.

    /// Space between a cell's text and its left and right borders, in points.
    public var tableCellHorizontalPadding = 10.0
    /// Space between a cell's text and its top and bottom borders, in points (10 matches the row height of the preview's cells).
    public var tableCellVerticalPadding = 8.0
    /// Line height of table cell text, as a multiple of the body font size: the same as the body.
    public var tableLineHeight: Double { lineHeight }
    /// Space the engine leaves above and below a table beyond the blank source line (measured), in points.
    public var tableSpaceBefore = 5.5
    public var tableSpaceAfter = 12.0
    public var tableBorderWidth = 1.0
    /// Grid line color, shared by the preview and the editor.
    public var tableBorderColor = MarkdownStyleColor(.text, alpha: 0.2)
    /// Header row fill. Alpha 0 means no fill, in both the preview and the editor.
    public var tableHeaderBackground = MarkdownStyleColor(.text, alpha: 0)
    /// true: columns share the full width of the container equally and long cell text wraps.
    /// false: columns are sized to their content.
    public var tableFillsWidth = true

    // MARK: Lists

    /// Where a list line starts (the engine's `lists.indentPerLevel`), in points.
    public var listIndentPerLevel = 24.0
    /// Width of the `- ` / `1. ` source markers the engine leaves in the line, so text starts at
    /// `listIndentPerLevel` plus this. Measured from the engine at the default body size.
    public var listBulletMarkerWidth = 11.0
    public var listNumberMarkerWidth = 15.5
    /// Task checkbox square and its gap to the text (engine-fixed: a bit over the font height).
    /// The engine centers the box a little lower on its line than the line box alone would (measured).
    public var taskBoxTopNudge = 1.5
    /// Fill of a checked box (the check mark uses the text color).
    public var taskBoxCheckedFill = MarkdownStyleColor(.text, alpha: 0.3)
    public var taskBoxSize = 13.0
    public var taskBoxGap = 4.0
    /// Gap between the start of the line's marker area and the painted bullet.
    public var listBulletInset = 0.0
    /// How far a nested list sits from its parent's text. In the editor this is the width of the
    /// two spaces that nest it in the source.
    public var listNestedIndent = 8.0

    // MARK: Comments

    /// Font size of an inline HTML comment chip, as a multiple of the body font size.
    public var commentFontScale = 0.85
    /// Text color of an inline HTML comment chip.
    public var commentColor = MarkdownStyleColor(.muted)
    /// Background of an inline HTML comment chip.
    public var commentBackground = MarkdownStyleColor(.text, alpha: 0.05)

    // MARK: Front matter

    /// Font size of the front matter card, as a multiple of the body font size.
    public var frontMatterFontScale = 0.85
    /// Line height of the card's text, as a multiple of its own font size.
    public var frontMatterLineHeight = 1.45
    public var frontMatterBackground = MarkdownStyleColor(.text, alpha: 0.05)
    public var frontMatterTextColor = MarkdownStyleColor(.muted)
    /// Color of the keys, which are drawn semibold.
    public var frontMatterKeyColor = MarkdownStyleColor(.text, alpha: 0.75)
    public var frontMatterHorizontalPadding = 14.0
    /// Space above the first and below the last line of the card, in points. The editor shows it
    /// as the height of the two `---` lines.
    public var frontMatterVerticalPadding = 10.0
    public var frontMatterCornerRadius = 8.0
    /// Space between two rows (lines) of the card, in points.
    public var frontMatterRowGap = 3.0
    /// Extra space the editor adds after the card, in points. None: the blank source line after
    /// the card already is the gap between blocks (`blockSpacingEm`), as the preview's margin is.
    public var frontMatterBottomSpacing = 0.0

    public init() {}

    /// The tokens at a document zoom. The preview zooms the whole page, so it needs no scaling; the
    /// editor has to scale every size given in points itself.
    public func scaled(by zoom: Double) -> MarkdownStyleTokens {
        var scaled = self
        scaled.bodyFontSize *= zoom
        scaled.horizontalInset *= zoom
        scaled.verticalInset *= zoom
        scaled.readingWidth *= zoom
        scaled.headingBaselineShift *= zoom
        scaled.codeBlockCornerRadius *= zoom
        scaled.codeBlockHorizontalPadding *= zoom
        scaled.quoteBarWidth *= zoom
        scaled.quoteIndent *= zoom
        scaled.quoteBarInset *= zoom
        scaled.tableCellHorizontalPadding *= zoom
        scaled.tableCellVerticalPadding *= zoom
        scaled.tableBorderWidth *= zoom
        scaled.tableSpaceBefore *= zoom
        scaled.tableSpaceAfter *= zoom
        scaled.listIndentPerLevel *= zoom
        scaled.listBulletMarkerWidth *= zoom
        scaled.listNumberMarkerWidth *= zoom
        scaled.listNestedIndent *= zoom
        scaled.listBulletInset *= zoom
        scaled.taskBoxSize *= zoom
        scaled.taskBoxTopNudge *= zoom
        scaled.codeSpaceAfter *= zoom
        scaled.ruleSpaceAfter *= zoom
        scaled.mathSpaceBefore *= zoom
        scaled.taskBoxGap *= zoom
        scaled.frontMatterHorizontalPadding *= zoom
        scaled.frontMatterVerticalPadding *= zoom
        scaled.frontMatterCornerRadius *= zoom
        scaled.frontMatterRowGap *= zoom
        scaled.frontMatterBottomSpacing *= zoom
        return scaled
    }

    /// Font size multiple for a heading level; levels outside 1...6 are clamped.
    public func headingScale(level: Int) -> Double {
        headingScales[min(max(level, 1), headingScales.count) - 1]
    }

    public func headingTopSpacingEm(level: Int) -> Double {
        headingTopSpacingEm[min(max(level, 1), headingTopSpacingEm.count) - 1]
    }
}
