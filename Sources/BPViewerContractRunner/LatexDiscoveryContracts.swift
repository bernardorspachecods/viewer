import BPViewerCore
import Foundation

extension BPViewerContractRunner {
    static func runLatexRootDiscoveryContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let latexProject = latex.project
        let latexRoot = latex.root
        let latexChapter = latex.chapter
        let latexResolution = try LatexRootDiscovery().resolve(
            openedFile: latexChapter,
            projectRoot: fixtureRoot
        )
        expect(latexResolution.selectedRoot == latexRoot, "LaTeX root discovery")
        expect(
            latexResolution.candidates.first?.reasons.contains("documentclass") == true,
            "LaTeX root discovery evidence"
        )
        var persistedContexts = [String: String]()
        LatexTabContextPersistence.store(
            contextURL: latexChapter,
            forTabID: latexRoot.path,
            in: &persistedContexts
        )
        expect(
            LatexTabContextPersistence.restore(
                forTabID: latexRoot.path,
                tabURL: latexRoot,
                kind: .latex,
                from: persistedContexts,
                projectRoot: latexProject
            ) == latexChapter.standardizedFileURL,
            "LaTeX chapter context persistence"
        )
    }

    static func runLatexExecutableLocatorContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let pdflatexOnly = fixtureRoot.appendingPathComponent("pdflatex")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/bin/echo"),
            to: pdflatexOnly
        )
        defer { try? FileManager.default.removeItem(at: pdflatexOnly) }
        expect(
            LatexExecutableLocator(candidateURLs: [pdflatexOnly])
                .findCompiler(preferredKind: .xelatex) == nil,
            "specialised LaTeX engine does not fall back to pdfLaTeX"
        )
        let latexmkOnly = fixtureRoot.appendingPathComponent("latexmk")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/bin/echo"),
            to: latexmkOnly
        )
        defer { try? FileManager.default.removeItem(at: latexmkOnly) }
        expect(
            LatexExecutableLocator(candidateURLs: [pdflatexOnly, latexmkOnly])
                .findCompiler(preferredKind: .xelatex)?.kind == .latexmk,
            "latexmk remains preferred over direct engine"
        )
    }

    static func runLatexRootSelectionContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let latexChapter = latex.chapter
        let secondLatexRoot = fixtureRoot.appendingPathComponent("appendix.tex")
        try "\\documentclass{article}\n\\begin{document}\nAppendix\n\\end{document}\n"
            .write(to: secondLatexRoot, atomically: true, encoding: .utf8)
        let ambiguousLatexResolution = try LatexRootDiscovery().resolve(
            openedFile: latexChapter,
            projectRoot: fixtureRoot
        )
        expect(ambiguousLatexResolution.selectedRoot == nil, "ambiguous LaTeX roots need selection")
        expect(ambiguousLatexResolution.requiresSelection, "ambiguous LaTeX selection state")

        let emptyRootProject = fixtureRoot.appendingPathComponent("empty-root", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyRootProject, withIntermediateDirectories: true)
        let incompleteLatexFile = emptyRootProject.appendingPathComponent("notes.tex")
        try "\\section{Notes}\n".write(to: incompleteLatexFile, atomically: true, encoding: .utf8)
        let emptyRootResolution = try LatexRootDiscovery().resolve(
            openedFile: incompleteLatexFile,
            projectRoot: emptyRootProject
        )
        expect(emptyRootResolution.candidates.isEmpty, "no automatic LaTeX root")
        expect(emptyRootResolution.requiresSelection, "no-root LaTeX selection state")
    }
}
