import BPViewerCore
import SwiftUI

extension AppShortcut {
    /// The key a menu item binds. Menu shortcuts are single characters; "Tab" is
    /// the only named key a menu binds.
    var menuKey: KeyEquivalent {
        if key == "Tab" { return .tab }
        return KeyEquivalent(key.first ?? " ")
    }

    var menuModifiers: EventModifiers {
        var result: EventModifiers = []
        if modifiers.contains(.control) { result.insert(.control) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.command) { result.insert(.command) }
        return result
    }
}

extension View {
    /// Binds a menu item to a catalog shortcut, so the menu and the Settings list read the same value.
    func appShortcut(_ shortcut: AppShortcut) -> some View {
        keyboardShortcut(shortcut.menuKey, modifiers: shortcut.menuModifiers)
    }
}
