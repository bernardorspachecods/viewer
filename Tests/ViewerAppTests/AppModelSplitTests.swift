import Testing
import Foundation
@testable import ViewerApp
@testable import ViewerCore

/// Builds a model with three tabs and isolated preferences, so split state never touches real settings.
@MainActor
private func makeSplitModel() -> (AppModel, [String]) {
    let defaults = UserDefaults(suiteName: "AppModelSplitTests-\(UUID().uuidString)")!
    let model = AppModel(
        workspaceSession: WorkspaceSessionCoordinator(store: AppStateStore(defaults: defaults)),
        restoresLastWorkspace: false,
        persistsSharedConfiguration: false
    )
    let urls = ["a", "b", "c"].map { URL(fileURLWithPath: "/tmp/viewer-split-tests/\(UUID().uuidString)-\($0).txt") }
    let tabs = urls.map { DocumentTab(id: $0.path, url: $0, kind: .other) }
    model.tabs = tabs
    model.activeTabID = tabs[0].id
    return (model, tabs.map(\.id))
}

@Test("entering a split on the trailing side focuses the dropped tab")
@MainActor
func appModelSplit_enterSplitTrailingFocusesDroppedTab() {
    let (model, ids) = makeSplitModel()

    model.enterSplit(dropping: ids[1], on: .trailing)

    #expect(model.isSplit)
    #expect(model.leadingTab?.id == ids[0])
    #expect(model.trailingTab?.id == ids[1])
    #expect(model.activeTabID == ids[1])
    #expect(model.visibleTabIDs == [ids[1], ids[0]])
}

@Test("entering a split on the leading side puts the dropped tab on the left")
@MainActor
func appModelSplit_enterSplitLeadingPlacesDroppedTabOnLeft() {
    let (model, ids) = makeSplitModel()

    model.enterSplit(dropping: ids[2], on: .leading)

    #expect(model.leadingTab?.id == ids[2])
    #expect(model.trailingTab?.id == ids[0])
    #expect(model.activeTabID == ids[2])
    #expect(model.activeSide == .leading)
}

@Test("selecting the partner swaps focus and keeps both tabs visible")
@MainActor
func appModelSplit_selectingPartnerSwapsFocus() {
    let (model, ids) = makeSplitModel()
    model.enterSplit(dropping: ids[1], on: .trailing)

    model.selectTab(id: ids[0])

    #expect(model.activeTabID == ids[0])
    #expect(model.splitPartnerID == ids[1])
    #expect(model.isSplit)
    #expect(model.leadingTab?.id == ids[0])
    #expect(model.trailingTab?.id == ids[1])
    #expect(Set(model.visibleTabIDs) == Set([ids[0], ids[1]]))
}

@Test("closing the partner tab ends the split and keeps the focused tab")
@MainActor
func appModelSplit_closingPartnerEndsSplit() {
    let (model, ids) = makeSplitModel()
    model.enterSplit(dropping: ids[1], on: .trailing)

    model.closeTabsImmediately([ids[0]])

    #expect(!model.isSplit)
    #expect(model.splitPartnerID == nil)
    #expect(model.activeTabID == ids[1])
    #expect(model.visibleTabIDs == [ids[1]])
}

@Test("closing the focused tab leaves the former partner focused and not split")
@MainActor
func appModelSplit_closingActiveLeavesPartnerFocusedNotSplit() {
    let (model, ids) = makeSplitModel()
    model.enterSplit(dropping: ids[1], on: .trailing)

    model.closeTabsImmediately([ids[1]])

    #expect(model.activeTabID == ids[0])
    #expect(!model.isSplit)
    #expect(model.splitPartnerID == nil)
}

@Test("closing the split keeps the focused tab and removes the partner")
@MainActor
func appModelSplit_closeSplitKeepsActiveTab() {
    let (model, ids) = makeSplitModel()
    model.enterSplit(dropping: ids[1], on: .trailing)

    model.closeSplit()

    #expect(!model.isSplit)
    #expect(model.activeTabID == ids[1])
    #expect(model.tabs.count == 3)
    #expect(model.visibleTabIDs == [ids[1]])
}

@Test("a model that is not split shows only the focused tab")
@MainActor
func appModelSplit_unsplitModelShowsOnlyActiveTab() {
    let (model, ids) = makeSplitModel()

    #expect(model.visibleTabIDs == [ids[0]])
    #expect(model.trailingTab == nil)
    model.closeSplit()
    #expect(model.activeTabID == ids[0])
    #expect(!model.isSplit)
}
