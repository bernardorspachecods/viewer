import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        WorkspaceWindowManager.shared.openWorkspace(url, from: self)
    }

    func requestRoot(_ url: URL) {
        guard rootURL != nil else {
            openRoot(url)
            let urlsToOpen = pendingOpenURLs
            pendingOpenURLs = []
            urlsToOpen.forEach { openDocument(url: $0) }
            return
        }

        pendingRootURL = url
        showingRootChangeConfirmation = true
    }

    func confirmRootChange() {
        guard let pendingRootURL else { return }
        if let tab = tabs.first(where: hasUnsavedChanges(in:)) {
            isPendingRootChange = true
            showingRootChangeConfirmation = false
            presentPendingClose(for: tab, closesTab: false)
            return
        }
        completeRootChange(to: pendingRootURL)
    }

    func completeRootChange(to rootURL: URL) {
        let urlsToOpen = pendingOpenURLs
        pendingOpenURLs = []
        openRoot(rootURL)
        self.pendingRootURL = nil
        showingRootChangeConfirmation = false
        isPendingRootChange = false
        urlsToOpen.forEach { openDocument(url: $0) }
    }

    func cancelRootChange() {
        pendingRootURL = nil
        pendingOpenURLs = []
        showingRootChangeConfirmation = false
        isPendingRootChange = false
    }

    func openRoot(_ url: URL) {
        snapshotWindowManager.closeAllPreservingRecords()
        persistState()
        documentRenderCoordinator.cancelAll()
        workspaceTreeSession.reset(rootURL: nil)
        stopWatchingActiveFiles()
        _ = workspaceSession.storeSecurityScopedBookmark(for: url)
        let accessibleRoot = (try? workspaceSession.resolveSecurityScopedBookmark(for: url))?.url ?? url
        stopSecurityScopedAccess()
        beginSecurityScopedAccess(to: accessibleRoot)
        let standardizedRoot = accessibleRoot.standardizedFileURL
        rootURL = standardizedRoot
        workspaceTreeSession.reset(rootURL: standardizedRoot)
        tabs = []
        activeTabID = nil
        restoreTabs()
        reloadTree()
        persistState()
    }

    func beginSecurityScopedAccess(to url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        activeSecurityScopedRootURL = url
    }

    func stopSecurityScopedAccess() {
        guard let activeSecurityScopedRootURL else { return }
        activeSecurityScopedRootURL.stopAccessingSecurityScopedResource()
        self.activeSecurityScopedRootURL = nil
    }

    func reloadTree() {
        workspaceTreeSession.reload()
    }

    func updateTreeQuery(_ query: String) {
        treeQuery = query
    }

    func updateShowSelectedFilesOnly(_ value: Bool) {
        workspaceTreeSession.setShowSelectedFilesOnly(value)
        persistState()
    }

    func setFileKind(_ kind: DocumentKind, selected: Bool) {
        var kinds = selectedFileKinds
        if selected {
            kinds.insert(kind)
        } else {
            kinds.remove(kind)
        }
        workspaceSession.setSelectedFileKinds(kinds)
        selectedFileKinds = workspaceSession.selectedFileKinds
        workspaceTreeSession.setSelectedFileKinds(selectedFileKinds)
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    /// Returns false when the input is invalid, already supported, or already listed.
    @discardableResult
    func addExtraFileExtension(_ raw: String) -> Bool {
        guard workspaceSession.addExtraFileExtension(raw) else { return false }
        syncExtraFileExtensions()
        return true
    }

    func removeExtraFileExtension(_ ext: String) {
        workspaceSession.removeExtraFileExtension(ext)
        syncExtraFileExtensions()
    }

    private func syncExtraFileExtensions() {
        extraFileExtensions = workspaceSession.extraFileExtensions
        workspaceTreeSession.setExtraFileExtensions(Set(extraFileExtensions))
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    func updateShowHiddenFiles(_ value: Bool) {
        workspaceTreeSession.setShowHiddenFiles(value)
        persistState()
    }

    func toggleExpanded(_ path: String) {
        workspaceTreeSession.toggleExpanded(path)
        persistState()
    }

    func pressRootCollapseButton() {
        workspaceTreeSession.pressRootButton()
        persistState()
    }

    func collapseFolder(_ node: FileNode) {
        guard node.isDirectory else { return }
        workspaceTreeSession.collapseFolder(node.id)
        persistState()
    }

    func revealInSidebar(_ url: URL) {
        guard let rootURL, isURL(url, inside: rootURL) else { return }
        treeQuery = ""
        treeRevealTargetID = relativePath(of: url, from: rootURL)
        workspaceTreeSession.reveal(url: url)
        persistState()
    }

    func clearTreeRevealTarget() {
        treeRevealTargetID = nil
    }

    func updateTreeScrollOffset(_ offset: Double) {
        workspaceTreeSession.updateScrollOffset(offset)
    }

    func updateMarkdownReadingPosition(
        _ position: MarkdownReadingPosition,
        forTabID tabID: String
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].markdownReadingPosition != position else { return }
        tabs[index].markdownReadingPosition = position
        readingPositionPersistenceTask?.cancel()
        readingPositionPersistenceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.persistState()
        }
    }

    func updatePDFReadingPosition(
        _ position: PDFReadingPosition,
        forTabID tabID: String
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let pageIndex = position.pageIndex
        let changed = tabs[index].pdfReadingPosition != position
            || tabs[index].previewPageIndex != pageIndex
        guard changed else { return }
        tabs[index].pdfReadingPosition = position
        tabs[index].previewPageIndex = pageIndex
        persistState()
    }

    func updateReadingPage(tabID: String, pageIndex: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              pageIndex >= 0 else { return }
        guard tabs[index].previewPageIndex != pageIndex else { return }
        tabs[index].previewPageIndex = pageIndex
        persistState()
    }

}
