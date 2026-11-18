import Foundation
import Testing
@testable import BPViewerCore

@Test("file kind filter admits only the selected kinds while it is on")
func fileKindFilterAdmitsSelectedKinds() {
    let filter = FileKindFilter(showsOnlySelectedKinds: true, selectedKinds: [.markdown, .pdf])

    #expect(filter.admits(.markdown))
    #expect(filter.admits(.pdf))
    #expect(!filter.admits(.csv))
    #expect(!filter.admits(.other))
}

@Test("file kind filter admits every kind when it is off")
func fileKindFilterAdmitsEveryKindWhenOff() {
    let filter = FileKindFilter(showsOnlySelectedKinds: false, selectedKinds: [])

    for kind in DocumentKind.allCases {
        #expect(filter.admits(kind))
    }
}

@Test("default file kind selection covers every supported kind except other files")
func defaultFileKindSelectionExcludesOther() {
    let filter = FileKindFilter()

    #expect(filter.selectedKinds == Set(DocumentKind.selectableKinds))
    #expect(!filter.selectedKinds.contains(.other))
    #expect(!filter.admits(.other))
}

private func node(_ name: String) -> FileNode {
    let url = URL(fileURLWithPath: "/tmp/\(name)")
    return FileNode(
        id: name, url: url, relativePath: name, isDirectory: false,
        kind: DocumentKind(url: url), children: [], childrenLoaded: true
    )
}

@Test("extra extensions admit unsupported files only, case-insensitively")
func extraExtensionsAdmitUnsupportedFiles() {
    let filter = FileKindFilter(
        showsOnlySelectedKinds: true,
        selectedKinds: [.markdown],
        extraExtensions: ["txt"]
    )

    #expect(filter.admits(node("a.txt")))
    #expect(filter.admits(node("B.TXT")))
    #expect(!filter.admits(node("a.log")))
    #expect(filter.admits(node("a.md")))
    // A supported kind that is unchecked stays hidden even if listed as an extra extension.
    let csvListed = FileKindFilter(selectedKinds: [.markdown], extraExtensions: ["csv"])
    #expect(!csvListed.admits(node("a.csv")))
}

@Test("extension input is normalized and rejects supported or duplicate extensions")
func extensionInputRules() {
    #expect(FileExtensionInput.normalized(" .TXT ") == "txt")
    #expect(FileExtensionInput.normalized("") == nil)
    #expect(FileExtensionInput.normalized("a b") == nil)
    #expect(FileExtensionInput.adding("txt", to: []) == ["txt"])
    #expect(FileExtensionInput.adding("md", to: []) == nil)
    #expect(FileExtensionInput.adding(".TXT", to: ["txt"]) == nil)
}
