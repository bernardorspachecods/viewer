import Testing
import Foundation
@testable import ViewerApp
@testable import ViewerCore

private func renderedHTML(_ source: String, highlighter: any MarkdownCodeHighlighting) throws -> String {
    try SwiftMarkdownAdapter(codeHighlighter: highlighter)
        .render(source: source, baseURL: URL(fileURLWithPath: "/tmp/viewer-test/", isDirectory: true))
        .html
}

@Test("preview colors fenced code with the editor's highlight.js theme in both appearances")
func previewColorsFencedCodeWithBothThemes() throws {
    let highlighter = MarkdownPreviewCodeHighlighter.shared
    let spans = try #require(highlighter.spans(code: "let x = 42", language: "swift"))
    #expect(!spans.isEmpty)
    #expect(spans.contains { $0.lightColorHex != $0.darkColorHex })
    #expect(spans.allSatisfy { $0.lightColorHex != nil || $0.darkColorHex != nil })

    let html = try renderedHTML("```swift\nlet x = 42\n```\n", highlighter: highlighter)
    #expect(html.contains("light-dark("))
}

@Test("unknown or missing language does not crash the preview highlighter")
func unknownLanguageDoesNotCrash() {
    let highlighter = MarkdownPreviewCodeHighlighter.shared
    let spans = highlighter.spans(code: "let x = 42", language: "no-such-language-xyz")
    #expect(spans == nil || spans?.isEmpty == false)
    _ = highlighter.spans(code: "", language: nil)
}
