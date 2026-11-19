import AppKit
import ViewerCore
import Foundation
import ImageIO
@preconcurrency import PDFKit

struct DocumentRenderRequest: Sendable {
    let tabID: String
    let url: URL
    let kind: DocumentKind
    let projectRoot: URL?
    let markdownSourceOverride: String?
    let latexSourceURL: URL?
    let latexSourceOverride: String?
    let latexRootURL: URL?
    let latexShellEscapeMode: LatexShellEscapeMode
    let approvedLatexExternalPaths: [String: Set<String>]
    let force: Bool

    init(
        tabID: String,
        url: URL,
        kind: DocumentKind,
        projectRoot: URL?,
        markdownSourceOverride: String?,
        latexSourceURL: URL? = nil,
        latexSourceOverride: String? = nil,
        latexRootURL: URL?,
        latexShellEscapeMode: LatexShellEscapeMode,
        approvedLatexExternalPaths: [String: Set<String>],
        force: Bool
    ) {
        self.tabID = tabID
        self.url = url
        self.kind = kind
        self.projectRoot = projectRoot
        self.markdownSourceOverride = markdownSourceOverride
        self.latexSourceURL = latexSourceURL
        self.latexSourceOverride = latexSourceOverride
        self.latexRootURL = latexRootURL
        self.latexShellEscapeMode = latexShellEscapeMode
        self.approvedLatexExternalPaths = approvedLatexExternalPaths
        self.force = force
    }
}

struct DocumentPreviewOutput: Sendable {
    let kind: DocumentKind
    let html: String?
    let json: String?
    let csv: CSVDocument?
    let pdfData: Data?
    let imageData: Data?
    let source: String?
    let baseURL: URL?
    let dependencies: [URL]
    let externalDependencies: [URL]
    let outline: [MarkdownOutlineEntry]
    let blocks: [MarkdownEditableBlock]
    let syncTeXData: Data?
    let generatedBibliographySource: String?
}

struct DocumentRenderFailure: Sendable {
    let status: PreviewStatus
    let message: String
    let latexRootSelectionCandidates: [LatexRootCandidate]?
    let latexRootURL: URL?
    let latexExternalDependencies: [LatexExternalDependency]?
    let projectRoot: URL?
}

enum DocumentRenderEvent {
    case started(tabID: String)
    case ready(tabID: String, output: DocumentPreviewOutput)
    case failed(tabID: String, failure: DocumentRenderFailure)
}

/// Owns preview work and its asynchronous lifecycle. The app remains the
/// owner of DocumentTab and applies these events to observable UI state.
@MainActor
final class DocumentRenderCoordinator {
    private let markdownAdapter: any MarkdownAdapter
    private let latexRenderCache: LatexRenderCache
    private let onEvent: (DocumentRenderEvent) -> Void
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generations: [String: Int] = [:]

    init(
        markdownAdapter: any MarkdownAdapter = SwiftMarkdownAdapter(codeHighlighter: MarkdownPreviewCodeHighlighter.shared),
        latexRenderCache: LatexRenderCache = LatexRenderCache(),
        onEvent: @escaping (DocumentRenderEvent) -> Void
    ) {
        self.markdownAdapter = markdownAdapter
        self.latexRenderCache = latexRenderCache
        self.onEvent = onEvent
    }

    func render(_ request: DocumentRenderRequest) {
        guard request.kind == .markdown
                || request.kind == .json
                || request.kind == .csv
                || request.kind == .latex
                || request.kind == .pdf
                || request.kind == .image else { return }

        tasks[request.tabID]?.cancel()
        let generation = (generations[request.tabID] ?? 0) + 1
        generations[request.tabID] = generation
        onEvent(.started(tabID: request.tabID))

        let markdownAdapter = markdownAdapter
        let latexRenderCache = latexRenderCache
        let task = Task { [weak self] in
            do {
                let output = try await Task.detached(priority: .userInitiated) {
                    try Self.render(
                        request,
                        markdownAdapter: markdownAdapter,
                        latexRenderCache: latexRenderCache
                    )
                }.value

                guard let self,
                      self.generations[request.tabID] == generation else { return }
                self.tasks.removeValue(forKey: request.tabID)
                self.onEvent(.ready(tabID: request.tabID, output: output))
            } catch {
                guard let self,
                      self.generations[request.tabID] == generation,
                      !Task.isCancelled else { return }
                self.tasks.removeValue(forKey: request.tabID)
                self.onEvent(.failed(
                    tabID: request.tabID,
                    failure: Self.failure(for: error, request: request)
                ))
            }
        }
        tasks[request.tabID] = task
    }

    func cancel(tabIDs: some Sequence<String>) {
        for tabID in tabIDs {
            tasks[tabID]?.cancel()
            tasks.removeValue(forKey: tabID)
            generations[tabID, default: 0] += 1
        }
    }

    func cancelAll() {
        cancel(tabIDs: tasks.keys)
    }

    nonisolated private static func render(
        _ request: DocumentRenderRequest,
        markdownAdapter: any MarkdownAdapter,
        latexRenderCache: LatexRenderCache
    ) throws -> DocumentPreviewOutput {
        switch request.kind {
        case .markdown:
            return try renderMarkdown(request, markdownAdapter: markdownAdapter)
        case .json:
            return try renderJSON(request)
        case .csv:
            return try renderCSV(request)
        case .pdf:
            return try renderPDF(request)
        case .image:
            return try renderImage(request)
        case .latex:
            return try renderLaTeX(request, latexRenderCache: latexRenderCache)
        case .docx, .other:
            throw DocumentRenderError.unsupportedKind
        }
    }

    nonisolated private static func failure(
        for error: Error,
        request: DocumentRenderRequest
    ) -> DocumentRenderFailure {
        if let latexError = error as? LatexRenderError {
            switch latexError {
            case let .rootSelectionRequired(candidates):
                return DocumentRenderFailure(
                    status: .failed,
                    message: error.localizedDescription,
                    latexRootSelectionCandidates: candidates,
                    latexRootURL: nil,
                    latexExternalDependencies: nil,
                    projectRoot: request.projectRoot
                )
            case let .externalDependenciesRequireConfirmation(rootURL, dependencies):
                return DocumentRenderFailure(
                    status: .failed,
                    message: error.localizedDescription,
                    latexRootSelectionCandidates: nil,
                    latexRootURL: rootURL,
                    latexExternalDependencies: dependencies,
                    projectRoot: request.projectRoot
                )
            default:
                return DocumentRenderFailure(
                    status: previewStatus(for: latexError),
                    message: error.localizedDescription,
                    latexRootSelectionCandidates: nil,
                    latexRootURL: nil,
                    latexExternalDependencies: nil,
                    projectRoot: request.projectRoot
                )
            }
        }

        return DocumentRenderFailure(
            status: .failed,
            message: error.localizedDescription,
            latexRootSelectionCandidates: nil,
            latexRootURL: nil,
            latexExternalDependencies: nil,
            projectRoot: request.projectRoot
        )
    }

    nonisolated private static func previewStatus(for error: LatexRenderError) -> PreviewStatus {
        switch error {
        case .toolUnavailable:
            return .unavailable
        case let .compilationFailed(result), let .outputPDFMissing(_, result):
            switch result.status {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            case .launchFailed: return .unavailable
            case .failed, .success: return .failed
            }
        default:
            return .failed
        }
    }

    nonisolated static func latexExternalGrantKey(projectRoot: URL, rootURL: URL) -> String {
        "\(projectRoot.standardizedFileURL.path)\n\(rootURL.standardizedFileURL.path)"
    }
}

enum PDFPreviewError: LocalizedError, Sendable {
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The file does not contain a valid PDF."
        }
    }
}

enum ImagePreviewError: LocalizedError, Sendable {
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "The file does not contain a valid image."
        }
    }
}

enum DocumentRenderError: LocalizedError, Sendable {
    case missingProjectRoot
    case unsupportedKind

    var errorDescription: String? {
        switch self {
        case .missingProjectRoot:
            "There is no active LaTeX workspace."
        case .unsupportedKind:
            "No renderer is available for this document type."
        }
    }
}
