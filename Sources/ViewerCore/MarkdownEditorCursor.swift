import Foundation

/// Maps a position in the Markdown source onto the text the live editor shows.
public enum MarkdownEditorCursor {
    /// The UTF-16 offset in `displayText` that matches `sourceUTF8Offset` in `source`.
    ///
    /// Exact when the editor shows the source verbatim. When it does not (an image or a formula
    /// drawn in place of its source), it falls back to the first place the source line holding
    /// the offset appears in `displayText`. Returns nil when neither works.
    public static func utf16Offset(
        inDisplay displayText: String,
        forSourceUTF8Offset sourceUTF8Offset: Int,
        source: String
    ) -> Int? {
        let utf8 = source.utf8
        guard sourceUTF8Offset >= 0, sourceUTF8Offset <= utf8.count,
              let sourceIndex = utf8.index(
                  utf8.startIndex,
                  offsetBy: sourceUTF8Offset,
                  limitedBy: utf8.endIndex
              ).flatMap({ $0.samePosition(in: source) }) else { return nil }

        if displayText == source {
            return source.utf16.distance(from: source.startIndex, to: sourceIndex)
        }

        let lineRange = source.lineRange(for: sourceIndex..<sourceIndex)
        let line = source[lineRange].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, let found = displayText.range(of: line) else { return nil }
        return displayText.utf16.distance(from: displayText.startIndex, to: found.lowerBound)
    }
}
