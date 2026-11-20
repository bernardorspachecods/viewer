import AppKit
import MarkdownEngine
import MarkdownEngineLatex
import SwiftUI
import Testing

@MainActor
private func nativeTextView(in view: NSView) -> NSTextView? {
    if String(describing: type(of: view)).contains("NativeTextView"), let textView = view as? NSTextView {
        return textView
    }
    return view.subviews.lazy.compactMap { nativeTextView(in: $0) }.first
}

/// The real editor (with formula rendering on) in an offscreen window, caret at the start.
@MainActor
private func editor(showing text: String) async throws -> (NSWindow, NSTextView) {
    var configuration = MarkdownEditorConfiguration.default
    configuration.services = MarkdownEditorServices(latex: SwiftMathBridge())
    let binding = Binding.constant(text)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = NSHostingView(rootView: NativeTextViewWrapper(
        text: binding,
        configuration: configuration,
        fontSize: 15,
        documentId: "caret-test",
        isFocused: Binding.constant(true)
    ))
    window.contentView?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(400))
    let textView = try #require(window.contentView.flatMap { nativeTextView(in: $0) })
    window.makeFirstResponder(textView)
    textView.setSelectedRange(NSRange(location: 0, length: 0))
    return (window, textView)
}

@MainActor
@Test(
    "→ walks through a rendered inline formula and out of it, to the end of the text",
    .serialized,
    arguments: [
        "Energy $E = mc^2$ after the formula.",
        "Energy $x$ after.",
        "Energy $x$after.",
        "$x$ $y$ and $\\frac{1}{2}$ end"
    ]
)
func rightArrowLeavesInlineFormula(_ text: String) async throws {
    let (window, textView) = try await editor(showing: text)
    withExtendedLifetime(window) {}
    let length = (text as NSString).length
    var previous = 0
    for _ in 0..<(length + 2) {
        textView.moveRight(nil)
        let location = textView.selectedRange().location
        #expect(location >= previous, "the caret went back from \(previous) to \(location)")
        previous = location
    }
    #expect(previous == length)
}
