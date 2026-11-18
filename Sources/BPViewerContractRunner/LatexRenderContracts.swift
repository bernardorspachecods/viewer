import BPViewerCore
import Darwin
import Foundation

extension BPViewerContractRunner {
    static func runLatexRenderContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let latexProject = latex.project
        let latexRoot = latex.root
        let latexChapter = latex.chapter
        let latexRenderResult = try LocalLatexAdapter(
            runner: SuccessfulLatexProcessRunner(),
            executableURL: URL(fileURLWithPath: "/tmp/fake-latexmk")
        ).render(rootURL: latexRoot, projectRoot: fixtureRoot)
        expect(latexRenderResult.pdfData.starts(with: Data("%PDF-1.4".utf8)), "LaTeX PDF output")
        expect(latexRenderResult.rootURL == latexRoot.standardizedFileURL, "LaTeX render root")
        expect(
            latexRenderResult.dependencies.contains(latexProject.appendingPathComponent("developercv.cls")),
            "local LaTeX class dependency"
        )
        expect(
            latexRenderResult.dependencies.contains(latexChapter),
            "recorder chapter dependency"
        )
        do {
            _ = try LocalLatexAdapter(
                runner: InvalidPDFProcessRunner(),
                executableURL: URL(fileURLWithPath: "/tmp/fake-latexmk")
            ).render(rootURL: latexRoot, projectRoot: fixtureRoot)
            expect(false, "invalid LaTeX PDF is rejected")
        } catch LatexRenderError.outputPDFInvalid {
            expect(true, "invalid LaTeX PDF is rejected")
        }
        expect(
            !FileManager.default.fileExists(
                atPath: fixtureRoot.appendingPathComponent(".bp-viewer-output").path
            ),
            "LaTeX output stays outside source project"
        )
    }

    static func runLatexRuntimeArtifactContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let latexRoot = latex.root
        let daemonSocket = fixtureRoot.appendingPathComponent("daemon.sock")
        expect(Darwin.mkfifo(daemonSocket.path, 0o600) == 0, "create runtime socket fixture")
        defer { _ = Darwin.unlink(daemonSocket.path) }
        do {
            _ = try LocalLatexAdapter(
                runner: SuccessfulLatexProcessRunner(),
                executableURL: URL(fileURLWithPath: "/tmp/fake-latexmk")
            ).render(rootURL: latexRoot, projectRoot: fixtureRoot)
            expect(true, "LaTeX ignores runtime socket")
        } catch {
            fatalError("LaTeX runtime artifact regression: \(error.localizedDescription)")
        }
    }

    static func runLiveLatexCompileContracts(fixtureRoot: URL, latex: LatexContractFixture) throws {
        let latexRoot = latex.root
        if let compiler = LatexExecutableLocator().findCompiler() {
            let liveLatexResult = try LocalLatexAdapter(
                executableURL: compiler.url,
                timeout: 30
            ).render(rootURL: latexRoot, projectRoot: fixtureRoot)
            expect(liveLatexResult.pdfData.starts(with: Data("%PDF".utf8)), "\(compiler.kind.rawValue) compiles fixture")
        } else {
            print("SKIP no local LaTeX compiler found")
        }
    }

    static func runManualLatexFixtureContracts() throws {
        let manualFixtureProject = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Fixtures/latex-preview-test", isDirectory: true)
        let manualFixtureRoot = manualFixtureProject.appendingPathComponent("main.tex")
        if FileManager.default.fileExists(atPath: manualFixtureRoot.path) {
            let manualFixtureResult = try LocalLatexAdapter(timeout: 60).render(
                rootURL: manualFixtureRoot,
                projectRoot: manualFixtureProject
            )
            expect(
                manualFixtureResult.pdfData.starts(with: Data("%PDF".utf8))
                    && manualFixtureResult.dependencies.contains {
                        $0.lastPathComponent == "fixture-diagram.tex"
                    }
                    && manualFixtureResult.dependencies.contains {
                        $0.lastPathComponent == "references.bib"
                    },
                "manual LaTeX fixture compiles with BibTeX"
            )
            let generatedBibliography = manualFixtureResult.generatedBibliographySource ?? ""
            let generatedLines = generatedBibliography.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            if let entryLine = generatedLines.firstIndex(where: {
                $0.contains(#"\bibitem{knuth1984texbook}"#)
            }) {
                expect(
                    LatexCitationLookup.keyInGeneratedBibliography(
                        atLine: entryLine + 1,
                        in: generatedBibliography
                    ) == "knuth1984texbook",
                    "generated BibTeX bibliography maps back to its source key"
                )
            } else {
                expect(false, "generated BibTeX bibliography maps back to its source key")
            }
            let broadProjectRoot = manualFixtureProject
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let broadRootResult = try LocalLatexAdapter(timeout: 30).render(
                rootURL: manualFixtureRoot,
                projectRoot: broadProjectRoot
            )
            expect(
                broadRootResult.pdfData.starts(with: Data("%PDF".utf8)),
                "nested LaTeX fixture avoids broad-root traversal"
            )
        } else {
            print("SKIP manual LaTeX fixture not found")
        }
    }

    static func runOptionalLatexCorpusContracts() throws {
        if let corpusPath = ProcessInfo.processInfo.environment["BP_VIEWER_LATEX_CORPUS"] {
            let realCorpusProject = URL(fileURLWithPath: corpusPath, isDirectory: true)
            let realCorpusRoot = realCorpusProject.appendingPathComponent("main.tex")
            guard FileManager.default.fileExists(atPath: realCorpusRoot.path) else {
                throw NSError(
                    domain: "BPViewerContractRunner",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "BP_VIEWER_LATEX_CORPUS must point to a project containing main.tex"
                    ]
                )
            }
            let realCorpusResult = try LocalLatexAdapter(timeout: 60).render(
                rootURL: realCorpusRoot,
                projectRoot: realCorpusProject
            )
            expect(
                realCorpusResult.pdfData.starts(with: Data("%PDF".utf8)),
                "optional LaTeX corpus compiles in isolated workspace"
            )
        } else {
            print("SKIP optional LaTeX corpus; set BP_VIEWER_LATEX_CORPUS to include one")
        }
    }
}
