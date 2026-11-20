import Foundation

/// A colored run of a fenced code block. `range` holds UTF-16 offsets into the code;
/// each color is `#RRGGBB`, nil when that appearance has no color for the run.
public struct MarkdownCodeSpan: Equatable, Sendable {
    public let range: Range<Int>
    public let lightColorHex: String?
    public let darkColorHex: String?

    public init(range: Range<Int>, lightColorHex: String?, darkColorHex: String?) {
        self.range = range
        self.lightColorHex = lightColorHex
        self.darkColorHex = darkColorHex
    }
}

/// Colors fenced code for the rendered preview. `nil` means no highlighting is available.
public protocol MarkdownCodeHighlighting: Sendable {
    func spans(code: String, language: String?) -> [MarkdownCodeSpan]?
}

/// Builds the escaped HTML of a highlighted code block. The visible text is always the code:
/// spans are clamped, sorted, and overlapping ones dropped before the text is cut.
enum MarkdownCodeSpanHTML {
    private struct Piece {
        let lower: Int
        let upper: Int
        let light: String?
        let dark: String?
    }

    static func html(code: String, spans: [MarkdownCodeSpan], escape: (String) -> String) -> String {
        let units = Array(code.utf16)
        var html = ""
        var cursor = 0
        for piece in pieces(from: spans, units: units) {
            if piece.lower > cursor {
                html += escape(text(units, cursor, piece.lower))
            }
            let color = "light-dark(\(piece.light ?? "-apple-system-label"),\(piece.dark ?? "-apple-system-label"))"
            html += "<span style=\"color:\(color)\">\(escape(text(units, piece.lower, piece.upper)))</span>"
            cursor = piece.upper
        }
        if cursor < units.count {
            html += escape(text(units, cursor, units.count))
        }
        return html
    }

    private static func pieces(from spans: [MarkdownCodeSpan], units: [UInt16]) -> [Piece] {
        let candidates = spans.compactMap { span -> Piece? in
            let light = validHex(span.lightColorHex)
            let dark = validHex(span.darkColorHex)
            guard light != nil || dark != nil else { return nil }
            let lower = boundary(span.range.lowerBound, units: units)
            let upper = boundary(span.range.upperBound, units: units)
            guard lower < upper else { return nil }
            return Piece(lower: lower, upper: upper, light: light, dark: dark)
        }
        let sorted = candidates.sorted { first, second in
            first.lower != second.lower ? first.lower < second.lower : first.upper > second.upper
        }
        var kept: [Piece] = []
        var end = 0
        for piece in sorted where piece.lower >= end {
            kept.append(piece)
            end = piece.upper
        }
        return kept
    }

    /// Clamps an offset into the code and moves it off the middle of a surrogate pair.
    private static func boundary(_ offset: Int, units: [UInt16]) -> Int {
        var index = min(max(offset, 0), units.count)
        while index > 0, index < units.count, (0xDC00...0xDFFF).contains(units[index]) {
            index -= 1
        }
        return index
    }

    private static func text(_ units: [UInt16], _ lower: Int, _ upper: Int) -> String {
        String(decoding: units[lower..<upper], as: UTF16.self)
    }

    /// Accepts only `#RRGGBB`, so a span can never inject CSS.
    private static func validHex(_ value: String?) -> String? {
        guard let value, value.count == 7, value.hasPrefix("#"),
              value.dropFirst().allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        return value
    }
}
