import Testing
@testable import BPViewerApp

private let plainTitleBar = WindowTitleBarState(
    titleHidden: false,
    titlebarTransparent: false,
    hasFullSizeContent: false,
    windowButtonsHidden: false,
    movableByBackground: false
)

private let customTitleBar = WindowTitleBarState(
    titleHidden: false,
    titlebarTransparent: true,
    hasFullSizeContent: true,
    windowButtonsHidden: false,
    movableByBackground: true
)

@Test("entering focus mode hides the title bar and remembers the previous state once")
func focusHidesTitleBarAndRemembersIt() {
    let first = FocusWindowChromePlan.titleBar(wantsFocus: true, current: customTitleBar, remembered: nil)
    #expect(first.apply == FocusWindowChromePlan.focusedTitleBar)
    #expect(first.remembered == customTitleBar)

    // A second focus step keeps the original remembered state, not the focused one.
    let second = FocusWindowChromePlan.titleBar(
        wantsFocus: true,
        current: FocusWindowChromePlan.focusedTitleBar,
        remembered: customTitleBar
    )
    #expect(second.apply == FocusWindowChromePlan.focusedTitleBar)
    #expect(second.remembered == customTitleBar)
}

@Test("leaving focus mode restores exactly the remembered title bar and forgets it")
func exitRestoresRememberedTitleBar() {
    let exit = FocusWindowChromePlan.titleBar(
        wantsFocus: false,
        current: FocusWindowChromePlan.focusedTitleBar,
        remembered: customTitleBar
    )
    #expect(exit.apply == customTitleBar)
    #expect(exit.remembered == nil)
}

@Test("a window that was never focused keeps its title bar untouched")
func unfocusedWindowIsLeftAlone() {
    let plain = FocusWindowChromePlan.titleBar(wantsFocus: false, current: plainTitleBar, remembered: nil)
    #expect(plain.apply == nil)
    #expect(plain.remembered == nil)
}

@Test("focused title bar keeps the window movable and hides the buttons and title")
func focusedTitleBarShape() {
    let focused = FocusWindowChromePlan.focusedTitleBar
    #expect(focused.titleHidden)
    #expect(focused.titlebarTransparent)
    #expect(focused.hasFullSizeContent)
    #expect(focused.windowButtonsHidden)
    #expect(focused.movableByBackground)
}

@Test("the tab strip hides for focus and shows again outside focus, only when it differs")
func tabBarFollowsFocusPerWindow() {
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: true, tabCount: 3, isVisible: true) == false)
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: true, tabCount: 3, isVisible: false) == nil)
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: false, tabCount: 3, isVisible: false) == true)
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: false, tabCount: 3, isVisible: true) == nil)
}

@Test("a single-tab window has no strip to change")
func singleTabHasNoTabBarChange() {
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: true, tabCount: 1, isVisible: false) == nil)
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: false, tabCount: 1, isVisible: true) == nil)
    #expect(FocusWindowChromePlan.tabBarVisibility(wantsFocus: true, tabCount: 0, isVisible: true) == nil)
}
