import Foundation
import Markdown

struct SafeMarkdownHTMLRenderer: MarkupWalker {
    let baseURL: URL
    let source: String
    let editableBlocks: [MarkdownEditableBlock]
    let specialRegions: [MarkdownSpecialRegion]
    private(set) var html = ""
    private var headingCounts: [String: Int] = [:]
    private let mathRenderer = TeXMathMLRenderer()
    private(set) var dependencies: Set<URL> = []
    private(set) var outline: [MarkdownOutlineEntry] = []

    init(
        baseURL: URL,
        source: String,
        editableBlocks: [MarkdownEditableBlock],
        specialRegions: [MarkdownSpecialRegion]
    ) {
        self.baseURL = baseURL
        self.source = source
        self.editableBlocks = editableBlocks
        self.specialRegions = specialRegions
    }

    mutating func visitDocument(_ document: Document) {
        if let frontMatter = specialRegions.first(where: { $0.kind == .frontMatter }) {
            html += "<pre class=\"bp-special-placeholder\"\(specialAttribute(for: frontMatter))>Front matter\n\(escapeText(frontMatter.source))</pre>\n"
        }
        descendInto(document)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        html += "<blockquote\(editableAttribute(for: blockQuote))>"
        descendInto(blockQuote)
        html += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let languageClass = codeBlock.language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
        html += "<pre\(editableAttribute(for: codeBlock))><code\(languageClass)>\(escapeText(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        let id = uniqueHeadingID(for: heading.plainText)
        let sourceUTF8Offset = heading.range.map { sourceOffset(for: $0.lowerBound) }
        outline.append(
            MarkdownOutlineEntry(
                id: id,
                title: heading.plainText,
                level: heading.level,
                sourceUTF8Offset: sourceUTF8Offset
            )
        )
        let blockAttribute = editableAttribute(for: heading)
        html += "<h\(heading.level) id=\"\(escapeAttribute(id))\"\(blockAttribute)>"
        descendInto(heading)
        html += "</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        html += "<hr\(editableAttribute(for: thematicBreak)) />\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        html += "<li>"
        if let checkbox = listItem.checkbox {
            let checkedAttribute: String
            switch checkbox {
            case .checked:
                checkedAttribute = " checked"
            case .unchecked:
                checkedAttribute = ""
            }
            html += "<input type=\"checkbox\" data-bp-task-checkbox=\"true\"\(checkedAttribute) disabled /> "
        }
        descendInto(listItem)
        html += "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        html += "<ol\(start)\(editableAttribute(for: orderedList))>"
        descendInto(orderedList)
        html += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        html += "<ul\(editableAttribute(for: unorderedList))>"
        descendInto(unorderedList)
        html += "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if let blockMath = blockMathSource(in: paragraph.plainText) {
            html += "<div class=\"math-block\"\(editableAttribute(for: paragraph))\(specialAttribute(for: paragraph, kind: .math))>\(mathRenderer.render(blockMath, displayMode: true))</div>\n"
            return
        }

        html += "<p\(editableAttribute(for: paragraph))>"
        descendInto(paragraph)
        html += "</p>\n"
    }

    mutating func visitTable(_ table: Table) {
        html += "<table\(editableAttribute(for: table))>"
        descendInto(table)
        html += "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) {
        html += "<thead>"
        descendInto(tableHead)
        html += "</thead>"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) {
        html += "<tbody>"
        descendInto(tableBody)
        html += "</tbody>"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        html += "<tr>"
        descendInto(tableRow)
        html += "</tr>"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        let tag = tableCell.parent is Table.Head ? "th" : "td"
        html += "<\(tag)>"
        descendInto(tableCell)
        html += "</\(tag)>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        html += "<code>\(escapeText(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        html += "<em>"
        descendInto(emphasis)
        html += "</em>"
    }

    mutating func visitStrong(_ strong: Strong) {
        html += "<strong>"
        descendInto(strong)
        html += "</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        html += "<del>"
        descendInto(strikethrough)
        html += "</del>"
    }

    mutating func visitImage(_ image: Markdown.Image) {
        guard let source = safeURL(image.source) else {
            html += "<span class=\"missing-image\"\(specialAttribute(for: image, kind: .image))>\(escapeText(image.plainText))</span>"
            return
        }
        var renderedSource = source
        if let resourceURL = localResourceURL(for: source) {
            dependencies.insert(resourceURL)
            if let embeddedSource = embeddedImageSource(for: resourceURL) {
                renderedSource = embeddedSource
            }
        }
        let alt = escapeAttribute(image.plainText)
        let markdownSourceAttribute = image.source.map {
            " data-bp-markdown-image-source=\"\(escapeAttribute($0))\""
        } ?? ""
        html += "<img\(specialAttribute(for: image, kind: .image))\(markdownSourceAttribute) loading=\"lazy\" decoding=\"async\" src=\"\(escapeAttribute(renderedSource))\" alt=\"\(alt)\""
        if let title = image.title, !title.isEmpty {
            html += " title=\"\(escapeAttribute(title))\""
        }
        html += " />"
    }

    mutating func visitLink(_ link: Markdown.Link) {
        guard let destination = safeURL(link.destination) else {
            descendInto(link)
            return
        }
        let renderedDestination = localPreviewLinkDestination(for: destination) ?? destination
        html += "<a href=\"\(escapeAttribute(renderedDestination))\" data-bp-markdown-href=\"\(escapeAttribute(destination))\""
        if let title = link.title, !title.isEmpty {
            html += " title=\"\(escapeAttribute(title))\""
        }
        html += ">"
        descendInto(link)
        html += "</a>"
    }

    private func localPreviewLinkDestination(for source: String) -> String? {
        guard !source.hasPrefix("#"),
              let sourceURL = URL(string: source),
              sourceURL.scheme == nil,
              let resolvedURL = URL(string: source, relativeTo: baseURL)?.absoluteURL,
              let previewURL = MarkdownPreviewLink.url(for: resolvedURL) else {
            return nil
        }

        return previewURL.absoluteString
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        html += "<br />\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        html += "\n"
    }

    mutating func visitText(_ text: Markdown.Text) {
        let offset = text.range.map { sourceOffset(for: $0.lowerBound) } ?? 0
        html += renderTextWithMath(text.string, sourceOffset: offset)
    }

    // Raw HTML is intentionally omitted until the sanitizer policy is expanded and tested.
    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) {
        guard let range = htmlBlock.range,
              let region = specialRegions.first(where: {
                  $0.kind == .html && $0.sourceRange.startOffset == sourceOffset(for: range.lowerBound)
              }) else { return }
        html += "<pre class=\"bp-special-placeholder\"\(specialAttribute(for: region))>HTML raw\n\(escapeText(region.source))</pre>\n"
    }
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        let attribute = inlineHTML.range.flatMap { range in
            specialRegions.first(where: {
                $0.kind == .html && $0.sourceRange.startOffset == sourceOffset(for: range.lowerBound)
            })
        }.map(specialAttribute(for:)) ?? ""
        html += "<span class=\"bp-special-placeholder\"\(attribute)>HTML raw</span>"
    }

    private func safeURL(_ rawURL: String?) -> String? {
        guard let rawURL, !rawURL.isEmpty else { return nil }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: { $0.isNewline || $0.isWhitespace }) else { return nil }

        if let scheme = URL(string: trimmed)?.scheme?.lowercased(),
           ["javascript", "vbscript", "data", "file", "blob"].contains(scheme) {
            return nil
        }
        return trimmed
    }

    private func editableAttribute(for markup: Markup) -> String {
        guard markup.parent is Document,
              let range = markup.range,
              let block = editableBlocks.first(where: {
                  $0.sourceRange.startOffset == sourceOffset(for: range.lowerBound)
              }) else {
            return ""
        }
        let supportAttribute = block.supportsVisualEditing ? "true" : "false"
        return " data-bp-block-id=\"\(escapeAttribute(block.id))\" data-bp-editable=\"\(supportAttribute)\""
    }

    private func specialAttribute(for markup: Markup, kind: MarkdownSpecialKind) -> String {
        guard let range = markup.range,
              let region = specialRegions.first(where: {
                  $0.kind == kind && $0.sourceRange.startOffset == sourceOffset(for: range.lowerBound)
              }) else {
            return ""
        }
        return " data-bp-special-kind=\"\(kind.rawValue)\" data-bp-special-id=\"\(escapeAttribute(region.id))\" data-bp-special-source=\"\(escapeAttribute(region.source))\""
    }

    private func specialAttribute(for region: MarkdownSpecialRegion) -> String {
        " data-bp-special-kind=\"\(region.kind.rawValue)\" data-bp-special-id=\"\(escapeAttribute(region.id))\" data-bp-special-source=\"\(escapeAttribute(region.source))\""
    }

    private func sourceOffset(for location: SourceLocation) -> Int {
        let bytes = Array(source.utf8)
        var line = 1
        var lineStart = 0
        var index = 0
        while index < bytes.count, line < location.line {
            if bytes[index] == 10 {
                line += 1
                lineStart = index + 1
            }
            index += 1
        }
        return min(lineStart + max(location.column - 1, 0), bytes.count)
    }

    private func localResourceURL(for source: String) -> URL? {
        guard URL(string: source)?.scheme == nil else { return nil }
        return baseURL.appendingPathComponent(source).standardizedFileURL
    }

    private func embeddedImageSource(for url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !data.isEmpty,
              let mimeType = imageMIMEType(for: url.pathExtension) else {
            return nil
        }

        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func imageMIMEType(for pathExtension: String) -> String? {
        switch pathExtension.lowercased() {
        case "avif": return "image/avif"
        case "bmp": return "image/bmp"
        case "gif": return "image/gif"
        case "ico": return "image/x-icon"
        case "jpeg", "jpg": return "image/jpeg"
        case "png": return "image/png"
        case "svg": return "image/svg+xml"
        case "tif", "tiff": return "image/tiff"
        case "webp": return "image/webp"
        default: return nil
        }
    }

    private func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeAttribute(_ value: String) -> String {
        escapeText(value)
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func renderTextWithMath(_ value: String, sourceOffset: Int) -> String {
        let pattern = #"\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^$\n]+)\$|@@([\s\S]+?)@@"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return escapeText(value)
        }

        let nsValue = value as NSString
        let range = NSRange(location: 0, length: nsValue.length)
        var result = ""
        var cursor = 0

        expression.enumerateMatches(in: value, range: range) { match, _, _ in
            guard let match else { return }
            let matchRange = match.range
            if matchRange.location > cursor {
                result += escapeText(nsValue.substring(with: NSRange(location: cursor, length: matchRange.location - cursor)))
            }

            let displayMode = match.range(at: 1).location != NSNotFound || match.range(at: 2).location != NSNotFound
            let captureIndex: Int
            if displayMode {
                captureIndex = match.range(at: 1).location != NSNotFound ? 1 : 2
            } else if match.range(at: 3).location != NSNotFound {
                captureIndex = 3
            } else if match.range(at: 4).location != NSNotFound {
                captureIndex = 4
            } else {
                captureIndex = 5
            }
            let source = nsValue.substring(with: match.range(at: captureIndex))
            let relativePrefix = nsValue.substring(to: matchRange.location)
            let matchOffset = sourceOffset + relativePrefix.utf8.count
            let attribute = specialRegions.first(where: {
                $0.kind == .math && $0.sourceRange.startOffset == matchOffset
            }).map(specialAttribute(for:)) ?? ""
            result += "<span class=\"math-inline\"\(attribute)>\(mathRenderer.render(source, displayMode: displayMode))</span>"
            cursor = matchRange.location + matchRange.length
        }

        if cursor < nsValue.length {
            result += escapeText(nsValue.substring(from: cursor))
        }
        return result
    }

    private func blockMathSource(in value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$$"), trimmed.hasSuffix("$$"), trimmed.count >= 4 {
            return String(trimmed.dropFirst(2).dropLast(2))
        }
        if trimmed.hasPrefix("\\["), trimmed.hasSuffix("\\]"), trimmed.count >= 4 {
            return String(trimmed.dropFirst(2).dropLast(2))
        }
        return nil
    }

    private mutating func uniqueHeadingID(for value: String) -> String {
        let base = value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let normalizedBase = base.isEmpty ? "section" : base
        let count = headingCounts[normalizedBase, default: 0]
        headingCounts[normalizedBase] = count + 1
        return count == 0 ? normalizedBase : "\(normalizedBase)-\(count + 1)"
    }
}
