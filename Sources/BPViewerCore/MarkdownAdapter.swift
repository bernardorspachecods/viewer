import Foundation
import Markdown

public struct MarkdownOutlineEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let level: Int
    public let sourceUTF8Offset: Int?

    public init(id: String, title: String, level: Int, sourceUTF8Offset: Int? = nil) {
        self.id = id
        self.title = title
        self.level = level
        self.sourceUTF8Offset = sourceUTF8Offset
    }
}

public struct MarkdownRenderResult: Sendable {
    public let html: String
    public let baseURL: URL
    public let dependencies: [URL]
    public let outline: [MarkdownOutlineEntry]
    public let blocks: [MarkdownEditableBlock]

    public init(
        html: String,
        baseURL: URL,
        dependencies: [URL],
        outline: [MarkdownOutlineEntry] = [],
        blocks: [MarkdownEditableBlock] = []
    ) {
        self.html = html
        self.baseURL = baseURL
        self.dependencies = dependencies
        self.outline = outline
        self.blocks = blocks
    }
}

public protocol MarkdownAdapter: Sendable {
    func render(source: String, baseURL: URL) throws -> MarkdownRenderResult
}

public struct SwiftMarkdownAdapter: MarkdownAdapter {
    public init() {}

    public func render(source: String, baseURL: URL) throws -> MarkdownRenderResult {
        let directoryBaseURL = baseURL.hasDirectoryPath
            ? baseURL
            : baseURL.appendingPathComponent("", isDirectory: true)
        let blockDocument = MarkdownBlockDocument(source: source)
        let maskedSource = maskedFrontMatterSource(
            source,
            region: blockDocument.specialRegions.first { $0.kind == .frontMatter }
        )
        let parsingSource = preserveMathDelimiters(
            in: maskedSource,
            regions: blockDocument.specialRegions
        )
        let document = Document(parsing: parsingSource)
        var renderer = SafeMarkdownHTMLRenderer(
            baseURL: directoryBaseURL,
            source: source,
            editableBlocks: blockDocument.blocks,
            specialRegions: blockDocument.specialRegions
        )
        renderer.visit(document)

        return MarkdownRenderResult(
            html: MarkdownHTMLDocument(body: renderer.html).rendered,
            baseURL: directoryBaseURL,
            dependencies: Array(renderer.dependencies),
            outline: renderer.outline,
            blocks: blockDocument.blocks
        )
    }

    private func maskedFrontMatterSource(_ source: String, region: MarkdownSpecialRegion?) -> String {
        guard let region else { return source }
        var bytes = Array(source.utf8)
        for index in region.sourceRange.startOffset..<region.sourceRange.endOffset {
            if bytes[index] != 10 && bytes[index] != 13 { bytes[index] = 32 }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func preserveMathDelimiters(
        in source: String,
        regions: [MarkdownSpecialRegion]
    ) -> String {
        var bytes = Array(source.utf8)

        for region in regions where region.kind == .math {
            let trimmedSource = region.source.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSource.hasPrefix("\\["), trimmedSource.hasSuffix("\\]") {
                replaceDelimiter("\\[", with: "$$", in: region.sourceRange, bytes: &bytes, useLast: false)
                replaceDelimiter("\\]", with: "$$", in: region.sourceRange, bytes: &bytes, useLast: true)
            } else if trimmedSource.hasPrefix("\\("), trimmedSource.hasSuffix("\\)") {
                replaceDelimiter("\\(", with: "@@", in: region.sourceRange, bytes: &bytes, useLast: false)
                replaceDelimiter("\\)", with: "@@", in: region.sourceRange, bytes: &bytes, useLast: true)
            }
        }

        return String(decoding: bytes, as: UTF8.self)
    }

    private func replaceDelimiter(
        _ delimiter: String,
        with replacement: String,
        in range: MarkdownSourceRange,
        bytes: inout [UInt8],
        useLast: Bool
    ) {
        let delimiterBytes = Array(delimiter.utf8)
        let upperBound = min(range.endOffset, bytes.count) - delimiterBytes.count
        guard range.startOffset <= upperBound else { return }

        let matches = (range.startOffset...upperBound).filter { offset in
            bytes[offset..<(offset + delimiterBytes.count)].elementsEqual(delimiterBytes)
        }
        guard let offset = useLast ? matches.last : matches.first else { return }
        bytes.replaceSubrange(
            offset..<(offset + delimiterBytes.count),
            with: replacement.utf8
        )
    }
}
