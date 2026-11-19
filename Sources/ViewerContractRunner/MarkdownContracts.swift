import ViewerCore
import Foundation

extension ViewerContractRunner {
    static func runMarkdownContracts() throws {
        let result = try SwiftMarkdownAdapter().render(
            source: """
            # Heading

            # Heading

            This is **important** with [a link](chapter-2.md) and an image:

            ![Figure](images/figure.png)

            Math: $E = mc^2$

            $$\\frac{a}{b}$$

            <script>alert('unsafe')</script>
            """,
            baseURL: URL(fileURLWithPath: "/tmp/project/chapter-1")
        )

        expect(result.html.contains("<h1 id=\"heading\""), "heading")
        expect(result.blocks.first?.kind == .heading, "render result exposes editable blocks")
        expect(result.html.contains("data-bp-block-id=\"markdown-block-1\""), "rendered blocks expose stable edit IDs")
        expect(result.html.contains("<h1 id=\"heading-2\""), "duplicate heading id")
        expect(result.outline.map(\.title) == ["Heading", "Heading"], "Markdown outline titles")
        expect(result.outline.map(\.level) == [1, 1], "Markdown outline levels")
        expect(result.outline.map(\.id) == ["heading", "heading-2"], "Markdown outline IDs")
        expect(result.html.contains("<strong>important</strong>"), "strong text")
        expect(
            result.html.contains("href=\"viewer://open-local-file?path=/tmp/project/chapter-1/chapter-2.md\""),
            "relative link"
        )
        expect(result.html.contains("src=\"images/figure.png\""), "relative image")
        expect(result.baseURL.absoluteString.hasSuffix("/"), "directory base URL")
        expect(result.dependencies.contains(URL(fileURLWithPath: "/tmp/project/chapter-1/images/figure.png")), "image dependency")
        expect(result.html.contains("Content-Security-Policy"), "content security policy")
        expect(!result.html.contains("<script"), "raw html removed")
        expect(result.html.contains("<math"), "math")
        expect(result.html.contains("<msup>"), "superscript")
        expect(result.html.contains("<mfrac>"), "fraction")

        let thesisLinkResult = try SwiftMarkdownAdapter().render(
            source: """
            [Tema original no CSV](../../../thesis_choice/working/thesis_topics_master.csv)
            [Plano anterior do C409](../README.md)
            """,
            baseURL: URL(fileURLWithPath: "/tmp/thesis/thesis_proposal/c409/working")
        )
        expect(
            thesisLinkResult.html.contains("href=\"viewer://open-local-file?path=/tmp/thesis/thesis_choice/working/thesis_topics_master.csv\""),
            "cross-project relative link"
        )
        expect(
            thesisLinkResult.html.contains("href=\"viewer://open-local-file?path=/tmp/thesis/thesis_proposal/c409/README.md\""),
            "parent-directory relative link"
        )
        expect(
            thesisLinkResult.baseURL.appendingPathComponent("../../../thesis_choice/working/thesis_topics_master.csv")
                .standardizedFileURL.path == "/tmp/thesis/thesis_choice/working/thesis_topics_master.csv",
            "relative link path resolution"
        )
        let bridgedLinkURL = MarkdownPreviewLink.url(
            for: URL(fileURLWithPath: "/tmp/thesis/space folder/README.md")
        )
        expect(bridgedLinkURL?.scheme == "viewer", "local link bridge scheme")
        expect(
            bridgedLinkURL.flatMap(MarkdownPreviewLink.fileURL(from:))?.path
                == "/tmp/thesis/space folder/README.md",
            "local link bridge round trip"
        )
    }

    static func runMarkdownLocalImageContracts(root fixtureRoot: URL) throws {
        let imageDirectory = fixtureRoot.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let pixelData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        try pixelData.write(to: imageDirectory.appendingPathComponent("pixel.png"))

        let localImageResult = try SwiftMarkdownAdapter().render(
            source: "![Pixel](images/pixel.png)",
            baseURL: fixtureRoot
        )
        expect(localImageResult.html.contains("src=\"data:image/png;base64,"), "local image is embedded")
        expect(
            localImageResult.dependencies.contains(imageDirectory.appendingPathComponent("pixel.png")),
            "embedded local image remains a dependency"
        )
    }
}
