import AppKit
import Foundation

struct DocxHTMLArtifact: Sendable {
    let htmlURL: URL
    let directoryURL: URL
}

struct DocxPageSize {
    let width: CGFloat
    let height: CGFloat

    static let a4 = DocxPageSize(width: 794, height: 1123)
}

enum DocxHTMLConverter {
    static func convert(url: URL) throws -> DocxHTMLArtifact {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewer-docx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let htmlURL = directoryURL.appendingPathComponent("document.html")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = [
            "-convert", "html",
            "-output", htmlURL.path,
            url.path
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: htmlURL.path) else {
            try? FileManager.default.removeItem(at: directoryURL)
            throw DocxHTMLConversionError.failed
        }

        let source = try String(contentsOf: htmlURL, encoding: .utf8)
        let pageSize = (try? pageSize(from: url)) ?? .a4
        let headerImageName = extractHeaderImage(from: url, to: directoryURL)
        let styledSource = DocxHTMLStyler.apply(
            to: source,
            pageSize: pageSize,
            headerImageName: headerImageName
        )
        try styledSource.write(to: htmlURL, atomically: true, encoding: .utf8)
        return DocxHTMLArtifact(htmlURL: htmlURL, directoryURL: directoryURL)
    }

    private static func pageSize(from url: URL) throws -> DocxPageSize {
        let source = try String(
            data: unzipData(from: url, entry: "word/document.xml"),
            encoding: .utf8
        ) ?? ""
        guard let start = source.range(of: "<w:pgSz"),
              let end = source.range(of: ">", range: start.upperBound..<source.endIndex),
              let width = attribute("w:w", in: String(source[start.lowerBound..<end.upperBound])),
              let height = attribute("w:h", in: String(source[start.lowerBound..<end.upperBound])),
              let widthTwips = Double(width),
              let heightTwips = Double(height) else {
            throw DocxHTMLConversionError.failed
        }
        return DocxPageSize(
            width: CGFloat(widthTwips / 15),
            height: CGFloat(heightTwips / 15)
        )
    }

    private static func extractHeaderImage(from url: URL, to directoryURL: URL) -> String? {
        guard let headerSource = try? String(
            data: unzipData(from: url, entry: "word/header1.xml"),
            encoding: .utf8
        ),
        let relationshipID = attribute("r:embed", in: headerSource),
        let relationships = try? String(
            data: unzipData(from: url, entry: "word/_rels/header1.xml.rels"),
            encoding: .utf8
        ),
        let relationshipRange = relationships.range(of: "Id=\"\(relationshipID)\"") else {
            return nil
        }

        let relationshipStart = relationships[..<relationshipRange.lowerBound]
            .range(of: "<Relationship", options: .backwards)?.lowerBound ?? relationshipRange.lowerBound
        guard let relationshipEnd = relationships.range(
            of: ">",
            range: relationshipRange.upperBound..<relationships.endIndex
        ) else {
            return nil
        }
        let relationship = String(relationships[relationshipStart..<relationshipEnd.upperBound])
        guard let target = attribute("Target", in: relationship) else { return nil }

        let zipEntry = "word/" + target
            .replacingOccurrences(of: "../", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let imageData = try? unzipData(from: url, entry: zipEntry) else { return nil }

        let imageName = "header-" + URL(fileURLWithPath: zipEntry).lastPathComponent
        let imageURL = directoryURL.appendingPathComponent(imageName)
        guard (try? imageData.write(to: imageURL, options: .atomic)) != nil else { return nil }
        return imageName
    }

    private static func unzipData(from url: URL, entry: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, entry]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DocxHTMLConversionError.failed
        }
        return outputPipe.fileHandleForReading.readDataToEndOfFile()
    }

    private static func attribute(_ name: String, in source: String) -> String? {
        let prefix = "\(name)=\""
        guard let start = source.range(of: prefix),
              let end = source.range(of: "\"", range: start.upperBound..<source.endIndex) else {
            return nil
        }
        return String(source[start.upperBound..<end.lowerBound])
    }

    private enum DocxHTMLConversionError: Error {
        case failed
    }
}

enum DocxHTMLStyler {
    static func apply(
        to source: String,
        pageSize: DocxPageSize,
        headerImageName: String?
    ) -> String {
        let headerMarkup = headerImageName.map {
            "<img class=\"viewer-header-logo\" src=\"\($0)\" alt=\"\">"
        } ?? ""
        let style = """
        <style id="viewer-docx-style">
          :root {
            color-scheme: light;
          }
          html {
            min-height: 100%;
            width: 100%;
            min-width: 100%;
            background: transparent;
          }
          body {
            margin: 0;
            width: 100%;
            min-width: 100%;
            background: transparent;
            display: flex;
            flex-direction: column;
            align-items: center;
            font-family: Calibri, "Helvetica Neue", Arial, sans-serif;
            font-size: 16px;
            line-height: 1.15;
            overflow-wrap: break-word;
          }
          .viewer-page,
          .viewer-page p,
          .viewer-page span {
            font-family: Calibri, "Helvetica Neue", Arial, sans-serif;
            font-size: 16px;
            line-height: 1.15;
          }
          .viewer-page p {
            margin: 0 0 18.67px;
          }
          .viewer-page p.p1,
          .viewer-page p.p2,
          .viewer-page p.p3 {
            margin-bottom: 14px;
          }
          .viewer-page p:last-child {
            margin-bottom: 0;
          }
          .viewer-page p.p2 {
            font-size: 18.67px;
          }
          .viewer-page {
            box-sizing: border-box;
            position: relative;
            width: \(pageSize.width)px;
            min-height: \(pageSize.height)px;
            flex: 0 0 auto;
            margin: 16px 0;
            padding: 96px;
            background: #ffffff;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.24);
            color: #202124;
          }
          .viewer-header-logo {
            position: absolute;
            top: 60px;
            left: 96px;
            display: block;
            width: 354px;
            height: auto;
          }
          .viewer-page > * {
            max-width: 100%;
          }
          img {
            max-width: 100%;
            height: auto;
          }
          table {
            max-width: 100%;
          }
        </style>
        """

        var styledSource = source
        if let closingHead = styledSource.range(of: "</head>", options: .caseInsensitive) {
            styledSource.replaceSubrange(closingHead, with: style + "</head>")
        }

        guard let bodyStart = styledSource.range(of: "<body", options: .caseInsensitive),
              let bodyEnd = styledSource.range(of: "</body>", options: .caseInsensitive),
              let openingTagEnd = styledSource.range(
                  of: ">",
                  range: bodyStart.upperBound..<bodyEnd.lowerBound
              ) else {
            return "<html><head>\(style)</head><body><div class=\"viewer-page\">\(headerMarkup)\(source)</div></body></html>"
        }

        styledSource.insert(
            contentsOf: "<div class=\"viewer-page\">\(headerMarkup)",
            at: openingTagEnd.upperBound
        )
        if let updatedBodyEnd = styledSource.range(of: "</body>", options: .caseInsensitive) {
            styledSource.insert(contentsOf: "</div>", at: updatedBodyEnd.lowerBound)
        }
        return styledSource
    }
}
