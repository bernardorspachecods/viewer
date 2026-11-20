import Foundation
import Testing
import ViewerCore

@Test("a fresh Cmd-W closes a tab while the window has tabs")
func freshPressClosesTab() {
    #expect(CloseShortcutAction.decide(tabCount: 2, isReader: false, isRepeat: false) == .closeTab)
}

@Test("an auto-repeated Cmd-W closes a tab while the window has tabs")
func repeatPressClosesTab() {
    #expect(CloseShortcutAction.decide(tabCount: 2, isReader: false, isRepeat: true) == .closeTab)
}

@Test("a fresh Cmd-W with no tabs left closes the window")
func freshPressWithNoTabsClosesWindow() {
    #expect(CloseShortcutAction.decide(tabCount: 0, isReader: false, isRepeat: false) == .closeWindow)
}

@Test("an auto-repeated Cmd-W with no tabs left never closes the window")
func repeatPressWithNoTabsIsIgnored() {
    #expect(CloseShortcutAction.decide(tabCount: 0, isReader: false, isRepeat: true) == .ignore)
}

@Test("a fresh Cmd-W in a reader with one tab closes the window")
func freshPressInReaderClosesWindow() {
    #expect(CloseShortcutAction.decide(tabCount: 1, isReader: true, isRepeat: false) == .closeWindow)
}

@Test("an auto-repeated Cmd-W in a reader with one tab is ignored")
func repeatPressInReaderIsIgnored() {
    #expect(CloseShortcutAction.decide(tabCount: 1, isReader: true, isRepeat: true) == .ignore)
}
