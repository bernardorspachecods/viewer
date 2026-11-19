import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    var activeTab: DocumentTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    var documentTabSession: DocumentTabSession {
        DocumentTabSession(tabs: tabs, activeTabID: activeTabID)
    }

    func applyDocumentTabSession(_ session: DocumentTabSession) {
        tabs = session.tabs
        activeTabID = session.activeTabID
    }

    func applyWorkspaceTreeState(_ state: WorkspaceTreeSession.State) {
        nodes = state.nodes
        expandedPaths = state.expandedPaths
        isRootCollapsed = state.isRootCollapsed
        treeScrollOffset = state.treeScrollOffset
        showSelectedFilesOnly = state.showSelectedFilesOnly
        showHiddenFiles = state.showHiddenFiles
        isScanningTree = state.isScanning
        isFilteringTree = state.isFiltering
    }

    func closeActiveTab() {
        guard let activeTab else { return }
        closeTab(activeTab)
    }

    func moveTab(id: String, before targetID: String) {
        var session = documentTabSession
        guard session.move(id, before: targetID) else { return }
        reorderTabs(using: session)
    }

    func moveTabToEnd(id: String) {
        var session = documentTabSession
        guard session.moveToEnd(id) else { return }
        reorderTabs(using: session)
    }

    func reorderTabs(ids: [String]) {
        var session = documentTabSession
        guard session.reorder(ids: ids) else { return }
        reorderTabs(using: session)
    }

    private func reorderTabs(using session: DocumentTabSession) {
        applyDocumentTabSession(session)
        persistState()
    }

    func closeOtherTabs(keeping tab: DocumentTab) {
        requestBatchClose(tabs.filter { $0.id != tab.id })
    }

    func closeTabsToRight(of tab: DocumentTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        requestBatchClose(Array(tabs.dropFirst(index + 1)))
    }

    private func requestBatchClose(_ tabsToClose: [DocumentTab]) {
        guard !tabsToClose.isEmpty else { return }
        let ids = Set(tabsToClose.map(\.id))
        if let unsavedTab = tabsToClose.first(where: hasUnsavedChanges(in:)) {
            pendingBatchCloseIDs = ids
            presentPendingClose(for: unsavedTab, closesTab: true)
            return
        }
        closeTabsImmediately(ids)
    }

    func continuePendingBatchClose() {
        guard !pendingBatchCloseIDs.isEmpty else { return }
        let batchTabs = tabs.filter { pendingBatchCloseIDs.contains($0.id) }
        if let unsavedTab = batchTabs.first(where: hasUnsavedChanges(in:)) {
            presentPendingClose(for: unsavedTab, closesTab: true)
        } else {
            let ids = pendingBatchCloseIDs
            pendingBatchCloseIDs.removeAll()
            closeTabsImmediately(ids)
        }
    }

    func closeTabsImmediately(_ ids: Set<String>) {
        let closingTabs = tabs.filter { ids.contains($0.id) }
        guard !closingTabs.isEmpty else { return }
        let wasActive = activeTabID.map(ids.contains) == true
        documentRenderCoordinator.cancel(tabIDs: closingTabs.map(\.id))
        var session = documentTabSession
        for tab in closingTabs {
            _ = session.close(id: tab.id)
        }
        applyDocumentTabSession(session)
        if wasActive {
            syncPreviewZoomToActiveTab()
            renderActiveTabIfNeeded()
        }
        persistState()
    }

    func refreshActiveTab() {
        guard let activeTabID else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshEditingSource(tabID: activeTabID)
            self.refreshTab(tabID: activeTabID)
            self.persistState()
        }
    }

    private func refreshEditingSource(tabID: String) async {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        switch tab.kind {
        case .markdown where tab.markdownEditSession?.isEditing == true:
            await handleExternalMarkdownChange(tabID: tabID)
        case .json where tab.jsonEditSession?.isEditing == true:
            await handleExternalJSONChange(tabID: tabID)
        case .latex where tab.latexEditSession?.isEditing == true:
            await handleExternalLatexChange(tabID: tabID)
        default:
            break
        }
    }

    func refreshTab(tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        if tab.kind == .markdown {
            renderMarkdown(tabID: tabID)
        } else if tab.kind == .latex {
            renderLatex(tabID: tabID, force: true)
        } else if tab.kind == .json {
            renderJSON(tabID: tabID)
        } else if tab.kind == .csv {
            renderCSV(tabID: tabID)
        } else if tab.kind == .pdf {
            renderPDF(tabID: tabID)
        } else if tab.kind == .image {
            renderImage(tabID: tabID)
        } else if tab.kind == .docx {
            refreshDocx(tabID: tabID)
        } else if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[index].status = .unavailable
            tabs[index].errorMessage = nil
        }
    }

    func selectTab(number: Int) {
        guard tabs.indices.contains(number) else { return }
        selectTab(id: tabs[number].id)
    }

    func selectNextTab() {
        var session = documentTabSession
        guard session.selectNext() else { return }
        hideFindBar()
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        persistState()
    }

    func selectTab(id: String) {
        var session = documentTabSession
        guard session.select(id: id) else { return }
        hideFindBar()
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        persistState()
    }

}
