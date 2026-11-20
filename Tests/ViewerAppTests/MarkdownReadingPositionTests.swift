import AppKit
import MarkdownEngine
import SwiftUI
import Testing
@testable import ViewerApp
@testable import ViewerCore

// Switching between the preview and the editor keeps the same text at the same height: both
// report and restore a `MarkdownReadingPosition` (block start in UTF-8, top edge below the view).

@Test("rendered blocks carry their UTF-8 start offset in the source")
func renderedBlocksCarryUTF8SourceOffsets() throws {
    // "ção" and the emoji take more bytes than characters, so a character offset would be wrong.
    let source = "Olá, ação 🙂\n\nSecond paragraph.\n\n## Heading\n"
    let html = try SwiftMarkdownAdapter().render(
        source: source,
        baseURL: URL(fileURLWithPath: "/tmp")
    ).html

    let secondStart = source.utf8.distance(
        from: source.utf8.startIndex,
        to: try #require(source.range(of: "Second")).lowerBound
    )
    let headingStart = source.utf8.distance(
        from: source.utf8.startIndex,
        to: try #require(source.range(of: "## Heading")).lowerBound
    )
    #expect(html.contains("data-bp-source-offset=\"0\""))
    #expect(html.contains("data-bp-source-offset=\"\(secondStart)\""))
    #expect(html.contains("data-bp-source-offset=\"\(headingStart)\""))
}

@Test("a reading position without a block still decodes, and a block position round-trips")
func readingPositionCodable() throws {
    let legacy = Data(#"{"scrollY":120,"anchorID":"intro","anchorOffset":4}"#.utf8)
    let old = try JSONDecoder().decode(MarkdownReadingPosition.self, from: legacy)
    #expect(old.sourceOffset == nil)
    #expect(old.blockTop == 0)

    let position = MarkdownReadingPosition(
        scrollY: 300, anchorID: nil, anchorOffset: 0, sourceOffset: 42, blockTop: 17.5
    )
    let decoded = try JSONDecoder().decode(
        MarkdownReadingPosition.self,
        from: JSONEncoder().encode(position)
    )
    #expect(decoded == position)
}

@MainActor
@Test("editor text drops half the extra line height, tables do not, and it scales with zoom")
func editorTextDrop() {
    let tokens = MarkdownStyleTokens.shared
    let paragraph = MarkdownLiveEditorStyle.textDrop(kind: .paragraph, tokens: tokens, zoom: 1)
    let zoomed = MarkdownLiveEditorStyle.textDrop(kind: .paragraph, tokens: tokens, zoom: 2)

    #expect(paragraph > 0)
    #expect(MarkdownLiveEditorStyle.textDrop(kind: .table, tokens: tokens, zoom: 1) == 0)
    #expect(MarkdownLiveEditorStyle.textDrop(kind: nil, tokens: tokens, zoom: 1) == paragraph)
    #expect(abs(zoomed - 2 * paragraph) < 0.6)
}

// MARK: Editor geometry

@MainActor
private func findNativeTextView(in view: NSView) -> NSTextView? {
    if String(describing: type(of: view)).contains("NativeTextView"), let textView = view as? NSTextView {
        return textView
    }
    return view.subviews.lazy.compactMap { findNativeTextView(in: $0) }.first
}

@MainActor
private func longEditor(source: String) async throws -> (NSWindow, NSTextView) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = NSHostingView(rootView: NativeTextViewWrapper(
        text: Binding.constant(source),
        configuration: MarkdownLiveEditorStyle.configuration(
            base: .default, tokens: .shared, limitsTextWidth: true
        ),
        fontSize: CGFloat(MarkdownStyleTokens.shared.bodyFontSize),
        documentId: "viewport-test",
        isFocused: Binding.constant(false)
    ))
    window.contentView?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(500))
    return (window, try #require(window.contentView.flatMap { findNativeTextView(in: $0) }))
}

@MainActor
@Test("the editor restores a reading position and reports the same one back", .serialized)
func editorViewportRoundTrip() async throws {
    let source = (1...60).map { "Paragraph number \($0) with some words in it." }.joined(separator: "\n\n")
    let (window, textView) = try await longEditor(source: source)
    withExtendedLifetime(window) {}
    let starts = MarkdownBlockDocument(source: source).blocks.map(\.sourceRange.startOffset).sorted()
    let target = try #require(starts.dropFirst(30).first)
    // The block starts 10 points above the top of the view, so it is the block at the top.
    let wanted = MarkdownReadingPosition(
        scrollY: 0, anchorID: nil, anchorOffset: 0, sourceOffset: target, blockTop: -10
    )

    // The editor's heights settle as text is laid out, so it restores in timed passes
    // (`MarkdownLiveEditorBridge.applyEntryPosition`); the position converges.
    for _ in 0..<4 {
        #expect(MarkdownLiveEditorViewport.restore(
            wanted, in: textView, source: source, zoom: 1, textDrop: { _ in 0 }
        ))
        try await Task.sleep(for: .milliseconds(150))
    }
    let reported = try #require(MarkdownLiveEditorViewport.position(
        in: textView, source: source, blockStarts: starts, zoom: 1, textDrop: { _ in 0 }
    ))

    #expect(reported.sourceOffset == target)
    #expect(abs(reported.blockTop - -10) < 1)
}

@MainActor
@Test("restoring a position without a block start does nothing", .serialized)
func editorViewportIgnoresPositionWithoutBlock() async throws {
    let source = "One.\n\nTwo."
    let (window, textView) = try await longEditor(source: source)
    withExtendedLifetime(window) {}
    let position = MarkdownReadingPosition(scrollY: 50, anchorID: nil, anchorOffset: 0)

    #expect(!MarkdownLiveEditorViewport.restore(
        position, in: textView, source: source, zoom: 1, textDrop: { _ in 0 }
    ))
}
