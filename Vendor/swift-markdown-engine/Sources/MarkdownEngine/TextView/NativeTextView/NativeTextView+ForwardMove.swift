//
//  NativeTextView+ForwardMove.swift
//  MarkdownEngine
//
//  VIEWER PATCH. → must never move the caret backwards or not at all in left-to-right text.
//  A rendered inline formula collapses its source into a few zero-width characters; with a
//  space right after the formula TextKit then answered → at the position after that space with
//  the position before it, so the caret bounced between the two and could never leave.
//

import AppKit

extension NativeTextView {
    override func moveRight(_ sender: Any?) {
        let before = selectedRange()
        super.moveRight(sender)
        let after = selectedRange()
        let text = string as NSString
        guard before.length == 0, after.length == 0, after.location <= before.location,
              before.location < text.length, baseWritingDirection != .rightToLeft else { return }
        let paragraph = text.substring(with: text.paragraphRange(for: before))
        guard !paragraph.unicodeScalars.contains(where: Self.isRightToLeft) else { return }
        let step = text.rangeOfComposedCharacterSequence(at: before.location)
        setSelectedRange(NSRange(location: NSMaxRange(step), length: 0))
    }

    private static func isRightToLeft(_ scalar: Unicode.Scalar) -> Bool {
        (0x0590...0x08FF).contains(scalar.value) || (0xFB1D...0xFDFF).contains(scalar.value)
            || (0xFE70...0xFEFF).contains(scalar.value)
    }
}
