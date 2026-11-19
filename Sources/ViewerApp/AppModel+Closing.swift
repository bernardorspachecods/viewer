import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func closeTab(_ tab: DocumentTab) {
        guard tabs.contains(tab) else { return }
        guard !hasUnsavedChanges(in: tab) else {
            presentPendingClose(for: tab, closesTab: true)
            return
        }
        closeTabImmediately(tab)
    }

    func shouldCloseWindow(_ window: NSWindow) -> Bool {
        if isPendingWindowClose
            || showingPendingCloseConfirmation
            || showingFileMoveConfirmation
            || showingInvalidJSONConfirmation
            || showingGitDiscardConfirmation {
            return false
        }
        guard let tab = tabs.first(where: hasUnsavedChanges(in:)) else {
            return true
        }
        let unsavedTabs = tabs.filter(hasUnsavedChanges(in:))
        pendingWindow = window
        isPendingWindowClose = true
        pendingBatchCloseIDs = Set(unsavedTabs.map(\.id))
        presentPendingClose(for: tab, closesTab: false, unsavedCount: unsavedTabs.count)
        return false
    }

    func presentPendingClose(
        for tab: DocumentTab,
        closesTab: Bool,
        unsavedCount: Int = 1
    ) {
        pendingCloseRequest = PendingCloseRequest(
            id: "\(closesTab ? "tab" : "window")-\(tab.id)",
            tabID: tab.id,
            title: tab.title,
            closesTab: closesTab,
            unsavedCount: unsavedCount
        )
        showingPendingCloseConfirmation = true
    }

    func cancelPendingClose() {
        let IDsToKeepEditing: Set<String> = pendingBatchCloseIDs.isEmpty
            ? Set(pendingCloseRequest.map { [$0.tabID] } ?? [])
            : pendingBatchCloseIDs
        for index in tabs.indices where IDsToKeepEditing.contains(tabs[index].id) {
            tabs[index].markdownEditSession?.isEditing = true
            tabs[index].jsonEditSession?.isEditing = true
            tabs[index].latexEditSession?.isEditing = true
        }
        pendingCloseRequest = nil
        showingPendingCloseConfirmation = false
        pendingBatchCloseIDs.removeAll()
        if isPendingWindowClose {
            isPendingWindowClose = false
            pendingWindow = nil
        }
        if isPendingRootChange {
            isPendingRootChange = false
            pendingRootURL = nil
            pendingOpenURLs = []
        }
    }

    var pendingCloseCanSave: Bool {
        guard let request = pendingCloseRequest else {
            return false
        }
        let IDs = request.closesTab || pendingBatchCloseIDs.isEmpty
            ? [request.tabID]
            : Array(pendingBatchCloseIDs)
        return IDs.allSatisfy { tabID in
            guard let tab = tabs.first(where: { $0.id == tabID }) else { return false }
            guard tab.kind == .json else { return true }
            return tab.jsonEditSession?.saveState != .failed && tab.errorMessage == nil
        }
    }

    func discardPendingClose() {
        guard let request = pendingCloseRequest,
              let tab = tabs.first(where: { $0.id == request.tabID }) else {
            pendingCloseRequest = nil
            showingPendingCloseConfirmation = false
            pendingBatchCloseIDs.removeAll()
            return
        }
        let closesTab = request.closesTab
        pendingCloseRequest = nil
        showingPendingCloseConfirmation = false
        if closesTab {
            closeTabImmediately(tab)
        } else if isPendingWindowClose && !isPendingRootChange {
            let IDs = pendingBatchCloseIDs
            for candidate in tabs where IDs.contains(candidate.id) {
                discardChanges(in: candidate)
            }
            pendingBatchCloseIDs.removeAll()
            let window = pendingWindow
            pendingWindow = nil
            isPendingWindowClose = false
            window?.close()
        } else {
            discardChanges(in: tab)
            continuePendingExit()
        }
    }

    func savePendingClose() {
        guard pendingCloseCanSave else { return }
        guard let request = pendingCloseRequest,
              let tab = tabs.first(where: { $0.id == request.tabID }) else {
            pendingCloseRequest = nil
            showingPendingCloseConfirmation = false
            return
        }
        let closesTab = request.closesTab
        pendingCloseRequest = nil
        showingPendingCloseConfirmation = false

        if !closesTab && isPendingWindowClose && !isPendingRootChange {
            let IDs = Array(pendingBatchCloseIDs)
            Task { @MainActor [weak self] in
                guard let self else { return }
                for tabID in IDs {
                    guard let tab = self.tabs.first(where: { $0.id == tabID }) else { continue }
                    let saved: Bool
                    switch tab.kind {
                    case .markdown:
                        saved = await self.saveMarkdownEdit(tabID: tab.id)
                    case .json:
                        saved = await self.saveJSONEdit(tabID: tab.id)
                    case .csv:
                        saved = await self.saveCSVEdit(tabID: tab.id)
                    case .latex:
                        saved = await self.saveLatexEdit(tabID: tab.id)
                    default:
                        saved = true
                    }
                    guard saved else { return }
                }
                self.pendingBatchCloseIDs.removeAll()
                let window = self.pendingWindow
                self.pendingWindow = nil
                self.isPendingWindowClose = false
                window?.close()
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let saved: Bool
            switch tab.kind {
            case .markdown:
                saved = await saveMarkdownEdit(tabID: tab.id)
            case .json:
                saved = await saveJSONEdit(tabID: tab.id, finishEditing: !closesTab)
            case .csv:
                saved = await saveCSVEdit(tabID: tab.id)
            case .latex:
                saved = await saveLatexEdit(tabID: tab.id, finishEditing: !closesTab)
            default:
                saved = true
            }
            guard saved else { return }
            if closesTab {
                guard let currentTab = tabs.first(where: { $0.id == tab.id }) else { return }
                closeTabImmediately(currentTab)
            } else {
                continuePendingExit()
            }
        }
    }

    private func continuePendingExit() {
        guard isPendingWindowClose || isPendingRootChange else { return }
        if let nextTab = tabs.first(where: hasUnsavedChanges(in:)) {
            presentPendingClose(for: nextTab, closesTab: false)
            return
        }
        if isPendingRootChange, let rootURL = pendingRootURL {
            completeRootChange(to: rootURL)
            return
        }
        let window = pendingWindow
        pendingWindow = nil
        isPendingWindowClose = false
        window?.close()
    }

    private func discardChanges(in tab: DocumentTab, keepEditing: Bool = false) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        if let session = tabs[index].markdownEditSession {
            tabs[index].markdownSource = session.baseSource
            tabs[index].markdownBlocks = MarkdownBlockDocument(source: session.baseSource).blocks
            tabs[index].markdownEditSession?.currentSource = session.baseSource
            tabs[index].markdownEditSession?.undoSources.removeAll()
            tabs[index].markdownEditSession?.redoSources.removeAll()
            tabs[index].markdownEditSession?.saveState = .saved
            tabs[index].markdownEditSession?.conflict = nil
            tabs[index].markdownEditSession?.isEditing = keepEditing
            tabs[index].errorMessage = nil
            renderMarkdown(tabID: tab.id)
        } else if let session = tabs[index].jsonEditSession {
            tabs[index].jsonSource = session.baseSource
            tabs[index].jsonEditSession?.currentSource = session.baseSource
            tabs[index].jsonEditSession?.undoSources.removeAll()
            tabs[index].jsonEditSession?.redoSources.removeAll()
            tabs[index].jsonEditSession?.saveState = .saved
            tabs[index].jsonEditSession?.conflict = nil
            tabs[index].jsonEditSession?.isEditing = keepEditing
            tabs[index].errorMessage = nil
            renderJSON(tabID: tab.id)
        } else if let session = tabs[index].latexEditSession {
            tabs[index].latexEditSession?.currentSource = session.baseSource
            tabs[index].latexEditSession?.undoSources.removeAll()
            tabs[index].latexEditSession?.redoSources.removeAll()
            tabs[index].latexEditSession?.saveState = .saved
            tabs[index].latexEditSession?.conflict = nil
            tabs[index].latexEditSession?.isEditing = keepEditing
            tabs[index].errorMessage = nil
            tabs[index].diffSession = nil
            renderLatex(tabID: tab.id)
        } else if let session = tabs[index].csvEditSession {
            if let document = try? CSVPreviewAdapter().parse(source: session.baseSource) {
                tabs[index].previewCSV = document
            }
            tabs[index].csvEditSession = keepEditing
                ? CSVEditSession(
                    isEditing: true,
                    baseSource: session.baseSource,
                    currentSource: session.baseSource,
                    saveState: .saved
                )
                : nil
            tabs[index].errorMessage = nil
            renderCSV(tabID: tab.id)
        }
    }

    func discardEditing(tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        discardChanges(in: tab, keepEditing: true)
    }

    func requestDiscardGitChanges(tabID: String) {
        guard !showingGitDiscardConfirmation,
              gitDiscardTask == nil,
              let tab = tabs.first(where: { $0.id == tabID }),
              (tab.kind == .markdown || tab.kind == .json || tab.kind == .latex),
              tab.presentationMode == .diff(.gitHead),
              tab.diffSession?.baseline != nil else { return }
        pendingGitDiscardTabID = tabID
        showingGitDiscardConfirmation = true
    }

    func cancelDiscardGitChanges() {
        pendingGitDiscardTabID = nil
        showingGitDiscardConfirmation = false
    }

    func confirmDiscardGitChanges() {
        guard let tabID = pendingGitDiscardTabID,
              let tab = tabs.first(where: { $0.id == tabID }) else {
            cancelDiscardGitChanges()
            return
        }

        pendingGitDiscardTabID = nil
        showingGitDiscardConfirmation = false
        gitDiscardTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.documentDiffCoordinator.restoreGitChanges(for: tab.editableSourceURL)
            self.applyGitDiscardOutcome(outcome, tabID: tabID)
            self.gitDiscardTask = nil
        }
    }

    var pendingGitDiscardTitle: String {
        guard let pendingGitDiscardTabID,
              let tab = tabs.first(where: { $0.id == pendingGitDiscardTabID }) else {
            return "This file"
        }
        return tab.title
    }

    private func applyGitDiscardOutcome(
        _ outcome: GitDocumentRestoreResolution,
        tabID: String
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        switch outcome {
        case let .restored(source):
            tabs[index].diffSession = nil
            tabs[index].errorMessage = nil
            if let session = tabs[index].markdownEditSession {
                tabs[index].markdownSource = source
                tabs[index].markdownBlocks = MarkdownBlockDocument(source: source).blocks
                tabs[index].markdownEditSession = MarkdownEditSession(
                    mode: session.mode,
                    isEditing: true,
                    baseSource: source,
                    currentSource: source
                )
                renderMarkdown(tabID: tabID)
            } else if let session = tabs[index].jsonEditSession {
                tabs[index].jsonSource = source
                tabs[index].jsonEditSession = MarkdownEditSession(
                    mode: session.mode,
                    isEditing: true,
                    baseSource: source,
                    currentSource: source
                )
                renderJSON(tabID: tabID)
            } else if let session = tabs[index].latexEditSession {
                tabs[index].latexEditSession = SourceEditSession(
                    mode: session.mode,
                    isEditing: true,
                    baseSource: source,
                    currentSource: source
                )
                renderLatex(tabID: tabID)
            }
            persistState()
        case let .unavailable(message), let .failed(message):
            tabs[index].errorMessage = message
            tabs[index].markdownEditSession?.saveState = .failed
            tabs[index].jsonEditSession?.saveState = .failed
            tabs[index].latexEditSession?.saveState = .failed
        }
    }

    private func closeTabImmediately(_ tab: DocumentTab) {
        guard tabs.contains(tab) else { return }
        latexRenderDebounceTasks[tab.id]?.cancel()
        latexRenderDebounceTasks[tab.id] = nil
        markdownRenderDebounceTasks[tab.id]?.cancel()
        markdownRenderDebounceTasks[tab.id] = nil
        documentRenderCoordinator.cancel(tabIDs: [tab.id])
        if pendingLatexRootSelection?.tabID == tab.id {
            pendingLatexRootSelection = nil
        }
        if pendingLatexExternalDependencies?.tabID == tab.id {
            pendingLatexExternalDependencies = nil
        }
        let wasActive = activeTabID == tab.id
        var session = documentTabSession
        guard session.close(id: tab.id) else { return }
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        if wasActive {
            renderActiveTabIfNeeded()
        }
        persistState()
        if pendingBatchCloseIDs.remove(tab.id) != nil {
            continuePendingBatchClose()
        }
    }

    func hasUnsavedChanges(in tab: DocumentTab) -> Bool {
        if tab.isUntitled,
           let session = tab.markdownEditSession,
           session.currentSource.isEmpty {
            return false
        }
        if let session = tab.markdownEditSession {
            return session.currentSource != session.baseSource || session.saveState != .saved
        }
        if let session = tab.jsonEditSession {
            return session.currentSource != session.baseSource || session.saveState != .saved
        }
        if let session = tab.csvEditSession {
            return session.currentSource != session.baseSource || session.saveState != .saved
        }
        if let session = tab.latexEditSession {
            return session.currentSource != session.baseSource || session.saveState != .saved
        }
        return false
    }

}
