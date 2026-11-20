//
//  MarkdownASTStyler+FrontMatter.swift
//  MarkdownEngine
//
//  VIEWER PATCH: styling of the YAML front matter card (see `FrontMatter.swift`
//  for what counts as front matter and `MarkdownTextLayoutFragment+FrontMatter.swift`
//  for how the card is painted).
//
//  The two fence lines (`---`, and `---` or `...`) are the card's top and bottom
//  padding: their text is hidden like a code fence's and their line height is the
//  vertical padding. They show again, muted and small enough to fit that height,
//  while the caret is on them, so the layout does not move. The lines between
//  are raw YAML in a smaller font with the key (before the first `:`) semibold.
//

import AppKit
import Foundation

extension MarkdownASTStyler {

    /// The region to style as a card, nil when the feature is off or the document has none.
    static func frontMatterRegion(in ns: NSString, configuration: MarkdownEditorConfiguration) -> FrontMatterRegion? {
        guard configuration.frontMatter.isEnabled else { return nil }
        return FrontMatter.region(in: ns)
    }

    /// Attributes for the lines of the card that fall in the restyle scope.
    static func styleFrontMatter(_ region: FrontMatterRegion, ctx: Ctx, into attrs: inout [StyledRange]) {
        let style = ctx.config.frontMatter
        let fontSize = ctx.baseFont.pointSize * style.fontSizeScale
        let font = NSFont(name: ctx.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let keyFont = semibold(font)
        let lineHeight = fontSize * style.lineHeightMultiple
        // Raw YAML is not prose: no spell-check underlines.
        attrs.append((region.fullRange, [.spellingState: 0]))

        var lineStart = region.openLine.location
        let end = NSMaxRange(region.fullRange)
        while lineStart < end {
            let line = ctx.ns.lineRange(for: NSRange(location: lineStart, length: 0))
            defer { lineStart = NSMaxRange(line) }
            guard ctx.inScope(line) else { continue }

            let isOpen = line.location == region.openLine.location
            let isClose = line.location == region.closeLine.location
            let position: FrontMatterCardPaint.Position = isOpen ? .top : (isClose ? .bottom : .middle)
            let card = FrontMatterCardPaint(color: style.backgroundColor, cornerRadius: style.cornerRadius, position: position)

            let para = NSMutableParagraphStyle()
            para.paragraphSpacingBefore = 0
            para.paragraphSpacing = isClose ? style.bottomSpacing : 0
            if isOpen || isClose {
                // TextKit puts all the extra height of a tall line above its text, CSS half on each
                // side: move that half from the top padding to the bottom one, so the text sits centred.
                let shift = max(0, lineHeight - (font.ascender - font.descender + font.leading)) / 2
                let height = max(1, isOpen ? style.verticalPadding - shift : style.verticalPadding + shift)
                para.minimumLineHeight = height
                para.maximumLineHeight = height
                para.firstLineHeadIndent = style.horizontalPadding   // the revealed `---` lines up with the text
                para.headIndent = style.horizontalPadding
                // The reveal font must fit the padding height, or the line would grow when the caret enters it.
                let fenceSize = min(fontSize, style.verticalPadding * 0.8)
                let fenceFont = NSFont(name: ctx.fontName, size: fenceSize) ?? .systemFont(ofSize: fenceSize)
                let revealed = isFenceRevealed(line, region: region, ctx: ctx)
                attrs.append((line, [
                    .paragraphStyle: para, .frontMatterCard: card, .font: fenceFont,
                    .foregroundColor: revealed ? ctx.theme.mutedText : NSColor.clear,
                ]))
            } else {
                // The gap between rows is the extra height of every row but the first, so it lies inside the card.
                let isFirstRow = line.location == NSMaxRange(region.openLine)
                let height = lineHeight + (isFirstRow ? 0 : style.rowGap)
                para.minimumLineHeight = height
                para.maximumLineHeight = height
                para.firstLineHeadIndent = style.horizontalPadding
                para.headIndent = style.horizontalPadding
                para.tailIndent = -style.horizontalPadding
                attrs.append((line, [
                    .paragraphStyle: para, .frontMatterCard: card, .font: font,
                    .foregroundColor: style.textColor,
                ]))
                if let key = keyRange(in: line, ctx.ns) {
                    attrs.append((key, [.font: keyFont, .foregroundColor: style.keyColor]))
                }
            }
        }
    }

    /// The part of a line before its first `:`, nil when the line has no key.
    static func keyRange(in line: NSRange, _ ns: NSString) -> NSRange? {
        let colon = ns.range(of: ":", options: [], range: line)
        guard colon.location != NSNotFound, colon.location > line.location else { return nil }
        let key = NSRange(location: line.location, length: colon.location - line.location)
        let text = ns.substring(with: key)
        return text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : key
    }

    private static func isFenceRevealed(_ line: NSRange, region: FrontMatterRegion, ctx: Ctx) -> Bool {
        guard let fence = region.fenceLine(containing: ctx.caret >= 0 ? ctx.caret : nil) else { return false }
        return fence == 0 ? line.location == region.openLine.location : line.location == region.closeLine.location
    }

    private static func semibold(_ font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: NSFont.Weight.semibold],
        ])
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }
}
