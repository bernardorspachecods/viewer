import Testing
@testable import BPViewerApp

@Test("normal windows show the header, the sidebar only when its flag is on, and the tab bar outside readers")
func normalWindowChrome() {
    let workspace = WindowChromeLayout(isFocusMode: false, sidebarVisible: true, isReader: false)
    #expect(workspace == WindowChromeLayout(isFocusMode: false, sidebarVisible: true, isReader: false))
    #expect(workspace.showsHeader)
    #expect(workspace.showsSidebar)
    #expect(workspace.showsTabBar)
    #expect(!workspace.showsFocusExitButton)

    let hiddenSidebar = WindowChromeLayout(isFocusMode: false, sidebarVisible: false, isReader: false)
    #expect(hiddenSidebar.showsHeader)
    #expect(!hiddenSidebar.showsSidebar)

    let reader = WindowChromeLayout(isFocusMode: false, sidebarVisible: true, isReader: true)
    #expect(!reader.showsTabBar)
}

@Test("focus mode hides the header, the sidebar and the tab bar whatever the sidebar flag says")
func focusModeHidesChrome() {
    for sidebarVisible in [true, false] {
        for isReader in [true, false] {
            let layout = WindowChromeLayout(isFocusMode: true, sidebarVisible: sidebarVisible, isReader: isReader)
            #expect(!layout.showsHeader)
            #expect(!layout.showsSidebar)
            #expect(!layout.showsTabBar)
            #expect(layout.showsFocusExitButton)
        }
    }
}

@Test("leaving focus mode returns to the sidebar state the window had")
@MainActor
func focusModeKeepsSidebarFlag() {
    let model = AppModel(restoresLastWorkspace: false)
    model.sidebarVisible = false

    model.setFocusMode(true)
    #expect(model.isFocusMode)
    #expect(!model.chromeLayout.showsSidebar)
    #expect(!model.sidebarVisible)

    model.exitFocusMode()
    #expect(!model.isFocusMode)
    #expect(!model.chromeLayout.showsSidebar)
    #expect(model.chromeLayout.showsHeader)

    model.sidebarVisible = true
    model.toggleFocusMode()
    #expect(model.isFocusMode)
    model.toggleFocusMode()
    #expect(model.chromeLayout.showsSidebar)
}

@Test("exit from focus mode does nothing while focus mode is off")
@MainActor
func exitIsNoOpWhenOff() {
    let model = AppModel(restoresLastWorkspace: false)
    model.sidebarVisible = true

    model.exitFocusMode()

    #expect(!model.isFocusMode)
    #expect(model.sidebarVisible)
    #expect(model.chromeLayout.showsSidebar)
}
