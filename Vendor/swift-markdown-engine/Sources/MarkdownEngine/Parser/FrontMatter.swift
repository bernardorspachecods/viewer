//
//  FrontMatter.swift
//  MarkdownEngine
//
//  VIEWER PATCH: detection of YAML front matter, used when
//  `MarkdownEditorConfiguration.frontMatter.isEnabled`.
//
//  Rules (the same as Viewer's Core scanner, `frontMatterRegions`): the
//  document's FIRST line, trimmed of whitespace, is `---`, and a later line,
//  trimmed, is `---` or `...`. The region runs from the start of line 1 to the
//  end of the closing line. No closing line, or `---` not on line 1: no region.
//

import Foundation

struct FrontMatterRegion: Equatable {
    /// Start of line 1 to the end of the closing line's content (no newline).
    let range: NSRange
    /// The opening `---` line, trailing newline included.
    let openLine: NSRange
    /// The closing line, trailing newline included when the document has one.
    let closeLine: NSRange

    /// Everything the card owns: both fence lines whole and the text between.
    var fullRange: NSRange {
        NSRange(location: 0, length: NSMaxRange(closeLine))
    }

    /// Whether a block lies wholly inside the card.
    func covers(_ block: NSRange) -> Bool {
        block.location >= fullRange.location && NSMaxRange(block) <= NSMaxRange(fullRange)
    }

    /// Which fence line holds `location` (0 = opening, 1 = closing), nil elsewhere.
    /// A location at the very end of the document belongs to the closing line.
    func fenceLine(containing location: Int?) -> Int? {
        guard let location else { return nil }
        if NSLocationInRange(location, openLine) { return 0 }
        if NSLocationInRange(location, closeLine) { return 1 }
        // No line break after the closing line: the end of the document is still on it.
        if location == NSMaxRange(closeLine), NSMaxRange(closeLine) == NSMaxRange(range) { return 1 }
        return nil
    }
}

enum FrontMatter {

    /// The front matter region of `text`, or nil when there is none.
    static func region(in text: NSString) -> FrontMatterRegion? {
        let length = text.length
        guard length > 0 else { return nil }
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: 0, length: 0))
        guard isFence(text, from: lineStart, to: contentsEnd, accepting: ["-"]) else { return nil }
        let openLine = NSRange(location: lineStart, length: lineEnd - lineStart)

        var cursor = lineEnd
        while cursor < length {
            text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: cursor, length: 0))
            if isFence(text, from: lineStart, to: contentsEnd, accepting: ["-", "."]) {
                return FrontMatterRegion(
                    range: NSRange(location: 0, length: contentsEnd),
                    openLine: openLine,
                    closeLine: NSRange(location: lineStart, length: lineEnd - lineStart)
                )
            }
            cursor = lineEnd
        }
        return nil
    }

    /// Whether `from..<to` is three of one accepted character (`-` or `.`) surrounded by whitespace only.
    private static func isFence(_ text: NSString, from: Int, to: Int, accepting marks: [Character]) -> Bool {
        var lo = from, hi = to
        while lo < hi, isWhitespace(text.character(at: lo)) { lo += 1 }
        while hi > lo, isWhitespace(text.character(at: hi - 1)) { hi -= 1 }
        guard hi - lo == 3 else { return false }
        let first = text.character(at: lo)
        guard marks.contains(where: { $0.unicodeScalars.first?.value == UInt32(first) }) else { return false }
        return text.character(at: lo + 1) == first && text.character(at: lo + 2) == first
    }

    private static func isWhitespace(_ unit: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return CharacterSet.whitespaces.contains(scalar)
    }
}
