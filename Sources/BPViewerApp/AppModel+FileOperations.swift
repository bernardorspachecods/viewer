import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func open(_ node: FileNode) {
        guard !node.isDirectory else {
            toggleExpanded(node.id)
            return
        }

        openDocument(url: node.url)
    }

    func createNewMarkdownDocument(source: String = "") {
        var tab = DocumentTab.untitledMarkdown()
        tab.previewZoom = defaultZoom(for: .markdown)
        let transition = documentEditCoordinator.beginMarkdown(source: source)
        var editSession = transition.session
        editSession.saveState = .unsaved
        tab.markdownSource = source
        tab.markdownBlocks = transition.markdownBlocks
        tab.markdownEditSession = editSession

        var session = documentTabSession
        _ = session.open(tab)
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        persistState()
    }

    func createSavedMarkdownDocument(source: String, at destinationURL: URL) async -> Bool {
        createNewMarkdownDocument(source: source)
        guard let tabID = activeTabID,
              let session = tabs.first(where: { $0.id == tabID })?.markdownEditSession else {
            return false
        }
        return commitUntitledMarkdown(
            tabID: tabID,
            session: session,
            selectedURL: destinationURL,
            finishEditing: true
        )
    }

    func reload(_ node: FileNode) {
        guard !node.isDirectory else { return }
        let tabIDsBeforeOpening = Set(tabs.map(\.id))
        guard let tabID = openDocument(url: node.url) else { return }
        guard tabIDsBeforeOpening.contains(tabID) else { return }
        refreshTab(tabID: tabID)
    }

    func reload(_ tab: DocumentTab) {
        guard let node = workspaceFileNode(for: tab) else { return }
        reload(node)
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyPath(_ url: URL) {
        copyText(FilePathCopy.string(for: url))
    }

    func rename(_ node: FileNode) {
        guard let rootURL else { return }

        let alert = NSAlert()
        alert.messageText = "Rename " + node.title
        alert.informativeText = "Enter a new name for this "
            + (node.isDirectory ? "folder" : "file")
            + "."
        let nameField = NSTextField(string: node.title)
        nameField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = nameField
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = nameField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            let newURL = try WorkspaceFileOperations.rename(
                itemAt: node.url,
                to: nameField.stringValue,
                in: rootURL
            )
            relocateOpenTabs(from: node.url, to: newURL)
            if node.isDirectory {
                workspaceTreeSession.relocateExpandedPaths(
                    from: node.relativePath,
                    to: relativePath(of: newURL, from: rootURL)
                )
            }
            refreshTreeAfterFileOperation(in: [node.url.deletingLastPathComponent()])
            persistState()
        } catch {
            showFileOperationError(error)
        }
    }

    func rename(_ tab: DocumentTab) {
        guard let node = workspaceFileNode(for: tab) else { return }
        rename(node)
    }

    @discardableResult
    func moveFiles(at sourceURLs: [URL], to destinationDirectory: URL) -> Bool {
        guard rootURL != nil,
              !sourceURLs.isEmpty,
              !showingFileMoveConfirmation else { return false }

        pendingFileMoveRequest = PendingFileMoveRequest(
            id: UUID().uuidString,
            sourceURLs: sourceURLs.map { $0.standardizedFileURL },
            destinationDirectory: destinationDirectory.standardizedFileURL
        )
        showingFileMoveConfirmation = true
        return true
    }

    @discardableResult
    func moveFile(at sourceURL: URL, to destinationDirectory: URL) -> Bool {
        moveFiles(at: [sourceURL], to: destinationDirectory)
    }

    var pendingFileMoveTitle: String {
        guard let request = pendingFileMoveRequest else { return "Move Item?" }
        if request.sourceURLs.count == 1,
           let title = request.itemTitles.first {
            return "Move \(title)?"
        }
        return "Move \(request.sourceURLs.count) items?"
    }

    var pendingFileMoveMessage: String {
        guard let request = pendingFileMoveRequest else { return "" }
        let destination = request.destinationDirectory.lastPathComponent
        if request.sourceURLs.count == 1,
           let title = request.itemTitles.first {
            return "\(title) will be moved to \(destination)."
        }
        let titles = request.itemTitles.joined(separator: ", ")
        return "\(titles) will be moved to \(destination)."
    }

    func cancelFileMove() {
        pendingFileMoveRequest = nil
        showingFileMoveConfirmation = false
    }

    func confirmFileMove() {
        guard let request = pendingFileMoveRequest,
              let rootURL else {
            cancelFileMove()
            return
        }

        pendingFileMoveRequest = nil
        showingFileMoveConfirmation = false

        var affectedDirectories = Set<URL>()
        var movedAny = false
        for sourceURL in request.sourceURLs {
            let sourceIsDirectory = isDirectory(sourceURL)
            do {
                let newURL = try WorkspaceFileOperations.move(
                    itemAt: sourceURL,
                    to: request.destinationDirectory,
                    in: rootURL
                )
                relocateOpenTabs(from: sourceURL, to: newURL)
                if sourceIsDirectory {
                    workspaceTreeSession.relocateExpandedPaths(
                        from: relativePath(of: sourceURL, from: rootURL),
                        to: relativePath(of: newURL, from: rootURL)
                    )
                }
                affectedDirectories.insert(sourceURL.deletingLastPathComponent())
                affectedDirectories.insert(request.destinationDirectory)
                movedAny = true
            } catch {
                showFileOperationError(error)
            }
        }

        guard movedAny else { return }
        refreshTreeAfterFileOperation(in: Array(affectedDirectories))
        persistState()
    }

    func duplicate(_ node: FileNode) {
        guard !node.isDirectory,
              let rootURL,
              !isPerformingFileOperation else { return }

        let sourceURL = node.url
        isPerformingFileOperation = true
        fileOperationTask = Task { @MainActor [weak self] in
            defer {
                self?.isPerformingFileOperation = false
                self?.fileOperationTask = nil
            }

            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try WorkspaceFileOperations.duplicate(
                        itemAt: sourceURL,
                        in: rootURL
                    )
                }.value

                guard let self,
                      self.rootURL?.standardizedFileURL == rootURL.standardizedFileURL else { return }
                await Task.yield()
                self.refreshTreeAfterFileOperation(in: [sourceURL.deletingLastPathComponent()])
                self.persistState()
            } catch is CancellationError {
                return
            } catch {
                self?.showFileOperationError(error)
            }
        }
    }

    func duplicate(_ tab: DocumentTab) {
        guard let node = workspaceFileNode(for: tab) else { return }
        duplicate(node)
    }

    private func refreshTreeAfterFileOperation(in directories: [URL]) {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.workspaceTreeSession.refreshAfterFileOperation(in: directories)
            self.persistState()
        }
    }

    func delete(_ node: FileNode) {
        guard let rootURL else { return }
        let affectedTabs = tabs.filter { isURL($0.url, inside: node.url) }
        guard !affectedTabs.contains(where: hasUnsavedChanges(in:)) else {
            showFileOperationError(
                NSError(
                    domain: "BPViewer.FileOperations",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Close or save this item before moving it to the Trash."]
                )
            )
            return
        }

        let alert = NSAlert()
        alert.messageText = "Move " + node.title + " to the Trash?"
        alert.informativeText = "This " + (node.isDirectory ? "folder" : "file") + " and its contents will be moved to the Trash."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try WorkspaceFileOperations.remove(itemAt: node.url, in: rootURL)
            closeTabsImmediately(Set(affectedTabs.map(\.id)))
            refreshTreeAfterFileOperation(in: [node.url.deletingLastPathComponent()])
            persistState()
        } catch {
            showFileOperationError(error)
        }
    }

    func delete(_ tab: DocumentTab) {
        guard let node = workspaceFileNode(for: tab) else { return }
        delete(node)
    }

    private func workspaceFileNode(for tab: DocumentTab) -> FileNode? {
        guard !tab.isUntitled,
              let rootURL,
              isURL(tab.url, inside: rootURL) else { return nil }
        return FileNode(
            id: tab.url.path,
            url: tab.url,
            relativePath: relativePath(of: tab.url, from: rootURL),
            isDirectory: false,
            kind: tab.kind,
            children: [],
            childrenLoaded: true
        )
    }

    private func relocateOpenTabs(from oldURL: URL, to newURL: URL) {
        let affectedTabs = tabs.filter { isURL($0.url, inside: oldURL) }
        guard !affectedTabs.isEmpty else { return }

        documentRenderCoordinator.cancel(tabIDs: affectedTabs.map(\.id))
        var relocatedIDs: [String: String] = [:]
        for index in tabs.indices {
            let oldID = tabs[index].id
            guard isURL(tabs[index].url, inside: oldURL) else { continue }
            tabs[index].relocate(from: oldURL, to: newURL)
            tabs[index].status = .idle
            tabs[index].isStale = false
            tabs[index].errorMessage = nil
            relocatedIDs[oldID] = tabs[index].id
        }
        if let activeTabID, let relocatedActiveID = relocatedIDs[activeTabID] {
            self.activeTabID = relocatedActiveID
        }
        restartWatchingActiveFilesIfNeeded()
    }

    func restartWatchingActiveFilesIfNeeded() {
        guard let activeTabID,
              let tab = tabs.first(where: { $0.id == activeTabID }) else {
            stopWatchingActiveFiles()
            return
        }
        startWatchingActiveFiles(
            [tab.url, tab.editableSourceURL] + tab.previewDependencies + tab.previewExternalDependencies
        )
        renderActiveTabIfNeeded()
    }

    func isURL(_ url: URL, inside parent: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let parentPath = parent.standardizedFileURL.path
        return path == parentPath || path.hasPrefix(parentPath + "/")
    }

    func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath ? "." : String(path.dropFirst(rootPath.count + 1))
    }

    private func showFileOperationError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

}
