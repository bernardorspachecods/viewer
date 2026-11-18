import BPViewerCore

struct SourceSyntaxToken: Sendable {
    let color: String
    let utf8Offset: Int
    let utf8End: Int
}

// This tokenizer is deliberately outside SourceTextView. The view and its
// coordinator are MainActor-isolated, but the tokenization itself is pure and
// must remain safe to run on the utility queue.
enum SourceSyntaxTokenizer {
    static func tokens(
        in source: String,
        for syntaxHighlighting: SourceSyntaxHighlighting
    ) -> [SourceSyntaxToken] {
        switch syntaxHighlighting {
        case let .json(palette):
            return JSONSyntaxHighlighter().tokenize(source).map {
                SourceSyntaxToken(
                    color: palette.color(for: $0.kind),
                    utf8Offset: $0.utf8Offset,
                    utf8End: $0.utf8End
                )
            }
        case let .markdown(palette):
            return MarkdownSyntaxHighlighter().tokenize(source).map {
                SourceSyntaxToken(
                    color: palette.color(for: $0.kind),
                    utf8Offset: $0.utf8Offset,
                    utf8End: $0.utf8End
                )
            }
        case let .latex(palette):
            return LatexSyntaxHighlighter().tokenize(source).map {
                SourceSyntaxToken(
                    color: palette.color(for: $0.kind),
                    utf8Offset: $0.utf8Offset,
                    utf8End: $0.utf8End
                )
            }
        }
    }
}
