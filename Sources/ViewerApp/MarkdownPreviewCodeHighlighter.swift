import AppKit
import Foundation
import MarkdownEngineCodeBlocks
import ViewerCore

/// Colors preview code blocks with the editor's highlight.js bridge and theme colors.
/// One bridge per appearance, each pinned to its theme, so both colors are known at once.
struct MarkdownPreviewCodeHighlighter: MarkdownCodeHighlighting {
    /// One instance: each bridge builds its own JavaScriptCore context.
    static let shared = MarkdownPreviewCodeHighlighter()

    private let light: HighlightJSBridge
    private let dark: HighlightJSBridge
    private let plainLightHex: String
    private let plainDarkHex: String

    init() {
        light = HighlightJSBridge(lightTheme: .githubLight, autoSwitchAppearance: false)
        dark = HighlightJSBridge(lightTheme: .githubDark, autoSwitchAppearance: false)
        plainLightHex = Self.hex(CodeHighlightTheme.githubLight.foreground) ?? ""
        plainDarkHex = Self.hex(CodeHighlightTheme.githubDark.foreground) ?? ""
    }

    /// Language tags that mean "no highlighting". A missing language is never guessed:
    /// highlight.js would guess one and color ordinary words as keywords.
    private static let plainLanguageNames: Set<String> = ["text", "txt", "plain", "plaintext", "none"]

    /// True when the fence's language (the first word of its info string) should be highlighted.
    static func isHighlightable(language: String?) -> Bool {
        guard let info = language,
              let name = info.split(whereSeparator: \.isWhitespace).first else {
            return false
        }
        return !plainLanguageNames.contains(name.lowercased())
    }

    func spans(code: String, language: String?) -> [MarkdownCodeSpan]? {
        guard Self.isHighlightable(language: language) else { return nil }
        guard let lightText = light.highlight(code: code, language: language),
              let darkText = dark.highlight(code: code, language: language),
              lightText.length == darkText.length else {
            return nil
        }
        let lightRuns = colorRuns(in: lightText, plainHex: plainLightHex)
        let darkRuns = colorRuns(in: darkText, plainHex: plainDarkHex)
        return Self.mergedSpans(light: lightRuns, dark: darkRuns, length: lightText.length)
    }

    private struct ColorRun {
        let range: Range<Int>
        let hex: String
    }

    /// Runs of token colors; text left in the theme's plain foreground is not a run.
    private func colorRuns(in text: NSAttributedString, plainHex: String) -> [ColorRun] {
        var runs: [ColorRun] = []
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let color = value as? NSColor, let hex = Self.hex(color), hex != plainHex else { return }
            runs.append(ColorRun(range: range.location..<(range.location + range.length), hex: hex))
        }
        return runs
    }

    /// Splits the code at every run boundary of either appearance and pairs the two colors.
    private static func mergedSpans(light: [ColorRun], dark: [ColorRun], length: Int) -> [MarkdownCodeSpan] {
        var boundaries = Set([0, length])
        for run in light + dark {
            boundaries.insert(run.range.lowerBound)
            boundaries.insert(run.range.upperBound)
        }
        let sorted = boundaries.filter { $0 <= length }.sorted()

        var spans: [MarkdownCodeSpan] = []
        var lightCursor = 0
        var darkCursor = 0
        for (start, end) in zip(sorted, sorted.dropFirst()) where start < end {
            let lightHex = hexCovering(start, in: light, cursor: &lightCursor)
            let darkHex = hexCovering(start, in: dark, cursor: &darkCursor)
            guard lightHex != nil || darkHex != nil else { continue }
            let span = MarkdownCodeSpan(range: start..<end, lightColorHex: lightHex, darkColorHex: darkHex)
            if let last = spans.last, last.range.upperBound == start,
               last.lightColorHex == lightHex, last.darkColorHex == darkHex {
                spans[spans.count - 1] = MarkdownCodeSpan(
                    range: last.range.lowerBound..<end,
                    lightColorHex: lightHex,
                    darkColorHex: darkHex
                )
            } else {
                spans.append(span)
            }
        }
        return spans
    }

    /// The color of the run containing `offset`; `runs` is ordered and offsets only increase.
    private static func hexCovering(_ offset: Int, in runs: [ColorRun], cursor: inout Int) -> String? {
        while cursor < runs.count, runs[cursor].range.upperBound <= offset {
            cursor += 1
        }
        guard cursor < runs.count, runs[cursor].range.lowerBound <= offset else { return nil }
        return runs[cursor].hex
    }

    private static func hex(_ color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        func component(_ value: CGFloat) -> Int {
            min(max(Int((value * 255).rounded()), 0), 255)
        }
        return String(
            format: "#%02X%02X%02X",
            component(rgb.redComponent),
            component(rgb.greenComponent),
            component(rgb.blueComponent)
        )
    }
}
