import BPViewerCore
import Foundation

extension Runner {
    /// Rules of the sidebar folder collapse button: the two-step press, the
    /// expansion it leaves behind, and when the button is shown.
    mutating func runFolderCollapseContracts() {
        runFolderRootCollapseContracts()
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

    /// Rules of the workspace root's header button and its persisted flag.
    mutating func runFolderRootCollapseContracts() {
        let tree: Set<String> = ["a", "a/b"]

        expect(
            FolderCollapseRules.rootStep(isRootCollapsed: true, expandedPaths: tree) == .expandRoot
                && FolderCollapseRules.rootStep(isRootCollapsed: true, expandedPaths: []) == .expandRoot,
            "a collapsed root is shown first, whatever is expanded inside it"
        )
        expect(
            FolderCollapseRules.rootStep(isRootCollapsed: false, expandedPaths: tree) == .collapseSubfolders,
            "the first root press on a shown root with open folders closes those folders, not the root"
        )
        expect(
            FolderCollapseRules.rootStep(isRootCollapsed: false, expandedPaths: []) == .collapseRoot,
            "the next root press on a shown root with nothing open hides the root listing"
        )

        expect(
            FolderCollapseRules.expandedPaths(afterRoot: .collapseSubfolders, expandedPaths: tree).isEmpty
                && FolderCollapseRules.expandedPaths(afterRoot: .expandRoot, expandedPaths: tree) == tree
                && FolderCollapseRules.expandedPaths(afterRoot: .collapseRoot, expandedPaths: []).isEmpty,
            "closing the root's subfolders clears every expansion, while showing or hiding the root keeps them"
        )
        expect(
            FolderCollapseRules.isRootCollapsed(after: .collapseRoot)
                && !FolderCollapseRules.isRootCollapsed(after: .expandRoot)
                && !FolderCollapseRules.isRootCollapsed(after: .collapseSubfolders),
            "only the collapse-root step leaves the root listing hidden"
        )

        let firstPress = FolderCollapseRules.expandedPaths(
            afterRoot: FolderCollapseRules.rootStep(isRootCollapsed: false, expandedPaths: tree),
            expandedPaths: tree
        )
        let secondPress = FolderCollapseRules.rootStep(
            isRootCollapsed: FolderCollapseRules.isRootCollapsed(after: .collapseSubfolders),
            expandedPaths: firstPress
        )
        expect(
            firstPress.isEmpty && secondPress == .collapseRoot,
            "two root presses close the open folders, then hide the root listing"
        )

        expect(
            FolderCollapseRules.showsRootButton(isRootCollapsed: true, expandedPaths: [], hasSubfolders: false)
                && FolderCollapseRules.showsRootButton(isRootCollapsed: false, expandedPaths: [], hasSubfolders: true)
                && !FolderCollapseRules.showsRootButton(isRootCollapsed: false, expandedPaths: [], hasSubfolders: false),
            "the root button shows while the listing is hidden or has subfolders, and not for a root with no subfolders"
        )
        expect(
            FolderCollapseRules.helpText(forRoot: .expandRoot) == "Show files"
                && FolderCollapseRules.helpText(forRoot: .collapseSubfolders) == "Close all folders"
                && FolderCollapseRules.helpText(forRoot: .collapseRoot) == "Hide files",
            "the root button tooltip names the step it will take"
        )

        var collapsed = WorkspaceState()
        collapsed.isRootCollapsed = true
        let roundTrip = (try? JSONEncoder().encode(collapsed))
            .flatMap { try? JSONDecoder().decode(WorkspaceState.self, from: $0) }
        let legacy = try? JSONDecoder().decode(WorkspaceState.self, from: Data("{}".utf8))
        expect(
            roundTrip?.isRootCollapsed == true && legacy?.isRootCollapsed == false,
            "a saved hidden root listing round-trips, and saved state without the field opens with the root shown"
        )
    }
}
