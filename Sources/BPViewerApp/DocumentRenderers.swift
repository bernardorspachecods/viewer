import BPViewerCore
import Foundation
import ImageIO
@preconcurrency import PDFKit

extension DocumentPreviewOutput {
    /// Output with only the fields a renderer produces set; every other field
    /// takes the empty value, so each renderer lists just what it fills in.
    static func make(
        kind: DocumentKind,
        html: String? = nil,
        json: String? = nil,
        csv: CSVDocument? = nil,
        pdfData: Data? = nil,
        imageData: Data? = nil,
        source: String? = nil,
        baseURL: URL? = nil,
        dependencies: [URL] = [],
        externalDependencies: [URL] = [],
        outline: [MarkdownOutlineEntry] = [],
        blocks: [MarkdownEditableBlock] = [],
        syncTeXData: Data? = nil,
        generatedBibliographySource: String? = nil
    ) -> DocumentPreviewOutput {
        DocumentPreviewOutput(
            kind: kind,
            html: html,
            json: json,
            csv: csv,
            pdfData: pdfData,
            imageData: imageData,
            source: source,
            baseURL: baseURL,
            dependencies: dependencies,
            externalDependencies: externalDependencies,
            outline: outline,
            blocks: blocks,
            syncTeXData: syncTeXData,
            generatedBibliographySource: generatedBibliographySource
        )
    }
}

/// Per-kind rendering used by `DocumentRenderCoordinator.render`.
extension DocumentRenderCoordinator {
    nonisolated static func renderMarkdown(
        _ request: DocumentRenderRequest,
        markdownAdapter: any MarkdownAdapter
    ) throws -> DocumentPreviewOutput {
        let source = try request.markdownSourceOverride
            ?? String(contentsOf: request.url, encoding: .utf8)
        let markdownBaseURL = request.url.isFileURL
            ? request.url.deletingLastPathComponent()
            : request.projectRoot
                ?? URL(fileURLWithPath: "/", isDirectory: true)
        let result = try markdownAdapter.render(
            source: source,
            baseURL: markdownBaseURL
        )
        return DocumentPreviewOutput.make(
            kind: .markdown,
            html: result.html,
            source: source,
            baseURL: result.baseURL,
            dependencies: result.dependencies,
            outline: result.outline,
            blocks: result.blocks
        )
    }

    nonisolated static func renderJSON(_ request: DocumentRenderRequest) throws -> DocumentPreviewOutput {
        let source = try String(contentsOf: request.url, encoding: .utf8)
        return DocumentPreviewOutput.make(
            kind: .json,
            json: try JSONPreviewAdapter().format(source: source),
            source: source
        )
    }

    nonisolated static func renderCSV(_ request: DocumentRenderRequest) throws -> DocumentPreviewOutput {
        let source = try String(contentsOf: request.url, encoding: .utf8)
        return DocumentPreviewOutput.make(
            kind: .csv,
            csv: try CSVPreviewAdapter().parse(source: source),
            source: source
        )
    }

    nonisolated static func renderPDF(_ request: DocumentRenderRequest) throws -> DocumentPreviewOutput {
        let data = try Data(contentsOf: request.url)
        guard data.starts(with: Data("%PDF".utf8)), PDFDocument(data: data) != nil else {
            throw PDFPreviewError.invalidDocument
        }
        return DocumentPreviewOutput.make(kind: .pdf, pdfData: data)
    }

    nonisolated static func renderImage(_ request: DocumentRenderRequest) throws -> DocumentPreviewOutput {
        let data = try Data(contentsOf: request.url)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw ImagePreviewError.invalidDocument
        }
        return DocumentPreviewOutput.make(kind: .image, imageData: data)
    }

    nonisolated static func renderLaTeX(
        _ request: DocumentRenderRequest,
        latexRenderCache: LatexRenderCache
    ) throws -> DocumentPreviewOutput {
        guard let projectRoot = request.projectRoot else {
            throw DocumentRenderError.missingProjectRoot
        }
        let storedRootURL = request.latexRootURL
        let adapter = LocalLatexAdapter(shellEscapeMode: request.latexShellEscapeMode)
        let resolvedRootURL: URL
        if let storedRootURL {
            resolvedRootURL = storedRootURL
        } else {
            let resolution = try LatexRootDiscovery().resolve(
                openedFile: request.url,
                projectRoot: projectRoot
            )
            guard let selectedRoot = resolution.selectedRoot else {
                throw LatexRenderError.rootSelectionRequired(resolution.candidates)
            }
            resolvedRootURL = selectedRoot
        }

        let sourceOverrides = request.latexSourceOverride.map {
            [request.latexSourceURL ?? request.url: $0]
        } ?? [:]
        let externalDependencies = adapter.externalDependencies(
            rootURL: resolvedRootURL,
            projectRoot: projectRoot,
            sourceOverrides: sourceOverrides
        )
        let grantKey = latexExternalGrantKey(
            projectRoot: projectRoot,
            rootURL: resolvedRootURL
        )
        let approvedPaths = request.approvedLatexExternalPaths[grantKey, default: []]
        let unapprovedDependencies = externalDependencies.filter {
            !approvedPaths.contains($0.url.resolvingSymlinksInPath().standardizedFileURL.path)
        }
        if !unapprovedDependencies.isEmpty {
            throw LatexRenderError.externalDependenciesRequireConfirmation(
                resolvedRootURL,
                unapprovedDependencies
            )
        }

        let cacheKey = LatexCacheKey(
            projectRoot: projectRoot,
            rootURL: resolvedRootURL,
            compilerIdentity: try adapter.compilerIdentity(
                rootURL: resolvedRootURL,
                projectRoot: projectRoot
            ),
            shellEscapeMode: request.latexShellEscapeMode
        )
        if request.latexSourceOverride == nil,
           !request.force,
           let cached = latexRenderCache.load(key: cacheKey) {
            return DocumentPreviewOutput.make(
                kind: .latex,
                pdfData: cached.pdfData,
                dependencies: cached.dependencies,
                externalDependencies: cached.externalDependencies,
                syncTeXData: cached.syncTeXData,
                generatedBibliographySource: cached.generatedBibliographySource
            )
        }

        let result = try adapter.render(
            rootURL: resolvedRootURL,
            projectRoot: projectRoot,
            sourceOverrides: sourceOverrides
        )
        if request.latexSourceOverride == nil {
            try? latexRenderCache.store(key: cacheKey, result: result)
        }
        return DocumentPreviewOutput.make(
            kind: .latex,
            pdfData: result.pdfData,
            dependencies: result.dependencies,
            externalDependencies: result.externalDependencies,
            syncTeXData: result.syncTeXData,
            generatedBibliographySource: result.generatedBibliographySource
        )
    }
}
