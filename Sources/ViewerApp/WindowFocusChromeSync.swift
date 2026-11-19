import AppKit

/// Applies focus mode to one window's native chrome: the title bar of this window,
/// and the tab strip of its tab group.
///
/// The decisions are in `FocusWindowChromePlan`; this type only reads and writes
/// AppKit. The tab strip belongs to the whole tab group, so it is re-synced when
/// any window of the group becomes key, using that window's own focus state.
@MainActor
final class WindowFocusChromeSync {
    private weak var window: NSWindow?
    private weak var model: AppModel?
    private var observers: [NSObjectProtocol] = []
    private var rememberedTitleBar: WindowTitleBarState?

    init(window: NSWindow, model: AppModel) {
        self.window = window
        self.model = model

        observe(NSWindow.didBecomeKeyNotification, for: window) { sync in
            sync.reconcile()
        }
        observe(NSWindow.willCloseNotification, for: window) { sync in
            sync.stop()
        }
        reconcile()
    }

    /// Applies the window's current focus state. Called when focus mode changes and
    /// when the window becomes key.
    func reconcile() {
        guard let window, let model else { return }
        let wantsFocus = model.isFocusMode

        let step = FocusWindowChromePlan.titleBar(
            wantsFocus: wantsFocus,
            current: Self.readTitleBar(window),
            remembered: rememberedTitleBar
        )
        if let state = step.apply {
            Self.writeTitleBar(state, to: window)
        }
        rememberedTitleBar = step.remembered
        // Changing the style mask rebuilds the title bar and can bring the tab strip
        // back, so the strip is set after it, and checked again on the next turn.
        syncTabBar()
        DispatchQueue.main.async { [weak self] in self?.syncTabBar() }
    }

    /// The native tab strip is a title bar accessory the system adds to each window of a
    /// tab group, so hiding it per window works where `toggleTabBar` did nothing (the
    /// strip stayed, even with the window key). The app adds no accessories of its own.
    private func syncTabBar() {
        guard let window, let model else { return }
        let hidesStrip = FocusWindowChromePlan.tabBarVisibility(
            wantsFocus: model.isFocusMode,
            tabCount: window.tabGroup?.windows.count ?? 1,
            isVisible: true
        ) != nil
        for accessory in window.titlebarAccessoryViewControllers where accessory.isHidden != hidesStrip {
            accessory.isHidden = hidesStrip
        }
    }

    /// Removes the observers. Called when the window closes and when the model
    /// attaches to another window.
    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private static func readTitleBar(_ window: NSWindow) -> WindowTitleBarState {
        WindowTitleBarState(
            titleHidden: window.titleVisibility == .hidden,
            titlebarTransparent: window.titlebarAppearsTransparent,
            hasFullSizeContent: window.styleMask.contains(.fullSizeContentView),
            windowButtonsHidden: window.standardWindowButton(.closeButton)?.isHidden ?? false,
            movableByBackground: window.isMovableByWindowBackground
        )
    }

    private static func writeTitleBar(_ state: WindowTitleBarState, to window: NSWindow) {
        window.titleVisibility = state.titleHidden ? .hidden : .visible
        window.titlebarAppearsTransparent = state.titlebarTransparent
        if state.hasFullSizeContent {
            window.styleMask.insert(.fullSizeContentView)
        } else {
            window.styleMask.remove(.fullSizeContentView)
        }
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = state.windowButtonsHidden
        }
        window.isMovableByWindowBackground = state.movableByBackground
    }

    private func observe(
        _ name: Notification.Name,
        for window: NSWindow,
        _ handle: @escaping @MainActor (WindowFocusChromeSync) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handle(self)
            }
        }
        observers.append(observer)
    }
}
