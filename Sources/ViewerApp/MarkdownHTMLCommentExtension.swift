import AppKit
import MarkdownEngine
import ViewerCore

/// Inline HTML comment (`<!-- note -->`) as an editor span, styled like the preview's placeholder
/// chip (`span.bp-special-placeholder`). Both read the comment tokens, so they look the same.
///
/// The content is opaque (not re-parsed), so the note text stays literal. The `<!--` and `-->`
/// markers are handled by the engine: they shrink away while the caret is outside the comment and
/// show muted while it is inside.
struct MarkdownHTMLCommentExtension: MarkdownExtension {
    /// Well-known id, unique among the registered extensions.
    static let identifier = "htmlComment"

    let tokens: MarkdownStyleTokens

    init(tokens: MarkdownStyleTokens = .shared) {
        self.tokens = tokens
    }

    var id: String { Self.identifier }

    var inline: InlineSyntax? {
        InlineSyntax(open: "<!--", close: "-->", parsesContent: false)
    }

    /// The font is a fixed size taken from the tokens: the engine passes the theme only (no font),
    /// so the chip does not follow the document zoom the way the body text does.
    func contentAttributes(theme: MarkdownEditorTheme) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(
                ofSize: CGFloat(tokens.bodyFontSize * tokens.commentFontScale),
                weight: .regular
            ),
            .foregroundColor: tokens.commentColor.nsColor,
            .backgroundColor: tokens.commentBackground.nsColor,
        ]
    }

    func html(childrenHTML: String) -> String {
        "<!--\(childrenHTML)-->"
    }
}
