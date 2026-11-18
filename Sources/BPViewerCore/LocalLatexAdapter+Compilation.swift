import Foundation

/// Where a LaTeX run reads from: the project itself, or a temporary overlay
/// that carries source overrides.
struct LatexCompilationScope {
    let project: URL
    let root: URL
}

extension LocalLatexAdapter {
    func validatedPaths(rootURL: URL, projectRoot: URL) throws -> (root: URL, project: URL) {
        let root = rootURL.standardizedFileURL
        let project = projectRoot.standardizedFileURL
        guard isDirectory(project) else {
            throw LatexRenderError.projectRootIsNotDirectory(project)
        }
        guard isRegularFile(root) else {
            throw LatexRenderError.rootIsNotFile(root)
        }
        guard isInside(root, project: project) else {
            throw LatexRenderError.rootOutsideProject(root)
        }
        return (root, project)
    }

    func resolveCompiler(preferredKind: LatexCompilerKind?) throws -> LatexCompiler {
        if let executableURL {
            let name = executableURL.lastPathComponent.lowercased()
            return LatexCompiler(
                url: executableURL,
                kind: LatexCompilerKind(rawValue: name) ?? .latexmk
            )
        }
        if let discovered = LatexExecutableLocator().findCompiler(preferredKind: preferredKind) {
            return discovered
        }
        throw LatexRenderError.toolUnavailable(preferredKind?.rawValue ?? "latexmk")
    }

    func createWorkspaceDirectories(_ workspace: URL, outputDirectory: URL) throws {
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw LatexRenderError.workspaceFailed(error.localizedDescription)
        }
    }

    func compilationScope(
        root: URL,
        project: URL,
        sourceDependencies: [URL],
        sourceOverrides: [URL: String],
        workspace: URL
    ) throws -> LatexCompilationScope {
        if sourceOverrides.isEmpty {
            return LatexCompilationScope(project: project, root: root)
        }
        let overlay = workspace.appendingPathComponent("project", isDirectory: true)
        do {
            try copyProjectInputs(
                sourceDependencies,
                projectRoot: project,
                overlayRoot: overlay
            )
            try writeSourceOverrides(
                sourceOverrides,
                projectRoot: project,
                overlayRoot: overlay
            )
        } catch {
            throw LatexRenderError.workspaceFailed(error.localizedDescription)
        }
        return LatexCompilationScope(
            project: overlay,
            root: overlay.appendingPathComponent(relativePath(of: root, within: project))
        )
    }

    /// The bibliography pass that follows the first compile, or nil when the
    /// document needs none. Throws when the bibliography tool is missing.
    func bibliographyRequest(
        compilerKind: LatexCompilerKind,
        sourceDependencies: [URL],
        root: URL,
        outputDirectory: URL,
        scope: LatexCompilationScope,
        externalDependencies: [URL]
    ) throws -> ProcessRequest? {
        let tool = compilerKind != .latexmk ? bibliographyTool(for: sourceDependencies) : nil
        guard let tool else { return nil }

        let executable: URL?
        switch tool {
        case .biber:
            executable = biberExecutableURL ?? LatexExecutableLocator().findTool(named: "biber")
        case .bibtex:
            executable = bibtexExecutableURL ?? LatexExecutableLocator().findTool(named: "bibtex")
        }
        guard let executable else {
            throw LatexRenderError.toolUnavailable(tool.rawValue)
        }

        let stem = root.deletingPathExtension().lastPathComponent
        let arguments: [String]
        switch tool {
        case .biber:
            arguments = [
                "--input-directory=\(outputDirectory.path)",
                "--output-directory=\(outputDirectory.path)",
                stem
            ]
        case .bibtex:
            arguments = [stem]
        }
        return ProcessRequest(
            executable: executable,
            arguments: arguments,
            workingDirectory: outputDirectory,
            environment: searchEnvironment(
                root: scope.root,
                project: scope.project,
                dependencies: sourceDependencies + externalDependencies
            ),
            timeout: timeout
        )
    }

    func compilationRequest(
        compiler: LatexCompiler,
        engineHint: LatexCompilerKind?,
        outputDirectory: URL,
        workspace: URL,
        scope: LatexCompilationScope,
        dependencies: [URL]
    ) -> ProcessRequest {
        var arguments: [String] = []
        if compiler.kind == .latexmk {
            arguments.append("-pdf")
            if engineHint == .xelatex {
                arguments.append("-xelatex")
            } else if engineHint == .lualatex {
                arguments.append("-lualatex")
            }
        }
        let outputArgument = compiler.kind == .latexmk
            ? "-outdir=\(outputDirectory.path)"
            : "-output-directory=\(outputDirectory.path)"
        arguments += [
            "-interaction=nonstopmode",
            "-halt-on-error",
            "-file-line-error",
            "-synctex=1",
            "-recorder",
            outputArgument,
            scope.root.path
        ]
        arguments.insert(shellEscapeArgument, at: 0)
        return ProcessRequest(
            executable: compiler.url,
            arguments: arguments,
            workingDirectory: workspace,
            environment: searchEnvironment(
                root: scope.root,
                project: scope.project,
                dependencies: dependencies
            ),
            timeout: timeout
        )
    }

    /// Runs the compile, then the bibliography pass, then the cross-reference
    /// reruns. Without latexmk the reruns resolve references and PDF outlines
    /// the way a normal local LaTeX workflow does.
    func runCompilationPasses(
        _ request: ProcessRequest,
        bibliography: ProcessRequest?,
        compilerKind: LatexCompilerKind
    ) throws -> [ProcessResult] {
        var processResults = [try runner.run(request)]
        guard processResults[0].status == .success else {
            throw LatexRenderError.compilationFailed(combinedResult(processResults))
        }

        if let bibliography {
            let bibliographyResult = try runner.run(bibliography)
            processResults.append(bibliographyResult)
            guard bibliographyResult.status == .success else {
                throw LatexRenderError.compilationFailed(combinedResult(processResults))
            }
        }

        if compilerKind != .latexmk {
            for _ in 0..<2 {
                let rerunResult = try runner.run(request)
                processResults.append(rerunResult)
                guard rerunResult.status == .success else {
                    throw LatexRenderError.compilationFailed(combinedResult(processResults))
                }
            }
        }
        return processResults
    }

    func readOutputPDF(_ outputURL: URL, result: ProcessResult) throws -> Data {
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw LatexRenderError.outputPDFMissing(outputURL, result)
        }
        guard let pdfData = try? Data(contentsOf: outputURL), !pdfData.isEmpty else {
            throw LatexRenderError.outputPDFUnreadable(outputURL)
        }
        guard pdfData.starts(with: Data("%PDF".utf8)) else {
            throw LatexRenderError.outputPDFInvalid(outputURL)
        }
        return pdfData
    }
}
