import BPViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownLinkContracts() {
        let base = URL(fileURLWithPath: "/tmp/project/chapter", isDirectory: true)

        expect(MarkdownAnchor.normalized("Seção") == "secao", "anchor key folds diacritics")
        expect(MarkdownAnchor.normalized("Secção") == "seccao", "anchor key folds cedilla to c, as the heading id does")
        expect(MarkdownAnchor.headingBase(for: "1. Introdução") == "1-introducao", "heading id keeps the numbered, accented text key")
        expect(MarkdownAnchor.headingBase(for: "!!!") == "section", "heading id falls back when nothing is kept")
        expect(MarkdownAnchor.candidates(forFragment: "seção") == ["seção", "secao"], "fragment tries the exact value, then the key")
        expect(MarkdownAnchor.candidates(forFragment: "secao") == ["secao"], "fragment key equal to the value is not repeated")
        expect(MarkdownAnchor.candidates(forFragment: "") == [], "empty fragment has no anchors")

        expect(
            MarkdownLinkResolver.target(forDestination: "#seção", baseURL: base) == .sameDocument(anchors: ["seção", "secao"]),
            "same-document fragment resolves to anchors"
        )
        expect(
            MarkdownLinkResolver.target(forDestination: "#Se%C3%A7%C3%A3o", baseURL: base) == .sameDocument(anchors: ["Seção", "secao"]),
            "percent-encoded fragment is decoded before matching"
        )
        expect(
            MarkdownLinkResolver.target(forDestination: "./a.md", baseURL: base)
                == .localFile(URL(fileURLWithPath: "/tmp/project/chapter/a.md"), fragment: nil),
            "dot-slash relative link resolves against the document directory"
        )
        expect(
            MarkdownLinkResolver.target(forDestination: "../b.md#Intro", baseURL: base)
                == .localFile(URL(fileURLWithPath: "/tmp/project/b.md"), fragment: "Intro"),
            "parent-directory link keeps its decoded fragment"
        )
        expect(
            MarkdownLinkResolver.target(forDestination: "my%20file.md", baseURL: base)
                == .localFile(URL(fileURLWithPath: "/tmp/project/chapter/my file.md"), fragment: nil),
            "percent-encoded path resolves to the file"
        )
        expect(
            MarkdownLinkResolver.target(forDestination: "100%.md", baseURL: base)
                == .localFile(URL(fileURLWithPath: "/tmp/project/chapter/100%.md"), fragment: nil),
            "invalid percent sequence keeps the literal path"
        )
        expect(
            MarkdownLinkResolver.target(forDestination: "https://example.com/a#b", baseURL: base) == nil,
            "external URL is not a local target"
        )

        expect(
            MarkdownLinkResolver.sameDocumentAnchors(
                for: URL(string: "file:///tmp/project/chapter/#seção")!,
                documentDirectory: base
            ) == ["seção", "secao"],
            "fragment on the document itself scrolls in place"
        )
        expect(
            MarkdownLinkResolver.sameDocumentAnchors(
                for: URL(string: "file:///tmp/project/chapter/other.md#x")!,
                documentDirectory: base
            ) == nil,
            "fragment on another file is not same-document"
        )
        expect(
            MarkdownLinkResolver.sameDocumentAnchors(
                for: URL(string: "file:///tmp/project/chapter/#x")!,
                documentDirectory: URL(fileURLWithPath: "/tmp/project/chapter")
            ) == ["x"],
            "document directory matches with or without a trailing slash"
        )

        let bridge = MarkdownPreviewLink.url(for: URL(fileURLWithPath: "/tmp/project/other.md"), fragment: "seção")
        expect(bridge.flatMap(MarkdownPreviewLink.fragment(from:)) == "seção", "bridge URL round-trips the decoded fragment")
        expect(bridge.flatMap(MarkdownPreviewLink.fileURL(from:))?.path == "/tmp/project/other.md", "bridge URL keeps the file path")
        expect(MarkdownPreviewLink.url(for: URL(fileURLWithPath: "/tmp/project/other.md"))?.fragment == nil, "bridge URL without a fragment")

        let sameDocument = try? SwiftMarkdownAdapter().render(
            source: "# Seção\n\n# Seção\n\nGo to [section](#seção) or [again](#Seção-2).",
            baseURL: base
        )
        expect(sameDocument?.html.contains("<h1 id=\"secao\"") == true, "heading id uses the shared key")
        expect(sameDocument?.html.contains("<h1 id=\"secao-2\"") == true, "duplicate heading gets a numbered key")
        expect(sameDocument?.html.contains("href=\"#secao\"") == true, "same-document link points at the normalized anchor")
        expect(sameDocument?.html.contains("href=\"#secao-2\"") == true, "numbered same-document link normalizes too")

        let crossFile = try? SwiftMarkdownAdapter().render(
            source: "[Other](other.md#Introdução)",
            baseURL: base
        )
        let crossFileHref = crossFile.flatMap { firstHref(in: $0.html) }
        expect(
            crossFileHref.flatMap(URL.init(string:)).flatMap(MarkdownPreviewLink.fragment(from:)) == "Introdução",
            "cross-file link carries its fragment"
        )
        expect(
            crossFileHref.flatMap(URL.init(string:)).flatMap(MarkdownPreviewLink.fileURL(from:))?.path == "/tmp/project/chapter/other.md",
            "cross-file link resolves its file"
        )

        let spaced = try? SwiftMarkdownAdapter().render(
            source: "[Spaced](<my file.md>) and [Encoded](my%20notes.md)",
            baseURL: base
        )
        let hrefs = spaced.map { allHrefs(in: $0.html) } ?? []
        expect(
            hrefs.compactMap(URL.init(string:)).compactMap(MarkdownPreviewLink.fileURL(from:)).map(\.path)
                == ["/tmp/project/chapter/my file.md", "/tmp/project/chapter/my notes.md"],
            "angle-bracket and percent-encoded destinations resolve to the file"
        )
        expect(
            spaced?.html.contains("data-bp-markdown-href=\"my%20notes.md\"") == true,
            "bridged link keeps its Markdown destination"
        )

        let external = try? SwiftMarkdownAdapter().render(source: "[Site](https://example.com/page#top)", baseURL: base)
        expect(external?.html.contains("href=\"https://example.com/page#top\"") == true, "external link is unchanged")
    }
}

private func allHrefs(in html: String) -> [String] {
    html.matches(of: /<a href="([^"]*)"/).map { String($0.output.1) }
}

private func firstHref(in html: String) -> String? {
    allHrefs(in: html).first
}
