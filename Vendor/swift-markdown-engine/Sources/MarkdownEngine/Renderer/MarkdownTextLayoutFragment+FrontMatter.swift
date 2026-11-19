//
//  MarkdownTextLayoutFragment+FrontMatter.swift
//  MarkdownEngine
//
//  VIEWER PATCH: the front matter card. Every line of the card carries
//  `.frontMatterCard`; each line's own fragment paints its slice of one rounded
//  rectangle (rounded at the top on the first line, at the bottom on the last),
//  across the text column. The fill is translucent, so slices that meet exactly
//  at a pixel boundary show no seam and the selection highlight stays visible.
//

import AppKit

extension NSAttributedString.Key {
    /// `FrontMatterCardPaint` — set on every character of a front matter line.
    static let frontMatterCard = NSAttributedString.Key("FrontMatterCard")
}

/// What one front matter line paints: the card's fill and corner radius, and where the line sits in the card.
struct FrontMatterCardPaint: Hashable {
    enum Position: Hashable {
        case top, middle, bottom
    }

    let color: NSColor
    let cornerRadius: CGFloat
    let position: Position
}

enum FrontMatterCardGeometry {

    /// The slice of the card for one line: a rectangle whose top corners are rounded on the first
    /// line and whose bottom corners are rounded on the last. y grows downward (flipped context).
    static func path(in rect: CGRect, radius: CGFloat, position: FrontMatterCardPaint.Position) -> CGPath {
        let top = position == .top ? min(radius, rect.height / 2) : 0
        let bottom = position == .bottom ? min(radius, rect.height / 2) : 0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        if top > 0 {
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                        tangent2End: CGPoint(x: rect.maxX, y: rect.minY + top), radius: top)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        if bottom > 0 {
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.maxX - bottom, y: rect.maxY), radius: bottom)
        }
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        if bottom > 0 {
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bottom), radius: bottom)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        if top > 0 {
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                        tangent2End: CGPoint(x: rect.minX + top, y: rect.minY), radius: top)
        }
        path.closeSubpath()
        return path
    }
}

extension MarkdownTextLayoutFragment {

    /// The card paint of this fragment's first character, nil outside a front matter card.
    var frontMatterCard: FrontMatterCardPaint? {
        guard let storage = textStorage, let range = fragmentNSRange, range.length > 0 else { return nil }
        return storage.attribute(.frontMatterCard, at: range.location, effectiveRange: nil) as? FrontMatterCardPaint
    }

    func drawFrontMatterCard(at point: CGPoint, in context: CGContext) {
        guard let paint = frontMatterCard,
              let container = textLayoutManager?.textContainer,
              let first = textLineFragments.first, let last = textLineFragments.last else { return }

        let scale = container.textView?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        // The text column, not the whole container: the card lines up with the body text's edges.
        let minX = point.x - layoutFragmentFrame.origin.x + container.lineFragmentPadding
        let maxX = point.x - layoutFragmentFrame.origin.x + container.size.width - container.lineFragmentPadding
        // Rounded to the nearest pixel on both edges, so neighbouring lines share their boundary exactly.
        let minY = (point.y + first.typographicBounds.minY) * scale
        let maxY = (point.y + last.typographicBounds.maxY) * scale
        let rect = CGRect(x: minX, y: minY.rounded() / scale, width: maxX - minX,
                          height: (maxY.rounded() - minY.rounded()) / scale)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        paint.color.setFill()
        context.addPath(FrontMatterCardGeometry.path(in: rect, radius: paint.cornerRadius, position: paint.position))
        context.fillPath()
    }
}
