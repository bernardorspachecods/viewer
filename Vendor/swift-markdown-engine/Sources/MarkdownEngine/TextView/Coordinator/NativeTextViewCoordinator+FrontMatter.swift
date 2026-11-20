//
//  NativeTextViewCoordinator+FrontMatter.swift
//  MarkdownEngine
//
//  VIEWER PATCH: which paragraphs to restyle so the front matter card stays right
//  as the document changes. Each card line is styled on its own (a keystroke in
//  one line restyles that line), so only a change of the card's SHAPE needs more.
//

import Foundation

extension NativeTextViewCoordinator {

    /// The card as it was and as it is, when an edit changed what it is: it appeared, vanished,
    /// or its fence lines moved. Empty when nothing about the card's shape changed.
    func frontMatterRestyleRanges(in text: NSString) -> [NSRange] {
        guard configuration.frontMatter.isEnabled else {
            previousFrontMatterRegion = nil
            return []
        }
        let current = FrontMatter.region(in: text)
        let previous = previousFrontMatterRegion
        let delta = text.length - previousFrontMatterTextLength
        previousFrontMatterRegion = current
        previousFrontMatterTextLength = text.length
        // The closing line only moves when an edit above it changed the text length; otherwise
        // it stays put. Anywhere else it is a different line now (the card ends earlier or later).
        if let current, let previous,
           current.openLine == previous.openLine, current.closeLine.length == previous.closeLine.length,
           current.closeLine.location == previous.closeLine.location
            || current.closeLine.location == previous.closeLine.location + delta {
            return []
        }
        let bounds = NSRange(location: 0, length: text.length)
        return [previous?.fullRange, current?.fullRange].compactMap { range in
            guard let range else { return nil }
            let clamped = NSIntersectionRange(range, bounds)
            return clamped.length > 0 ? clamped : nil
        }
    }

    /// Whether the caret moved on or off a fence line of the card, which shows or hides its `---`.
    func frontMatterFenceChanged(in text: NSString, from previousCaret: Int?, to caret: Int) -> Bool {
        guard configuration.frontMatter.isEnabled, let region = FrontMatter.region(in: text) else { return false }
        return region.fenceLine(containing: previousCaret) != region.fenceLine(containing: caret)
    }
}
