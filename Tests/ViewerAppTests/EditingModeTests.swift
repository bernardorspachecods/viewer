import Testing
import Foundation
import Darwin
import AppKit
@testable import ViewerApp
@testable import ViewerCore

@Test("Markdown editing exposes source and split modes")
func exposesMarkdownEditingModes() {
    #expect(MarkdownEditingMode.allCases == [.markdown, .split])
    #expect(MarkdownEditingMode(rawValue: "visual") == nil)
}

@Test("resolves a Git HEAD baseline through the process seam")
func resolvesGitHeadBaselineThroughProcessSeam() {
    let provider = GitHeadDocumentDiffBaselineProvider(runner: StubGitProcessRunner())
    let result = provider.baseline(for: URL(fileURLWithPath: "/tmp/project/notes.md"))

    guard case let .available(baseline) = result else {
        Issue.record("Expected a Git HEAD baseline")
        return
    }
    #expect(baseline.label == "HEAD")
    #expect(baseline.source == "from head")
}

@Test("restores a tracked file to Git HEAD including staged and worktree changes")
func restoresTrackedFileToGitHead() {
    let runner = RecordingGitProcessRunner()
    let restorer = GitHeadDocumentRestorer(runner: runner)

    let result = restorer.restoreToHead(for: URL(fileURLWithPath: "/tmp/project/notes.md"))

    guard case let .restored(source) = result else {
        Issue.record("Expected the file to be restored from Git HEAD")
        return
    }
    #expect(source == "from head")
    #expect(runner.requests.map(\.arguments) == [
        ["-C", "/tmp/project", "rev-parse", "--show-toplevel"],
        ["show", "HEAD:notes.md"],
        ["restore", "--source=HEAD", "--staged", "--worktree", "--", "notes.md"]
    ])
}

@Test("does not restore a file that has no version in Git HEAD")
func doesNotRestoreFileWithoutGitHeadVersion() {
    let runner = RecordingGitProcessRunner(headResult: ProcessResult(
        status: .failed,
        exitCode: 128,
        standardOutput: "",
        standardError: "pathspec 'notes.md' did not match any file(s) known to git"
    ))
    let restorer = GitHeadDocumentRestorer(runner: runner)

    let result = restorer.restoreToHead(for: URL(fileURLWithPath: "/tmp/project/notes.md"))

    guard case let .unavailable(message) = result else {
        Issue.record("Expected Git restore to be unavailable without a HEAD version")
        return
    }
    #expect(message == "This file has no version in the latest Git commit.")
    #expect(runner.requests.count == 2)
}

@Test("uses direct labels for document diff modes")
func usesDirectLabelsForDocumentDiffModes() {
    #expect(DocumentDiffMode.savedOnDisk.label == "Disk Diff")
    #expect(DocumentDiffMode.gitHead.label == "Git Diff")
}

@Test("keeps tab and worktree file context actions aligned")
func keepsTabAndWorktreeFileContextActionsAligned() {
    let tabActions = Set(WorkspaceContextMenuOptions.forTab(isUntitled: false))
    let fileActions = Set(WorkspaceContextMenuOptions.forFile(isDirectory: false))

    #expect(
        tabActions.subtracting([.closeTab, .closeOtherTabs, .revealInSidebar]) == fileActions
    )
    #expect(fileActions.contains(.revealInFinder))
}

@Test("toggles document editing modes directly")
@MainActor
func togglesDocumentEditingModesDirectly() {
    let tabID = "file:///tmp/project/notes.md"
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: URL(fileURLWithPath: "/tmp/project/notes.md"),
            kind: .markdown,
            markdownEditSession: MarkdownEditSession(
                baseSource: "# Notes",
                currentSource: "# Notes"
            )
        )
    ]

    model.toggleMarkdownSplitView(tabID: tabID)
    #expect(model.tabs[0].markdownEditSession?.mode == .split)

    model.toggleDocumentDiff(mode: .savedOnDisk, tabID: tabID)
    #expect(model.tabs[0].markdownEditSession?.mode == .markdown)
    #expect(model.tabs[0].presentationMode == .diff(.savedOnDisk))
    #expect(model.tabs[0].diffSession?.mode == .savedOnDisk)

    model.toggleDocumentDiff(mode: .gitHead, tabID: tabID)
    #expect(model.tabs[0].presentationMode == .diff(.gitHead))
    #expect(model.tabs[0].markdownEditSession?.isEditing == true)
    #expect(model.tabs[0].markdownEditSession?.mode == .markdown)

    model.toggleMarkdownSplitView(tabID: tabID)
    #expect(model.tabs[0].presentationMode == .split)
    #expect(model.tabs[0].diffSession == nil)

    model.toggleDocumentDiff(mode: .gitHead, tabID: tabID)
    #expect(model.tabs[0].markdownEditSession?.mode == .markdown)
    #expect(model.tabs[0].presentationMode == .diff(.gitHead))
    #expect(model.tabs[0].diffSession?.mode == .gitHead)
    model.toggleDocumentDiff(mode: .gitHead, tabID: tabID)
    #expect(model.tabs[0].diffSession == nil)
}

@Test("forwards source edits immediately while split and diff editing stays active")
@MainActor
func forwardsSourceEditsImmediatelyWhileSplitAndDiffEditingStaysActive() {
    var receivedSources: [String] = []
    let coordinator = SourceTextView.Coordinator(
        onSourceChanged: { source in
            receivedSources.append(source)
        },
        onEndEditing: { _ in },
        onFindMatchCount: { _ in },
        defersSourceChangeUpdates: false
    )
    let textView = NSTextView()
    textView.string = "# After"

    coordinator.textDidChange(
        Notification(name: NSText.didChangeNotification, object: textView)
    )

    #expect(receivedSources == ["# After"])
}

@Test("returns to preview after closing a diff opened from preview")
@MainActor
func returnsToPreviewAfterClosingDiffOpenedFromPreview() {
    let tabID = "file:///tmp/project/preview-notes.md"
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: URL(fileURLWithPath: "/tmp/project/preview-notes.md"),
            kind: .markdown,
            previewHTML: "<p>Preview</p>",
            markdownSource: "# Notes"
        )
    ]

    #expect(model.tabs[0].markdownEditSession == nil)

    model.toggleDocumentDiff(mode: .gitHead, tabID: tabID)
    #expect(model.tabs[0].presentationMode == .diff(.gitHead))
    #expect(model.tabs[0].markdownEditSession?.isEditing == true)
    #expect(model.tabs[0].markdownEditSession != nil)

    model.toggleDocumentDiff(mode: .gitHead, tabID: tabID)
    #expect(model.tabs[0].diffSession == nil)
    #expect(model.tabs[0].presentationMode == .preview)
    #expect(model.tabs[0].markdownEditSession!.isEditing == false)
}

@Test("restores editor and split modes after closing a diff")
@MainActor
func restoresEditorAndSplitModesAfterClosingDiff() {
    let editorTabID = "file:///tmp/project/editor-notes.md"
    let splitTabID = "file:///tmp/project/split-notes.md"
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: editorTabID,
            url: URL(fileURLWithPath: "/tmp/project/editor-notes.md"),
            kind: .markdown,
            markdownEditSession: MarkdownEditSession(
                baseSource: "# Editor",
                currentSource: "# Editor"
            )
        ),
        DocumentTab(
            id: splitTabID,
            url: URL(fileURLWithPath: "/tmp/project/split-notes.md"),
            kind: .markdown,
            markdownEditSession: MarkdownEditSession(
                mode: .split,
                baseSource: "# Split",
                currentSource: "# Split"
            )
        )
    ]

    model.toggleDocumentDiff(mode: .gitHead, tabID: editorTabID)
    model.toggleDocumentDiff(mode: .gitHead, tabID: editorTabID)
    #expect(model.tabs[0].presentationMode == .source)
    #expect(model.tabs[0].markdownEditSession?.isEditing == true)

    model.toggleDocumentDiff(mode: .savedOnDisk, tabID: splitTabID)
    model.toggleDocumentDiff(mode: .gitHead, tabID: splitTabID)
    #expect(model.tabs[1].presentationMode == .diff(.gitHead))
    model.toggleDocumentDiff(mode: .gitHead, tabID: splitTabID)
    #expect(model.tabs[1].presentationMode == .split)
}

@Test("keeps the original return mode when switching diff types")
@MainActor
func keepsOriginalReturnModeWhenSwitchingDiffTypes() {
    let tabID = "file:///tmp/project/switched-diff.md"
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: URL(fileURLWithPath: "/tmp/project/switched-diff.md"),
            kind: .markdown,
            previewHTML: "<p>Preview</p>",
            markdownSource: "# Notes"
        )
    ]

    model.toggleDocumentDiff(mode: .gitHead, tabID: tabID)
    model.toggleDocumentDiff(mode: .savedOnDisk, tabID: tabID)
    #expect(model.tabs[0].presentationMode == .diff(.savedOnDisk))

    model.toggleDocumentDiff(mode: .savedOnDisk, tabID: tabID)
    #expect(model.tabs[0].presentationMode == .preview)
    #expect(model.tabs[0].markdownEditSession?.isEditing != true)
}

@Test("saves Markdown from split view without leaving split view")
@MainActor
func savesMarkdownFromSplitViewWithoutLeavingSplitView() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-split-save-\(UUID().uuidString)", isDirectory: true)
    let fileURL = root.appendingPathComponent("notes.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "# Saved".write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let tabID = fileURL.path
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: fileURL,
            kind: .markdown,
            markdownSource: "# Draft",
            markdownEditSession: MarkdownEditSession(
                mode: .split,
                baseSource: "# Saved",
                currentSource: "# Draft",
                saveState: .unsaved
            )
        )
    ]

    #expect(await model.saveMarkdownEditing(tabID: tabID))
    #expect(try String(contentsOf: fileURL, encoding: .utf8) == "# Draft")
    #expect(model.tabs[0].markdownEditSession?.isEditing == true)
    #expect(model.tabs[0].markdownEditSession?.mode == .split)
    #expect(model.tabs[0].presentationMode == .split)
    #expect(model.tabs[0].markdownEditSession?.saveState == .saved)
}

@Test("returns to preview after closing a split view opened from preview")
@MainActor
func returnsToPreviewAfterClosingSplitViewOpenedFromPreview() {
    let tabID = "file:///tmp/project/split-preview.md"
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: URL(fileURLWithPath: "/tmp/project/split-preview.md"),
            kind: .markdown,
            previewHTML: "<p>Preview</p>",
            markdownSource: "# Notes"
        )
    ]

    model.toggleMarkdownSplitView(tabID: tabID)
    #expect(model.tabs[0].presentationMode == .split)

    model.toggleMarkdownSplitView(tabID: tabID)
    #expect(model.tabs[0].presentationMode == .preview)
    #expect(model.tabs[0].markdownEditSession?.isEditing != true)
}

@Test("returns to the editor after closing a split view opened from the editor")
@MainActor
func returnsToEditorAfterClosingSplitViewOpenedFromEditor() {
    let tabID = "file:///tmp/project/split-editor.md"
    let model = AppModel()
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: URL(fileURLWithPath: "/tmp/project/split-editor.md"),
            kind: .markdown,
            markdownEditSession: MarkdownEditSession(
                baseSource: "# Notes",
                currentSource: "# Notes"
            )
        )
    ]

    model.toggleMarkdownSplitView(tabID: tabID)
    model.toggleMarkdownSplitView(tabID: tabID)

    #expect(model.tabs[0].presentationMode == .source)
    #expect(model.tabs[0].markdownEditSession?.isEditing == true)
}

@Test("discards Git changes and leaves Markdown in source mode")
@MainActor
func discardsGitChangesAndLeavesMarkdownInSourceMode() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-git-discard-\(UUID().uuidString)", isDirectory: true)
    let fileURL = root.appendingPathComponent("notes.md")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "# On disk".write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let restorer = GitHeadDocumentRestorer(
        runner: RecordingGitProcessRunner(repositoryPath: root.path)
    )
    let model = AppModel(documentDiffCoordinator: DocumentDiffCoordinator(gitRestorer: restorer))
    let tabID = fileURL.path
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: fileURL,
            kind: .markdown,
            markdownSource: "# On disk",
            markdownEditSession: MarkdownEditSession(
                baseSource: "# On disk",
                currentSource: "# Draft"
            ),
            diffSession: DocumentDiffSession(
                mode: .gitHead,
                baseline: DocumentDiffBaseline(label: "HEAD", source: "# Head")
            )
        )
    ]

    model.requestDiscardGitChanges(tabID: tabID)
    #expect(model.showingGitDiscardConfirmation)
    #expect(model.pendingGitDiscardTitle == "notes")

    model.confirmDiscardGitChanges()
    for _ in 0..<10 {
        try await Task.sleep(nanoseconds: 1_000_000)
    }

    let updated = model.tabs[0]
    #expect(!model.showingGitDiscardConfirmation)
    #expect(updated.diffSession == nil)
    #expect(updated.presentationMode == .source)
    #expect(updated.markdownEditSession?.isEditing == true)
    #expect(updated.markdownEditSession?.baseSource == "from head")
    #expect(updated.markdownEditSession?.currentSource == "from head")
    #expect(updated.markdownEditSession?.undoSources.isEmpty == true)
}

@Test("discards Git changes and leaves JSON in source mode")
@MainActor
func discardsGitChangesAndLeavesJSONInSourceMode() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("viewer-git-discard-json-\(UUID().uuidString)", isDirectory: true)
    let fileURL = root.appendingPathComponent("data.json")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "{\"disk\":true}".write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let restorer = GitHeadDocumentRestorer(
        runner: RecordingGitProcessRunner(
            headResult: ProcessResult(
                status: .success,
                exitCode: 0,
                standardOutput: "{\"head\":true}",
                standardError: ""
            ),
            repositoryPath: root.path
        )
    )
    let model = AppModel(documentDiffCoordinator: DocumentDiffCoordinator(gitRestorer: restorer))
    let tabID = fileURL.path
    model.tabs = [
        DocumentTab(
            id: tabID,
            url: fileURL,
            kind: .json,
            jsonSource: "{\"disk\":true}",
            jsonEditSession: MarkdownEditSession(
                baseSource: "{\"disk\":true}",
                currentSource: "{\"draft\":true}"
            ),
            diffSession: DocumentDiffSession(
                mode: .gitHead,
                baseline: DocumentDiffBaseline(label: "HEAD", source: "{\"head\":true}")
            )
        )
    ]

    model.requestDiscardGitChanges(tabID: tabID)
    model.confirmDiscardGitChanges()
    for _ in 0..<10 {
        try await Task.sleep(nanoseconds: 1_000_000)
    }

    let updated = model.tabs[0]
    #expect(updated.diffSession == nil)
    #expect(updated.presentationMode == .source)
    #expect(updated.jsonEditSession?.isEditing == true)
    #expect(updated.jsonEditSession?.baseSource == "{\"head\":true}")
    #expect(updated.jsonEditSession?.currentSource == "{\"head\":true}")
    #expect(updated.jsonEditSession?.saveState == .saved)
}

@MainActor
private final class NativeTextView: NSTextView {}

@Test("the draft flush skips the Markdown editor and the search field")
@MainActor
func draftFlushSkipsTheMarkdownEditorAndFieldEditors() {
    let rawEditor = NSTextView()
    rawEditor.isEditable = true
    #expect(MarkdownDraftFlushPolicy.shouldFlush(from: rawEditor))

    let readOnly = NSTextView()
    readOnly.isEditable = false
    #expect(!MarkdownDraftFlushPolicy.shouldFlush(from: readOnly))

    let fieldEditor = NSTextView()
    fieldEditor.isEditable = true
    fieldEditor.isFieldEditor = true
    #expect(!MarkdownDraftFlushPolicy.shouldFlush(from: fieldEditor))

    let engine = NativeTextView()
    engine.isEditable = true
    #expect(!MarkdownDraftFlushPolicy.shouldFlush(from: engine))
}
