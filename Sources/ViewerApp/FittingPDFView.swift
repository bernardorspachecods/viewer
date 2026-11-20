import AppKit
import ViewerCore
import PDFKit

final class FittingPDFView: FindTrackingPDFView {
    struct ReadingPosition {
        let pageIndex: Int
        let point: CGPoint?

        init(pageIndex: Int, point: CGPoint?) {
            self.pageIndex = pageIndex
            self.point = point
        }

        init(_ position: PDFReadingPosition) {
            pageIndex = position.pageIndex
            if let x = position.x, let y = position.y {
                point = CGPoint(x: x, y: y)
            } else {
                point = nil
            }
        }
    }

    var zoom = 1.0
    var loadedPDFData: Data?
    var isRestoringPosition = false
    var onFindMatchCount: ((Int) -> Void)?
    var onDoubleClick: ((CGPoint) -> Void)?
    private var activeFindQuery = ""
    private var lastFindRequestID = 0
    private var findMatches: [PDFSelection] = []
    private var currentFindIndex = 0
    private var restoreGeneration = 0

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        claimKeyboardFocus()
    }

    override func mouseDown(with event: NSEvent) {
        claimKeyboardFocus()
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            onDoubleClick?(point)
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        CopyOnSelect.copy(currentSelection?.string)
    }

    override func keyDown(with event: NSEvent) {
        guard let command = PDFPageKeyCommand.command(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags
        ) else {
            super.keyDown(with: event)
            return
        }
        let currentIndex = readingPosition(fallbackPageIndex: 0).pageIndex
        guard let document,
              let target = command.targetPageIndex(from: currentIndex, pageCount: document.pageCount) else {
            return
        }
        goToPage(at: target)
    }

    /// Makes the PDF the key view so arrows work without a click. Skipped when a text
    /// field or the find field is editing, so typing there is never taken over.
    func claimKeyboardFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window,
                  window.firstResponder !== self,
                  !(window.firstResponder is NSTextView) else { return }
            window.makeFirstResponder(self)
        }
    }

    override func layout() {
        super.layout()
        fitPageWidth()
    }

    func fitPageWidth(force: Bool = false) {
        guard let page = document?.page(at: 0) else { return }

        let pageBounds = page.bounds(for: displayBox)
        let availableWidth = bounds.width - 32
        guard pageBounds.width > 0, availableWidth > 0 else { return }

        let targetScale = max((availableWidth / pageBounds.width) * zoom, 0.1)
        guard force || abs(scaleFactor - targetScale) > 0.001 else { return }

        scaleFactor = targetScale
    }

    func goToPage(at index: Int) {
        guard let document, document.pageCount > 0 else { return }
        let safeIndex = min(max(index, 0), document.pageCount - 1)
        guard let page = document.page(at: safeIndex), currentPage !== page else { return }
        go(to: page)
    }

    func readingPosition(fallbackPageIndex: Int) -> ReadingPosition {
        guard let document,
              let currentPage,
              let pageIndex = (0..<document.pageCount).first(where: {
                  document.page(at: $0) === currentPage
              }) else {
            return ReadingPosition(pageIndex: fallbackPageIndex, point: nil)
        }

        return ReadingPosition(
            pageIndex: pageIndex,
            point: currentDestination?.point
        )
    }

    func persistedReadingPosition(fallbackPageIndex: Int) -> PDFReadingPosition {
        let position = readingPosition(fallbackPageIndex: fallbackPageIndex)
        return PDFReadingPosition(
            pageIndex: position.pageIndex,
            x: position.point.map { Double($0.x) },
            y: position.point.map { Double($0.y) }
        )
    }

    func scheduleRestore(of position: ReadingPosition, onRestored: @escaping (Int) -> Void) {
        restoreGeneration += 1
        let generation = restoreGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.restoreGeneration == generation else { return }
            self.layoutDocumentView()
            guard let document, document.pageCount > 0 else {
                self.isRestoringPosition = false
                return
            }
            let safeIndex = min(max(position.pageIndex, 0), document.pageCount - 1)
            guard let page = document.page(at: safeIndex) else {
                self.isRestoringPosition = false
                return
            }
            if let point = position.point {
                go(to: PDFDestination(page: page, at: point))
            } else {
                go(to: page)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.restoreGeneration == generation else { return }
                self.isRestoringPosition = false
                onRestored(safeIndex)
            }
        }
    }

    func updateFind(
        query: String,
        requestID: Int,
        backwards: Bool,
        isFindTarget: Bool,
        force: Bool = false
    ) -> Bool {
        guard isFindTarget else {
            activeFindQuery = ""
            lastFindRequestID = requestID
            findMatches = []
            highlightedSelections = []
            currentSelection = nil
            return false
        }
        guard force || query != activeFindQuery || requestID != lastFindRequestID else { return false }

        let queryChanged = query != activeFindQuery
        activeFindQuery = query
        lastFindRequestID = requestID

        guard let document, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            findMatches = []
            highlightedSelections = []
            currentSelection = nil
            publishFindMatchCount(0, query: query, requestID: requestID)
            return true
        }

        if force || queryChanged {
            findMatches = document.findString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
            currentFindIndex = backwards ? max(findMatches.count - 1, 0) : 0
        } else if !findMatches.isEmpty {
            let step = backwards ? -1 : 1
            currentFindIndex = (currentFindIndex + step + findMatches.count) % findMatches.count
        }

        publishFindMatchCount(findMatches.count, query: query, requestID: requestID)
        highlightedSelections = findMatches
        guard !findMatches.isEmpty else {
            currentSelection = nil
            return true
        }

        let selection = findMatches[currentFindIndex]
        if let page = selection.pages.first {
            go(to: page)
        }
        setCurrentSelection(selection, animate: true)
        scrollSelectionToVisible(selection)
        return true
    }

    private func publishFindMatchCount(_ count: Int, query: String, requestID: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.activeFindQuery == query,
                  self.lastFindRequestID == requestID else { return }
            self.onFindMatchCount?(count)
        }
    }
}
