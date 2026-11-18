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
