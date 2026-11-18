import Foundation

/// Where a captured reply opens. `⇧⌘E` uses a standalone reader window, `⌥⌘E`
/// a tab of the workspace window in use. The raw value is the hot key id.
enum TerminalReplyDestination: UInt32, CaseIterable {
    case readerWindow = 1
    case workspaceTab = 2
}

/// What the terminal reader engine needs from the app. The engine never builds
/// a window; the app owns every workspace and reader window.
@MainActor
protocol TerminalReplyHost: AnyObject {
    /// Brings up the window that will show the reply and returns the target
    /// that receives it, or nil when no window can be shown.
    func showReplyWindow(for destination: TerminalReplyDestination) -> TerminalReplyTarget?
}

/// A window's document, ready to receive a saved reply.
@MainActor
protocol TerminalReplyTarget: AnyObject {
    /// Creates the reply document with `markdown` and saves it to `fileURL`.
    /// Returns false when saving failed; the document then stays unsaved.
    func saveReply(markdown: String, to fileURL: URL) async -> Bool
}
