import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func openExternalURLs(_ urls: [URL]) {
        let files = urls
            .filter(\.isFileURL)
            .map { $0.resolvingSymlinksInPath().standardizedFileURL }
            .filter {
                documentOpenCoordinator.isPreviewable(DocumentKind(url: $0))
            }
        guard let first = files.first else { return }

        let desiredRoot = DocumentKind(url: first) == .latex
            ? documentOpenCoordinator.inferredLatexProjectRoot(for: first)
            : first.deletingLastPathComponent()
        let currentRoot = rootURL?.resolvingSymlinksInPath().standardizedFileURL
        let sameRoot = currentRoot?.path == desiredRoot.resolvingSymlinksInPath().standardizedFileURL.path

        if rootURL == nil {
            openRoot(desiredRoot)
            files.forEach { openDocument(url: $0) }
        } else if sameRoot {
            files.forEach { openDocument(url: $0) }
        } else {
            WorkspaceWindowManager.shared.openWorkspace(desiredRoot, opening: files, from: self)
        }
    }

    func openDroppedURLs(_ urls: [URL]) {
        let resolvedURLs = urls.map { $0.resolvingSymlinksInPath().standardizedFileURL }
        if let directory = resolvedURLs.first(where: { isDirectory($0) }) {
            WorkspaceWindowManager.shared.openWorkspace(directory, from: self)
            return
        }
        openExternalURLs(resolvedURLs)
    }

    func openPreviewURL(_ url: URL) {
        if let localFileURL = MarkdownPreviewLink.fileURL(from: url) {
            openPreviewURL(localFileURL)
            return
        }

        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            NSWorkspace.shared.open(url)
            return
        }

        guard url.isFileURL else {
            NSWorkspace.shared.open(url)
            return
        }

        let standardizedURL = url.resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: standardizedURL.path) else {
            return
        }

        guard let result = documentOpenCoordinator.resolve(
            standardizedURL,
            workspaceRoot: rootURL,
            storedLatexRoot: rootURL.flatMap { workspaceSession.storedLatexRoot(for: $0) }
        ) else { return }
        switch result {
        case let .external(externalURL):
            NSWorkspace.shared.open(externalURL)
        case .preview:
            openDocument(url: standardizedURL)
        }
    }

    @discardableResult
    func openDocument(url: URL) -> String? {
        guard let result = documentOpenCoordinator.resolve(
            url,
            workspaceRoot: rootURL,
            storedLatexRoot: rootURL.flatMap { workspaceSession.storedLatexRoot(for: $0) }
        ) else { return nil }
        guard case let .preview(documentURL, kind, contextURL) = result else {
            if case let .external(externalURL) = result {
                NSWorkspace.shared.open(externalURL)
            }
            return nil
        }

        let id = documentURL.path
        var session = documentTabSession
        if let existingTab = session.tabs.first(where: { $0.id == id }) {
            _ = session.select(id: existingTab.id)
            let sourceURL = contextURL ?? documentURL
            let isBibliography = sourceURL.pathExtension.lowercased() == "bib"
            let isNewSource = sourceURL.standardizedFileURL
                != existingTab.editableSourceURL.standardizedFileURL
            if existingTab.kind == .latex,
               isNewSource || (isBibliography && existingTab.latexEditSession?.isEditing != true) {
                if !hasUnsavedChanges(in: existingTab),
                   let source = try? String(contentsOf: sourceURL, encoding: .utf8) {
                    _ = session.update(id: id) { tab in
                        let previousMode = tab.latexEditSession?.mode
                        tab.contextURL = contextURL
                        if previousMode != nil || isBibliography {
                            var editSession = documentEditCoordinator.beginLatex(source: source).session
                            editSession.mode = previousMode ?? .markdown
                            tab.latexEditSession = editSession
                            tab.latexCursorUTF8Offset = nil
                            tab.diffSession = nil
                        }
                    }
                }
            }
            applyDocumentTabSession(session)
            syncPreviewZoomToActiveTab()
            renderActiveTabIfNeeded()
            persistState()
            return id
        }

        let documentState = workspaceSession.documentState(for: documentURL)
        var tab = DocumentTab(
            id: id,
            url: documentURL,
            kind: kind,
            contextURL: contextURL,
            status: kind == .docx ? .ready : .updating,
            isOutlineVisible: documentState.outlineVisible,
            outlineWidth: documentState.outlineWidth,
            previewZoom: documentState.zoom ?? defaultZoom(for: kind),
            isPreviewZoomCustomized: documentState.zoom != nil,
            previewPageIndex: documentState.pdfReadingPosition?.pageIndex ?? 0,
            markdownReadingPosition: documentState.markdownReadingPosition,
            pdfReadingPosition: documentState.pdfReadingPosition
        )
        if kind == .latex,
           let contextURL,
           contextURL.pathExtension.lowercased() == "bib",
           let source = try? String(contentsOf: contextURL, encoding: .utf8) {
            tab.latexEditSession = documentEditCoordinator.beginLatex(source: source).session
        }

        _ = session.open(tab)
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        persistState()
        return id
    }

}
