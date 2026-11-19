import Testing
import Foundation
import Darwin
import AppKit
@testable import ViewerApp
@testable import ViewerCore

@Test("recognizes bibliography files as contextual LaTeX sources")
func recognizesBibliographyFilesAsContextualLatexSources() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-bib-open-\(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let bibliographyURL = projectRoot.appendingPathComponent("references.bib")
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try "\\documentclass{article}\n\\begin{document}\n\\bibliography{references}\n\\end{document}\n"
        .write(to: rootURL, atomically: true, encoding: .utf8)
    try "@article{key, title = {A paper}}\n"
        .write(to: bibliographyURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    #expect(DocumentKind(url: bibliographyURL) == .latex)
    let result = DocumentOpenCoordinator().resolve(
        bibliographyURL,
        workspaceRoot: projectRoot
    )
    guard case let .preview(documentURL, kind, contextURL) = result else {
        Issue.record("The bibliography should open as a LaTeX contextual source")
        return
    }
    #expect(documentURL == rootURL)
    #expect(kind == .latex)
    #expect(contextURL == bibliographyURL)
}

@Test("parses SyncTeX input paths with spaces and whitespace")
func parsesSyncTeXInputPathsWithSpacesAndWhitespace() {
    let output = """
    SyncTeX result begin
     Input: /tmp/project with spaces/chapter.tex
     Line: 42
     Column: -1
    SyncTeX result end
    """

    let location = LatexSyncTeXLookup.parse(output)
    #expect(location?.url.path == "/tmp/project with spaces/chapter.tex")
    #expect(location?.line == 42)
    #expect(location?.column == 0)
}

@Test("LaTeX tabs edit their contextual source and expose source split and diff modes")
func exposesLatexEditingModes() {
    let root = URL(fileURLWithPath: "/tmp/project/main.tex")
    let chapter = URL(fileURLWithPath: "/tmp/project/chapters/introduction.tex")
    var tab = DocumentTab(
        id: root.path,
        url: root,
        kind: .latex,
        contextURL: chapter,
        latexEditSession: MarkdownEditSession(
            baseSource: "\\section{Introduction}",
            currentSource: "\\section{Introduction}"
        )
    )

    #expect(tab.editableSourceURL == chapter)
    #expect(tab.presentationMode == .source)

    tab.selectPresentationMode(.split)
    #expect(tab.presentationMode == .split)

    tab.activateDiff(DocumentDiffSession(
        mode: .savedOnDisk,
        baseline: DocumentDiffBaseline(label: "Saved on Disk", source: "original")
    ))
    #expect(tab.presentationMode == .diff(.savedOnDisk))
}

@Test("compiles a contextual LaTeX source override without changing the project")
func compilesLatexSourceOverrideWithoutChangingProject() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-latex-override-\(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let chapterURL = projectRoot.appendingPathComponent("chapter.tex")
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try "\\documentclass{article}\n\\begin{document}\n\\input{chapter}\n\\end{document}\n"
        .write(to: rootURL, atomically: true, encoding: .utf8)
    try "Original chapter\n".write(to: chapterURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    let runner = RecordingLatexProcessRunner()
    let result = try LocalLatexAdapter(
        runner: runner,
        executableURL: URL(fileURLWithPath: "/usr/bin/latexmk")
    ).render(
        rootURL: rootURL,
        projectRoot: projectRoot,
        sourceOverrides: [chapterURL: "Draft chapter\n"]
    )

    #expect(result.pdfData.starts(with: Data("%PDF".utf8)))
    #expect(runner.observedChapterSource == "Draft chapter\n")
    #expect(runner.observedRootPath != rootURL.path)
    #expect(runner.requests.first?.arguments.contains("-synctex=1") == true)
    #expect(result.syncTeXData != nil)
    #expect(try String(contentsOf: chapterURL, encoding: .utf8) == "Original chapter\n")
}

@Test("ignores runtime sockets while preparing a LaTeX draft overlay")
func ignoresRuntimeSocketsWhilePreparingLatexDraftOverlay() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-latex-runtime-(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let socketURL = projectRoot.appendingPathComponent("daemon.sock")
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try "\\documentclass{article}\n\\begin{document}\nDraft\n\\end{document}\n"
        .write(to: rootURL, atomically: true, encoding: .utf8)
    #expect(mkfifo(socketURL.path, mode_t(0o600)) == 0)
    defer {
        unlink(socketURL.path)
        try? FileManager.default.removeItem(at: projectRoot)
    }

    let result = try LocalLatexAdapter(
        runner: RecordingLatexProcessRunner(),
        executableURL: URL(fileURLWithPath: "/usr/bin/latexmk")
    ).render(
        rootURL: rootURL,
        projectRoot: projectRoot,
        sourceOverrides: [rootURL: "\\documentclass{article}\n\\begin{document}\nChanged\n\\end{document}\n"]
    )

    #expect(result.pdfData.starts(with: Data("%PDF".utf8)))
}

@Test("treats independent LaTeX source changes as a text conflict")
func treatsIndependentLatexSourceChangesAsTextConflict() {
    #expect(
        SourceThreeWayMerge.resolve(
            base: "base",
            local: "local",
            external: "external"
        ) == .conflict(base: "base", local: "local", external: "external")
    )
    #expect(
        SourceThreeWayMerge.resolve(
            base: "base",
            local: "local",
            external: "base"
        ) == .merged("local")
    )
}

@Test("highlights LaTeX commands comments arguments and math")
func highlightsLatexSyntaxTokens() {
    let source = "\\section{Intro} % note\n$a_i$"
    let tokens = LatexSyntaxHighlighter().tokenize(source)
    #expect(tokens.map(\.kind) == [
        .command, .argument, .comment, .math
    ])
}

@Test("resolves a clicked LaTeX citation to its bibliography entry")
func resolvesClickedLatexCitationToBibliographyEntry() {
    let source = "Introdução.\n\nA claim \\citep{trippe,abood}."
    let citationKeyStart = source.range(of: "trippe")!.lowerBound
    let citationOffset = source[..<citationKeyStart].utf8.count
    let bibliography = "@techreport{trippe,\n  title = {A paper}\n}\n\n@article{abood,\n  title = {Another paper}\n}\n"

    #expect(
        LatexCitationLookup.citationKey(
            atUTF8Offset: citationOffset,
            in: source
        ) == "trippe"
    )
    #expect(
        LatexCitationLookup.citationKey(
            atUTF8Offset: source[..<source.range(of: "A claim")!.lowerBound].utf8.count,
            in: source
        ) == "trippe"
    )
    #expect(
        LatexCitationLookup.bibliographyEntryOffset(
            for: "trippe",
            in: bibliography
        ) == 0
    )
    #expect(
        LatexCitationLookup.bibliographyEntryOffset(
            for: "abood",
            in: bibliography
        ) == bibliography[..<bibliography.range(of: "@article")!.lowerBound].utf8.count
    )
}

@Test("maps a SyncTeX bibliography line to its BibTeX key")
func mapsGeneratedBibliographyLineToBibKey() {
    let generated = """
    \\begin{thebibliography}{}
    \\bibitem[Abood and Feltenberger, 2018]{abood}
    Abood, A. and Feltenberger, D. (2018).
    Automated patent landscaping.
    \\bibitem[Trippe, 2015]{trippe}
    Trippe, A. (2015).
    \\end{thebibliography}
    """

    #expect(LatexCitationLookup.keyInGeneratedBibliography(atLine: 1, in: generated) == nil)
    #expect(LatexCitationLookup.keyInGeneratedBibliography(atLine: 3, in: generated) == "abood")
    #expect(LatexCitationLookup.keyInGeneratedBibliography(atLine: 6, in: generated) == "trippe")
}

@Test("a SyncTeX location in a generated bibliography opens the BibTeX entry")
@MainActor
func syncTeXBibliographyLocationOpensBibEntry() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-synctex-bib-\(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let bibliographyURL = projectRoot.appendingPathComponent("references.bib")
    let texSource = "\\documentclass{article}\n\\begin{document}\n\\bibliography{references}\n\\end{document}\n"
    let bibSource = "@article{trippe,\n  title = {A paper}\n}\n"
    let generated = "\\begin{thebibliography}{}\n\\bibitem[Trippe, 2015]{trippe}\nTrippe, A. (2015).\n\\end{thebibliography}\n"
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try texSource.write(to: rootURL, atomically: true, encoding: .utf8)
    try bibSource.write(to: bibliographyURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    let model = AppModel()
    model.rootURL = projectRoot
    model.tabs = [DocumentTab(
        id: rootURL.path,
        url: rootURL,
        kind: .latex,
        latexGeneratedBibliographySource: generated,
        previewDependencies: [rootURL, bibliographyURL],
        latexEditSession: SourceEditSession(baseSource: texSource, currentSource: texSource)
    )]
    model.activeTabID = rootURL.path

    model.applyLatexSourceLocation(
        LatexSourceLocation(
            url: projectRoot.appendingPathComponent("output/main.bbl"),
            line: 1,
            column: 0
        ),
        tabID: rootURL.path,
        projectRoot: projectRoot
    )

    #expect(model.activeTab?.editableSourceURL == bibliographyURL)
    #expect(model.activeTab?.latexCursorUTF8Offset == 0)

    model.applyLatexSourceLocation(
        LatexSourceLocation(
            url: projectRoot.appendingPathComponent("output/main.bbl"),
            line: 3,
            column: 0
        ),
        tabID: rootURL.path,
        projectRoot: projectRoot
    )

    #expect(model.activeTab?.editableSourceURL == bibliographyURL)
    #expect(model.activeTab?.latexEditSession?.currentSource == bibSource)
    #expect(model.activeTab?.latexCursorUTF8Offset == 0)
}

@Test("opens the bibliography file when a LaTeX citation is double-clicked")
@MainActor
func opensBibliographyFileWhenLatexCitationIsDoubleClicked() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-latex-citation-(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let bibliographyURL = projectRoot.appendingPathComponent("references.bib")
    let source = "A claim \\citep{trippe}."
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try source.write(to: rootURL, atomically: true, encoding: .utf8)
    try "@article{trippe,\n  title = {A paper}\n}\n"
        .write(to: bibliographyURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    let tabID = rootURL.path
    let citationOffset = source[..<source.range(of: "trippe")!.lowerBound].utf8.count
    let model = AppModel()
    model.rootURL = projectRoot
    model.tabs = [DocumentTab(
        id: tabID,
        url: rootURL,
        kind: .latex,
        previewDependencies: [rootURL, bibliographyURL],
        latexEditSession: SourceEditSession(
            mode: .split,
            baseSource: source,
            currentSource: source
        )
    )]
    model.activeTabID = tabID

    model.openLatexCitation(tabID: tabID, sourceOffset: citationOffset)

    #expect(model.tabs[0].editableSourceURL == bibliographyURL)
    #expect(model.tabs[0].latexCursorUTF8Offset == 0)
    #expect(model.tabs[0].latexEditSession?.currentSource.contains("trippe") == true)
}

@Test("opening a bibliography in an existing LaTeX tab shows its source")
@MainActor
func openingBibliographyInExistingLatexTabShowsItsSource() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-existing-bib-\(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let bibliographyURL = projectRoot.appendingPathComponent("references.bib")
    let texSource = "\\documentclass{article}\n\\begin{document}\n\\bibliography{references}\n\\end{document}\n"
    let bibSource = "@article{trippe, title = {A paper}}\n"
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try texSource.write(to: rootURL, atomically: true, encoding: .utf8)
    try bibSource.write(to: bibliographyURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    let model = AppModel()
    model.rootURL = projectRoot
    model.tabs = [DocumentTab(
        id: rootURL.path,
        url: rootURL,
        kind: .latex,
        latexEditSession: SourceEditSession(
            mode: .split,
            baseSource: texSource,
            currentSource: texSource
        )
    )]
    model.activeTabID = rootURL.path

    model.open(FileNode(
        id: bibliographyURL.path,
        url: bibliographyURL,
        relativePath: "references.bib",
        isDirectory: false,
        kind: .latex,
        children: [],
        childrenLoaded: true
    ))

    #expect(model.activeTab?.editableSourceURL == bibliographyURL)
    #expect(model.activeTab?.latexEditSession?.currentSource == bibSource)
    #expect(model.activeTab?.latexEditSession?.mode == .split)

    model.open(FileNode(
        id: rootURL.path,
        url: rootURL,
        relativePath: "main.tex",
        isDirectory: false,
        kind: .latex,
        children: [],
        childrenLoaded: true
    ))

    #expect(model.activeTab?.editableSourceURL == rootURL)
    #expect(model.activeTab?.latexEditSession?.currentSource == texSource)
}

@Test("opening a bibliography from the tree enters its source editor")
@MainActor
func openingBibliographyFromTreeEntersItsSourceEditor() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-new-bib-\(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let bibliographyURL = projectRoot.appendingPathComponent("references.bib")
    let bibSource = "@book{sample, title = {Sample}}\n"
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try "\\documentclass{article}\n\\begin{document}\n\\bibliography{references}\n\\end{document}\n"
        .write(to: rootURL, atomically: true, encoding: .utf8)
    try bibSource.write(to: bibliographyURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    let model = AppModel()
    model.rootURL = projectRoot
    model.open(FileNode(
        id: bibliographyURL.path,
        url: bibliographyURL,
        relativePath: "references.bib",
        isDirectory: false,
        kind: .latex,
        children: [],
        childrenLoaded: true
    ))

    #expect(model.activeTab?.url == rootURL)
    #expect(model.activeTab?.editableSourceURL == bibliographyURL)
    #expect(model.activeTab?.latexEditSession?.isEditing == true)
    #expect(model.activeTab?.latexEditSession?.currentSource == bibSource)
}

@Test("invalidates LaTeX cache entries created before SyncTeX support")
func invalidatesLatexCacheEntriesCreatedBeforeSyncTeXSupport() throws {
    let projectRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-latex-cache-(UUID().uuidString)", isDirectory: true)
    let rootURL = projectRoot.appendingPathComponent("main.tex")
    let cacheDirectory = projectRoot.appendingPathComponent("cache", isDirectory: true)
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    try "\\documentclass{article}\n\\begin{document}\nText\n\\end{document}\n"
        .write(to: rootURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: projectRoot) }

    let cache = LatexRenderCache(directory: cacheDirectory)
    let key = LatexCacheKey(
        projectRoot: projectRoot,
        rootURL: rootURL,
        compilerIdentity: "xelatex",
        shellEscapeMode: .disabled
    )
    try cache.store(
        key: key,
        result: LatexRenderResult(
            pdfData: Data("%PDF-1.4\n".utf8),
            rootURL: rootURL,
            dependencies: [rootURL],
            processResult: ProcessResult(
                status: .success,
                exitCode: 0,
                standardOutput: "",
                standardError: ""
            )
        )
    )

    let cacheFile = try #require(
        FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ).first
    )
    var legacyEntry = try #require(
        JSONSerialization.jsonObject(
            with: Data(contentsOf: cacheFile)
        ) as? [String: Any]
    )
    legacyEntry.removeValue(forKey: "version")
    try JSONSerialization.data(withJSONObject: legacyEntry).write(to: cacheFile)

    #expect(cache.load(key: key) == nil)
}

@Test("LaTeX cache preserves generated bibliography source for PDF navigation")
func latexCachePreservesGeneratedBibliographySource() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-bib-cache-\(UUID().uuidString)", isDirectory: true)
    let rootURL = directory.appendingPathComponent("main.tex")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try "\\documentclass{article}\n".write(to: rootURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: directory) }

    let cache = LatexRenderCache(directory: directory.appendingPathComponent("cache"))
    let key = LatexCacheKey(
        projectRoot: directory,
        rootURL: rootURL,
        compilerIdentity: "xelatex",
        shellEscapeMode: .disabled
    )
    let generated = "\\bibitem[Trippe, 2015]{trippe}\nTrippe, A. (2015).\n"
    try cache.store(
        key: key,
        result: LatexRenderResult(
            pdfData: Data("%PDF-1.4\n".utf8),
            rootURL: rootURL,
            dependencies: [rootURL],
            processResult: ProcessResult(
                status: .success,
                exitCode: 0,
                standardOutput: "",
                standardError: ""
            ),
            generatedBibliographySource: generated
        )
    )

    #expect(cache.load(key: key)?.generatedBibliographySource == generated)
}
