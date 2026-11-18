import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func setOutlineVisible(_ visible: Bool, forTabID tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].isOutlineVisible != visible else { return }
        tabs[index].isOutlineVisible = visible
        persistState()
    }

    func resizeOutline(to width: Double, forTabID tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let normalizedWidth = DocumentOutlineSizing.clamped(width)
        guard tabs[index].outlineWidth != normalizedWidth else { return }
        tabs[index].outlineWidth = normalizedWidth
    }

    func finishOutlineResize(forTabID tabID: String) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        persistState()
    }

    func setSidebarVisible(_ visible: Bool) {
        sidebarVisible = visible
        persistState()
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    func setSidebarWidth(_ width: Double) {
        sidebarWidth = min(max(width, BPTokens.Size.sidebarMin), BPTokens.Size.sidebarMax)
        persistState()
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    func resizeSidebar(to width: Double) {
        sidebarWidth = min(max(width, BPTokens.Size.sidebarMin), BPTokens.Size.sidebarMax)
    }

}
