import Foundation
import ViewerCore

/// Whether the Markdown preview and editor keep their text in a centered reading column or let
/// it run to the window edges. Stored in `UserDefaults` and read by the views, so it applies to
/// every window at once.
enum TextWidthPreference {
    static let key = "limitsTextWidth"
    /// The text runs to the window edges unless the user asks for a reading column.
    static let defaultLimitsTextWidth = false
    /// Width of the preview's reading column; the editor's is in `MarkdownLiveEditorSession`.
    static let previewColumnWidth = MarkdownStyleTokens.shared.readingWidth

    /// Runs when a preview document starts loading (and on a preference change, on the live
    /// page): the stylesheet reads `--bp-content-max` and falls back to the reading column.
    static func previewScript(limitsTextWidth: Bool) -> String {
        let root = "document.documentElement"
        return limitsTextWidth
            ? "try { \(root).style.removeProperty('--bp-content-max'); } catch (e) {}"
            : "try { \(root).style.setProperty('--bp-content-max', 'none'); } catch (e) {}"
    }
}
