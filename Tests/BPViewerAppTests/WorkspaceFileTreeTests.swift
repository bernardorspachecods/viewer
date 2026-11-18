import Testing
import Foundation
import Darwin
import AppKit
@testable import BPViewerApp
@testable import BPViewerCore

@Test("produces the normalized absolute path used by copy-path actions")
func producesNormalizedAbsolutePathForCopyActions() {
    let url = URL(fileURLWithPath: "/tmp/project/chapters/../working.md")

    #expect(FilePathCopy.string(for: url) == "/tmp/project/working.md")
}

@Test("renames, duplicates, and moves workspace items within the project root")
func performsWorkspaceFileOperationsWithinProjectRoot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("bp-viewer-file-operations-\(UUID().uuidString)", isDirectory: true)
    let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
    let destinationDirectory = root.appendingPathComponent("destination", isDirectory: true)
    let source = sourceDirectory.appendingPathComponent("notes.md")

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    try "# Notes".write(to: source, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let renamed = try WorkspaceFileOperations.rename(
        itemAt: source,
        to: "renamed.md",
        in: root
    )
    #expect(renamed.lastPathComponent == "renamed.md")
    #expect(FileManager.default.fileExists(atPath: renamed.path))

    let duplicate = try WorkspaceFileOperations.duplicate(itemAt: renamed, in: root)
    #expect(duplicate.lastPathComponent == "renamed copy.md")
    #expect(FileManager.default.fileExists(atPath: duplicate.path))

    let moved = try WorkspaceFileOperations.move(
        itemAt: duplicate,
        to: destinationDirectory,
        in: root
    )
    #expect(moved == destinationDirectory.appendingPathComponent("renamed copy.md"))
    #expect(FileManager.default.fileExists(atPath: moved.path))

    let movedToRoot = try WorkspaceFileOperations.move(
        itemAt: renamed,
        to: root,
        in: root
    )
    #expect(movedToRoot == root.appendingPathComponent("renamed.md"))
    #expect(FileManager.default.fileExists(atPath: movedToRoot.path))

    let movedFolder = try WorkspaceFileOperations.move(
        itemAt: sourceDirectory,
        to: destinationDirectory,
        in: root
    )
    #expect(movedFolder == destinationDirectory.appendingPathComponent("source", isDirectory: true))
    #expect(FileManager.default.fileExists(atPath: movedFolder.path))
}

@Test("keeps a supported file visible when its rename omits the extension")
func preservesTheExistingExtensionDuringRename() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("bp-viewer-extension-preservation-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("notes.md")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "# Notes".write(to: source, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let renamed = try WorkspaceFileOperations.rename(
        itemAt: source,
        to: "temporary",
        in: root
    )

    #expect(renamed.lastPathComponent == "temporary.md")
    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(FileManager.default.fileExists(atPath: renamed.path))
}

@Test("asks for confirmation before moving a workspace item")
@MainActor
func asksForConfirmationBeforeMovingWorkspaceItem() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("bp-viewer-move-confirmation-\(UUID().uuidString)", isDirectory: true)
    let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
    let destinationDirectory = root.appendingPathComponent("destination", isDirectory: true)
    let source = sourceDirectory.appendingPathComponent("notes.md")
    let sourceFolder = sourceDirectory.appendingPathComponent("drafts", isDirectory: true)
    let destination = destinationDirectory.appendingPathComponent("notes.md")
    let destinationFolder = destinationDirectory.appendingPathComponent("drafts", isDirectory: true)

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
    try "# Notes".write(to: source, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    let model = AppModel()
    model.rootURL = root

    #expect(model.moveFiles(at: [source, sourceFolder], to: destinationDirectory))
    #expect(model.showingFileMoveConfirmation)
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(FileManager.default.fileExists(atPath: sourceFolder.path))
    #expect(!FileManager.default.fileExists(atPath: destination.path))
    #expect(!FileManager.default.fileExists(atPath: destinationFolder.path))

    model.confirmFileMove()

    #expect(!model.showingFileMoveConfirmation)
    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: sourceFolder.path))
    #expect(FileManager.default.fileExists(atPath: destination.path))
    #expect(FileManager.default.fileExists(atPath: destinationFolder.path))
}

@Test("persists LaTeX approvals across coordinator instances")
@MainActor
func persistsLatexApprovalsAcrossCoordinatorInstances() {
    let suiteName = "bp-viewer-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let projectRoot = URL(fileURLWithPath: "/tmp/project")
    let latexRoot = projectRoot.appendingPathComponent("main.tex")
    let dependency = LatexExternalDependency(
        url: URL(fileURLWithPath: "/tmp/assets/../assets/figure.pdf"),
        sourceURL: latexRoot
    )

    WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults))
        .approveLatexExternalDependencies(
            [dependency],
            rootURL: latexRoot,
            projectRoot: projectRoot
        )

    let restored = WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults))
    let grantKey = "/tmp/project\n/tmp/project/main.tex"

    #expect(restored.approvedLatexExternalPaths(for: projectRoot)[grantKey] == ["/tmp/assets/figure.pdf"])
}

@Test("persists open workspace order and active workspace")
@MainActor
func persistsOpenWorkspaceOrderAndActiveWorkspace() {
    let suiteName = "bp-viewer-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = URL(fileURLWithPath: "/tmp/first-project")
    let second = URL(fileURLWithPath: "/tmp/second-project")
    let coordinator = WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults))

    coordinator.setOpenWorkspaces([first, second], activeRoot: second)

    let restored = WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults))
    #expect(restored.openWorkspacePaths == [first.path, second.path])
    #expect(restored.activeWorkspacePath == second.path)
    #expect(restored.lastWorkspacePath == second.path)
}

@Test("persists a security-scoped bookmark for an opened folder")
@MainActor
func persistsSecurityScopedBookmarkForOpenedFolder() throws {
    let suiteName = "bp-viewer-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("bp-viewer-bookmark-(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    let coordinator = WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults))
    #expect(coordinator.storeSecurityScopedBookmark(for: folder))

    let restored = WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults))
    let resolution = try restored.resolveSecurityScopedBookmark(for: folder)

    #expect(resolution.url.standardizedFileURL == folder.standardizedFileURL)
    #expect(!resolution.isStale)
}

@Test("flattens expanded tree branches into individually lazy rows")
func flattensExpandedTreeBranchesIntoLazyRows() {
    let folderURL = URL(fileURLWithPath: "/tmp/project/chapters", isDirectory: true)
    let fileURL = folderURL.appendingPathComponent("intro.md")
    let file = FileNode(
        id: "chapters/intro.md",
        url: fileURL,
        relativePath: "chapters/intro.md",
        isDirectory: false,
        kind: .markdown,
        children: [],
        childrenLoaded: true
    )
    let folder = FileNode(
        id: "chapters",
        url: folderURL,
        relativePath: "chapters",
        isDirectory: true,
        kind: .other,
        children: [file],
        childrenLoaded: true
    )

    let items = SidebarTreeItem.flatten(
        nodes: [folder],
        expandedPaths: [folder.id]
    )

    #expect(items.map(\.id) == ["chapters", "chapters/intro.md"])
    #expect(items.map(\.level) == [0, 1])
}

@Test("does not show a loading row before the delayed tree load threshold")
func delaysTreeLoadingRowUntilRequested() {
    let folderURL = URL(fileURLWithPath: "/tmp/project/chapters", isDirectory: true)
    let folder = FileNode(
        id: "chapters",
        url: folderURL,
        relativePath: "chapters",
        isDirectory: true,
        kind: .other,
        children: [],
        childrenLoaded: false
    )

    let immediateItems = SidebarTreeItem.flatten(
        nodes: [folder],
        expandedPaths: [folder.id]
    )
    let delayedItems = SidebarTreeItem.flatten(
        nodes: [folder],
        expandedPaths: [folder.id],
        loadingPaths: [folder.id]
    )

    #expect(immediateItems.map(\.id) == ["chapters"])
    #expect(delayedItems.map(\.id) == ["chapters", "chapters/loading"])
}

@Test("clears all folder expansion records or one folder branch")
@MainActor
func clearsFolderExpansionRecords() {
    let session = WorkspaceTreeSession(
        onStateChange: { _ in },
        onPersistenceRequested: {}
    )
    session.restore(
        expandedPaths: ["chapters", "chapters/part-one", "assets"],
        treeScrollOffset: 0,
        compatibleOnly: true,
        showHiddenFiles: false,
        automaticSingleChildExpansion: true
    )

    session.collapseFolder("chapters")
    #expect(session.snapshot.expandedPaths == ["assets"])

    session.collapseAllFolders()
    #expect(session.snapshot.expandedPaths.isEmpty)
}

@Test("expands every ancestor when revealing a workspace file")
@MainActor
func revealsWorkspaceFileByExpandingAncestors() {
    let root = URL(fileURLWithPath: "/tmp/project", isDirectory: true)
    let target = root
        .appendingPathComponent("chapters", isDirectory: true)
        .appendingPathComponent("part-one", isDirectory: true)
        .appendingPathComponent("intro.md")
    let session = WorkspaceTreeSession(
        onStateChange: { _ in },
        onPersistenceRequested: {}
    )

    session.reset(rootURL: root)
    session.reveal(url: target)

    #expect(session.snapshot.expandedPaths == ["chapters", "chapters/part-one"])
}

@Test("rejects moving a workspace item outside the project root")
func rejectsWorkspaceFileOperationsOutsideProjectRoot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("bp-viewer-file-operations-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("notes.md")
    let outside = FileManager.default.temporaryDirectory
        .appendingPathComponent("bp-viewer-outside-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try "# Notes".write(to: source, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: outside)
    }

    #expect(throws: WorkspaceFileOperationError.destinationOutsideWorkspace) {
        try WorkspaceFileOperations.move(itemAt: source, to: outside, in: root)
    }
}

@Test("relocates an open tab and its preview paths when its file moves")
func relocatesOpenDocumentTabPaths() {
    let oldURL = URL(fileURLWithPath: "/tmp/project/old/notes.md")
    let newURL = URL(fileURLWithPath: "/tmp/project/new/notes.md")
    var tab = DocumentTab(
        id: oldURL.path,
        url: oldURL,
        kind: .markdown,
        contextURL: oldURL.deletingLastPathComponent(),
        previewBaseURL: oldURL.deletingLastPathComponent(),
        previewDependencies: [oldURL.deletingLastPathComponent().appendingPathComponent("image.png")]
    )

    tab.relocate(from: oldURL.deletingLastPathComponent(), to: newURL.deletingLastPathComponent())

    #expect(tab.id == newURL.path)
    #expect(tab.url == newURL)
    #expect(tab.contextURL == newURL.deletingLastPathComponent())
    #expect(tab.previewBaseURL == newURL.deletingLastPathComponent())
    #expect(tab.previewDependencies == [newURL.deletingLastPathComponent().appendingPathComponent("image.png")])
}
