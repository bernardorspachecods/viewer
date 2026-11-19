import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownSyntaxContracts() {
        let markdownSyntaxSource = """
        # Thesis foundation

        - [fonte](https://example.com) — **forte**, *ênfase*, ~~riscado~~ e `código`
        > citação

        ```swift
        let value = 1
        ```
        """
        let markdownSyntaxKinds = Set(MarkdownSyntaxHighlighter().tokenize(markdownSyntaxSource).map(\.kind))
        expect(
            markdownSyntaxKinds.isSuperset(of: [
                .heading,
                .listMarker,
                .linkText,
                .linkDestination,
                .strong,
                .emphasis,
                .strikethrough,
                .code,
                .quoteMarker
            ]),
            "Markdown syntax highlighting tokenizes editor markup"
        )
        let markdownFrontMatter = "---\ntitle: Thesis\n---\n# Content"
        expect(
            MarkdownSyntaxHighlighter().tokenize(markdownFrontMatter).contains(where: { $0.kind == .frontMatter }),
            "Markdown syntax highlighting colors front matter"
        )
        expect(
            MarkdownSyntaxColorPalette(isDark: false).foreground != MarkdownSyntaxColorPalette(isDark: true).foreground,
            "Markdown syntax highlighting has light and dark palettes"
        )
        expect(
            MarkdownSyntaxColorPalette.light.emphasis == MarkdownSyntaxColorPalette.light.heading
                && MarkdownSyntaxColorPalette.light.strong == MarkdownSyntaxColorPalette.light.heading
                && MarkdownSyntaxColorPalette.dark.emphasis == MarkdownSyntaxColorPalette.dark.heading
                && MarkdownSyntaxColorPalette.dark.strong == MarkdownSyntaxColorPalette.dark.heading,
            "Markdown emphasis uses the heading blue"
        )
    }
}
