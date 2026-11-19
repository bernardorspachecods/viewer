import Foundation
import Testing
@testable import ViewerApp
@testable import ViewerCore

@Suite("Document split drop zone")
struct DocumentSplitDropZoneTests {
    @Test func leftHalfDropsToLeadingPane() {
        #expect(DocumentSplitDropZone.side(forX: 100, width: 800) == .leading)
    }

    @Test func rightHalfDropsToTrailingPane() {
        #expect(DocumentSplitDropZone.side(forX: 600, width: 800) == .trailing)
    }

    @Test func exactMiddleDropsToTrailingPane() {
        #expect(DocumentSplitDropZone.side(forX: 400, width: 800) == .trailing)
    }

    @Test func zeroWidthDropsToTrailingPane() {
        #expect(DocumentSplitDropZone.side(forX: 0, width: 0) == .trailing)
    }
}

@Suite("Tab drag payload")
struct TabDragItemTests {
    @Test func jsonRoundTripKeepsTabID() throws {
        let original = TabDragItem(tabID: "/notes/plan.md")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TabDragItem.self, from: data)
        #expect(decoded.tabID == "/notes/plan.md")
    }
}

@Test("the outline keeps its width in a wide pane and takes at most 40% of a narrow one")
func outlineWidthInNarrowPane() {
    #expect(DocumentOutlineSizing.displayed(preferred: 250, paneWidth: nil) == 250)
    #expect(DocumentOutlineSizing.displayed(preferred: 250, paneWidth: 1000) == 250)
    #expect(DocumentOutlineSizing.displayed(preferred: 250, paneWidth: 460) == 184)
    // Never thinner than the floor of a narrow pane; the usual minimum still applies without one.
    #expect(DocumentOutlineSizing.displayed(preferred: 250, paneWidth: 200) == 140)
    #expect(DocumentOutlineSizing.displayed(preferred: 100, paneWidth: nil) == 220)
}
