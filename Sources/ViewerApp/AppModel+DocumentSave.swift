import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func saveUntitledMarkdown(
        tabID: String,
        session: MarkdownEditSession,
        finishEditing: Bool
    ) async -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].isUntitled else { return false }
        tabs[index].markdownEditSession?.saveState = .saving

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "Untitled.md"
        panel.title = "Save Markdown File"
        panel.prompt = "Save"

        guard panel.runModal() == .OK,
              let selectedURL = panel.url else {
            tabs[index].markdownEditSession?.saveState = .unsaved
            return false
        }

        return commitUntitledMarkdown(
            tabID: tabID,
            session: session,
            selectedURL: selectedURL,
            finishEditing: finishEditing
        )
    }

    func commitUntitledMarkdown(
        tabID: String,
        session: MarkdownEditSession,
        selectedURL: URL,
        finishEditing: Bool
    ) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].isUntitled else { return false }
        tabs[index].markdownEditSession?.saveState = .saving

        let targetURL = markdownSaveURL(for: selectedURL)
        let outcome = documentEditCoordinator.commitMarkdown(
            url: targetURL,
            source: session.currentSource
        )
        guard case let .saved(source) = outcome else {
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return false }
            if case let .failed(message) = outcome {
                tabs[index].markdownEditSession?.saveState = .failed
                tabs[index].errorMessage = message
            }
            return false
        }

        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return false }
        let normalizedURL = targetURL.resolvingSymlinksInPath().standardizedFileURL
        let oldID = tabs[index].id
        documentRenderCoordinator.cancel(tabIDs: [oldID])
        tabs[index].id = normalizedURL.path
        tabs[index].url = normalizedURL
        tabs[index].kind = .markdown
        tabs[index].contextURL = nil
        tabs[index].status = .updating
        tabs[index].isStale = false
        tabs[index].previewBaseURL = nil
        tabs[index].previewDependencies = []
        tabs[index].previewExternalDependencies = []
        tabs[index].markdownSource = source
        tabs[index].markdownBlocks = MarkdownBlockDocument(source: source).blocks
        tabs[index].markdownEditSession?.baseSource = source
        tabs[index].markdownEditSession?.currentSource = source
        tabs[index].markdownEditSession?.saveState = .saved
        tabs[index].markdownEditSession?.conflict = nil
        tabs[index].markdownEditSession?.isEditing = !finishEditing
        if finishEditing {
            tabs[index].diffSession = nil
        }
        if activeTabID == oldID {
            activeTabID = normalizedURL.path
        }
        renderMarkdown(tabID: normalizedURL.path)
        if activeTabID == normalizedURL.path {
            restartWatchingActiveFilesIfNeeded()
        }
        syncPreviewZoomToActiveTab()
        persistState()
        return true
    }

    private func markdownSaveURL(for url: URL) -> URL {
        let extensionName = url.pathExtension.lowercased()
        guard extensionName == "md" || extensionName == "markdown" else {
            return url.appendingPathExtension("md")
        }
        return url
    }

    func applyMarkdownTransition(
        _ transition: DocumentEditTransition,
        at index: Int
    ) {
        tabs[index].markdownSource = transition.source
        tabs[index].markdownBlocks = transition.markdownBlocks
        tabs[index].markdownEditSession = transition.session
    }

    func applyJSONTransition(
        _ transition: DocumentEditTransition,
        at index: Int
    ) {
        tabs[index].jsonSource = transition.source
        tabs[index].jsonEditSession = transition.session
        if let cursorOffset = transition.jsonCursorUTF8Offset {
            tabs[index].jsonCursorUTF8Offset = cursorOffset
        }
        tabs[index].errorMessage = transition.jsonErrorMessage
    }

    @discardableResult
    func applyMarkdownSaveOutcome(
        _ outcome: DocumentEditSaveOutcome,
        tabID: String,
        renderWhenNotEditing: Bool,
        finishEditing: Bool = false
    ) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return false }
        switch outcome {
        case let .saved(source):
            tabs[index].markdownSource = source
            tabs[index].markdownBlocks = MarkdownBlockDocument(source: source).blocks
            tabs[index].markdownEditSession?.baseSource = source
            tabs[index].markdownEditSession?.currentSource = source
            tabs[index].markdownEditSession?.saveState = .saved
            tabs[index].markdownEditSession?.conflict = nil
            if tabs[index].diffSession?.mode == .savedOnDisk {
                tabs[index].diffSession?.baseline = DocumentDiffBaseline(
                    label: "Saved on Disk",
                    source: source
                )
            }
            tabs[index].errorMessage = nil
            if finishEditing {
                tabs[index].markdownEditSession?.isEditing = false
                tabs[index].diffSession = nil
            }
            if renderWhenNotEditing && tabs[index].markdownEditSession?.isEditing != true {
                renderMarkdown(tabID: tabID)
            }
            return true
        case let .conflict(conflict):
            tabs[index].markdownEditSession?.saveState = .conflict
            tabs[index].markdownEditSession?.conflict = conflict
            return false
        case let .failed(message):
            tabs[index].markdownEditSession?.saveState = .failed
            tabs[index].errorMessage = message
            return false
        }
    }

    @discardableResult
    func applyJSONSaveOutcome(
        _ outcome: DocumentEditSaveOutcome,
        tabID: String,
        finishEditing: Bool
    ) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return false }
        switch outcome {
        case let .saved(source):
            tabs[index].jsonSource = source
            tabs[index].jsonEditSession?.baseSource = source
            tabs[index].jsonEditSession?.currentSource = source
            tabs[index].jsonEditSession?.saveState = .saved
            tabs[index].jsonEditSession?.conflict = nil
            if tabs[index].diffSession?.mode == .savedOnDisk {
                tabs[index].diffSession?.baseline = DocumentDiffBaseline(
                    label: "Saved on Disk",
                    source: source
                )
            }
            tabs[index].errorMessage = nil
            if finishEditing {
                tabs[index].jsonEditSession?.isEditing = false
                tabs[index].diffSession = nil
                renderJSON(tabID: tabID)
            }
            return true
        case let .conflict(conflict):
            tabs[index].jsonEditSession?.saveState = .conflict
            tabs[index].jsonEditSession?.isEditing = true
            tabs[index].jsonEditSession?.conflict = conflict
            return false
        case let .failed(message):
            tabs[index].jsonEditSession?.saveState = .failed
            tabs[index].jsonEditSession?.isEditing = true
            tabs[index].errorMessage = message
            return false
        }
    }

}
