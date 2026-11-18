import Foundation
import Markdown

struct MarkdownBlockScanner {
    let source: String

    func scan() -> [MarkdownEditableBlock] {
        let lines = sourceLines()
        var result: [MarkdownEditableBlock] = []
        var index = 0

        while index < lines.count {
            guard !lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                index += 1
                continue
            }

            let start = index
            let kind: MarkdownBlockKind
            let detectedHeadingLevel: Int?

            if index == 0, let end = frontMatterEnd(from: index, lines: lines) {
                kind = .frontMatter
                detectedHeadingLevel = nil
                index = end
            } else if let level = self.headingLevel(in: lines[index].text) {
                kind = .heading
                detectedHeadingLevel = level
                index += 1
            } else if let fence = fencedCodeStart(in: lines[index].text) {
                kind = .codeBlock
                detectedHeadingLevel = nil
                index = consumeFencedCode(from: index, lines: lines, fence: fence)
            } else if isTableStart(at: index, lines: lines) {
                kind = .table
                detectedHeadingLevel = nil
                index = consumeTable(from: index, lines: lines)
            } else if isThematicBreak(lines[index].text) {
                kind = .thematicBreak
                detectedHeadingLevel = nil
                index += 1
            } else if isBlockQuoteLine(lines[index].text) {
                kind = .blockquote
                detectedHeadingLevel = nil
                index = consumeBlockQuote(from: index, lines: lines)
            } else if isListLine(lines[index].text, ordered: true) {
                kind = .orderedList
                detectedHeadingLevel = nil
                index = consumeList(from: index, lines: lines, ordered: true)
            } else if isListLine(lines[index].text, ordered: false) {
                kind = .unorderedList
                detectedHeadingLevel = nil
                index = consumeList(from: index, lines: lines, ordered: false)
            } else {
                kind = .paragraph
                detectedHeadingLevel = nil
                index += 1
                while index < lines.count,
                      !lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      self.headingLevel(in: lines[index].text) == nil,
                      self.fencedCodeStart(in: lines[index].text) == nil,
                      !self.isTableStart(at: index, lines: lines),
                      !isThematicBreak(lines[index].text),
                      !isBlockQuoteLine(lines[index].text),
                      !isListLine(lines[index].text, ordered: true),
                      !isListLine(lines[index].text, ordered: false) {
                    index += 1
                }
            }

            let first = lines[start]
            let last = lines[index - 1]
            let range = MarkdownSourceRange(startOffset: first.start, endOffset: last.contentEnd)
            let blockSource = substring(range)
            result.append(
                MarkdownEditableBlock(
                    id: "markdown-block-\(result.count + 1)",
                    kind: kind,
                    sourceRange: range,
                    source: blockSource,
                    headingLevel: detectedHeadingLevel
                )
            )
        }

        return result
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
                let text = String(decoding: bytes[start..<contentEnd], as: UTF8.self)
                lines.append(SourceLine(start: start, contentEnd: contentEnd, text: text))
                start = index + 1
            }
            index += 1
        }

        if lines.last?.start == bytes.count + 1 {
            lines.removeLast()
        }
        return lines
    }

    private func substring(_ range: MarkdownSourceRange) -> String {
        let bytes = Array(source.utf8)
        return String(decoding: bytes[range.startOffset..<range.endOffset], as: UTF8.self)
    }

    private func headingLevel(in line: String) -> Int? {
        guard let match = line.firstMatch(of: #/^\s{0,3}(#{1,6})(?:\s+|$)/#) else { return nil }
        return match.output.1.count
    }

    private func isListLine(_ line: String, ordered: Bool) -> Bool {
        let pattern = ordered
            ? #/^\s{0,3}\d+[.)]\s+/#
            : #/^\s{0,3}[-+*]\s+/#
        return line.firstMatch(of: pattern) != nil
    }

    private func isThematicBreak(_ line: String) -> Bool {
        line.firstMatch(of: #/^\s{0,3}((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$/#) != nil
    }

    private func fencedCodeStart(in line: String) -> (character: Character, length: Int)? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let character = trimmed.first, character == "`" || character == "~" else { return nil }
        let length = trimmed.prefix { $0 == character }.count
        return length >= 3 ? (character, length) : nil
    }

    private func consumeFencedCode(
        from start: Int,
        lines: [SourceLine],
        fence: (character: Character, length: Int)
    ) -> Int {
        var index = start + 1
        while index < lines.count {
            let trimmed = lines[index].text.trimmingCharacters(in: .whitespaces)
            let prefix = String(repeating: fence.character, count: fence.length)
            if trimmed.hasPrefix(prefix),
               trimmed.dropFirst(fence.length).allSatisfy({ $0 == fence.character || $0.isWhitespace }) {
                return index + 1
            }
            index += 1
        }
        return index
    }

    private func isTableStart(at index: Int, lines: [SourceLine]) -> Bool {
        guard index + 1 < lines.count,
              isTableRow(lines[index].text),
              isTableDelimiter(lines[index + 1].text) else { return false }
        return true
    }

    private func consumeTable(from start: Int, lines: [SourceLine]) -> Int {
        var index = start + 2
        while index < lines.count,
              !lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isTableRow(lines[index].text) {
            index += 1
        }
        return index
    }

    private func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        let cells = tableCells(in: trimmed)
        return cells.count >= 1 && cells.contains { !$0.isEmpty }
    }

    private func frontMatterEnd(from start: Int, lines: [SourceLine]) -> Int? {
        guard lines[start].text.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var index = start + 1
        while index < lines.count {
            let value = lines[index].text.trimmingCharacters(in: .whitespaces)
            if value == "---" || value == "..." { return index + 1 }
            index += 1
        }
        return nil
    }

    private func isTableDelimiter(_ line: String) -> Bool {
        let cells = tableCells(in: line.trimmingCharacters(in: .whitespaces))
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespaces)
            var characters = Array(value)
            if characters.first == ":" { characters.removeFirst() }
            if characters.last == ":" { characters.removeLast() }
            return characters.count >= 3 && characters.allSatisfy { $0 == "-" }
        }
    }

    private func tableCells(in line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.first == "|" { value.removeFirst() }
        if value.last == "|" { value.removeLast() }
        return value.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private func isBlockQuoteLine(_ line: String) -> Bool {
        line.firstMatch(of: #/^\s{0,3}>/#) != nil
    }

    private func consumeBlockQuote(from start: Int, lines: [SourceLine]) -> Int {
        var index = start
        while index < lines.count, isBlockQuoteLine(lines[index].text) {
            index += 1
        }
        return index
    }

    private func consumeList(from start: Int, lines: [SourceLine], ordered: Bool) -> Int {
        var index = start
        while index < lines.count {
            let text = lines[index].text
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
            if index == start || isListLine(text, ordered: ordered) || text.first == " " || text.first == "\t" {
                index += 1
            } else {
                break
            }
        }
        return index
    }

    private struct SourceLine {
        let start: Int
        let contentEnd: Int
        let text: String
    }
}

private extension Substring {
    var isNewline: Bool { first == "\n" || first == "\r" }
}
