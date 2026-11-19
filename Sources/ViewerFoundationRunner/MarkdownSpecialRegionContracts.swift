import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownImageAndMathContracts() {
        let imageSource = "![Old label](images/figure.png \"Old title\")"
        let imageDocument = MarkdownBlockDocument(source: imageSource)
        let imageRegion = imageDocument.specialRegions.first
        expect(imageRegion?.kind == .image, "images expose specialized source regions")
        let editedImage = imageRegion.map {
            imageDocument.replacingSpecialEdits([
                MarkdownSpecialEdit(
                    id: $0.id,
                    kind: .image,
                    replacement: "![New label](images/figure.png \"New title\")"
                )
            ])
        }
        expect(editedImage?.source == "![New label](images/figure.png \"New title\")", "visual image edits preserve Markdown image syntax")
        let renderedImage = try? SwiftMarkdownAdapter().render(
            source: imageSource,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedImage?.html.contains("data-bp-special-kind=\"image\"") == true, "images expose a specialized editing hook")

        let mathSource = "$$\na + b\n$$"
        let mathDocument = MarkdownBlockDocument(source: mathSource)
        expect(mathDocument.specialRegions.first?.kind == .math, "block formulas expose specialized source regions")
        let editedMath = mathDocument.specialRegions.first.map {
            mathDocument.replacingSpecialEdits([
                MarkdownSpecialEdit(id: $0.id, kind: .math, replacement: "$$\na - b\n$$")
            ])
        }
        expect(editedMath?.source == "$$\na - b\n$$", "visual formula edits preserve delimiters")
        let renderedMath = try? SwiftMarkdownAdapter().render(
            source: mathSource,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedMath?.html.contains("data-bp-special-kind=\"math\"") == true, "block formulas expose a specialized editing hook")
        let inlineMath = try? SwiftMarkdownAdapter().render(
            source: "Inline $a+b$ formula",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(
            // Inline formulas render as MathML inside a `math-inline` span, not as the
            // dashed placeholder box that raw HTML and front matter use.
            inlineMath?.html.contains("class=\"math-inline\"") == true
                && inlineMath?.html.contains("data-bp-special-kind=\"math\"") == true,
            "inline formulas expose a specialized editing hook"
        )
    }

    mutating func runMarkdownHTMLAndFrontMatterContracts() {
        let htmlSource = "<div class=\"note\">Raw HTML</div>"
        let htmlDocument = MarkdownBlockDocument(source: htmlSource)
        expect(htmlDocument.specialRegions.first?.kind == .html, "raw HTML exposes specialized source regions")
        let renderedHTML = try? SwiftMarkdownAdapter().render(
            source: htmlSource,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedHTML?.html.contains("data-bp-special-kind=\"html\"") == true, "raw HTML exposes a specialized editing hook")
        let inlineHTML = try? SwiftMarkdownAdapter().render(
            source: "Text <span>raw</span>",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(inlineHTML?.html.contains("data-bp-special-kind=\"html\"") == true, "inline HTML exposes a specialized editing hook")

        let frontMatterSource = "---\ntitle: Draft\n---\n\n# Body"
        let frontMatterDocument = MarkdownBlockDocument(source: frontMatterSource)
        expect(frontMatterDocument.blocks.first?.kind == .frontMatter, "front matter remains a distinct document region")
        expect(frontMatterDocument.specialRegions.first?.kind == .frontMatter, "front matter exposes specialized source regions")
        let renderedFrontMatter = try? SwiftMarkdownAdapter().render(
            source: frontMatterSource,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedFrontMatter?.html.contains("data-bp-special-kind=\"frontMatter\"") == true, "front matter exposes a specialized editing hook")

        let protected = try? SwiftMarkdownAdapter().render(
            source: "![image](photo.png)",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(protected?.html.contains("data-bp-editable=\"false\"") == true, "unsupported Markdown regions remain protected")
    }
}

extension Runner {
    mutating func runFrontMatterPropertyContracts() {
        let flat = "---\ntitle: \"Hello\"\ntags: [a, b]\ndescription: first line\n  continues here\n---"
        let parsed = MarkdownFrontMatterProperties.parse(flat)
        expect(parsed?.map(\.key) == ["title", "tags", "description"], "front matter properties keep their keys in order")
        expect(parsed?.map(\.value) == ["Hello", "[a, b]", "first line continues here"], "front matter values drop quotes and join continuation lines")
        expect(MarkdownFrontMatterProperties.parse("---\ntags:\n  - a\n---") == nil, "front matter with a list falls back to text")
        expect(MarkdownFrontMatterProperties.parse("---\nnote: |\n  block\n---") == nil, "front matter with a block scalar falls back to text")
        expect(MarkdownFrontMatterProperties.parse("not front matter") == nil, "text without delimiters is not front matter")

        let rendered = try? SwiftMarkdownAdapter().render(
            source: "---\ntitle: A\n---\n\n# Body\n\n<!-- note -->\n\n<div>x</div>\n",
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )
        expect(rendered?.html.contains("<aside class=\"bp-front-matter\"") == true, "flat front matter renders as a property list")
        expect(rendered?.html.contains("<dt>title</dt><dd>A</dd>") == true, "front matter property list shows the pair")
        expect(rendered?.html.contains("bp-html-comment") == true, "an HTML comment keeps a quiet placeholder")
        expect(rendered?.html.contains("bp-html-block") == true, "other HTML keeps the labelled placeholder")
    }
}
