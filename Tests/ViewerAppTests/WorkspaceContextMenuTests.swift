import Foundation
import Testing
@testable import ViewerApp

@Test("tabs offer reveal in sidebar and reveal in Finder")
func tabsOfferRevealInSidebarAndFinder() {
    let options = WorkspaceContextMenuOptions.forTab(isUntitled: false)

    #expect(options.contains(.revealInSidebar))
    #expect(options.contains(.revealInFinder))
    #expect(options.first == .copyPath)
}

@Test("sidebar file and folder menus offer only reveal in Finder")
func sidebarMenusOfferOnlyRevealInFinder() {
    for isDirectory in [false, true] {
        let options = WorkspaceContextMenuOptions.forFile(isDirectory: isDirectory)

        #expect(options.contains(.revealInFinder))
        #expect(!options.contains(.revealInSidebar))
    }
}

@Test("untitled tabs offer no file actions, so no reveal option")
func untitledTabsOfferNoRevealOption() {
    let options = WorkspaceContextMenuOptions.forTab(isUntitled: true)

    #expect(!options.contains(.revealInFinder))
    #expect(!options.contains(.revealInSidebar))
}

@Test("folder menus omit file-only actions")
func folderMenusOmitFileOnlyActions() {
    let options = WorkspaceContextMenuOptions.forFile(isDirectory: true)

    #expect(!options.contains(.reload))
    #expect(!options.contains(.duplicate))
}

@MainActor
@Test("reveal in Finder hands the standardized URL to the Finder seam")
func revealInFinderUsesFinderSeam() {
    let recorder = RecordingFinderRevealer()
    let model = AppModel()
    model.finderRevealer = recorder

    model.revealInFinder(URL(fileURLWithPath: "/tmp/project/chapters/../notes.md"))
    model.revealInFinder(URL(fileURLWithPath: "/tmp/project/docs"))

    #expect(recorder.urls.map(\.path) == ["/tmp/project/notes.md", "/tmp/project/docs"])
}

private final class RecordingFinderRevealer: FinderRevealing {
    private(set) var urls: [URL] = []

    func reveal(_ url: URL) {
        urls.append(url)
    }
}
