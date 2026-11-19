//
//  FrontMatterTests.swift
//  MarkdownEngineTests
//
//  VIEWER PATCH: YAML front matter shown as a card. The detection follows
//  Viewer's Core scanner; the styling is checked on the attributes the styler
//  emits, so no window is needed.
//

import AppKit
import Testing
@testable import MarkdownEngine

@Suite("Front matter")
struct FrontMatterTests {

    // MARK: - Detection

    private func region(_ text: String) -> FrontMatterRegion? {
        FrontMatter.region(in: text as NSString)
    }

    @Test("a first-line --- closed by --- or ... is front matter")
    func detectsClosedRegion() throws {
        let dashes = try #require(region("---\ntitle: a\n---\nBody"))
        #expect(dashes.range == NSRange(location: 0, length: 16))
        #expect(dashes.openLine == NSRange(location: 0, length: 4))
        #expect(dashes.closeLine == NSRange(location: 13, length: 4))

        let dots = try #require(region("---\ntitle: a\n...\nBody"))
        #expect(dots.closeLine == NSRange(location: 13, length: 4))
    }

    @Test("the fences may carry spaces and tabs around them")
    func trimsSpacesAndTabs() {
        #expect(region("  ---\t\na: b\n --- \n") != nil)
    }

    @Test("no closing line, or --- not on line 1, is not front matter")
    func rejectsOthers() {
        #expect(region("---\ntitle: a\n") == nil)
        #expect(region("\n---\ntitle: a\n---\n") == nil)
        #expect(region("Text\n---\ntitle: a\n---\n") == nil)
        #expect(region("--\na: b\n---\n") == nil)
        #expect(region("----\na: b\n---\n") == nil)
        #expect(region("") == nil)
    }

    @Test("an opening ... is not front matter, a closing line needs exactly three marks")
    func fenceShape() {
        #expect(region("...\na: b\n---\n") == nil)
        #expect(region("---\na: b\n....\n") == nil)
        #expect(region("---\na: b\n--\n") == nil)
    }

    @Test("a closing line at the end of the document without a newline counts")
    func closingLineWithoutNewline() throws {
        let found = try #require(region("---\na: b\n---"))
        #expect(found.closeLine == NSRange(location: 9, length: 3))
        #expect(found.fenceLine(containing: 12) == 1)
        #expect(found.fenceLine(containing: 0) == 0)
        #expect(found.fenceLine(containing: 5) == nil)
        let withNewline = try #require(region("---\na: b\n---\n"))
        #expect(withNewline.fenceLine(containing: 13) == nil)
    }

    // MARK: - Styling

    private func style(_ text: String, enabled: Bool = true, caret: Int = -1) -> [StyledRange] {
        var configuration = MarkdownEditorConfiguration.default
        configuration.frontMatter = FrontMatterStyle(isEnabled: enabled)
        let font = NSFont.systemFont(ofSize: 20)
        return MarkdownStyler.styleAttributes(
            text: text, fontName: font.fontName, fontSize: 20,
            caretLocation: caret, activeTokenIndices: [], configuration: configuration
        )
    }

    /// The value the styler leaves on the character at `index` (later ranges win).
    private func value(_ key: NSAttributedString.Key, at index: Int, in ranges: [StyledRange]) -> Any? {
        ranges.last { NSLocationInRange(index, $0.range) && $0.attributes[key] != nil }?.attributes[key]
    }

    private let sample = "---\ntitle: Front\ntags: [a, b]\n---\n\n# Heading\n"

    @Test("disabled by default: the --- lines stay thematic breaks and nothing is a card")
    func disabledChangesNothing() {
        #expect(FrontMatterStyle.default.isEnabled == false)
        let ranges = style(sample, enabled: false)
        #expect(value(.thematicBreak, at: 0, in: ranges) as? Bool == true)
        #expect(value(.frontMatterCard, at: 5, in: ranges) == nil)
    }

    @Test("enabled: the fence lines are not thematic breaks and every line of the card is tagged")
    func cardLines() throws {
        let ranges = style(sample)
        #expect(value(.thematicBreak, at: 0, in: ranges) == nil)
        #expect(value(.thematicBreak, at: 30, in: ranges) == nil)
        let positions = [0, 4, 17, 30].map { (value(.frontMatterCard, at: $0, in: ranges) as? FrontMatterCardPaint)?.position }
        #expect(positions == [.top, .middle, .middle, .bottom])
        // The blank line and the heading after the card are not part of it.
        #expect(value(.frontMatterCard, at: 34, in: ranges) == nil)
        #expect(value(.frontMatterCard, at: 36, in: ranges) == nil)
    }

    @Test("enabled: the fences are hidden and as high as the vertical padding, the text lines use the card's look")
    func cardGeometryAndColors() throws {
        let configuration = FrontMatterStyle(isEnabled: true)
        let ranges = style(sample)
        let fence = try #require(value(.paragraphStyle, at: 0, in: ranges) as? NSParagraphStyle)
        // Padding minus the leading TextKit puts above a text line: the card centres its text.
        #expect(fence.minimumLineHeight > 0 && fence.minimumLineHeight <= configuration.verticalPadding)
        #expect(fence.minimumLineHeight == fence.maximumLineHeight)
        #expect(value(.foregroundColor, at: 0, in: ranges) as? NSColor == NSColor.clear)

        let row = try #require(value(.paragraphStyle, at: 12, in: ranges) as? NSParagraphStyle)
        #expect(row.firstLineHeadIndent == configuration.horizontalPadding)
        #expect(row.headIndent == configuration.horizontalPadding)
        #expect(row.tailIndent == -configuration.horizontalPadding)
        let size = (value(.font, at: 12, in: ranges) as? NSFont)?.pointSize
        #expect(size == 20 * configuration.fontSizeScale)
        #expect(row.minimumLineHeight == 20 * configuration.fontSizeScale * configuration.lineHeightMultiple)
        #expect(value(.foregroundColor, at: 12, in: ranges) as? NSColor == configuration.textColor)
    }

    @Test("enabled: the key before the first colon is semibold in the key color, the value is not")
    func keyStyling() throws {
        let configuration = FrontMatterStyle(isEnabled: true)
        let ranges = style(sample)
        // "title" starts at 4, the value "Front" at 11.
        let key = try #require(value(.font, at: 4, in: ranges) as? NSFont)
        let valueFont = try #require(value(.font, at: 11, in: ranges) as? NSFont)
        #expect(key.fontDescriptor.symbolicTraits.contains(.bold) || weight(of: key) > weight(of: valueFont))
        #expect(value(.foregroundColor, at: 4, in: ranges) as? NSColor == configuration.keyColor)
        #expect(value(.foregroundColor, at: 11, in: ranges) as? NSColor == configuration.textColor)
        #expect(FrontMatterStyleKeyProbe.keyRange(in: "tags: [a, b]\n") == NSRange(location: 0, length: 4))
        #expect(FrontMatterStyleKeyProbe.keyRange(in: "no key\n") == nil)
        #expect(FrontMatterStyleKeyProbe.keyRange(in: ": value\n") == nil)
    }

    @Test("YAML inside the card is not Markdown: a # comment is no heading, [a, b] and URLs get no link styling")
    func yamlStaysPlain() {
        let text = "---\n# comment\nurl: https://example.com\n---\n"
        let ranges = style(text)
        #expect(value(.link, at: 20, in: ranges) == nil)
        let commentFont = value(.font, at: 6, in: ranges) as? NSFont
        #expect(commentFont?.pointSize == 20 * FrontMatterStyle.default.fontSizeScale)
    }

    @Test("a caret on a fence line shows its --- muted; elsewhere it stays hidden")
    func fenceRevealsUnderCaret() {
        let hidden = style(sample, caret: 8)
        #expect(value(.foregroundColor, at: 0, in: hidden) as? NSColor == NSColor.clear)
        #expect(value(.foregroundColor, at: 30, in: hidden) as? NSColor == NSColor.clear)

        let onOpen = style(sample, caret: 2)
        #expect(value(.foregroundColor, at: 0, in: onOpen) as? NSColor != NSColor.clear)
        #expect(value(.foregroundColor, at: 30, in: onOpen) as? NSColor == NSColor.clear)

        let onClose = style(sample, caret: 31)
        #expect(value(.foregroundColor, at: 0, in: onClose) as? NSColor == NSColor.clear)
        #expect(value(.foregroundColor, at: 30, in: onClose) as? NSColor != NSColor.clear)
    }

    @Test("without a closing line the document stays ordinary Markdown")
    func unclosedIsNotACard() {
        let ranges = style("---\ntitle: a\n\nBody\n")
        #expect(value(.frontMatterCard, at: 5, in: ranges) == nil)
        #expect(value(.thematicBreak, at: 0, in: ranges) as? Bool == true)
    }

    @Test("a scoped restyle of one card line still styles it as part of the card")
    func scopedRestyleKeepsCard() {
        var configuration = MarkdownEditorConfiguration.default
        configuration.frontMatter = FrontMatterStyle(isEnabled: true)
        let font = NSFont.systemFont(ofSize: 20)
        let line = (sample as NSString).paragraphRange(for: NSRange(location: 8, length: 0))
        let ranges = MarkdownStyler.styleAttributes(
            text: sample, fontName: font.fontName, fontSize: 20,
            caretLocation: 8, activeTokenIndices: [], scopedRanges: [line], configuration: configuration
        )
        #expect((value(.frontMatterCard, at: 8, in: ranges) as? FrontMatterCardPaint)?.position == .middle)
        #expect(value(.frontMatterCard, at: 0, in: ranges) == nil)
    }

    private func weight(of font: NSFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        return traits?[.weight] as? CGFloat ?? 0
    }
}

/// `MarkdownASTStyler.keyRange` takes a line inside a document; this feeds it one line.
private enum FrontMatterStyleKeyProbe {
    static func keyRange(in line: String) -> NSRange? {
        let ns = line as NSString
        return MarkdownASTStyler.keyRange(in: NSRange(location: 0, length: ns.length), ns)
    }
}
