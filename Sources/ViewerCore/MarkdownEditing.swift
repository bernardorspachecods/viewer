import Foundation
import Markdown

public enum SourceEditingMode: String, Codable, CaseIterable, Hashable, Sendable {
    case markdown
    case split
}

public typealias MarkdownEditingMode = SourceEditingMode

public enum MarkdownBlockKind: String, Codable, Hashable, Sendable {
    case paragraph
    case heading
    case orderedList
    case unorderedList
    case blockquote
    case thematicBreak
    case codeBlock
    case table
    case frontMatter
}

public enum MarkdownSpecialKind: String, Codable, Hashable, Sendable {
    case image
    case math
    case html
    case frontMatter
}

public struct MarkdownSourceRange: Hashable, Sendable {
    public let startOffset: Int
    public let endOffset: Int

    public init(startOffset: Int, endOffset: Int) {
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

public struct MarkdownSpecialRegion: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: MarkdownSpecialKind
    public let sourceRange: MarkdownSourceRange
    public let source: String

    public init(id: String, kind: MarkdownSpecialKind, sourceRange: MarkdownSourceRange, source: String) {
        self.id = id
        self.kind = kind
        self.sourceRange = sourceRange
        self.source = source
    }
}

public struct MarkdownSpecialEdit: Codable, Hashable, Sendable {
    public let id: String
    public let kind: MarkdownSpecialKind
    public let replacement: String

    public init(id: String, kind: MarkdownSpecialKind, replacement: String) {
        self.id = id
        self.kind = kind
        self.replacement = replacement
    }
}

public struct MarkdownEditableBlock: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: MarkdownBlockKind
    public let sourceRange: MarkdownSourceRange
    public let source: String
    public let headingLevel: Int?

    public init(
        id: String,
        kind: MarkdownBlockKind,
        sourceRange: MarkdownSourceRange,
        source: String,
        headingLevel: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sourceRange = sourceRange
        self.source = source
        self.headingLevel = headingLevel
    }

    public var visualText: String {
        switch kind {
        case .heading:
            return source.replacingOccurrences(
                of: #"^\s{0,3}#{1,6}\s+"#,
                with: "",
                options: .regularExpression
            )
        case .unorderedList:
            return source
                .split(whereSeparator: \.isNewline)
                .map { $0.replacingOccurrences(of: #"^\s{0,3}[-+*]\s+"#, with: "", options: .regularExpression) }
                .joined(separator: "\n")
        case .orderedList:
            return source
                .split(whereSeparator: \.isNewline)
                .map { $0.replacingOccurrences(of: #"^\s{0,3}\d+[.)]\s+"#, with: "", options: .regularExpression) }
                .joined(separator: "\n")
        case .blockquote:
            return source
                .split(whereSeparator: \.isNewline)
                .map { $0.replacingOccurrences(of: #"^\s{0,3}>\s?"#, with: "", options: .regularExpression) }
                .joined(separator: "\n")
        case .thematicBreak:
            return ""
        case .codeBlock:
            let lines = source.components(separatedBy: .newlines)
            guard lines.count >= 2 else { return source }
            return lines.dropFirst().dropLast().joined(separator: "\n")
        case .table:
            return source
        case .frontMatter:
            return source
        case .paragraph:
            return source
        }
    }

    public var supportsVisualEditing: Bool {
        if kind == .codeBlock || kind == .table { return true }
        if kind == .frontMatter { return false }
        let text = visualText
        return kind != .thematicBreak
            && !text.contains("![")
            && !text.contains("$$")
            && !text.contains("<")
    }

    public func sourceOffset(forRenderedTextOffset offset: Int) -> Int {
        let renderedText = renderedTextForCursor
        let rawCharacters = Array(source)
        let renderedCharacters = Array(renderedText)
        guard !rawCharacters.isEmpty, !renderedCharacters.isEmpty else { return 0 }

        var rawIndex = 0
        var matchingRawIndexes: [Int] = []
        for renderedCharacter in renderedCharacters {
            while rawIndex < rawCharacters.count, rawCharacters[rawIndex] != renderedCharacter {
                rawIndex += 1
            }
            guard rawIndex < rawCharacters.count else { break }
            matchingRawIndexes.append(rawIndex)
            rawIndex += 1
        }

        guard let firstMatch = matchingRawIndexes.first else { return 0 }
        let clampedOffset = max(offset, 0)
        let rawCharacterOffset: Int
        if clampedOffset < matchingRawIndexes.count {
            rawCharacterOffset = matchingRawIndexes[clampedOffset]
        } else {
            rawCharacterOffset = (matchingRawIndexes.last ?? firstMatch) + 1
        }
        let sourceIndex = source.index(
            source.startIndex,
            offsetBy: min(rawCharacterOffset, source.count)
        )
        return source.utf8.distance(from: source.utf8.startIndex, to: sourceIndex)
    }

    private var renderedTextForCursor: String {
        var text = visualText
        text = text.replacingOccurrences(
            of: #"!\[[^\]]*\]\([^)]+\)"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        return text.replacingOccurrences(
            of: #"(\*\*|__|~~|`|\*|_)"#,
            with: "",
            options: .regularExpression
        )
    }
}

public struct MarkdownVisualEntry: Codable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let kind: MarkdownBlockKind?

    public init(id: String, text: String, kind: MarkdownBlockKind? = nil) {
        self.id = id
        self.text = text
        self.kind = kind
    }
}

public struct MarkdownVisualInsertion: Codable, Hashable, Sendable {
    public let afterID: String?
    public let kind: MarkdownBlockKind

    public init(afterID: String? = nil, kind: MarkdownBlockKind) {
        self.afterID = afterID
        self.kind = kind
    }
}
