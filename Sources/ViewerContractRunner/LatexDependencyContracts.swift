import ViewerCore
import Foundation

extension ViewerContractRunner {
    static func runLatexDependencyContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let bibliographyRoot = fixtureRoot.appendingPathComponent("bibliography.tex")
        try """
        \\documentclass{article}
        \\usepackage{biblatex}
        \\addbibresource{references.bib}
        \\input{\(fixtureRoot.deletingLastPathComponent().appendingPathComponent("viewer-external.tex").path)}
        \\begin{document}
        Bibliography
        \\printbibliography
        \\end{document}
        """.write(to: bibliographyRoot, atomically: true, encoding: .utf8)
        try "@book{example, author={Example}, title={A title}, year={2026}}\n"
            .write(
                to: fixtureRoot.appendingPathComponent("references.bib"),
                atomically: true,
                encoding: .utf8
            )
        let externalDependency = fixtureRoot.deletingLastPathComponent()
            .appendingPathComponent("viewer-external.tex")
        try "External dependency\n"
            .write(to: externalDependency, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: externalDependency) }
        let externalDependencies = LocalLatexAdapter().externalDependencies(
            rootURL: bibliographyRoot,
            projectRoot: fixtureRoot
        )
        expect(
            externalDependencies.contains { $0.url == externalDependency.standardizedFileURL },
            "external LaTeX dependency detection"
        )
        var invalidContexts = [String: String]()
        LatexTabContextPersistence.store(
            contextURL: externalDependency,
            forTabID: bibliographyRoot.path,
            in: &invalidContexts
        )
        expect(
            LatexTabContextPersistence.restore(
                forTabID: bibliographyRoot.path,
                tabURL: bibliographyRoot,
                kind: .latex,
                from: invalidContexts,
                projectRoot: fixtureRoot
            ) == nil,
            "LaTeX context outside project is rejected"
        )
        let linkedExternalRoot = fixtureRoot.appendingPathComponent("linked-external.tex")
        let linkedExternalPath = fixtureRoot.appendingPathComponent("linked.tex")
        try "\\input{linked.tex}\n".write(
            to: linkedExternalRoot,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createSymbolicLink(
            at: linkedExternalPath,
            withDestinationURL: externalDependency
        )
        defer {
            try? FileManager.default.removeItem(at: linkedExternalRoot)
            try? FileManager.default.removeItem(at: linkedExternalPath)
        }
        let linkedDependencies = LocalLatexAdapter().externalDependencies(
            rootURL: linkedExternalRoot,
            projectRoot: fixtureRoot
        )
        expect(
            linkedDependencies.contains { $0.url == externalDependency.resolvingSymlinksInPath().standardizedFileURL },
            "symlinked external LaTeX dependency requires confirmation"
        )
        let bibliographyRunner = RecordingLatexProcessRunner()
        let bibliographyResult = try LocalLatexAdapter(
            runner: bibliographyRunner,
            executableURL: URL(fileURLWithPath: "/tmp/pdflatex"),
            biberExecutableURL: URL(fileURLWithPath: "/tmp/biber")
        ).render(rootURL: bibliographyRoot, projectRoot: fixtureRoot)
        expect(
            bibliographyRunner.calls == ["pdflatex", "biber", "pdflatex", "pdflatex"],
            "BibLaTeX fallback pass sequence"
        )
        expect(
            bibliographyRunner.requests.first?.arguments.contains("-no-shell-escape") == true,
            "LaTeX shell escape disabled by default"
        )
        expect(
            ["TEXINPUTS", "BIBINPUTS", "BSTINPUTS"].allSatisfy { key in
                !(bibliographyRunner.requests.first?.environment[key]?.contains("//") ?? true)
            },
            "LaTeX search paths are non-recursive"
        )
        expect(
            bibliographyResult.externalDependencies.contains(externalDependency.standardizedFileURL),
            "approved external dependency remains observable"
        )
    }

    static func runLatexFontContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let fontRoot = fixtureRoot.appendingPathComponent("system-fonts.tex")
        try """
        \\documentclass{article}
        \\usepackage{fontspec}
        \\begin{document}
        System fonts
        \\end{document}
        """.write(to: fontRoot, atomically: true, encoding: .utf8)
        let fontRunner = RecordingLatexProcessRunner()
        _ = try LocalLatexAdapter(
            runner: fontRunner,
            executableURL: URL(fileURLWithPath: "/tmp/xelatex")
        ).render(rootURL: fontRoot, projectRoot: fixtureRoot)
        expect(fontRunner.calls == ["xelatex", "xelatex", "xelatex"], "XeLaTeX engine selection and reruns")
        expect(
            fontRunner.requests.first?.arguments.contains("-no-shell-escape") == true,
            "LaTeX shell escape disabled by default"
        )
    }

    static func runLatexCacheContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let latexProject = latex.project
        let latexRoot = latex.root
        let cacheDirectory = fixtureRoot.deletingLastPathComponent()
            .appendingPathComponent("viewer-latex-cache-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let cache = LatexRenderCache(directory: cacheDirectory)
        let cacheKey = LatexCacheKey(
            projectRoot: fixtureRoot,
            rootURL: latexRoot,
            compilerIdentity: "pdflatex\u{1f}/tmp/pdflatex",
            shellEscapeMode: .disabled
        )
        let cachedPDF = Data("%PDF-1.4\n% cached PDF\n".utf8)
        let cacheResult = LatexRenderResult(
            pdfData: cachedPDF,
            rootURL: latexRoot,
            dependencies: [latexRoot, latexProject.appendingPathComponent("developercv.cls")],
            processResult: ProcessResult(status: .success, exitCode: 0, standardOutput: "", standardError: "")
        )
        try cache.store(key: cacheKey, result: cacheResult)
        expect(cache.load(key: cacheKey)?.pdfData == cachedPDF, "LaTeX cache hit")
        let changedRoot = try String(contentsOf: latexRoot, encoding: .utf8) + "% changed\n"
        try changedRoot.write(to: latexRoot, atomically: true, encoding: .utf8)
        expect(cache.load(key: cacheKey) == nil, "LaTeX cache invalidates changed dependency")
        try "\\documentclass{developercv}\n\\begin{document}\nMain\\end{document}\n"
            .write(to: latexRoot, atomically: true, encoding: .utf8)
        try cache.store(key: cacheKey, result: cacheResult)
        let changedModeKey = LatexCacheKey(
            projectRoot: fixtureRoot,
            rootURL: latexRoot,
            compilerIdentity: "pdflatex\u{1f}/tmp/pdflatex",
            shellEscapeMode: .restricted
        )
        expect(cache.load(key: changedModeKey) == nil, "LaTeX cache invalidates configuration change")
        let failedCacheResult = LatexRenderResult(
            pdfData: Data("%PDF-1.4\n% failed output\n".utf8),
            rootURL: latexRoot,
            dependencies: cacheResult.dependencies,
            processResult: ProcessResult(status: .failed, exitCode: 1, standardOutput: "", standardError: "error")
        )
        try cache.store(key: cacheKey, result: failedCacheResult)
        expect(cache.load(key: cacheKey)?.pdfData == cachedPDF, "failed LaTeX render does not replace cache")
    }
}
