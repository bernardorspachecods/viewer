import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownStyleContracts() {
        let tokens = MarkdownStyleTokens.shared
        let rendered = try? SwiftMarkdownAdapter().render(
            source: "# Title\n\nParagraph\n\n| Left | Center |\n| :--- | :---: |\n| a | b |",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        let html = rendered?.html ?? ""
        let bodySize = "font-size: \(Int(tokens.bodyFontSize))px"
        expect(html.contains(bodySize), "preview body font size comes from the shared style tokens")
        let h1Scale = "h1 { font-size: \(tokens.headingScale(level: 1))em"
        expect(html.contains(h1Scale), "preview h1 scale comes from the shared style tokens")
        expect(html.contains("<th style=\"text-align:center\">"), "GFM center column alignment is emitted on its header cell")
        expect(html.contains("<td style=\"text-align:center\">b</td>"), "GFM center column alignment is emitted on its body cell")
        expect(!html.contains("-apple-system-body"), "preview no longer uses the -apple-system-body font shorthand")

        let comment = try? SwiftMarkdownAdapter().render(
            source: "Text <!-- a note --> more",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        let commentHTML = comment?.html ?? ""
        expect(commentHTML.contains("> a note </span>"), "an inline comment shows only its text, as the editor does")
        expect(!commentHTML.contains("&lt;!--"), "an inline comment does not show its markers")
        let tag = try? SwiftMarkdownAdapter().render(
            source: "Text <span> more",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(tag?.html.contains("&lt;span&gt;") == true, "a stray tag still shows as source")
    }
}
