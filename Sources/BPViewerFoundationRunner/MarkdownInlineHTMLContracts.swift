import BPViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownInlineHTMLContracts() {
        let base = URL(fileURLWithPath: "/tmp/project")

        expect(MarkdownSafeInlineHTML.inline("<br>") == "<br />", "bare line break renders as a break")
        expect(MarkdownSafeInlineHTML.inline("<br/>") == "<br />", "self-closing line break renders as a break")
        expect(MarkdownSafeInlineHTML.inline("<BR />") == "<br />", "line break tag is case-insensitive")
        expect(MarkdownSafeInlineHTML.inline("<b>") == "<b>" && MarkdownSafeInlineHTML.inline("</b>") == "</b>", "bare formatting tags pass")
        expect(MarkdownSafeInlineHTML.inline("<KBD>") == "<kbd>", "formatting tags are normalized to lowercase")
        expect(MarkdownSafeInlineHTML.inline("<b class=\"x\">") == nil, "formatting tag with attributes keeps the placeholder")
        expect(MarkdownSafeInlineHTML.inline("<span>") == nil, "span is not on the allowlist")
        expect(MarkdownSafeInlineHTML.inline("<script>") == nil, "script is not on the allowlist")
        expect(MarkdownSafeInlineHTML.inline("<img src=x onerror=y>") == nil, "image with event handler keeps the placeholder")
        expect(MarkdownSafeInlineHTML.inline("<!-- note -->") == nil, "comment keeps the placeholder")
        expect(MarkdownSafeInlineHTML.block("<br>") == "<br />", "block made of a line break renders")
        expect(MarkdownSafeInlineHTML.block("<u> </u>") == "<u></u>", "block of allowlisted tags renders")
        expect(MarkdownSafeInlineHTML.block("<script>alert(1)</script>") == nil, "script block keeps the placeholder")

        let tableCell = try? SwiftMarkdownAdapter().render(
            source: "| Field | Note |\n| --- | --- |\n| one<br>two | **bold** <b>tag</b> |",
            baseURL: base
        )
        expect(tableCell?.html.contains("<td>one<br />two</td>") == true, "table cell line break renders")
        expect(tableCell?.html.contains("<strong>bold</strong> <b>tag</b>") == true, "table cell allowlisted formatting renders")

        let paragraph = try? SwiftMarkdownAdapter().render(
            source: "Line one<br />Line two and <span>raw</span>",
            baseURL: base
        )
        expect(paragraph?.html.contains("Line one<br />Line two") == true, "paragraph line break renders")
        expect(paragraph?.html.contains("<span class=\"bp-special-placeholder\"") == true, "other inline HTML keeps the placeholder")

        let blockBreak = try? SwiftMarkdownAdapter().render(source: "Before\n\n<br>\n\nAfter", baseURL: base)
        expect(blockBreak?.html.contains("<p><br /></p>") == true, "break as its own block renders")

        let scripted = try? SwiftMarkdownAdapter().render(
            source: "Text <script>alert('x')</script> and <img src=x onerror=alert(1)>",
            baseURL: base
        )
        expect(scripted?.html.contains("<script>alert") == false, "script in inline text is never emitted")
        expect(scripted?.html.contains("<img src=x") == false, "image tag in inline HTML is never emitted as markup")
    }
}
