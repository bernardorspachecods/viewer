import Foundation

public enum LatexRenderError: LocalizedError, Sendable {
    case rootIsNotFile(URL)
    case rootOutsideProject(URL)
    case projectRootIsNotDirectory(URL)
    case rootSelectionRequired([LatexRootCandidate])
    case externalDependenciesRequireConfirmation(URL, [LatexExternalDependency])
    case toolUnavailable(String)
    case compilationFailed(ProcessResult)
    case outputPDFMissing(URL, ProcessResult)
    case outputPDFUnreadable(URL)
    case outputPDFInvalid(URL)
    case workspaceFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .rootIsNotFile(url):
            return "The LaTeX root is not a file: \(url.path)"
        case let .rootOutsideProject(url):
            return "The LaTeX root is outside the project folder: \(url.path)"
        case let .projectRootIsNotDirectory(url):
            return "The LaTeX project folder does not exist or is not a folder: \(url.path)"
        case let .rootSelectionRequired(candidates):
            if candidates.isEmpty {
                return "No main LaTeX document was found in this folder."
            }
            let paths = candidates.map(\.url.path).joined(separator: ", ")
            return "You must choose the main LaTeX document from: \(paths)"
        case let .externalDependenciesRequireConfirmation(_, dependencies):
            let paths = dependencies.map(\.url.path).joined(separator: ", ")
            return "The LaTeX document references files outside the project folder and requires confirmation: \(paths)"
        case let .toolUnavailable(name):
            return "The LaTeX tool '\(name)' was not found. Install a local LaTeX distribution and try again."
        case let .compilationFailed(result):
            let output = result.combinedOutput
            if output.isEmpty {
                return "LaTeX compilation failed (code \(result.exitCode.map(String.init) ?? "unknown"))."
            }
            return "LaTeX compilation failed:\n\(output)"
        case let .outputPDFMissing(url, result):
            return "Compilation finished without producing the expected PDF at \(url.path).\n\(result.combinedOutput)"
        case let .outputPDFUnreadable(url):
            return "Unable to read the compiled PDF: \(url.path)"
        case let .outputPDFInvalid(url):
            return "The tool produced a file that is not a valid PDF: \(url.path)"
        case let .workspaceFailed(message):
            return "Unable to prepare the temporary LaTeX workspace: \(message)"
        }
    }
}
public struct LatexRenderResult: Sendable {
    public let pdfData: Data
    public let rootURL: URL
    public let dependencies: [URL]
    public let externalDependencies: [URL]
    public let processResult: ProcessResult
    public let wasCached: Bool
    public let syncTeXData: Data?
    public let generatedBibliographySource: String?

    public init(
        pdfData: Data,
        rootURL: URL,
        dependencies: [URL],
        externalDependencies: [URL] = [],
        processResult: ProcessResult,
        wasCached: Bool = false,
        syncTeXData: Data? = nil,
        generatedBibliographySource: String? = nil
    ) {
        self.pdfData = pdfData
        self.rootURL = rootURL.standardizedFileURL
        self.dependencies = dependencies.map(\.standardizedFileURL)
        self.externalDependencies = externalDependencies.map(\.standardizedFileURL)
        self.processResult = processResult
        self.wasCached = wasCached
        self.syncTeXData = syncTeXData
        self.generatedBibliographySource = generatedBibliographySource
    }
}

public struct LatexExternalDependency: Hashable, Sendable {
    public let url: URL
    public let sourceURL: URL

    public init(url: URL, sourceURL: URL) {
        self.url = url.resolvingSymlinksInPath().standardizedFileURL
        self.sourceURL = sourceURL.resolvingSymlinksInPath().standardizedFileURL
    }
}
