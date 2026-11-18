import Foundation

/// Pure rules of the sidebar's folder collapse button. Paths are the
/// workspace-relative ids of `FileNode`, joined with "/".
///
/// Pressing a folder's button takes one step:
/// - while the folder holds an expanded subfolder, the step collapses every
///   expanded folder inside it and keeps the folder open;
/// - otherwise the step collapses the folder itself with its branch.
public enum FolderCollapseRules {
    public enum Step: Equatable, Sendable {
        case collapseSubfolders
        case collapseFolder
    }

    /// True when `path` is strictly inside `folder`, not `folder` itself and
    /// not a sibling that only shares the name prefix.
    public static func isInside(_ path: String, folder: String) -> Bool {
        path.hasPrefix(folder + "/")
    }

    public static func hasExpandedDescendant(
        of folder: String,
        expandedPaths: Set<String>
    ) -> Bool {
        expandedPaths.contains { isInside($0, folder: folder) }
    }

    public static func step(for folder: String, expandedPaths: Set<String>) -> Step {
        hasExpandedDescendant(of: folder, expandedPaths: expandedPaths)
            ? .collapseSubfolders
            : .collapseFolder
    }

    public static func expandedPaths(
        after step: Step,
        for folder: String,
        expandedPaths: Set<String>
    ) -> Set<String> {
        switch step {
        case .collapseSubfolders:
            return expandedPaths.filter { !isInside($0, folder: folder) }
        case .collapseFolder:
            return expandedPaths.filter { $0 != folder && !isInside($0, folder: folder) }
        }
    }

    public static func hasSubfolders(_ children: [FileNode]) -> Bool {
        children.contains { $0.isDirectory }
    }

    /// The button belongs to an expanded folder that shows at least one subfolder.
    public static func showsButton(isDirectory: Bool, hasSubfolders: Bool, isExpanded: Bool) -> Bool {
        isDirectory && hasSubfolders && isExpanded
    }

    public static func helpText(for step: Step) -> String {
        switch step {
        case .collapseSubfolders: "Close subfolders"
        case .collapseFolder: "Close folder"
        }
    }
}
