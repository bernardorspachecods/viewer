import Testing
import Foundation
@testable import ViewerCore

private func splitTestTab(_ name: String) -> DocumentTab {
    DocumentTab(id: name, url: URL(fileURLWithPath: "/tmp/viewer-split-\(name).md"), kind: .markdown)
}

@Test("a session that is not split shows only the active tab in the leading pane")
func unsplitSessionShowsActiveTabOnly() {
    let session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "b")

    #expect(session.isSplit == false)
    #expect(session.splitPartnerID == nil)
    #expect(session.leadingTabID == "b")
    #expect(session.trailingTabID == nil)
}

@Test("enterSplit from one pane puts the dropped tab on the trailing side")
func enterSplitOnTrailingSide() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")

    let entered = session.enterSplit(dropping: "b", on: .trailing)

    #expect(entered)
    #expect(session.leadingTabID == "a")
    #expect(session.trailingTabID == "b")
    #expect(session.activeTabID == "b")
    #expect(session.activeSide == .trailing)
    #expect(session.splitPartnerID == "a")
}

@Test("enterSplit from one pane puts the dropped tab on the leading side")
func enterSplitOnLeadingSide() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")

    let entered = session.enterSplit(dropping: "b", on: .leading)

    #expect(entered)
    #expect(session.leadingTabID == "b")
    #expect(session.trailingTabID == "a")
    #expect(session.activeTabID == "b")
    #expect(session.activeSide == .leading)
    #expect(session.splitPartnerID == "a")
}

@Test("enterSplit with the active tab does nothing")
func enterSplitWithActiveTabReturnsFalse() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")

    let entered = session.enterSplit(dropping: "a", on: .trailing)

    #expect(entered == false)
    #expect(session.isSplit == false)
    #expect(session.activeTabID == "a")
}

@Test("enterSplit while split replaces the tab on the dropped side")
func enterSplitWhileSplitReplacesPane() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b"), splitTestTab("c")], activeTabID: "a")
    let first = session.enterSplit(dropping: "b", on: .trailing)
    #expect(first)

    let second = session.enterSplit(dropping: "c", on: .trailing)

    #expect(second)
    #expect(session.leadingTabID == "a")
    #expect(session.trailingTabID == "c")
    #expect(session.activeTabID == "c")
    #expect(session.splitPartnerID == "a")
}

@Test("enterSplit with the other pane's tab swaps the panes")
func enterSplitWithOtherPaneTabSwaps() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")
    let first = session.enterSplit(dropping: "b", on: .trailing)
    #expect(first)

    let swapped = session.enterSplit(dropping: "b", on: .leading)

    #expect(swapped)
    #expect(session.leadingTabID == "b")
    #expect(session.trailingTabID == "a")
    #expect(session.activeTabID == "b")
    #expect(session.activeSide == .leading)
    #expect(session.splitPartnerID == "a")
}

@Test("selecting the partner swaps focus and flips the active side")
func selectPartnerSwapsFocus() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)

    let selected = session.select(id: "a")

    #expect(selected)
    #expect(session.activeTabID == "a")
    #expect(session.activeSide == .leading)
    #expect(session.splitPartnerID == "b")
    #expect(session.leadingTabID == "a")
    #expect(session.trailingTabID == "b")
}

@Test("selecting another tab while split replaces only the focused pane")
func selectOtherTabReplacesFocusedPane() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b"), splitTestTab("c")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)

    let selected = session.select(id: "c")

    #expect(selected)
    #expect(session.activeTabID == "c")
    #expect(session.activeSide == .trailing)
    #expect(session.splitPartnerID == "a")
    #expect(session.leadingTabID == "a")
    #expect(session.trailingTabID == "c")
}

@Test("opening the partner's file while split swaps focus to it")
func openPartnerFileSwapsFocus() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)

    let opened = session.open(splitTestTab("a"))

    #expect(opened == false)
    #expect(session.activeTabID == "a")
    #expect(session.activeSide == .leading)
    #expect(session.splitPartnerID == "b")
}

@Test("selectNext skips the partner tab while split")
func selectNextSkipsPartner() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b"), splitTestTab("c")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)
    _ = session.select(id: "a")

    let moved = session.selectNext()

    #expect(moved)
    #expect(session.activeTabID == "c")
    #expect(session.splitPartnerID == "b")
}

@Test("selectNext does nothing while split when only the pair exists")
func selectNextDoesNothingWithOnlyThePair() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)
    _ = session.select(id: "a")

    let moved = session.selectNext()

    #expect(moved == false)
    #expect(session.activeTabID == "a")
    #expect(session.splitPartnerID == "b")
}

@Test("closing the partner ends the split and keeps the active tab")
func closingPartnerEndsSplit() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)

    let closed = session.close(id: "a")

    #expect(closed)
    #expect(session.isSplit == false)
    #expect(session.activeTabID == "b")
}

@Test("closing the active tab makes the partner active and ends the split")
func closingActiveTabPromotesPartner() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b"), splitTestTab("c")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)

    let closed = session.close(id: "b")

    #expect(closed)
    #expect(session.activeTabID == "a")
    #expect(session.splitPartnerID == nil)
    #expect(session.isSplit == false)
    #expect(session.tabs.map(\.id) == ["a", "c"])
}

@Test("closeOthers clears the split")
func closeOthersClearsSplit() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b"), splitTestTab("c")], activeTabID: "a")
    let entered = session.enterSplit(dropping: "b", on: .trailing)
    #expect(entered)

    let closed = session.closeOthers(keeping: "a")

    #expect(closed)
    #expect(session.isSplit == false)
    #expect(session.splitPartnerID == nil)
    #expect(session.tabs.map(\.id) == ["a"])
}

@Test("init drops a partner that is unknown or equal to the active tab")
func initDropsInvalidPartner() {
    let unknown = DocumentTabSession(
        tabs: [splitTestTab("a"), splitTestTab("b")],
        activeTabID: "a",
        splitPartnerID: "missing"
    )
    let sameAsActive = DocumentTabSession(
        tabs: [splitTestTab("a"), splitTestTab("b")],
        activeTabID: "a",
        splitPartnerID: "a"
    )
    let valid = DocumentTabSession(
        tabs: [splitTestTab("a"), splitTestTab("b")],
        activeTabID: "a",
        splitPartnerID: "b",
        activeSide: .trailing
    )

    #expect(unknown.splitPartnerID == nil)
    #expect(sameAsActive.splitPartnerID == nil)
    #expect(valid.splitPartnerID == "b")
    #expect(valid.trailingTabID == "a")
}

@Test("unsplit select, close and selectNext behave as before")
func unsplitSelectCloseAndNextUnchanged() {
    var session = DocumentTabSession(tabs: [splitTestTab("a"), splitTestTab("b"), splitTestTab("c")], activeTabID: "a")

    let selectedC = session.select(id: "c")
    let selectedMissing = session.select(id: "zzz")
    let movedNext = session.selectNext()
    #expect(selectedC)
    #expect(selectedMissing == false)
    #expect(movedNext)
    #expect(session.activeTabID == "a")
    let closedA = session.close(id: "a")
    #expect(closedA)
    #expect(session.activeTabID == "b")
    #expect(session.isSplit == false)
}
