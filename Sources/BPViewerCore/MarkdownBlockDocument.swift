import Foundation
import Markdown

public struct MarkdownBlockDocument: Sendable, Equatable {
    public let source: String
    public let blocks: [MarkdownEditableBlock]
    public let specialRegions: [MarkdownSpecialRegion]

    public init(source: String) {
        self.source = source
        self.blocks = MarkdownBlockScanner(source: source).scan()
        self.specialRegions = MarkdownSpecialScanner(source: source).scan()
    }

    public func block(id: String) -> MarkdownEditableBlock? {
        blocks.first { $0.id == id }
    }

    public func replacingBlock(id: String, withSource replacement: String) -> MarkdownBlockDocument {
        guard let block = block(id: id) else { return self }
        return replacing(block, with: replacement)
    }

    public func replacingBlock(id: String, withVisualText text: String) -> MarkdownBlockDocument {
        replacingBlock(id: id, withVisualText: text, kind: nil)
    }

    public func replacingBlock(
        id: String,
        withVisualText text: String,
        kind desiredKind: MarkdownBlockKind?
    ) -> MarkdownBlockDocument {
        guard let block = block(id: id) else { return self }
        let replacement: String
        switch desiredKind ?? block.kind {
        case .heading:
            replacement = headingSource(for: block, text: text)
        case .unorderedList:
            replacement = listSource(for: block, text: text, ordered: false)
        case .orderedList:
            replacement = listSource(for: block, text: text, ordered: true)
        case .blockquote:
            replacement = quoteSource(for: text)
        case .thematicBreak:
            replacement = "---"
        case .codeBlock:
            replacement = fencedCodeSource(for: block, text: text)
        case .table:
            replacement = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .frontMatter:
            replacement = text
        case .paragraph:
            replacement = text
        }
        return replacing(block, with: replacement)
    }

    public func replacingVisualEntries(
        _ entries: [MarkdownVisualEntry],
        insertions: [MarkdownVisualInsertion] = []
    ) -> MarkdownBlockDocument {
        let updated = entries.reduce(self) { document, entry in
            guard let block = document.block(id: entry.id), block.supportsVisualEditing else {
                return document
            }
            return document.replacingBlock(id: entry.id, withVisualText: entry.text, kind: entry.kind)
        }
        return insertions.reduce(updated) { document, insertion in
            document.insertingVisualBlock(insertion)
        }
    }

    public func insertingVisualBlock(_ insertion: MarkdownVisualInsertion) -> MarkdownBlockDocument {
        let sourceToInsert: String
        switch insertion.kind {
        case .thematicBreak:
            sourceToInsert = "---"
        default:
            return self
        }

        if let afterID = insertion.afterID,
           let blockIndex = blocks.firstIndex(where: { $0.id == afterID }) {
            let nextBlock = blocks.dropFirst(blockIndex + 1).first
            if nextBlock?.kind == insertion.kind {
                return self
            }
            let offset = blocks[blockIndex].sourceRange.endOffset
            let bytes = Array(source.utf8)
            let prefix = String(decoding: bytes[..<offset], as: UTF8.self)
            let suffix = String(decoding: bytes[offset...], as: UTF8.self)
            return MarkdownBlockDocument(source: prefix + "\n\n" + sourceToInsert + suffix)
        }

        if blocks.first?.kind == insertion.kind {
            return self
        }
        return MarkdownBlockDocument(source: sourceToInsert + (source.isEmpty ? "" : "\n\n" + source))
    }

    public func replacingSpecialEdits(_ edits: [MarkdownSpecialEdit]) -> MarkdownBlockDocument {
        edits.reduce(self) { document, edit in
            document.replacingSpecialRegion(id: edit.id, kind: edit.kind, withSource: edit.replacement)
        }
    }

    public func replacingSpecialRegion(
        id: String,
        kind: MarkdownSpecialKind,
        withSource replacement: String
    ) -> MarkdownBlockDocument {
        guard let region = specialRegions.first(where: { $0.id == id && $0.kind == kind }) else { return self }
        let bytes = Array(source.utf8)
        let prefix = String(decoding: bytes[..<region.sourceRange.startOffset], as: UTF8.self)
        let suffix = String(decoding: bytes[region.sourceRange.endOffset...], as: UTF8.self)
        return MarkdownBlockDocument(source: prefix + replacement + suffix)
    }

    private func replacing(_ block: MarkdownEditableBlock, with replacement: String) -> MarkdownBlockDocument {
        let bytes = Array(source.utf8)
        let prefix = String(decoding: bytes[..<block.sourceRange.startOffset], as: UTF8.self)
        let suffix = String(decoding: bytes[block.sourceRange.endOffset...], as: UTF8.self)
        return MarkdownBlockDocument(source: prefix + replacement + suffix)
    }

    private func headingSource(for block: MarkdownEditableBlock, text: String) -> String {
        let prefix = block.source.firstMatch(of: #/^\s{0,3}#{1,6}\s+/#)?.output ?? Substring("# ")
        return String(prefix) + text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func listSource(for block: MarkdownEditableBlock, text: String, ordered: Bool) -> String {
        let originalLines = block.source.split(whereSeparator: \.isNewline).map(String.init)
        let sourceMarkers = originalLines.compactMap { line -> String? in
            listMarker(in: line, ordered: ordered)
        }
        let fallback = ordered ? "1. " : "- "
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        return lines.enumerated().map { index, line in
            let marker = index < sourceMarkers.count ? sourceMarkers[index] : fallback
            return marker + line.trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\n")
    }

    private func listMarker(in line: String, ordered: Bool) -> String? {
        if ordered {
            return line.firstMatch(of: #/^\s{0,3}\d+[.)]\s+/#).map { String($0.output) }
        }
        return line.firstMatch(of: #/^\s{0,3}[-+*]\s+/#).map { String($0.output) }
    }

    private func quoteSource(for text: String) -> String {
        text.split(whereSeparator: \.isNewline).map { "> " + $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    }

    private func fencedCodeSource(for block: MarkdownEditableBlock, text: String) -> String {
        let lines = block.source.components(separatedBy: .newlines)
        guard lines.count >= 2,
              let opening = lines.first,
              let closing = lines.last,
              isFenceLine(closing, matching: opening) else {
            return text
        }

        let newline = block.source.contains("\r\n") ? "\r\n" : "\n"
        return ([opening] + text.components(separatedBy: .newlines) + [closing]).joined(separator: newline)
    }

    private func isFenceLine(_ line: String, matching opening: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let openingTrimmed = opening.trimmingCharacters(in: .whitespaces)
        guard let character = openingTrimmed.first,
              (character == "`" || character == "~") else { return false }
        let length = openingTrimmed.prefix { $0 == character }.count
        let closingPrefix = String(repeating: character, count: length)
        return trimmed.hasPrefix(closingPrefix)
            && trimmed.dropFirst(length).allSatisfy { $0 == character || $0.isWhitespace }
    }
}
