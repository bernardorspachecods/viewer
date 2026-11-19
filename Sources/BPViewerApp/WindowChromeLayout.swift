/// Which window chrome is shown. Focus mode hides the header, the sidebar and the
/// tab bar, and leaves the stored sidebar flag alone, so leaving focus mode
/// brings back the sidebar state the window had before.
struct WindowChromeLayout: Equatable {
    let showsHeader: Bool
    let showsSidebar: Bool
    let showsTabBar: Bool
    /// The header is hidden in focus mode, so a small exit button stays on the content.
    let showsFocusExitButton: Bool

    init(isFocusMode: Bool, sidebarVisible: Bool, isReader: Bool) {
        showsHeader = !isFocusMode
        showsSidebar = !isFocusMode && sidebarVisible
        showsTabBar = !isFocusMode && !isReader
        showsFocusExitButton = isFocusMode
    }
}
