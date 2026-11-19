import AppKit
import MarkdownEngine
import Testing
@testable import ViewerApp
@testable import ViewerCore

@MainActor
private func editorConfiguration(
    _ tokens: MarkdownStyleTokens = .shared,
    limitsTextWidth: Bool = true
) -> MarkdownEditorConfiguration {
    MarkdownLiveEditorStyle.configuration(
        base: .default,
        tokens: tokens,
        limitsTextWidth: limitsTextWidth
    )
}

@MainActor
@Test("editor takes heading, code and list metrics from the style tokens")
func editorMetricsFollowTokens() {
    var tokens = MarkdownStyleTokens.shared
    tokens.headingScales = [2, 1.5, 1.2, 1, 1, 1]
    tokens.headingTopSpacingEm = [1, 0.8, 0.7, 0.6, 0.5, 0.4]
    tokens.codeFontScale = 0.75
    tokens.listIndentPerLevel = 30

    let configuration = editorConfiguration(tokens)

    #expect(configuration.headings.fontMultipliers == tokens.headingScales.map { CGFloat($0) })
    #expect(configuration.headings.topSpacingEm == tokens.headingTopSpacingEm.map { CGFloat($0) })
    #expect(configuration.inlineCode.fontSizeScale == 0.75)
    #expect(configuration.codeBlock.fontSizeScale == 0.75)
    #expect(configuration.lists.indentPerLevel == 30)
}

@MainActor
@Test("editor insets and reading width follow the tokens and the text width setting")
func editorInsetsAndReadingWidthFollowTokens() {
    var tokens = MarkdownStyleTokens.shared
    tokens.horizontalInset = 40
    tokens.verticalInset = 24
    tokens.readingWidth = 900

    let limited = editorConfiguration(tokens, limitsTextWidth: true)
    let full = editorConfiguration(tokens, limitsTextWidth: false)

    #expect(limited.textInsets.horizontal == 40)
    #expect(limited.textInsets.vertical == 24)
    #expect(limited.readingWidth == 900)
    #expect(full.readingWidth == nil)
}

@MainActor
@Test("editor links show at full theme color and extensions are registered")
func editorLinksAndExtensions() {
    let configuration = editorConfiguration()

    #expect(configuration.link.activeLinkAlpha == 1)
    #expect(!configuration.extensions.isEmpty)
}

@MainActor
@Test("editor table geometry and colors follow the tokens")
func editorTableFollowsTokens() {
    var tokens = MarkdownStyleTokens.shared
    tokens.tableCellHorizontalPadding = 7
    tokens.tableCellVerticalPadding = 9
    tokens.tableBorderWidth = 2
    tokens.tableFillsWidth = false
    tokens.tableHeaderBackground = MarkdownStyleColor(.text, alpha: 0)

    let table = editorConfiguration(tokens).table
    #expect(table.cellHorizontalPadding == 7)
    #expect(table.cellVerticalPadding == 9)
    #expect(table.borderWidth == 2)
    #expect(table.fillsAvailableWidth == false)
    #expect(table.headerFillColor == .clear)
    #expect(table.borderColor != nil)

    let shared = editorConfiguration().table
    #expect(shared.cellHorizontalPadding == CGFloat(MarkdownStyleTokens.shared.tableCellHorizontalPadding))
    #expect(shared.fillsAvailableWidth == MarkdownStyleTokens.shared.tableFillsWidth)
    #expect(shared.headerFillColor == .clear)
}

@MainActor
@Test("a translucent style color keeps its alpha and resolves per appearance")
func translucentStyleColorIsDynamic() {
    let color = MarkdownStyleColor(.muted, alpha: 0.5).nsColor

    func resolved(_ name: NSAppearance.Name) -> NSColor {
        var result = color
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            result = color.usingColorSpace(.sRGB) ?? color
        }
        return result
    }
    let light = resolved(.aqua)
    let dark = resolved(.darkAqua)

    #expect(abs(light.alphaComponent - 0.5) < 0.001)
    #expect(abs(dark.alphaComponent - 0.5) < 0.001)
    #expect(light.redComponent != dark.redComponent)
}

@Test("scaled tokens multiply every size in points and leave ratios alone")
func scaledTokensMultiplyPointSizes() {
    let tokens = MarkdownStyleTokens.shared
    let scaled = tokens.scaled(by: 1.5)

    #expect(scaled.bodyFontSize == tokens.bodyFontSize * 1.5)
    #expect(scaled.horizontalInset == tokens.horizontalInset * 1.5)
    #expect(scaled.listIndentPerLevel == tokens.listIndentPerLevel * 1.5)
    #expect(scaled.tableCellVerticalPadding == tokens.tableCellVerticalPadding * 1.5)
    #expect(scaled.lineHeight == tokens.lineHeight)
    #expect(scaled.headingScales == tokens.headingScales)
    #expect(scaled.codeFontScale == tokens.codeFontScale)
    #expect(scaled.frontMatterVerticalPadding == tokens.frontMatterVerticalPadding * 1.5)
    #expect(scaled.frontMatterFontScale == tokens.frontMatterFontScale)
}

@MainActor
@Test("editor front matter card follows the tokens, the same ones the preview CSS reads")
func editorFrontMatterFollowsTokens() {
    var tokens = MarkdownStyleTokens.shared
    tokens.frontMatterFontScale = 0.8
    tokens.frontMatterLineHeight = 1.5
    tokens.frontMatterHorizontalPadding = 20
    tokens.frontMatterVerticalPadding = 12
    tokens.frontMatterCornerRadius = 6
    tokens.frontMatterRowGap = 4
    tokens.frontMatterBottomSpacing = 5
    tokens.frontMatterBackground = MarkdownStyleColor(.text, alpha: 0.1)

    let style = editorConfiguration(tokens).frontMatter

    #expect(style.isEnabled)
    #expect(style.fontSizeScale == 0.8)
    #expect(style.lineHeightMultiple == 1.5)
    #expect(style.horizontalPadding == 20)
    #expect(style.verticalPadding == 12)
    #expect(style.cornerRadius == 6)
    #expect(style.rowGap == 4)
    #expect(style.bottomSpacing == 5)
    #expect(abs(style.backgroundColor.usingColorSpace(.sRGB)!.alphaComponent - 0.1) < 0.001)
    #expect(abs(style.keyColor.usingColorSpace(.sRGB)!.alphaComponent - 0.75) < 0.001)
    #expect(style.textColor == NSColor.secondaryLabelColor)

    let css = MarkdownStylesheet.css(tokens: tokens)
    #expect(css.contains("padding: 12px 20px"))
    #expect(css.contains("border-radius: 6px"))
    #expect(css.contains("font-size: 0.8em"))
    #expect(css.contains("line-height: 1.5"))
}
