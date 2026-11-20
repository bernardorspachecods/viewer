import Testing
import Foundation
@testable import ViewerCore

private struct FakeHighlighter: MarkdownCodeHighlighting {
    let result: [MarkdownCodeSpan]
    func spans(code: String, language: String?) -> [MarkdownCodeSpan]? { result }
}

/// Strips the tags and unescapes the entities the renderer emits: the text a reader sees.
private func visibleText(ofCodeHTML html: String) -> String {
    let stripped = html.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    return stripped
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
}

private func codeHTML(_ source: String, spans: [MarkdownCodeSpan]) throws -> String {
    let html = try SwiftMarkdownAdapter(codeHighlighter: FakeHighlighter(result: spans))
        .render(source: source, baseURL: URL(fileURLWithPath: "/tmp/viewer-test/", isDirectory: true))
        .html
    let start = try #require(html.range(of: "<code"))
    let end = try #require(html.range(of: "</code>", range: start.upperBound..<html.endIndex))
    return String(html[start.lowerBound..<end.upperBound])
}

private let sampleCode = "let a = \"<b>&\" 😀 + 1"
/// A fenced block's code keeps its trailing newline.
private let sampleBlockText = sampleCode + "\n"

@Test("highlighted code emits light-dark spans and keeps the visible text")
func highlightedCodeEmitsLightDarkSpans() throws {
    let spans = [
        MarkdownCodeSpan(range: 0..<3, lightColorHex: "#D73A49", darkColorHex: "#FF7B72"),
        MarkdownCodeSpan(range: 8..<11, lightColorHex: "#032F62", darkColorHex: nil),
    ]
    let html = try codeHTML("```swift\n\(sampleCode)\n```\n", spans: spans)
    #expect(html.contains("color:light-dark(#D73A49,#FF7B72)"))
    #expect(html.contains("color:light-dark(#032F62,-apple-system-label)"))
    #expect(visibleText(ofCodeHTML: html) == sampleBlockText)
}

@Test("overlapping, unsorted and out-of-range spans never drop or duplicate text")
func badSpansKeepTheText() throws {
    let spans = [
        MarkdownCodeSpan(range: 12..<40, lightColorHex: "#000000", darkColorHex: "#FFFFFF"),
        MarkdownCodeSpan(range: 0..<5, lightColorHex: "#111111", darkColorHex: "#EEEEEE"),
        MarkdownCodeSpan(range: 3..<8, lightColorHex: "#222222", darkColorHex: "#DDDDDD"),
        MarkdownCodeSpan(range: 9..<10, lightColorHex: "not-a-color", darkColorHex: nil),
        MarkdownCodeSpan(range: 2..<2, lightColorHex: "#333333", darkColorHex: "#CCCCCC"),
    ]
    let html = try codeHTML("```\n\(sampleCode)\n```\n", spans: spans)
    #expect(visibleText(ofCodeHTML: html) == sampleBlockText)
    #expect(!html.contains("#222222"))
    #expect(!html.contains("not-a-color"))
}

@Test("without spans the code block is unchanged")
func noSpansLeavesCodePlain() throws {
    let html = try codeHTML("```\n\(sampleCode)\n```\n", spans: [])
    #expect(!html.contains("light-dark("))
    #expect(visibleText(ofCodeHTML: html) == sampleBlockText)
}
