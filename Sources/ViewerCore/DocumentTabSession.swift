import Foundation

/// Which pane of a split session a tab occupies.
public enum DocumentSplitSide: Hashable, Sendable { case leading, trailing }

fileprivate extension DocumentSplitSide {
    var opposite: DocumentSplitSide { self == .leading ? .trailing : .leading }
}

/// Owns document-tab identity, ordering, selection and the two-pane split without knowing the UI.
///
/// `activeTabID` is the focused pane. While split, `splitPartnerID` is the tab in the other pane
/// and `activeSide` says which side the focused tab is on.
public struct DocumentTabSession: Equatable, Sendable {
    public private(set) var tabs: [DocumentTab]
    public private(set) var activeTabID: String?
    /// The tab in the non-focused pane. nil when not split.
    public private(set) var splitPartnerID: String?
    /// The side of the active tab.
    public private(set) var activeSide: DocumentSplitSide

    public init(tabs: [DocumentTab] = [], activeTabID: String? = nil,
                splitPartnerID: String? = nil, activeSide: DocumentSplitSide = .leading) {
        var uniqueTabs: [DocumentTab] = []
        var seenURLs = Set<URL>()
        for tab in tabs {
            let normalizedURL = tab.isUntitled ? tab.url : tab.url.standardizedFileURL
            guard seenURLs.insert(normalizedURL).inserted else { continue }
            uniqueTabs.append(tab)
        }
        let resolvedActiveID = activeTabID.flatMap { id in
            uniqueTabs.contains { $0.id == id } ? id : nil
        } ?? uniqueTabs.first?.id
        self.tabs = uniqueTabs
        self.activeTabID = resolvedActiveID
        self.splitPartnerID = splitPartnerID.flatMap { id in
            (uniqueTabs.contains { $0.id == id } && id != resolvedActiveID) ? id : nil
        }
        self.activeSide = activeSide
    }

    public var activeTab: DocumentTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    public var isSplit: Bool { splitPartnerID != nil }

    public var leadingTabID: String? {
        guard isSplit else { return activeTabID }
        return activeSide == .leading ? activeTabID : splitPartnerID
    }

    public var trailingTabID: String? {
        guard isSplit else { return nil }
        return activeSide == .trailing ? activeTabID : splitPartnerID
    }

    @discardableResult
    public mutating func open(_ tab: DocumentTab) -> Bool {
        let normalizedURL = tab.url.standardizedFileURL
        if let existing = tabs.first(where: { $0.url.standardizedFileURL == normalizedURL }) {
            select(id: existing.id)
            return false
        }
        tabs.append(tab)
        activeTabID = tab.id
        return true
    }

    @discardableResult
    public mutating func select(id: String) -> Bool {
        guard tabs.contains(where: { $0.id == id }) else { return false }
        guard id != activeTabID else { return true }
        if isSplit && id == splitPartnerID {
            // Focus swap: the partner becomes focused and the previous focus becomes the partner.
            splitPartnerID = activeTabID
            activeSide = activeSide.opposite
        }
        activeTabID = id
        normalizeSplit()
        return true
    }

    @discardableResult
    public mutating func selectNext() -> Bool {
        guard !tabs.isEmpty else { return false }
        guard let activeTabID,
              let index = tabs.firstIndex(where: { $0.id == activeTabID }) else {
            self.activeTabID = tabs[0].id
            return true
        }
        guard let splitPartnerID else {
            self.activeTabID = tabs[(index + 1) % tabs.count].id
            return true
        }
        // Skip the partner; stepping fewer than count times never lands back on the active tab.
        for step in 1..<tabs.count {
            let candidate = tabs[(index + step) % tabs.count]
            if candidate.id != splitPartnerID {
                self.activeTabID = candidate.id
                normalizeSplit()
                return true
            }
        }
        return false
    }

    /// Drops a tab into one pane. Dropping the tab of the opposite pane swaps the two panes.
    @discardableResult
    public mutating func enterSplit(dropping id: String, on side: DocumentSplitSide) -> Bool {
        guard tabs.contains(where: { $0.id == id }) else { return false }
        guard isSplit else {
            guard id != activeTabID, let previousActive = activeTabID else { return false }
            splitPartnerID = previousActive
            activeTabID = id
            activeSide = side
            return true
        }
        let otherID = paneTabID(on: side.opposite)
        let sideID = paneTabID(on: side)
        // Swapping puts the tab previously on `side` into the opposite pane; otherwise it stays.
        splitPartnerID = id == otherID ? sideID : otherID
        activeTabID = id
        activeSide = side
        normalizeSplit()
        return true
    }

    public mutating func closeSplit() {
        splitPartnerID = nil
    }

    @discardableResult
    public mutating func close(id: String) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        let wasActive = activeTabID == id
        tabs.remove(at: index)
        if isSplit {
            if wasActive, let partner = splitPartnerID {
                activeTabID = partner
                splitPartnerID = nil
            } else if splitPartnerID == id {
                splitPartnerID = nil
            }
            normalizeSplit()
            return true
        }
        if wasActive {
            activeTabID = tabs.indices.contains(index) ? tabs[index].id : tabs.last?.id
        } else if tabs.isEmpty {
            activeTabID = nil
        }
        return true
    }

    @discardableResult
    public mutating func closeOthers(keeping id: String) -> Bool {
        guard let tab = tabs.first(where: { $0.id == id }) else { return false }
        tabs = [tab]
        activeTabID = tab.id
        splitPartnerID = nil
        return true
    }

    @discardableResult
    public mutating func closeToRight(of id: String) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        tabs = Array(tabs.prefix(through: index))
        if let activeTabID, !tabs.contains(where: { $0.id == activeTabID }) {
            self.activeTabID = tabs.last?.id
        }
        normalizeSplit()
        return true
    }

    @discardableResult
    public mutating func move(_ id: String, before targetID: String) -> Bool {
        guard id != targetID,
              let sourceIndex = tabs.firstIndex(where: { $0.id == id }),
              let targetIndex = tabs.firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        let tab = tabs.remove(at: sourceIndex)
        let adjustedTargetIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        tabs.insert(tab, at: adjustedTargetIndex)
        return true
    }

    @discardableResult
    public mutating func moveToEnd(_ id: String) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }),
              index != tabs.index(before: tabs.endIndex) else { return false }
        let tab = tabs.remove(at: index)
        tabs.append(tab)
        return true
    }

    @discardableResult
    public mutating func reorder(ids: [String]) -> Bool {
        guard ids.count == tabs.count,
              Set(ids) == Set(tabs.map(\.id)) else { return false }
        let tabsByID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        tabs = ids.compactMap { tabsByID[$0] }
        return true
    }

    @discardableResult
    public mutating func update(id: String, _ change: (inout DocumentTab) -> Void) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }
        change(&tabs[index])
        return true
    }

    public func tab(id: String) -> DocumentTab? {
        tabs.first { $0.id == id }
    }

    public var persistedPaths: [String] {
        tabs.filter { !$0.isUntitled }.map(\.url.path)
    }

    /// The tab shown in `side`. When not split only the leading pane exists, showing the active tab.
    private func paneTabID(on side: DocumentSplitSide) -> String? {
        side == .leading ? leadingTabID : trailingTabID
    }

    /// A partner that is gone, or equal to the active tab, is not a split.
    private mutating func normalizeSplit() {
        guard let partner = splitPartnerID else { return }
        if !tabs.contains(where: { $0.id == partner }) || partner == activeTabID {
            splitPartnerID = nil
        }
    }
}
