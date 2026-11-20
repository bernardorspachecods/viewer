/// What a Cmd+W press does in the key window. Decided from the window's state and
/// whether the key event is an auto-repeat, so holding the key closes tabs but never
/// the window.
public enum CloseShortcutAction: Equatable, Sendable {
    case closeTab
    case closeWindow
    case ignore

    /// A fresh press closes the last tab's window (a reader window counts its single
    /// tab as the last one). An auto-repeat never closes a window: it closes a tab while
    /// tabs remain and does nothing once only the window is left.
    public static func decide(tabCount: Int, isReader: Bool, isRepeat: Bool) -> CloseShortcutAction {
        let isLastTab = tabCount == 0 || (isReader && tabCount <= 1)
        if isLastTab {
            return isRepeat ? .ignore : .closeWindow
        }
        return .closeTab
    }
}
