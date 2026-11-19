import ViewerCore
import Foundation

struct ViewerFoundationRunner {
    static func main() throws {
        var runner = Runner()
        try runner.run()
    }
}

struct Runner {
    var passed = 0
    var failed = 0

    mutating func run() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewer-foundation-" + UUID().uuidString)
        try makeFixture(at: fixture)
        defer { try? FileManager.default.removeItem(at: fixture) }

        runScannerContracts(root: fixture)
        runJSONFormatContracts()
        runJSONSyntaxContracts()
        runMarkdownSyntaxContracts()
        runMarkdownShortcutContracts()
        runJSONPreviewContracts()
        runDocumentTabSessionContracts(root: fixture)
        runDocumentOpenContracts(root: fixture)
        runDefaultWorkspaceContracts(root: fixture)
        runFileKindContracts()
        runPathCopyContracts(root: fixture)
        runCSVContracts()
        runMarkdownBlockEditingContracts()
        runMarkdownEditorCursorContracts()
        runFrontMatterPropertyContracts()
        runMarkdownMergeContracts()
        runMarkdownRenderContracts()
        runMarkdownCodeAndTableContracts()
        runMarkdownImageAndMathContracts()
        runMarkdownHTMLAndFrontMatterContracts()
        runMarkdownLinkContracts()
        runMarkdownInlineHTMLContracts()
        runTerminalReplyContracts()
        runDocumentZoomContracts()
        runFolderCollapseContracts()
        runLaunchFolderContracts()

        print("Foundation contracts: " + String(passed) + " passed, " + String(failed) + " failed")
        if failed > 0 {
            exit(1)
        }
    }

    private func makeFixture(at root: URL) throws {
        let fileManager = FileManager.default
        let docs = root.appendingPathComponent("docs", isDirectory: true)
        let nested = docs.appendingPathComponent("nested", isDirectory: true)
        try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: root.appendingPathComponent("empty", isDirectory: true),
            withIntermediateDirectories: true
        )

        try write("# README", to: root.appendingPathComponent("README.md"))
        try write("{\"name\":\"viewer\"}", to: root.appendingPathComponent("config.json"))
        try write("%PDF-1.7", to: root.appendingPathComponent("sample.pdf"))
        try write("plain", to: root.appendingPathComponent("zeta.txt"))
        try write("hidden", to: root.appendingPathComponent(".hidden.md"))
        try write("# Inside", to: docs.appendingPathComponent("inside.md"))
        try write("\\documentclass{article}", to: nested.appendingPathComponent("deep.tex"))
        try write("docx fixture", to: root.appendingPathComponent("report.docx"))
    }

    private func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private mutating func runPathCopyContracts(root: URL) {
        let path = root.appendingPathComponent("chapters/../working.md")
        expect(
            FilePathCopy.string(for: path) == root.appendingPathComponent("working.md").path,
            "copy path is normalized and absolute"
        )
    }

    private mutating func runCSVContracts() {
        do {
            let document = try CSVPreviewAdapter().parse(
                source: "Name,Note\nAlice,\"hello\nworld\"\nBob,\"He said \"\"hi\"\"\""
            )
            expect(
                document.rows == [
                    ["Name", "Note"],
                    ["Alice", "hello\nworld"],
                    ["Bob", "He said \"hi\""]
                ],
                "CSV parser preserves quoted values and escaped quotes"
            )
            let unsafeDocument = try CSVPreviewAdapter().parse(source: "Name\n<unsafe>")
            let html = CSVPreviewAdapter().html(document: document, isDark: false)
            let unsafeHTML = CSVPreviewAdapter().html(document: unsafeDocument, isDark: false)
            expect(
                html.contains("hello\nworld") && !unsafeHTML.contains("<td><unsafe>"),
                "CSV preview escapes cell content"
            )
            expect(
                html.contains("background: transparent"),
                "CSV preview keeps the app canvas visible"
            )
            expect(
                html.contains("<div class=\"sheet\" data-bp-csv")
                    && !html.contains("<table data-bp-csv"),
                "CSV preview uses a shared grid layout for frozen headers"
            )
            expect(
                html.contains("background-color: #e9e9eb")
                    && !html.contains("selected-header"),
                "CSV coordinate headers stay opaque without selection tint"
            )
            let crlfDocument = try CSVPreviewAdapter().parse(source: "Name,Age\r\nAlice,42")
            expect(
                crlfDocument.rows.count == 2,
                "CSV parser treats CRLF as a record separator"
            )
        } catch {
            expect(false, "CSV parser preserves quoted values and escaped quotes")
            expect(false, "CSV preview escapes cell content")
            expect(false, "CSV parser treats CRLF as a record separator")
        }
    }

    private mutating func runDocumentOpenContracts(root: URL) {
        let coordinator = DocumentOpenCoordinator()
        let markdown = root.appendingPathComponent("README.md")
        let unsupported = root.appendingPathComponent("zeta.txt")
        let latex = root.appendingPathComponent("docs/nested/deep.tex")

        expect(coordinator.isPreviewable(.csv), "document opening treats CSV as a previewable kind")

        if case let .preview(documentURL, kind, contextURL)? = coordinator.resolve(
            markdown,
            workspaceRoot: root
        ) {
            expect(documentURL == markdown.standardizedFileURL, "document opening resolves Markdown preview")
            expect(kind == .markdown && contextURL == nil, "document opening preserves Markdown context")
        } else {
            expect(false, "document opening resolves Markdown preview")
            expect(false, "document opening preserves Markdown context")
        }

        if case let .external(externalURL)? = coordinator.resolve(
            unsupported,
            workspaceRoot: root
        ) {
            expect(externalURL == unsupported.standardizedFileURL, "document opening exposes unsupported files externally")
        } else {
            expect(false, "document opening exposes unsupported files externally")
        }

        if case let .preview(documentURL, kind, contextURL)? = coordinator.resolve(
            latex,
            workspaceRoot: root
        ) {
            expect(documentURL == latex.standardizedFileURL, "document opening resolves automatic LaTeX root")
            expect(kind == .latex && contextURL == nil, "document opening keeps selected LaTeX root context")
        } else {
            expect(false, "document opening resolves automatic LaTeX root")
            expect(false, "document opening keeps selected LaTeX root context")
        }

        expect(
            coordinator.inferredLatexProjectRoot(for: latex) == latex.deletingLastPathComponent().standardizedFileURL,
            "document opening infers the nearest LaTeX project directory"
        )
        expect(
            coordinator.resolve(root.appendingPathComponent("missing.md"), workspaceRoot: root) == nil,
            "document opening ignores missing files"
        )
    }

    private mutating func runDocumentTabSessionContracts(root: URL) {
        let first = DocumentTab(
            id: "first",
            url: root.appendingPathComponent("first.md"),
            kind: .markdown
        )
        let second = DocumentTab(
            id: "second",
            url: root.appendingPathComponent("second.json"),
            kind: .json
        )
        let third = DocumentTab(
            id: "third",
            url: root.appendingPathComponent("third.pdf"),
            kind: .pdf
        )

        var session = DocumentTabSession()
        expect(session.open(first), "document session opens first tab")
        expect(session.open(second), "document session opens second tab")
        expect(!session.open(first), "document session focuses duplicate tab")
        expect(session.activeTabID == "first", "document session tracks active duplicate")
        expect(session.select(id: "second"), "document session selects tab")
        expect(!session.select(id: "missing"), "document session rejects unknown tab")
        expect(session.open(third), "document session opens third tab")
        expect(session.move("third", before: "first"), "document session moves tab")
        expect(session.tabs.map(\.id) == ["third", "first", "second"], "document session preserves moved order")
        expect(session.moveToEnd("third"), "document session moves tab to end")
        expect(session.tabs.map(\.id) == ["first", "second", "third"], "document session preserves end order")
        expect(session.closeToRight(of: "second"), "document session closes tabs to right")
        expect(session.tabs.map(\.id) == ["first", "second"], "document session removes only right tabs")
        expect(session.closeOthers(keeping: "first"), "document session closes other tabs")
        expect(session.tabs.map(\.id) == ["first"] && session.activeTabID == "first", "document session keeps requested tab active")

        var cycling = DocumentTabSession(tabs: [first, second, third], activeTabID: "first")
        expect(cycling.selectNext() && cycling.activeTabID == "second", "document session advances active tab")
        expect(cycling.selectNext() && cycling.activeTabID == "third", "document session advances to last tab")
        expect(cycling.selectNext() && cycling.activeTabID == "first", "document session wraps active tab")
        expect(cycling.close(id: "first"), "document session closes active tab")
        expect(cycling.activeTabID == "second", "document session selects adjacent tab after close")
        expect(cycling.close(id: "second") && cycling.close(id: "third"), "document session closes remaining tabs")
        expect(cycling.activeTabID == nil && cycling.tabs.isEmpty, "document session clears active tab when empty")

        var reordered = DocumentTabSession(tabs: [first, second, third], activeTabID: "second")
        expect(reordered.reorder(ids: ["third", "first", "second"]), "document session accepts valid native order")
        expect(reordered.tabs.map(\.id) == ["third", "first", "second"], "document session applies native order")
        expect(!reordered.reorder(ids: ["third", "third", "second"]), "document session rejects duplicate native order")
        expect(reordered.move("third", before: "second"), "document session moves tab before target")
        expect(reordered.tabs.map(\.id) == ["first", "third", "second"], "document session preserves move semantics")
        expect(reordered.update(id: "first") { $0.isOutlineVisible = true }, "document session updates tab value")
        expect(reordered.tab(id: "first")?.isOutlineVisible == true, "document session exposes updated tab")

        let deduplicated = DocumentTabSession(tabs: [first, first], activeTabID: "missing")
        expect(deduplicated.tabs.count == 1 && deduplicated.activeTabID == "first", "document session deduplicates and restores active fallback")

        let suiteName = "viewer-foundation-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var state = AppState()
        state.global.sidebarWidth = 340
        state.workspaceStates["workspace"] = WorkspaceState()
        AppStateStore(defaults: defaults).save(state)
        let restored = AppStateStore(defaults: defaults).load()
        expect(restored.global.sidebarWidth == 340, "session models persist global state")
        expect(restored.workspaceStates["workspace"] != nil, "session models persist workspace state")
    }

    private mutating func runDefaultWorkspaceContracts(root: URL) {
        expect(
            DefaultWorkspaceFolders.deduplicated(["/a", "/b", "/a"]) == ["/a", "/b"],
            "default workspace list keeps the first occurrence in order"
        )
        expect(
            DefaultWorkspaceFolders.removing("/a", from: ["/a", "/b"]) == ["/b"],
            "default workspace removal drops only the given path"
        )

        let suiteName = "viewer-defaults-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let folderA = root.appendingPathComponent("docs", isDirectory: true)
        let folderB = root.appendingPathComponent("empty", isDirectory: true)
        let folderC = root.appendingPathComponent("docs/nested", isDirectory: true)

        MainActor.assumeIsolated {
            let storeDefaults = UserDefaults(suiteName: suiteName)!
            let first = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(first.defaultWorkspaceFolderPaths.isEmpty, "default workspace list starts empty")

            first.addDefaultWorkspaceFolder(folderA)
            first.addDefaultWorkspaceFolder(folderB)
            first.addDefaultWorkspaceFolder(folderA)
            first.addDefaultWorkspaceFolder(folderC)
            first.removeDefaultWorkspaceFolder(path: first.defaultWorkspaceFolderPaths[2])

            let reloaded = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(
                reloaded.defaultWorkspaceFolderPaths == [
                    folderA.resolvingSymlinksInPath().standardizedFileURL.path,
                    folderB.resolvingSymlinksInPath().standardizedFileURL.path,
                ],
                "default workspace folders persist in order without duplicates or removed entries"
            )
        }

        let legacyJSON = Data(#"{"schemaVersion":2,"global":{"theme":"light","launchBehavior":"openFolders","launchFolderPaths":["/x"]}}"#.utf8)
        let legacy = try? JSONDecoder().decode(AppState.self, from: legacyJSON)
        expect(
            legacy?.global.theme == "light" && legacy?.global.defaultWorkspaceFolders == [],
            "state with the earlier launch keys decodes safely with an empty default list"
        )
    }

    private mutating func runFileKindContracts() {
        expect(
            DocumentKind.selectableKinds.count == 7 && !DocumentKind.selectableKinds.contains(.other),
            "selectable file kinds are every known kind except other"
        )
        expect(
            FileKindFilter().admits(.markdown) && FileKindFilter().admits(.image) && !FileKindFilter().admits(.other),
            "default file filter admits every selectable kind and never other"
        )

        let suiteName = "viewer-kinds-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        MainActor.assumeIsolated {
            let storeDefaults = UserDefaults(suiteName: suiteName)!
            let first = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(first.selectedFileKinds == Set(DocumentKind.selectableKinds), "selected file kinds default to every supported kind")

            first.setSelectedFileKinds([.pdf, .markdown])
            let reloaded = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(reloaded.selectedFileKinds == [.markdown, .pdf], "selected file kinds persist across sessions")
        }

        let corruptJSON = Data(#"{"schemaVersion":2,"global":{"selectedFileKinds":["markdown","other","bogus"]}}"#.utf8)
        let corrupt = try? JSONDecoder().decode(AppState.self, from: corruptJSON)
        expect(
            corrupt?.global.selectedFileKinds == ["markdown", "other", "bogus"],
            "stored kind names decode as written"
        )
        MainActor.assumeIsolated {
            let storeDefaults = UserDefaults(suiteName: suiteName)!
            var state = AppState()
            state.global.selectedFileKinds = ["markdown", "other", "bogus"]
            AppStateStore(defaults: storeDefaults).save(state)
            let coordinator = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(coordinator.selectedFileKinds == [.markdown], "unknown and non-selectable stored kinds are ignored")
        }

        let legacyWorkspace = try? JSONDecoder().decode(WorkspaceState.self, from: Data(#"{"compatibleOnly":false}"#.utf8))
        expect(legacyWorkspace?.showSelectedFilesOnly == false, "saved compatibleOnly key still restores the workspace toggle")
        let emptyWorkspace = try? JSONDecoder().decode(WorkspaceState.self, from: Data("{}".utf8))
        expect(emptyWorkspace?.showSelectedFilesOnly == true, "workspace toggle defaults to showing selected files only")
        let legacyGlobal = try? JSONDecoder().decode(AppState.self, from: Data(#"{"schemaVersion":2,"global":{"theme":"dark"}}"#.utf8))
        expect(
            legacyGlobal?.global.selectedFileKinds == DocumentKind.selectableKinds.map(\.rawValue),
            "state saved before file kind selection selects every supported kind"
        )
    }

    mutating func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        if condition() {
            passed += 1
            print("PASS " + name)
        } else {
            failed += 1
            print("FAIL " + name)
        }
    }
}

try ViewerFoundationRunner.main()
