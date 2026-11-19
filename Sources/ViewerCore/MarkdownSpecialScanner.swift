import Foundation
import Markdown

struct MarkdownSpecialScanner {
    let source: String

    func scan() -> [MarkdownSpecialRegion] {
        (imageRegions() + mathRegions() + inlineMathRegions() + htmlRegions() + inlineHTMLRegions() + frontMatterRegions())
            .sorted { $0.sourceRange.startOffset < $1.sourceRange.startOffset }
    }

    private func imageRegions() -> [MarkdownSpecialRegion] {
        var result: [MarkdownSpecialRegion] = []
        var cursor = source.startIndex

        while cursor < source.endIndex {
            guard let marker = source.range(of: "![", range: cursor..<source.endIndex),
                  let destinationStart = source.range(of: "](", range: marker.upperBound..<source.endIndex),
                  let closing = source.range(of: ")", range: destinationStart.upperBound..<source.endIndex) else {
                break
            }

            let range = MarkdownSourceRange(
                startOffset: utf8Offset(of: marker.lowerBound),
                endOffset: utf8Offset(of: closing.upperBound)
            )
            result.append(
                MarkdownSpecialRegion(
                    id: "markdown-special-image-\(range.startOffset)",
                    kind: .image,
                    sourceRange: range,
                    source: String(source[marker.lowerBound..<closing.upperBound])
                )
            )
            cursor = closing.upperBound
        }

        return result
    }

    private func utf8Offset(of index: String.Index) -> Int {
        source.utf8.distance(from: source.utf8.startIndex, to: index)
    }

    private func mathRegions() -> [MarkdownSpecialRegion] {
        let lines = sourceLines()
        var result: [MarkdownSpecialRegion] = []
        var index = 0
        while index < lines.count {
            let opening = lines[index].text.trimmingCharacters(in: .whitespaces)
            guard opening == "$$" || opening == "\\[" else {
                index += 1
                continue
            }
            guard let closing = lines[(index + 1)...].first(where: {
                let value = $0.text.trimmingCharacters(in: .whitespaces)
                return value == (opening == "$$" ? "$$" : "\\]")
            }) else {
                index += 1
                continue
            }
            let range = MarkdownSourceRange(startOffset: lines[index].start, endOffset: closing.contentEnd)
            result.append(region(kind: .math, range: range, idPrefix: "math"))
            index = lines.firstIndex(where: { $0.start == closing.start }).map { $0 + 1 } ?? lines.count
        }
        return result
    }

    private func htmlRegions() -> [MarkdownSpecialRegion] {
        let lines = sourceLines()
        var result: [MarkdownSpecialRegion] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].text.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("<"), trimmed.contains(">") else {
                index += 1
                continue
            }
            let start = index
            index += 1
            while index < lines.count,
                  !lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  lines[index].text.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
                index += 1
            }
            let range = MarkdownSourceRange(startOffset: lines[start].start, endOffset: lines[index - 1].contentEnd)
            result.append(region(kind: .html, range: range, idPrefix: "html"))
        }
        return result
    }

    private func inlineMathRegions() -> [MarkdownSpecialRegion] {
        regions(matching: #"\$([^$\n]+)\$|\\\(([^)]+)\\\)"#, kind: .math, idPrefix: "math")
    }

    private func inlineHTMLRegions() -> [MarkdownSpecialRegion] {
        regions(matching: #"</?[A-Za-z][^>]*>"#, kind: .html, idPrefix: "html")
    }

    private func regions(
        matching pattern: String,
        kind: MarkdownSpecialKind,
        idPrefix: String
    ) -> [MarkdownSpecialRegion] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(location: 0, length: (source as NSString).length)
        return expression.matches(in: source, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: source) else { return nil }
            let sourceRange = MarkdownSourceRange(
                startOffset: utf8Offset(of: range.lowerBound),
                endOffset: utf8Offset(of: range.upperBound)
            )
            return region(kind: kind, range: sourceRange, idPrefix: idPrefix)
        }
    }

    private func frontMatterRegions() -> [MarkdownSpecialRegion] {
        let lines = sourceLines()
        guard let first = lines.first,
              first.text.trimmingCharacters(in: .whitespaces) == "---",
              let closing = lines.dropFirst().first(where: {
                  let value = $0.text.trimmingCharacters(in: .whitespaces)
                  return value == "---" || value == "..."
              }) else { return [] }
        let range = MarkdownSourceRange(startOffset: first.start, endOffset: closing.contentEnd)
        return [region(kind: .frontMatter, range: range, idPrefix: "front-matter")]
    }

    private func region(
        kind: MarkdownSpecialKind,
        range: MarkdownSourceRange,
        idPrefix: String
    ) -> MarkdownSpecialRegion {
        let bytes = Array(source.utf8)
        return MarkdownSpecialRegion(
            id: "markdown-special-\(idPrefix)-\(range.startOffset)",
            kind: kind,
            sourceRange: range,
            source: String(decoding: bytes[range.startOffset..<range.endOffset], as: UTF8.self)
        )
    }

    private struct SourceLine {
        let start: Int
        let contentEnd: Int
        let text: String
    }

    private func sourceLines() -> [SourceLine] {
        let bytes = Array(source.utf8)
        var lines: [SourceLine] = []
        var start = 0
        var index = 0
        while index <= bytes.count {
            if index == bytes.count || bytes[index] == 10 {
                let rawEnd = index
                let contentEnd = rawEnd > start && bytes[rawEnd - 1] == 13 ? rawEnd - 1 : rawEnd
                lines.append(SourceLine(
                    start: start,
                    contentEnd: contentEnd,
                    text: String(decoding: bytes[start..<contentEnd], as: UTF8.self)
                ))
                start = index + 1
            }
            index += 1
        }
        if lines.last?.start == bytes.count + 1 { lines.removeLast() }
        return lines
    }
}
