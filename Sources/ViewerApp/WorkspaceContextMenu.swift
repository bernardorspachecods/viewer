import ViewerCore
import SwiftUI

enum WorkspaceContextMenuOption: Hashable {
    case copyPath
    /// Tabs only: selects the file in the workspace sidebar.
    case revealInSidebar
    case revealInFinder
    case reload
    case rename
    case duplicate
    case moveToTrash
    case closeTab
    case closeOtherTabs
}

enum WorkspaceContextMenuOptions {
    static func forFile(isDirectory: Bool) -> [WorkspaceContextMenuOption] {
        var options: [WorkspaceContextMenuOption] = [
            .copyPath,
            .revealInFinder
        ]
        if !isDirectory {
            options.append(.reload)
        }
        options.append(.rename)
        if !isDirectory {
            options.append(.duplicate)
        }
        options.append(.moveToTrash)
        return options
    }

    static func forTab(isUntitled: Bool) -> [WorkspaceContextMenuOption] {
        guard !isUntitled else {
            return [.closeTab, .closeOtherTabs]
        }
        // The sidebar's own menu already sits on the file, so only tabs offer reveal in sidebar.
        let fileOptions = forFile(isDirectory: false)
        return [.copyPath, .revealInSidebar] + fileOptions.dropFirst() + [.closeTab, .closeOtherTabs]
    }
}

enum WorkspaceContextMenuTarget {
    case tab(DocumentTab)
    case file(FileNode)

    var url: URL {
        switch self {
        case .tab(let tab): tab.url
        case .file(let node): node.url
        }
    }

    var isDirectory: Bool {
        switch self {
        case .tab: false
        case .file(let node): node.isDirectory
        }
    }
}

struct WorkspaceContextMenuModifier: ViewModifier {
    @EnvironmentObject private var model: AppModel
    let target: WorkspaceContextMenuTarget

    func body(content: Content) -> some View {
        content.contextMenu {
            menu
        }
    }

    @ViewBuilder
    private var menu: some View {
        switch target {
        case .tab(let tab):
            if !tab.isUntitled {
                fileActions
                Divider()
            }
            if model.activeTabID != tab.id {
                Button {
                    model.enterSplit(dropping: tab.id, on: .trailing)
                } label: {
                    Label("Open in Split View", systemImage: "rectangle.split.2x1")
                }
                Divider()
            }
            Button {
                model.closeTab(tab)
            } label: {
                Label("Close Tab", systemImage: "xmark")
            }

            Button {
                model.closeOtherTabs(keeping: tab)
            } label: {
                Label("Close Other Tabs", systemImage: "rectangle.stack")
            }
        case .file:
            fileActions
        }
    }

    @ViewBuilder
    private var fileActions: some View {
        Button {
            model.copyPath(target.url)
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }

        if case .tab = target {
            Button {
                model.revealInSidebar(target.url)
            } label: {
                Label("Reveal in Sidebar", systemImage: "sidebar.left")
            }
        }

        Button {
            model.revealInFinder(target.url)
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }

        if !target.isDirectory {
            Button {
                performReload()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
        }

        Button {
            performRename()
        } label: {
            Label("Rename…", systemImage: "pencil")
        }

        if !target.isDirectory {
            Divider()
            Button {
                performDuplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .disabled(model.isPerformingFileOperation)
        }

        Divider()
        Button(role: .destructive) {
            performDelete()
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
    }

    private func performReload() {
        switch target {
        case .tab(let tab): model.reload(tab)
        case .file(let node): model.reload(node)
        }
    }

    private func performRename() {
        switch target {
        case .tab(let tab): model.rename(tab)
        case .file(let node): model.rename(node)
        }
    }

    private func performDuplicate() {
        switch target {
        case .tab(let tab): model.duplicate(tab)
        case .file(let node): model.duplicate(node)
        }
    }

    private func performDelete() {
        switch target {
        case .tab(let tab): model.delete(tab)
        case .file(let node): model.delete(node)
        }
    }
}
