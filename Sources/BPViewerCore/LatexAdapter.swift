import Foundation
import Darwin

public struct LocalLatexAdapter: Sendable {
    let runner: any ProcessRunning
    let executableURL: URL?
    let biberExecutableURL: URL?
    let bibtexExecutableURL: URL?
    let shellEscapeMode: LatexShellEscapeMode
    let timeout: TimeInterval

    public init(
        runner: any ProcessRunning = LiveProcessRunner(),
        executableURL: URL? = nil,
        biberExecutableURL: URL? = nil,
        bibtexExecutableURL: URL? = nil,
        shellEscapeMode: LatexShellEscapeMode = .disabled,
        timeout: TimeInterval = 120
    ) {
        self.runner = runner
        self.executableURL = executableURL
        self.biberExecutableURL = biberExecutableURL
        self.bibtexExecutableURL = bibtexExecutableURL
        self.shellEscapeMode = shellEscapeMode
        self.timeout = timeout
    }

    public func externalDependencies(
        rootURL: URL,
        projectRoot: URL,
        sourceOverrides: [URL: String] = [:]
    ) -> [LatexExternalDependency] {
        guard let paths = try? validatedPaths(rootURL: rootURL, projectRoot: projectRoot) else {
            return []
        }
        let root = paths.root
        let project = paths.project

        var visited = Set([root])
        var pending = [root]
        var discovered = Set<LatexExternalDependency>()

        while let current = pending.popLast() {
            guard let source = source(for: current, overrides: sourceOverrides) else { continue }
            for reference in referencedPaths(in: source) {
                let candidates = candidateURLs(reference: reference, relativeTo: current)
                if let externalURL = candidates.first(where: {
                    isRegularFile($0) && !isInside($0, project: project)
                }) {
                    discovered.insert(
                        LatexExternalDependency(url: externalURL, sourceURL: current)
                    )
                    continue
                }
                if let localURL = candidates.first(where: {
                    isRegularFile($0) && isInside($0, project: project)
                }), visited.insert(localURL).inserted {
                    pending.append(localURL)
                }
            }
        }

        return discovered.sorted {
            $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
        }
    }

    public func sourceDependencies(rootURL: URL, projectRoot: URL) -> [URL] {
        guard let paths = try? validatedPaths(rootURL: rootURL, projectRoot: projectRoot) else {
            return []
        }
        return dependencies(for: paths.root, project: paths.project)
    }

    public func compilerIdentity(rootURL: URL, projectRoot: URL) throws -> String {
        let paths = try validatedPaths(rootURL: rootURL, projectRoot: projectRoot)
        let dependencies = dependencies(for: paths.root, project: paths.project)
        let hint = engineHint(for: dependencies)
        let compiler = try resolveCompiler(preferredKind: hint)

        let values = try? compiler.url.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        )
        let effectiveEngine = compiler.kind == .latexmk
            ? (hint ?? .pdflatex)
            : compiler.kind
        return [
            compiler.kind.rawValue,
            effectiveEngine.rawValue,
            compiler.url.standardizedFileURL.path,
            values?.fileSize.map(String.init) ?? "",
            values?.contentModificationDate?.timeIntervalSinceReferenceDate.description ?? ""
        ].joined(separator: "\u{1f}")
    }

    public func render(
        rootURL: URL,
        projectRoot: URL,
        sourceOverrides: [URL: String] = [:]
    ) throws -> LatexRenderResult {
        let paths = try validatedPaths(rootURL: rootURL, projectRoot: projectRoot)
        let root = paths.root
        let project = paths.project
        let sourceDependencies = dependencies(
            for: root,
            project: project,
            sourceOverrides: sourceOverrides
        )
        let engineHint = engineHint(for: sourceDependencies)
        let externalDependencyURLs = externalDependencies(
            rootURL: root,
            projectRoot: project,
            sourceOverrides: sourceOverrides
        )
            .map(\.url)
        let compiler = try resolveCompiler(preferredKind: engineHint)

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("bp-viewer-latex-" + UUID().uuidString, isDirectory: true)
        let outputDirectory = workspace.appendingPathComponent("output", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        try createWorkspaceDirectories(workspace, outputDirectory: outputDirectory)

        let scope = try compilationScope(
            root: root,
            project: project,
            sourceDependencies: sourceDependencies,
            sourceOverrides: sourceOverrides,
            workspace: workspace
        )
        let bibliography = try bibliographyRequest(
            compilerKind: compiler.kind,
            sourceDependencies: sourceDependencies,
            root: root,
            outputDirectory: outputDirectory,
            scope: scope,
            externalDependencies: externalDependencyURLs
        )
        let request = compilationRequest(
            compiler: compiler,
            engineHint: engineHint,
            outputDirectory: outputDirectory,
            workspace: workspace,
            scope: scope,
            dependencies: sourceDependencies + externalDependencyURLs
        )
        let processResults = try runCompilationPasses(
            request,
            bibliography: bibliography,
            compilerKind: compiler.kind
        )
        let result = combinedResult(processResults)

        let stem = root.deletingPathExtension().lastPathComponent
        let pdfData = try readOutputPDF(
            outputDirectory.appendingPathComponent(stem).appendingPathExtension("pdf"),
            result: result
        )
        let syncTeXData = readSyncTeXData(
            in: outputDirectory,
            stem: stem,
            compilationProject: scope.project,
            project: project
        )
        let generatedBibliographySource = try? String(
            contentsOf: outputDirectory.appendingPathComponent(stem + ".bbl"),
            encoding: .utf8
        )

        let recorderDependencies = dependenciesFromRecorder(
            at: outputDirectory.appendingPathComponent(stem + ".fls"),
            project: project,
            overlayProject: sourceOverrides.isEmpty ? nil : scope.project
        )
        let allDependencies = Set(sourceDependencies).union(recorderDependencies).sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }

        return LatexRenderResult(
            pdfData: pdfData,
            rootURL: root,
            dependencies: allDependencies,
            externalDependencies: externalDependencyURLs,
            processResult: result,
            syncTeXData: syncTeXData,
            generatedBibliographySource: generatedBibliographySource
        )
    }
}
