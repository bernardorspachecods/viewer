import Foundation

/// What Viewer opens at launch, chosen in Settings > Workspaces.
public enum LaunchBehavior: String, CaseIterable, Sendable {
    /// Restore the previous session; the default list is the fallback.
    case reopenLast
    /// Ignore the previous session and open the default list.
    case alwaysDefaults
}

/// Which folders the launch opens. The home folder is the last resort.
public enum LaunchFolderSource: Equatable, Sendable {
    /// Reopen the workspaces of the previous session.
    case previousSession
    /// Open these folders, in order: the first in the initial window, the rest as tabs.
    case defaultFolders([String])
    /// Open the home folder, because no default folder can be used.
    case homeFolder
}

/// Pure launch rules, kept apart from windows and persistence so they can be
/// checked without UserDefaults or AppKit. Both path lists must already hold
/// only folders that exist.
public enum LaunchFolderPlanner {
    public static func source(
        behavior: LaunchBehavior,
        existingSessionPaths: [String],
        existingDefaultPaths: [String]
    ) -> LaunchFolderSource {
        let defaults: LaunchFolderSource = existingDefaultPaths.isEmpty
            ? .homeFolder
            : .defaultFolders(existingDefaultPaths)
        switch behavior {
        case .alwaysDefaults:
            return defaults
        case .reopenLast:
            return existingSessionPaths.isEmpty ? defaults : .previousSession
        }
    }
}
