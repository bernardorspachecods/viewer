import BPViewerCore
import Foundation

extension Runner {
    /// Rules of the sidebar folder collapse button: the two-step press, the
    /// expansion it leaves behind, and when the button is shown.
    mutating func runFolderCollapseContracts() {
        let tree: Set<String> = ["a", "a/b", "a/b/c", "other", "ab"]

        expect(
            FolderCollapseRules.isInside("a/b", folder: "a")
                && !FolderCollapseRules.isInside("a", folder: "a")
                && !FolderCollapseRules.isInside("ab", folder: "a"),
            "a folder is inside its parent, not itself and not a name-prefix sibling"
        )

        expect(
            FolderCollapseRules.hasExpandedDescendant(of: "a", expandedPaths: tree),
            "a folder with expanded subfolders reports an expanded descendant"
        )
        expect(
            !FolderCollapseRules.hasExpandedDescendant(of: "ab", expandedPaths: ["a", "a/b"]),
            "a name-prefix sibling is not a descendant"
        )
        expect(
            !FolderCollapseRules.hasExpandedDescendant(of: "a", expandedPaths: ["a"]),
            "an expanded folder with no expanded subfolder has no expanded descendant"
        )

        expect(
            FolderCollapseRules.step(for: "a", expandedPaths: tree) == .collapseSubfolders,
            "the first press on a folder with open subfolders collapses the subfolders"
        )
        expect(
            FolderCollapseRules.step(for: "a", expandedPaths: ["a"]) == .collapseFolder,
            "the next press collapses the folder once nothing inside is open"
        )

        expect(
            FolderCollapseRules.expandedPaths(
                after: .collapseSubfolders,
                for: "a",
                expandedPaths: tree
            ) == ["a", "other", "ab"],
            "collapsing subfolders keeps the folder open and leaves other branches alone"
        )
        expect(
            FolderCollapseRules.expandedPaths(
                after: .collapseFolder,
                for: "a",
                expandedPaths: ["a", "other", "ab"]
            ) == ["other", "ab"],
            "collapsing the folder removes it and keeps the sibling name-prefix folder open"
        )
        expect(
            FolderCollapseRules.expandedPaths(
                after: .collapseFolder,
                for: "a",
                expandedPaths: tree
            ) == ["other", "ab"],
            "collapsing the folder removes its whole branch"
        )

        let firstPress = FolderCollapseRules.expandedPaths(
            after: FolderCollapseRules.step(for: "a", expandedPaths: tree),
            for: "a",
            expandedPaths: tree
        )
        let secondPress = FolderCollapseRules.expandedPaths(
            after: FolderCollapseRules.step(for: "a", expandedPaths: firstPress),
            for: "a",
            expandedPaths: firstPress
        )
        expect(
            firstPress == ["a", "other", "ab"] && secondPress == ["other", "ab"],
            "two presses on a folder close its subfolders, then the folder"
        )

        let nested: Set<String> = ["a", "a/b", "a/b/c"]
        expect(
            FolderCollapseRules.step(for: "a/b", expandedPaths: nested) == .collapseSubfolders
                && FolderCollapseRules.expandedPaths(
                    after: .collapseSubfolders,
                    for: "a/b",
                    expandedPaths: nested
                ) == ["a", "a/b"],
            "a nested folder applies the same first step to its own branch"
        )

        expect(
            FolderCollapseRules.helpText(for: .collapseSubfolders) == "Close subfolders"
                && FolderCollapseRules.helpText(for: .collapseFolder) == "Close folder",
            "the button tooltip names the step it will take"
        )

        let folder = FileNode(
            id: "a",
            url: URL(fileURLWithPath: "/workspace/a", isDirectory: true),
            relativePath: "a",
            isDirectory: true,
            kind: .other,
            children: [],
            childrenLoaded: false
        )
        let file = FileNode(
            id: "a/notes.md",
            url: URL(fileURLWithPath: "/workspace/a/notes.md"),
            relativePath: "a/notes.md",
            isDirectory: false,
            kind: .markdown,
            children: [],
            childrenLoaded: false
        )
        expect(
            !FolderCollapseRules.hasSubfolders([file]) && FolderCollapseRules.hasSubfolders([file, folder]),
            "a folder counts as having subfolders only when one of its children is a folder"
        )

        expect(
            FolderCollapseRules.showsButton(isDirectory: true, hasSubfolders: true, isExpanded: true),
            "an expanded folder with subfolders shows the collapse button at any depth"
        )
        expect(
            !FolderCollapseRules.showsButton(isDirectory: true, hasSubfolders: false, isExpanded: true),
            "a folder with no subfolders has no collapse button"
        )
        expect(
            !FolderCollapseRules.showsButton(isDirectory: true, hasSubfolders: true, isExpanded: false),
            "a collapsed folder has no collapse button"
        )
        expect(
            !FolderCollapseRules.showsButton(isDirectory: false, hasSubfolders: true, isExpanded: true),
            "a file never has a collapse button"
        )
    }
}
