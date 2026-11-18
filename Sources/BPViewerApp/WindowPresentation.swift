/// How a window presents its model. Stored on AppModel, read by the views, and
/// used by WorkspaceWindowManager to decide tabbing, frame restore, and close.
enum WindowPresentation: Equatable {
    /// A native workspace window: sidebar, folder header, and document tab bar,
    /// joined to the workspace tab group.
    case workspace
    /// A standalone window with the full chrome and no tab group. Used for a
    /// reply window that is minimized when a reply is captured.
    case standalone
    /// A standalone reader window: the document body only, with no sidebar,
    /// folder, workspace name, or tab bar.
    case reader

    var isReader: Bool {
        self == .reader
    }

    /// Standalone windows stay out of the tab group and are not restored with the workspaces.
    var isStandalone: Bool {
        self != .workspace
    }
}
