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

@Test("fenced code without a language, or tagged as plain text, is not colored")
func languageLessCodeIsNotColored() throws {
    let highlighter = MarkdownPreviewCodeHighlighter.shared
    let prose = "software-factory/  igual: entrada, as decisões vivem na prática"
    #expect(highlighter.spans(code: prose, language: nil) == nil)
    #expect(highlighter.spans(code: prose, language: "") == nil)
    #expect(highlighter.spans(code: prose, language: "   ") == nil)
    #expect(highlighter.spans(code: prose, language: "text") == nil)
    #expect(highlighter.spans(code: prose, language: "plaintext") == nil)
    #expect(highlighter.spans(code: prose, language: "Plain title=\"x\"") == nil)

    let html = try renderedHTML("```\n\(prose)\n```\n", highlighter: highlighter)
    let block = try #require(html.range(of: "<pre").flatMap { start in
        html.range(of: "</pre>", range: start.lowerBound..<html.endIndex).map { start.lowerBound..<$0.upperBound }
    }.map { String(html[$0]) })
    #expect(!block.contains("light-dark("))
}

@Test("only the info string's first word decides whether a language is highlighted")
func highlightableLanguageRule() {
    #expect(MarkdownPreviewCodeHighlighter.isHighlightable(language: "swift"))
    #expect(MarkdownPreviewCodeHighlighter.isHighlightable(language: "python title=\"x.py\""))
    #expect(MarkdownPreviewCodeHighlighter.isHighlightable(language: "console"))
    #expect(!MarkdownPreviewCodeHighlighter.isHighlightable(language: "TXT"))
    #expect(!MarkdownPreviewCodeHighlighter.isHighlightable(language: nil))
}

@Test("unknown or missing language does not crash the preview highlighter")
func unknownLanguageDoesNotCrash() {
    let highlighter = MarkdownPreviewCodeHighlighter.shared
    let spans = highlighter.spans(code: "let x = 42", language: "no-such-language-xyz")
    #expect(spans == nil || spans?.isEmpty == false)
    _ = highlighter.spans(code: "", language: nil)
}
