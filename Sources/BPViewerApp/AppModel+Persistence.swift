import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func persistState() {
        let configuration = persistsSharedConfiguration
            ? WorkspaceSessionConfiguration(
                theme: theme.rawValue,
                sidebarVisible: sidebarVisible,
                sidebarWidth: sidebarWidth,
                latexShellEscapeMode: latexShellEscapeMode.rawValue,
                defaultMarkdownZoom: defaultMarkdownZoom,
                defaultLatexZoom: defaultLatexZoom
            )
            : workspaceSession.configuration

        workspaceSession.persist(
            rootURL: rootURL,
            tabs: tabs,
            activeTabID: activeTabID,
            expandedPaths: expandedPaths,
            isRootCollapsed: isRootCollapsed,
            treeScrollOffset: treeScrollOffset,
            showSelectedFilesOnly: showSelectedFilesOnly,
            showHiddenFiles: showHiddenFiles,
            configuration: configuration
        )
    }

    func restoreTabs() {
        guard let rootURL else {
            tabs = []
            activeTabID = nil
            workspaceTreeSession.reset(rootURL: nil)
            return
        }

        let savedWorkspace = workspaceSession.workspaceState(for: rootURL)
        workspaceTreeSession.restore(
            expandedPaths: Set(savedWorkspace.expandedPaths),
            treeScrollOffset: savedWorkspace.treeScrollOffset,
            showSelectedFilesOnly: savedWorkspace.showSelectedFilesOnly,
            selectedFileKinds: selectedFileKinds,
            extraFileExtensions: Set(extraFileExtensions),
            showHiddenFiles: savedWorkspace.showHiddenFiles,
            automaticSingleChildExpansion: !workspaceSession.hasWorkspaceState(for: rootURL),
            isRootCollapsed: savedWorkspace.isRootCollapsed
        )
        let available = savedWorkspace.tabPaths
            .map(URL.init(fileURLWithPath:))
            .map(\.standardizedFileURL)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .compactMap { url -> DocumentTab? in
            let kind = DocumentKind(url: url)
            let documentState = workspaceSession.documentState(for: url)
            let contextURL = LatexTabContextPersistence.restore(
                forTabID: url.path,
                tabURL: url,
                kind: kind,
                from: savedWorkspace.tabContexts,
                projectRoot: rootURL
            )
            return DocumentTab(
                id: url.path,
                url: url,
                kind: kind,
                contextURL: contextURL,
                status: kind == .docx ? .ready : (documentOpenCoordinator.isPreviewable(kind) ? .idle : .unavailable),
                isOutlineVisible: documentState.outlineVisible,
                outlineWidth: documentState.outlineWidth,
                previewZoom: documentState.zoom ?? defaultZoom(for: kind),
                isPreviewZoomCustomized: documentState.zoom != nil,
                previewPageIndex: documentState.pdfReadingPosition?.pageIndex ?? 0,
                markdownReadingPosition: documentState.markdownReadingPosition,
                pdfReadingPosition: documentState.pdfReadingPosition
            )
        }
        let session = DocumentTabSession(
            tabs: available,
            activeTabID: savedWorkspace.activeTabPath
        )
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        restoreSnapshots(for: rootURL)
    }

}
