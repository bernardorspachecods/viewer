import Foundation
import ViewerCore

extension AppModel {
    var isSplit: Bool { splitPartnerID != nil }

    var leadingTab: DocumentTab? {
        guard let id = documentTabSession.leadingTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    /// The tab in the trailing pane. nil when not split.
    var trailingTab: DocumentTab? {
        guard let id = documentTabSession.trailingTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    /// The tabs currently shown: the focused tab, plus the partner while split.
    var visibleTabIDs: [String] {
        [activeTabID, splitPartnerID].compactMap { $0 }
    }

    /// Drops a tab into one pane of a split, making it the focused tab.
    func enterSplit(dropping tabID: String, on side: DocumentSplitSide) {
        var session = documentTabSession
        guard session.enterSplit(dropping: tabID, on: side) else { return }
        hideFindBar()
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        persistState()
    }

    func closeSplit() {
        guard isSplit else { return }
        var session = documentTabSession
        session.closeSplit()
        hideFindBar()
        applyDocumentTabSession(session)
        syncPreviewZoomToActiveTab()
        renderActiveTabIfNeeded()
        persistState()
    }

    func startWatchingPartnerFiles(_ urls: [URL]) {
        guard let splitPartnerID else { return }
        partnerDocumentWatcher.start(
            tabID: splitPartnerID,
            urls: urls.filter(\.isFileURL)
        )
    }

    func stopWatchingPartnerFiles() {
        partnerDocumentWatcher.stop()
    }

    func restartWatchingPartnerFiles(_ urls: [URL]) {
        startWatchingPartnerFiles(urls)
    }
}
