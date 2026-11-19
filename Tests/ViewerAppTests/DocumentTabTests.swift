import Testing
import Foundation
import Darwin
import AppKit
@testable import ViewerApp
@testable import ViewerCore

@Test("recognizes Word documents as supported preview files")
func recognizesWordDocuments() {
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/report.docx")) == .docx)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/REPORT.DOCX")) == .docx)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/report.doc")) == .other)
}

@Test("creates an untitled Markdown tab without a filesystem path")
func createsUntitledMarkdownTabWithoutAFilesystemPath() {
    let tab = DocumentTab.untitledMarkdown()

    #expect(tab.kind == .markdown)
    #expect(tab.isUntitled)
    #expect(!tab.url.isFileURL)
    #expect(tab.title == "Untitled")
    #expect(tab.subtitle == "Not saved")
}

@Test("opens a new Markdown tab directly in the source editor")
@MainActor
func opensNewMarkdownTabDirectlyInTheSourceEditor() throws {
    let model = AppModel()

    model.createNewMarkdownDocument()

    let tab = try #require(model.activeTab)
    #expect(tab.kind == .markdown)
    #expect(tab.isUntitled)
    #expect(tab.markdownEditSession?.isEditing == true)
    #expect(tab.markdownEditSession?.mode == .markdown)
    #expect(tab.markdownEditSession?.saveState == .unsaved)
}

@Test("closes an empty untitled Markdown tab without confirmation")
@MainActor
func closesEmptyUntitledMarkdownTabWithoutConfirmation() throws {
    let model = AppModel()

    model.createNewMarkdownDocument()
    let tab = try #require(model.activeTab)

    model.closeTab(tab)

    #expect(model.tabs.isEmpty)
    #expect(model.showingPendingCloseConfirmation == false)
}

@Test("does not persist an untitled Markdown tab as a file path")
func doesNotPersistUntitledMarkdownTabAsAFilePath() {
    let savedURL = URL(fileURLWithPath: "/tmp/project/notes.md")
    let session = DocumentTabSession(tabs: [
        DocumentTab(id: savedURL.path, url: savedURL, kind: .markdown),
        .untitledMarkdown()
    ])

    #expect(session.persistedPaths == [savedURL.path])
}

@Test("renders an untitled Markdown draft from memory")
@MainActor
func rendersUntitledMarkdownDraftFromMemory() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-untitled-markdown-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let tab = DocumentTab.untitledMarkdown()
    var renderedOutput: DocumentPreviewOutput?
    let coordinator = DocumentRenderCoordinator { event in
        if case let .ready(_, output) = event {
            renderedOutput = output
        }
    }
    coordinator.render(DocumentRenderRequest(
        tabID: tab.id,
        url: tab.url,
        kind: .markdown,
        projectRoot: root,
        markdownSourceOverride: "# Draft",
        latexRootURL: nil,
        latexShellEscapeMode: .disabled,
        approvedLatexExternalPaths: [:],
        force: false
    ))

    for _ in 0..<20 where renderedOutput == nil {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(renderedOutput?.source == "# Draft")
    #expect(renderedOutput?.baseURL == root)
    #expect(renderedOutput?.html?.contains("<h1 id=\"draft\"") == true)
}

@Test("refreshes the current Markdown draft while a diff is open")
@MainActor
func refreshesCurrentMarkdownDraftWhileDiffIsOpen() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-markdown-diff-refresh-\(UUID().uuidString)", isDirectory: true)
    let url = root.appendingPathComponent("notes.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let originalSource = "# Original"
    let refreshedSource = "# Refreshed"
    try refreshedSource.write(to: url, atomically: true, encoding: .utf8)

    let model = AppModel(restoresLastWorkspace: false)
    model.tabs = [
        DocumentTab(
            id: url.path,
            url: url,
            kind: .markdown,
            previewHTML: "<h1>Original</h1>",
            markdownSource: originalSource,
            markdownEditSession: MarkdownEditSession(
                isEditing: true,
                baseSource: originalSource,
                currentSource: originalSource
            ),
            diffSession: DocumentDiffSession(
                mode: .gitHead,
                baseline: DocumentDiffBaseline(label: "HEAD", source: "# HEAD"),
                returnMode: .source
            )
        )
    ]
    model.activeTabID = url.path

    model.refreshActiveTab()

    for _ in 0..<40 where model.tabs[0].markdownEditSession?.currentSource != refreshedSource {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(model.tabs[0].markdownEditSession?.baseSource == refreshedSource)
    #expect(model.tabs[0].markdownEditSession?.currentSource == refreshedSource)
    #expect(model.tabs[0].diffSession?.baseline?.source == "# HEAD")
}

@Test("preserves a local Markdown draft and marks an external refresh as a conflict")
@MainActor
func preservesLocalMarkdownDraftAndMarksExternalRefreshAsConflict() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-markdown-conflict-refresh-\(UUID().uuidString)", isDirectory: true)
    let url = root.appendingPathComponent("notes.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try "# External".write(to: url, atomically: true, encoding: .utf8)

    let model = AppModel(restoresLastWorkspace: false)
    model.tabs = [
        DocumentTab(
            id: url.path,
            url: url,
            kind: .markdown,
            markdownEditSession: MarkdownEditSession(
                isEditing: true,
                baseSource: "# Original",
                currentSource: "# Local"
            ),
            diffSession: DocumentDiffSession(
                mode: .savedOnDisk,
                baseline: DocumentDiffBaseline(label: "Saved on Disk", source: "# Original"),
                returnMode: .source
            )
        )
    ]
    model.activeTabID = url.path

    model.refreshActiveTab()

    for _ in 0..<40 where model.tabs[0].markdownEditSession?.conflict == nil {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(model.tabs[0].markdownEditSession?.currentSource == "# Local")
    #expect(model.tabs[0].markdownEditSession?.conflict?.externalSource == "# External")
    #expect(model.tabs[0].diffSession?.baseline?.source == "# External")
}

@Test("hides completed document actions after saving")
@MainActor
func hidesCompletedDocumentActionsAfterSaving() {
    let savedBar = DocumentEditActionBar(
        saveState: .saved,
        onDiscard: {},
        onSave: {}
    )
    let unsavedBar = DocumentEditActionBar(
        saveState: .unsaved,
        onDiscard: {},
        onSave: {}
    )

    #expect(savedBar.showsStatus == false)
    #expect(savedBar.showsDiscardChanges == false)
    #expect(savedBar.isSaveDisabled)
    #expect(savedBar.saveButtonOpacity == 0.55)
    #expect(unsavedBar.showsStatus)
    #expect(unsavedBar.showsDiscardChanges)
    #expect(unsavedBar.isSaveDisabled == false)
    #expect(unsavedBar.saveButtonOpacity == 1)
}

@Test("discards an active Markdown draft without closing its tab")
@MainActor
func discardsActiveMarkdownDraftWithoutClosingTab() {
    let tabID = "file:///tmp/project/notes.md"
    let tab = DocumentTab(
        id: tabID,
        url: URL(fileURLWithPath: "/tmp/project/notes.md"),
        kind: .markdown,
        markdownSource: "# Draft",
        markdownEditSession: MarkdownEditSession(
            baseSource: "# Saved",
            currentSource: "# Draft",
            saveState: .unsaved,
            undoSources: ["# Saved"]
        )
    )
    let model = AppModel()
    model.tabs = [tab]
    model.activeTabID = tabID

    model.discardEditing(tabID: tabID)

    let updated = model.tabs[0]
    #expect(model.tabs.count == 1)
    #expect(updated.markdownEditSession?.currentSource == "# Saved")
    #expect(updated.markdownEditSession?.isEditing == true)
    #expect(updated.markdownEditSession?.saveState == .saved)
    #expect(updated.markdownEditSession?.undoSources.isEmpty == true)
}

@Test("keeps CSV editing active after discarding its draft")
@MainActor
func keepsCSVEditingActiveAfterDiscardingDraft() throws {
    let source = "Name,Age\nAlice,30"
    let editedSource = "Name,Age\nAlice,31"
    let url = URL(fileURLWithPath: "/tmp/viewer-discard-csv-\(UUID().uuidString).csv")
    let tabID = url.path
    let tab = DocumentTab(
        id: tabID,
        url: url,
        kind: .csv,
        previewCSV: try CSVPreviewAdapter().parse(source: editedSource),
        csvEditSession: CSVEditSession(
            baseSource: source,
            currentSource: editedSource,
            saveState: .unsaved
        )
    )
    let model = AppModel()
    model.tabs = [tab]
    model.activeTabID = tabID

    model.discardEditing(tabID: tabID)

    let updated = model.tabs[0]
    #expect(updated.csvEditSession?.currentSource == source)
    #expect(updated.csvEditSession?.isEditing == true)
    #expect(updated.csvEditSession?.saveState == .saved)
    #expect(updated.previewCSV?.rows[1][1] == "30")
}

@Test("undoes and redoes CSV cell edits without saving the file")
@MainActor
func undoesAndRedoesCSVCellEditsWithoutSavingFile() throws {
    let source = "Name,Age\nAlice,30"
    let editedSource = "Name,Age\nAlice,31"
    let url = URL(fileURLWithPath: "/tmp/viewer-undo-csv-\(UUID().uuidString).csv")
    let tabID = url.path
    let tab = DocumentTab(
        id: tabID,
        url: url,
        kind: .csv,
        previewCSV: try CSVPreviewAdapter().parse(source: source)
    )
    let model = AppModel()
    model.tabs = [tab]
    model.activeTabID = tabID

    model.updateCSVEditing(tabID: tabID, row: 1, column: 1, value: "31")
    #expect(model.tabs[0].csvEditSession?.currentSource == editedSource)
    #expect(model.tabs[0].csvEditSession?.undoSources == [source])
    #expect(model.undoCSVEdit())
    #expect(model.tabs[0].previewCSV?.rows[1][1] == "30")
    #expect(model.tabs[0].csvEditSession?.saveState == .saved)
    #expect(model.tabs[0].csvEditSession?.redoSources == [editedSource])
    #expect(model.redoCSVEdit())
    #expect(model.tabs[0].previewCSV?.rows[1][1] == "31")
    #expect(model.tabs[0].csvEditSession?.saveState == .unsaved)
}

@Test("saves an active CSV edit through the shared editing action")
@MainActor
func savesActiveCSVEditThroughSharedEditingAction() async throws {
    let source = "Name,Age\nAlice,30"
    let editedSource = "Name,Age\nAlice,31"
    let url = URL(fileURLWithPath: "/tmp/viewer-shared-csv-(UUID().uuidString).csv")
    try source.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let tab = DocumentTab(
        id: url.path,
        url: url,
        kind: .csv,
        previewCSV: try CSVPreviewAdapter().parse(source: source),
        csvEditSession: CSVEditSession(
            baseSource: source,
            currentSource: editedSource,
            saveState: .unsaved
        )
    )
    let model = AppModel()
    model.tabs = [tab]

    #expect(await model.saveCSVEditing(tabID: url.path))
    #expect(try String(contentsOf: url, encoding: .utf8) == editedSource)
    #expect(model.tabs[0].csvEditSession?.baseSource == editedSource)
    #expect(model.tabs[0].csvEditSession?.saveState == .saved)
    #expect(model.tabs[0].previewCSV?.rows[1][1] == "31")
}
