import AppKit
import BPViewerCore

enum SourceSyntaxHighlighting: Equatable, Sendable {
    case json(JSONSyntaxColorPalette)
    case markdown(MarkdownSyntaxColorPalette)
    case latex(LatexSyntaxColorPalette)

    var background: String {
        switch self {
        case let .json(palette): palette.background
        case let .markdown(palette): palette.background
        case let .latex(palette): palette.background
        }
    }

    var foreground: String {
        switch self {
        case let .json(palette): palette.foreground
        case let .markdown(palette): palette.foreground
        case let .latex(palette): palette.foreground
        }
    }
}

struct SourceSyntaxHighlightingRequest: Equatable, Sendable {
    let source: String
    let syntaxHighlighting: SourceSyntaxHighlighting?
}

struct SourceSyntaxHighlightingGate: Equatable, Sendable {
    private(set) var scheduled: SourceSyntaxHighlightingRequest?
    private(set) var applied: SourceSyntaxHighlightingRequest?

    init() {
        scheduled = nil
        applied = nil
    }

    mutating func shouldSchedule(_ request: SourceSyntaxHighlightingRequest) -> Bool {
        if applied == request || scheduled == request {
            return false
        }
        scheduled = request
        return true
    }

    mutating func markApplied(_ request: SourceSyntaxHighlightingRequest) {
        scheduled = nil
        applied = request
    }
}

extension NSColor {
    convenience init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
