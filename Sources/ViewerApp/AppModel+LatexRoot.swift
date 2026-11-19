import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func cancelLatexRootSelection() {
        pendingLatexRootSelection = nil
    }

    func cancelLatexExternalDependencies() {
        pendingLatexExternalDependencies = nil
    }

    func chooseLatexRootFile() {
        guard let request = pendingLatexRootSelection else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = request.projectRoot
        if let texType = UTType(filenameExtension: "tex") {
            panel.allowedContentTypes = [texType]
        }
        panel.prompt = "Choose Root"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        chooseLatexRoot(url)
    }

    func approveLatexExternalDependencies() {
        guard let request = pendingLatexExternalDependencies else { return }
        workspaceSession.approveLatexExternalDependencies(
            request.dependencies,
            rootURL: request.rootURL,
            projectRoot: request.projectRoot
        )
        pendingLatexExternalDependencies = nil
        renderLatex(tabID: request.tabID, rootURL: request.rootURL)
    }

    func changeLatexRoot() {
        guard let tab = activeTab,
              tab.kind == .latex,
              let projectRoot = rootURL else {
            return
        }

        let openedFile = tab.contextURL ?? tab.url
        guard let resolution = try? LatexRootDiscovery().resolve(
            openedFile: openedFile,
            projectRoot: projectRoot
        ) else {
            return
        }

        pendingLatexRootSelection = LatexRootSelectionRequest(
            id: tab.id,
            tabID: tab.id,
            openedFile: openedFile,
            projectRoot: projectRoot,
            candidates: resolution.candidates
        )
    }

    func chooseLatexRoot(_ rootURL: URL) {
        guard let request = pendingLatexRootSelection,
              (request.candidates.isEmpty
                || request.candidates.contains(where: { $0.url.standardizedFileURL == rootURL.standardizedFileURL })),
              rootURL.pathExtension.lowercased() == "tex",
              isRegularFile(rootURL),
              isInside(rootURL, project: request.projectRoot) else {
            return
        }

        pendingLatexRootSelection = nil
        storeLatexRoot(rootURL, for: request.projectRoot)

        guard let oldIndex = tabs.firstIndex(where: { $0.id == request.tabID }) else { return }
        let contextURL = request.openedFile.standardizedFileURL == rootURL.standardizedFileURL
            ? nil
            : request.openedFile.standardizedFileURL

        if let existingIndex = tabs.firstIndex(where: {
            $0.id == rootURL.path && $0.id != request.tabID
        }) {
            tabs[existingIndex].contextURL = contextURL
            tabs.remove(at: oldIndex)
            activeTabID = rootURL.path
            syncPreviewZoomToActiveTab()
        } else {
            tabs[oldIndex] = DocumentTab(
                id: rootURL.path,
                url: rootURL.standardizedFileURL,
                kind: .latex,
                contextURL: contextURL,
                status: .updating
            )
            activeTabID = rootURL.path
            let documentState = workspaceSession.documentState(for: rootURL)
            tabs[oldIndex].isOutlineVisible = documentState.outlineVisible
            tabs[oldIndex].outlineWidth = documentState.outlineWidth
            tabs[oldIndex].previewZoom = documentState.zoom ?? defaultZoom(for: .latex)
            tabs[oldIndex].isPreviewZoomCustomized = documentState.zoom != nil
            tabs[oldIndex].previewPageIndex = documentState.pdfReadingPosition?.pageIndex ?? 0
            tabs[oldIndex].markdownReadingPosition = documentState.markdownReadingPosition
            tabs[oldIndex].pdfReadingPosition = documentState.pdfReadingPosition
            syncPreviewZoomToActiveTab()
        }

        renderLatex(tabID: rootURL.path, rootURL: rootURL, force: true)
        persistState()
    }

    func storedLatexRoot(for projectRoot: URL) -> URL? {
        guard let rootURL = workspaceSession.storedLatexRoot(for: projectRoot)?.standardizedFileURL else {
            return nil
        }
        guard isRegularFile(rootURL),
              isInside(rootURL, project: projectRoot.standardizedFileURL) else {
            return nil
        }
        return rootURL
    }

    private func storeLatexRoot(_ rootURL: URL, for projectRoot: URL) {
        workspaceSession.storeLatexRoot(rootURL, for: projectRoot)
    }

    var approvedLatexExternalPaths: [String: Set<String>] {
        guard let rootURL else { return [:] }
        return workspaceSession.approvedLatexExternalPaths(for: rootURL)
    }

}
