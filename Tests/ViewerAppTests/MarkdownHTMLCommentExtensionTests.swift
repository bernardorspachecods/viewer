import AppKit
import MarkdownEngine
import Testing
@testable import ViewerApp
@testable import ViewerCore

@Test("the comment extension is an opaque inline span between <!-- and -->")
func commentExtensionSyntax() {
    let syntax = MarkdownHTMLCommentExtension().inline

    #expect(MarkdownHTMLCommentExtension().id == "htmlComment")
    #expect(syntax?.open == "<!--")
    #expect(syntax?.close == "-->")
    #expect(syntax?.parsesContent == false)
}

@Test("the comment extension re-wraps its content as an HTML comment for copy")
func commentExtensionHTML() {
    #expect(MarkdownHTMLCommentExtension().html(childrenHTML: " note ") == "<!-- note -->")
}

@MainActor
@Test("comment content takes font size, color and background from the tokens")
func commentContentAttributesFollowTokens() {
    let tokens = MarkdownStyleTokens.shared
    let attributes = MarkdownHTMLCommentExtension(tokens: tokens)
        .contentAttributes(theme: MarkdownEditorTheme.default)

    let font = attributes[.font] as? NSFont
    #expect(font?.pointSize == CGFloat(tokens.bodyFontSize * tokens.commentFontScale))
    #expect(font?.isFixedPitch == true)
    #expect(attributes[.foregroundColor] as? NSColor == tokens.commentColor.nsColor)
    #expect(attributes[.backgroundColor] != nil)
}

@MainActor
@Test("a modified token copy changes the comment chip in the editor")
func commentContentAttributesChangeWithTokens() {
    var tokens = MarkdownStyleTokens.shared
    tokens.bodyFontSize = 20
    tokens.commentFontScale = 0.5
    tokens.commentColor = MarkdownStyleColor(.link)
    tokens.commentBackground = MarkdownStyleColor(.link, alpha: 0.2)

    let attributes = MarkdownHTMLCommentExtension(tokens: tokens)
        .contentAttributes(theme: MarkdownEditorTheme.default)

    #expect((attributes[.font] as? NSFont)?.pointSize == 10)
    #expect(attributes[.foregroundColor] as? NSColor == MarkdownStyleColor(.link).nsColor)
    let background = attributes[.backgroundColor] as? NSColor
    var alpha: CGFloat = 0
    NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
        alpha = background?.usingColorSpace(.sRGB)?.alphaComponent ?? 0
    }
    #expect(abs(alpha - 0.2) < 0.001)
}

@Test("the preview placeholder chip rule reads the comment tokens")
func previewCommentChipRuleFollowsTokens() {
    var tokens = MarkdownStyleTokens.shared
    tokens.commentFontScale = 0.7
    tokens.commentBackground = MarkdownStyleColor(.link, alpha: 0.3)
    let css = MarkdownStylesheet.css(tokens: tokens)

    let rule = css.split(separator: "\n").first { $0.contains("span.bp-special-placeholder { display: inline;") }.map(String.init) ?? ""
    #expect(rule.contains("font-size: 0.7em;"))
    #expect(rule.contains("color: \(tokens.commentColor.css);"))
    #expect(rule.contains("background: \(tokens.commentBackground.css);"))
}
