import AppKit
import ViewerCore
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

extension AppModel {
    /// The chrome this window shows. Read by RootView and the workspace surface so both
    /// apply the same focus-mode rule.
    var chromeLayout: WindowChromeLayout {
        WindowChromeLayout(
            isFocusMode: isFocusMode,
            sidebarVisible: sidebarVisible,
            isReader: presentation.isReader
        )
    }

    /// Focus mode is per window and is not stored: every launch starts with it off.
    /// It does not write `sidebarVisible`, so the saved sidebar state is untouched.
    func setFocusMode(_ isOn: Bool) {
        guard isFocusMode != isOn else { return }
        isFocusMode = isOn
        focusChrome?.reconcile()
    }

    func toggleFocusMode() {
        setFocusMode(!isFocusMode)
    }

    /// Esc route: a no-op unless focus mode is on. Called only after the editors,
    /// the find bar and the dialogs have had their chance at the key.
    func exitFocusMode() {
        setFocusMode(false)
    }
}
