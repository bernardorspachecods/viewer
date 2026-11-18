import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func addDefaultWorkspaceFolder(_ url: URL) {
        workspaceSession.addDefaultWorkspaceFolder(url)
        defaultWorkspaceFolders = workspaceSession.defaultWorkspaceFolderPaths
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    func removeDefaultWorkspaceFolder(path: String) {
        workspaceSession.removeDefaultWorkspaceFolder(path: path)
        defaultWorkspaceFolders = workspaceSession.defaultWorkspaceFolderPaths
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    func setLatexShellEscapeMode(_ mode: LatexShellEscapeMode) {
        guard latexShellEscapeMode != mode else { return }
        latexShellEscapeMode = mode
        persistState()
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
        if let activeTabID, activeTab?.kind == .latex {
            renderLatex(tabID: activeTabID, force: true)
        }
    }

    func applySharedPreferences(from source: AppModel) {
        theme = source.theme
        sidebarVisible = source.sidebarVisible
        sidebarWidth = source.sidebarWidth
        defaultMarkdownZoom = source.defaultMarkdownZoom
        defaultLatexZoom = source.defaultLatexZoom
        latexShellEscapeMode = source.latexShellEscapeMode
        defaultWorkspaceFolders = source.defaultWorkspaceFolders
        selectedFileKinds = source.selectedFileKinds
        workspaceTreeSession.setSelectedFileKinds(selectedFileKinds)
        applyDefaultZoom(defaultMarkdownZoom, to: .markdown)
        applyDefaultZoom(defaultLatexZoom, to: .latex)
    }

}
