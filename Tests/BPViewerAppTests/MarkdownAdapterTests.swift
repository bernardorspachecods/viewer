import Testing
import Foundation
import Darwin
import AppKit
@testable import BPViewerApp
@testable import BPViewerCore

@Test("coalesces repeated syntax highlighting requests without losing a pending edit")
func coalescesRepeatedSyntaxHighlightingRequests() {
    let palette = MarkdownSyntaxColorPalette.light
    let request = SourceSyntaxHighlightingRequest(
        source: "# Title\n\n**important**",
        syntaxHighlighting: .markdown(palette)
    )
    var gate = SourceSyntaxHighlightingGate()

    let firstSchedule = gate.shouldSchedule(request)
    let duplicateSchedule = gate.shouldSchedule(request)
    #expect(firstSchedule)
    #expect(!duplicateSchedule)

    gate.markApplied(request)
    let appliedSchedule = gate.shouldSchedule(request)
    #expect(!appliedSchedule)

    let changedRequest = SourceSyntaxHighlightingRequest(
        source: "# Title\n\n*important*",
        syntaxHighlighting: .markdown(palette)
    )
    let changedSchedule = gate.shouldSchedule(changedRequest)
    #expect(changedSchedule)
}

@Test("renders core Markdown and keeps resource URLs relative")
func rendersCoreMarkdownAndKeepsResourceURLsRelative() throws {
        let source = """
        # Heading

        This is **important** with [a link](chapter-2.md) and an image:

        ![Figure](images/figure.png)
        """

        let result = try SwiftMarkdownAdapter().render(
            source: source,
            baseURL: URL(fileURLWithPath: "/tmp/project/chapter-1")
        )

    #expect(result.html.contains("<h1 id=\"heading\""))
    #expect(result.html.contains("<strong>important</strong>"))
    #expect(result.html.contains("href=\"bpviewer://open-local-file?path=/tmp/project/chapter-1/chapter-2.md\""))
    #expect(result.html.contains("src=\"images/figure.png\""))
    #expect(result.html.contains("loading=\"lazy\""))
    #expect(result.html.contains("decoding=\"async\""))
}

@Test("keeps the Markdown page width stable while the preview resizes")
func keepsMarkdownPageWidthStableWhilePreviewResizes() throws {
    let result = try SwiftMarkdownAdapter().render(
        source: "# Heading",
        baseURL: URL(fileURLWithPath: "/tmp/project")
    )

    #expect(result.html.contains("<main class=\"bp-document-content\">"))
    #expect(result.html.contains("body {"))
    #expect(result.html.contains("width: 100%;"))
    #expect(result.html.contains("overflow-x: hidden;"))
    #expect(result.html.contains("scrollbar-gutter: stable;"))
    #expect(result.html.contains("margin: 0;"))
    #expect(result.html.contains(".bp-document-content {"))
    #expect(result.html.contains("max-width: 860px;"))
    #expect(result.html.contains(".bp-document-content > * {"))
    #expect(result.html.contains("content-visibility: auto;"))
    #expect(result.html.contains("contain-intrinsic-size: auto 72px;"))
}

@Test("clamps and persists the outline width per document")
func clampsAndPersistsOutlineWidthPerDocument() throws {
    let state = DocumentState(
        outlineVisible: true,
        outlineWidth: 340
    )
    let encoded = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(DocumentState.self, from: encoded)

    #expect(decoded.outlineVisible)
    #expect(decoded.outlineWidth == 340)
    #expect(DocumentState(outlineWidth: 80).outlineWidth == DocumentOutlineSizing.minimumWidth)
    #expect(DocumentState(outlineWidth: 900).outlineWidth == DocumentOutlineSizing.maximumWidth)
}

@Test("keeps both panes usable while resizing a split view")
func keepsBothSplitPanesUsableWhileResizing() {
    #expect(
        ResizableSplitSizing.clampedLeadingWidth(
            totalWidth: 1000,
            proposedWidth: 700,
            minimumLeadingWidth: 280,
            minimumTrailingWidth: 280
        ) == 700
    )
    #expect(
        ResizableSplitSizing.clampedLeadingWidth(
            totalWidth: 1000,
            proposedWidth: 120,
            minimumLeadingWidth: 280,
            minimumTrailingWidth: 280
        ) == 280
    )
    #expect(
        ResizableSplitSizing.clampedLeadingWidth(
            totalWidth: 1000,
            proposedWidth: 900,
            minimumLeadingWidth: 280,
            minimumTrailingWidth: 280
        ) == 715
    )
}

@Test("does not pass raw HTML through to the preview")
func doesNotPassRawHTMLThroughToThePreview() throws {
        let source = """
        # Safe title

        <script>alert('unsafe')</script>
        <span>raw HTML</span>
        """

        let result = try SwiftMarkdownAdapter().render(
            source: source,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )

    #expect(result.html.contains("<h1 id=\"safe-title\""))
    #expect(!result.html.contains("<script"))
    #expect(!result.html.contains("<span>raw HTML</span>"))
}

@Test("renders common TeX math as local MathML")
func rendersCommonTeXMathAsLocalMathML() throws {
    let result = try SwiftMarkdownAdapter().render(
        source: "Einstein: $E = mc^2$\n\n$$\\frac{a}{b}$$",
        baseURL: URL(fileURLWithPath: "/tmp/project")
    )

    #expect(result.html.contains("<math"))
    #expect(result.html.contains("<msup>"))
    #expect(result.html.contains("<mfrac>"))
}

@Test("exposes a navigable outline with stable heading IDs")
func exposesNavigableMarkdownOutline() throws {
    let source = """
    # Introduction

    ## Methods

    ```markdown
    # Not a heading
    ```

    ## Methods
    """

    let result = try SwiftMarkdownAdapter().render(
        source: source,
        baseURL: URL(fileURLWithPath: "/tmp/project")
    )

    #expect(result.outline.map(\.title) == ["Introduction", "Methods", "Methods"])
    #expect(result.outline.map(\.level) == [1, 2, 2])
    #expect(result.outline.map(\.id) == ["introduction", "methods", "methods-2"])
    #expect(result.outline.allSatisfy { result.html.contains("id=\"\($0.id)\"") })
}
