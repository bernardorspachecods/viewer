/// The title bar properties focus mode changes, as plain values so the rule is testable.
struct WindowTitleBarState: Equatable {
    var titleHidden: Bool
    var titlebarTransparent: Bool
    var hasFullSizeContent: Bool
    var windowButtonsHidden: Bool
    var movableByBackground: Bool
}

/// Pure decisions behind focus mode's window chrome: the title bar state to apply,
/// the state to remember so exit restores it exactly, and the tab strip visibility.
enum FocusWindowChromePlan {
    /// What a window's title bar looks like in focus mode: no title, no buttons, and
    /// a transparent bar, so only the document is visible. The window stays movable
    /// by its background, so it can still be dragged.
    static let focusedTitleBar = WindowTitleBarState(
        titleHidden: true,
        titlebarTransparent: true,
        hasFullSizeContent: true,
        windowButtonsHidden: true,
        movableByBackground: true
    )

    struct TitleBarStep: Equatable {
        /// The state to write to the window, or nil when nothing changes.
        let apply: WindowTitleBarState?
        /// The state to keep for exit; nil once it has been restored.
        let remembered: WindowTitleBarState?
    }

    /// Entering focus mode remembers the window's current title bar, once. Leaving it
    /// writes that remembered state back and forgets it. A window that was never
    /// focused is left alone.
    static func titleBar(
        wantsFocus: Bool,
        current: WindowTitleBarState,
        remembered: WindowTitleBarState?
    ) -> TitleBarStep {
        if wantsFocus {
            return TitleBarStep(apply: focusedTitleBar, remembered: remembered ?? current)
        }
        guard let remembered else {
            return TitleBarStep(apply: nil, remembered: nil)
        }
        return TitleBarStep(apply: remembered, remembered: nil)
    }

    /// The tab strip is shared by the whole tab group, so it is only changed when the
    /// group has more than one tab; a single-tab window has no strip. Returns the
    /// visibility to set, or nil when it already matches.
    static func tabBarVisibility(wantsFocus: Bool, tabCount: Int, isVisible: Bool) -> Bool? {
        guard tabCount > 1 else { return nil }
        let wanted = !wantsFocus
        return wanted == isVisible ? nil : wanted
    }
}
