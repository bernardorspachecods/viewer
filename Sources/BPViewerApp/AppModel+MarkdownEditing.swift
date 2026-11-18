import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func beginMarkdownEditing(
        tabID: String,
        mode: MarkdownEditingMode = .markdown
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .markdown else { return }

        let source = tabs[index].markdownSource
            ?? (try? String(contentsOf: tabs[index].url, encoding: .utf8))
            ?? ""
        markdownUndoGroupTimes[tabID] = nil
        tabs[index].diffSession = nil
        applyMarkdownTransition(
            documentEditCoordinator.beginMarkdown(source: source, mode: mode),
            at: index
        )
    }

    /// Split view and diffs are their own modes, so Quick Edit and the raw editor stay out of them.
    private func isMarkdownQuickEditAvailable(at index: Int) -> Bool {
        tabs[index].presentationMode != .split && tabs[index].diffSession == nil
    }

    func beginMarkdownQuickEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .markdown,
              isMarkdownQuickEditAvailable(at: index) else { return }
        guard tabs[index].markdownEditSession?.isEditing == true else {
            // The displayed HTML already matches the source, so nothing is re-rendered here.
            beginMarkdownEditing(tabID: tabID)
            tabs[index].markdownEditSession?.isPreviewInline = true
            return
        }
        guard tabs[index].markdownEditSession?.isPreviewInline != true,
              let session = tabs[index].markdownEditSession else { return }
        tabs[index].markdownEditSession?.isPreviewInline = true
        renderMarkdown(tabID: tabID, sourceOverride: session.currentSource)
    }

    func setMarkdownRawEditing(tabID: String, raw: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .markdown,
              isMarkdownQuickEditAvailable(at: index) else { return }
        if !raw {
            beginMarkdownQuickEdit(tabID: tabID)
        } else if tabs[index].markdownEditSession?.isEditing == true {
            tabs[index].markdownEditSession?.isPreviewInline = false
        } else {
            beginMarkdownEditing(tabID: tabID)
        }
    }

    func updateMarkdownEditing(
        tabID: String,
        text: String,
        rebuildBlocks: Bool = true
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let shouldRecordUndo = markdownUndoGroupTimes[tabID].map {
            now - $0 >= 0.5
        } ?? true
        markdownUndoGroupTimes[tabID] = now
        guard
              let transition = documentEditCoordinator.updateMarkdown(
                  session: session,
                  source: text,
                  recordUndo: shouldRecordUndo,
                  markdownBlocks: rebuildBlocks ? nil : tabs[index].markdownBlocks
              ) else { return }

        applyMarkdownTransition(transition, at: index)
        if transition.session.mode == .split {
            scheduleMarkdownRender(tabID: tabID)
        }
    }

    func endMarkdownEditing(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession else { return }
        if tabs[index].isUntitled,
           session.currentSource != session.baseSource || session.saveState != .saved {
            tabs[index].markdownEditSession?.saveState = .saving
            Task { @MainActor [weak self] in
                _ = await self?.saveMarkdownEdit(tabID: tabID, finishEditing: true)
            }
            return
        }
        if session.currentSource == session.baseSource {
            tabs[index].markdownEditSession?.isEditing = false
            tabs[index].markdownEditSession?.isPreviewInline = false
            tabs[index].diffSession = nil
            renderMarkdown(tabID: tabID)
        } else {
            tabs[index].markdownEditSession?.saveState = .saving
            Task { @MainActor [weak self] in
                _ = await self?.saveMarkdownEdit(tabID: tabID, finishEditing: true)
            }
        }
    }

    /// Applies one edit made directly in the Quick Edit preview. The HTML is not
    /// re-rendered: the DOM already shows the typed text. A rejected edit re-renders
    /// from the session source when Quick Edit is showing, which drops the DOM change.
    /// The guard is on `isEditing` so a change posted just before a mode switch still lands.
    func applyInlineMarkdownEdit(
        tabID: String,
        blockID: String,
        unitIndex: Int?,
        original: String,
        edited: String
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession,
              session.isEditing else { return }
        let updatedSource = MarkdownBlockDocument(source: session.currentSource).applyingInlineTextEdit(
            blockID: blockID,
            unitIndex: unitIndex,
            originalText: original,
            editedText: edited
        )
        guard let updatedSource else {
            if session.isPreviewInline {
                renderMarkdown(tabID: tabID, sourceOverride: session.currentSource)
            }
            return
        }
        updateMarkdownEditing(tabID: tabID, text: updatedSource, rebuildBlocks: true)
    }

    @discardableResult
    func saveMarkdownEditing(tabID: String) async -> Bool {
        await saveMarkdownEdit(tabID: tabID)
    }

    func toggleMarkdownSplitView(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard tabs[index].markdownEditSession?.isEditing == true else {
            let returnMode = tabs[index].presentationMode
            beginMarkdownEditing(tabID: tabID, mode: .split)
            tabs[index].markdownEditSession?.splitReturnMode = returnMode
            return
        }

        if tabs[index].presentationMode == .split {
            let returnMode = tabs[index].markdownEditSession?.splitReturnMode ?? .source
            let modeAfterClosing = returnMode == .preview && hasUnsavedChanges(in: tabs[index])
                ? .source
                : returnMode
            tabs[index].selectPresentationMode(modeAfterClosing)
            tabs[index].markdownEditSession?.splitReturnMode = nil
            if modeAfterClosing == .preview {
                renderMarkdown(tabID: tabID)
            }
            return
        }

        let returnMode = tabs[index].markdownEditSession?.splitReturnMode ?? .source
        tabs[index].markdownEditSession?.splitReturnMode = returnMode
        tabs[index].markdownEditSession?.isPreviewInline = false
        tabs[index].selectPresentationMode(.split)
        if let session = tabs[index].markdownEditSession {
            renderMarkdown(tabID: tabID, sourceOverride: session.currentSource)
        }
    }

    @discardableResult
    func undoMarkdownEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession,
              let transition = documentEditCoordinator.undoMarkdown(session: session) else { return false }

        markdownUndoGroupTimes[tabID] = nil
        applyMarkdownTransition(transition, at: index)
        if transition.session.mode == .split {
            scheduleMarkdownRender(tabID: tabID)
        } else if transition.session.isPreviewInline {
            renderMarkdown(tabID: tabID, sourceOverride: transition.session.currentSource)
        }
        return true
    }

    @discardableResult
    func redoMarkdownEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession,
              let transition = documentEditCoordinator.redoMarkdown(session: session) else { return false }

        markdownUndoGroupTimes[tabID] = nil
        applyMarkdownTransition(transition, at: index)
        if transition.session.mode == .split {
            scheduleMarkdownRender(tabID: tabID)
        } else if transition.session.isPreviewInline {
            renderMarkdown(tabID: tabID, sourceOverride: transition.session.currentSource)
        }
        return true
    }

    func keepLocalMarkdownEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession else { return }
        applyMarkdownSaveOutcome(
            documentEditCoordinator.commitMarkdown(url: tabs[index].url, source: session.currentSource),
            tabID: tabID,
            renderWhenNotEditing: true
        )
    }

    func useExternalMarkdownEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession,
              let conflict = session.conflict else { return }
        applyMarkdownTransition(
            documentEditCoordinator.useExternal(
                session: session,
                externalSource: conflict.externalSource
            ),
            at: index
        )
        tabs[index].diffSession = nil
        renderMarkdown(tabID: tabID)
    }

    @discardableResult
    func saveMarkdownEdit(tabID: String, finishEditing: Bool = false) async -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession else { return false }

        if tabs[index].isUntitled {
            return await saveUntitledMarkdown(
                tabID: tabID,
                session: session,
                finishEditing: finishEditing
            )
        }

        guard session.currentSource != session.baseSource else {
            if finishEditing {
                tabs[index].markdownEditSession?.isEditing = false
                tabs[index].markdownEditSession?.isPreviewInline = false
                tabs[index].diffSession = nil
                renderMarkdown(tabID: tabID)
            }
            return true
        }

        let localSource = session.currentSource
        tabs[index].markdownEditSession?.saveState = .saving
        let outcome = await documentEditCoordinator.saveMarkdown(
            url: tabs[index].url,
            baseSource: session.baseSource,
            localSource: localSource
        )
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[currentIndex].markdownEditSession?.currentSource == localSource else {
            return false
        }
        return applyMarkdownSaveOutcome(
            outcome,
            tabID: tabID,
            renderWhenNotEditing: true,
            finishEditing: finishEditing
        )
    }

}
