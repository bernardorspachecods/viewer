import SwiftUI
import Testing
import ViewerCore
@testable import ViewerApp

@Test("shortcut display follows macOS modifier order")
func shortcutDisplay() {
    #expect(AppShortcuts.focusMode.display == "⇧⌘F")
    #expect(AppShortcuts.toggleSidebar.display == "⌥⌘B")
    #expect(AppShortcuts.nextTab.display == "⌃Tab")
    #expect(AppShortcuts.exitFocusMode.display == "Esc")
    #expect(AppShortcuts.nextPage.display == "→")
    #expect(AppShortcuts.captureReplyToReader.display == "⇧⌘E")
    #expect(AppShortcuts.captureReplyToWorkspace.display == "⌥⌘E")
}

@Test("no shortcut repeats within a section, and no section is empty")
func sectionsHaveNoDuplicates() {
    for section in AppShortcuts.sections {
        let displays = section.shortcuts.map(\.display)
        #expect(Set(displays).count == displays.count, "duplicate in \(section.title)")
        #expect(!section.shortcuts.isEmpty)
    }
}

@Test("menu shortcuts bind the catalog key and modifiers")
func menuBindingsMatchCatalog() {
    #expect(AppShortcuts.focusMode.menuKey == KeyEquivalent("F"))
    #expect(AppShortcuts.focusMode.menuModifiers == [.command, .shift])
    #expect(AppShortcuts.nextTab.menuKey == .tab)
    #expect(AppShortcuts.zoomOut.menuKey == KeyEquivalent("-"))
    #expect(AppShortcuts.closeTab.menuModifiers == [.command])
}
