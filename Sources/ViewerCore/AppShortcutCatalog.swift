/// Modifier keys of an app shortcut. Display order follows macOS: ⌃⌥⇧⌘.
public struct ShortcutModifiers: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let control = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let shift = ShortcutModifiers(rawValue: 1 << 2)
    public static let command = ShortcutModifiers(rawValue: 1 << 3)

    /// The symbols in macOS menu order, for example "⇧⌘".
    public var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

/// One keyboard shortcut the app responds to. `key` is the label of the key:
/// a single character for menu shortcuts ("F", "+", "1"), or a name such as
/// "Tab", "Esc", "←" or "→" for keys handled by a view.
public struct AppShortcut: Equatable, Sendable {
    public let title: String
    public let key: String
    public let modifiers: ShortcutModifiers

    public init(title: String, key: String, modifiers: ShortcutModifiers = []) {
        self.title = title
        self.key = key
        self.modifiers = modifiers
    }

    /// The shortcut as shown in Settings, for example "⇧⌘F" or "Esc".
    public var display: String {
        modifiers.symbols + key
    }
}

/// A titled group of shortcuts, as shown in Settings.
public struct AppShortcutSection: Equatable, Sendable {
    public let title: String
    public let shortcuts: [AppShortcut]

    public init(title: String, shortcuts: [AppShortcut]) {
        self.title = title
        self.shortcuts = shortcuts
    }
}

/// Every keyboard shortcut the app responds to. The menu commands in
/// `ViewerApp.swift` bind these values, and the Shortcuts tab in Settings lists
/// them, so a shortcut is defined once. Shortcuts that other code handles
/// (the reply capture pair, the editors, the PDF arrows) are listed here as well,
/// so the list is complete.
public enum AppShortcuts {
    // File and tabs
    public static let newMarkdownFile = AppShortcut(title: "New Markdown File", key: "T", modifiers: .command)
    public static let newWorkspace = AppShortcut(title: "New Workspace…", key: "T", modifiers: [.command, .shift])
    public static let openFolder = AppShortcut(title: "Open Folder…", key: "O", modifiers: .command)
    public static let closeTab = AppShortcut(title: "Close Tab", key: "W", modifiers: .command)
    public static let nextTab = AppShortcut(title: "Next Tab", key: "Tab", modifiers: .control)
    public static let selectTab = AppShortcut(title: "Select Tab", key: "1–9", modifiers: .command)

    // View
    public static let refreshPreview = AppShortcut(title: "Refresh Preview", key: "R", modifiers: .command)
    public static let findInDocument = AppShortcut(title: "Find in Document", key: "F", modifiers: .command)
    public static let zoomIn = AppShortcut(title: "Zoom In", key: "+", modifiers: .command)
    public static let zoomOut = AppShortcut(title: "Zoom Out", key: "-", modifiers: .command)
    public static let resetZoom = AppShortcut(title: "Reset Zoom", key: "0", modifiers: .command)
    public static let toggleSidebar = AppShortcut(title: "Toggle Sidebar", key: "B", modifiers: [.command, .option])
    public static let focusMode = AppShortcut(title: "Focus Mode", key: "F", modifiers: [.command, .shift])
    public static let exitFocusMode = AppShortcut(title: "Exit Focus Mode", key: "Esc")
    public static let toggleTheme = AppShortcut(title: "Toggle Theme", key: "T", modifiers: [.command, .option])

    // PDF
    public static let nextPage = AppShortcut(title: "Next Page", key: "→")
    public static let previousPage = AppShortcut(title: "Previous Page", key: "←")

    // Markdown editing
    public static let saveEdits = AppShortcut(title: "Save Edits", key: "S", modifiers: .command)
    public static let undo = AppShortcut(title: "Undo Edit", key: "Z", modifiers: .command)
    public static let redo = AppShortcut(title: "Redo Edit", key: "Z", modifiers: [.command, .shift])
    public static let bold = AppShortcut(title: "Bold", key: "B", modifiers: .command)
    public static let italic = AppShortcut(title: "Italic", key: "I", modifiers: .command)
    public static let inlineCode = AppShortcut(title: "Inline Code", key: "K", modifiers: .command)
    public static let acceptInlineCompletion = AppShortcut(title: "Accept Inline Completion", key: "Tab")

    // Terminal reply capture (global, works in any app)
    public static let captureReplyToReader = AppShortcut(title: "Capture Reply in Reader Window", key: "E", modifiers: [.command, .shift])
    public static let captureReplyToWorkspace = AppShortcut(title: "Capture Reply in Workspace Tab", key: "E", modifiers: [.command, .option])

    // Snapshots
    public static let closeFloatingWindow = AppShortcut(title: "Close Floating Window", key: "W", modifiers: .command)
    public static let cancelSelection = AppShortcut(title: "Cancel Selection", key: "Esc")

    public static let sections: [AppShortcutSection] = [
        AppShortcutSection(title: "File and Tabs", shortcuts: [
            newMarkdownFile, newWorkspace, openFolder, closeTab, nextTab, selectTab,
        ]),
        AppShortcutSection(title: "View", shortcuts: [
            refreshPreview, findInDocument, zoomIn, zoomOut, resetZoom,
            toggleSidebar, focusMode, exitFocusMode, toggleTheme,
        ]),
        AppShortcutSection(title: "PDF", shortcuts: [nextPage, previousPage]),
        AppShortcutSection(title: "Markdown Editing", shortcuts: [
            saveEdits, undo, redo, bold, italic, inlineCode, acceptInlineCompletion,
        ]),
        AppShortcutSection(title: "Terminal Reply Capture", shortcuts: [
            captureReplyToReader, captureReplyToWorkspace,
        ]),
        AppShortcutSection(title: "Snapshots", shortcuts: [closeFloatingWindow, cancelSelection]),
    ]
}
