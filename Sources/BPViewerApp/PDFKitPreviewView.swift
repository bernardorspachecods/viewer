import AppKit
import BPViewerCore
import PDFKit
import SwiftUI

struct PDFKitPreviewView: NSViewRepresentable {
    let data: Data
    let zoom: Double
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let pageIndex: Int
    let requestedPageIndex: Int?
    let readingPosition: PDFReadingPosition?
    let onReadingPositionChanged: (PDFReadingPosition) -> Void
    let onNavigate: ((URL) -> Void)?
    let onDoubleClick: ((Int, CGPoint) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onReadingPositionChanged: onReadingPositionChanged, onNavigate: onNavigate)
    }

    func makeNSView(context: Context) -> FittingPDFView {
        let view = FittingPDFView()
        view.onFindFocus = onFindFocus
        view.onFindMatchCount = onFindMatchCount
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.autoScales = false
        view.backgroundColor = PreviewCanvasStyle.backgroundColor
        view.pageShadowsEnabled = true
        view.delegate = context.coordinator
        view.onDoubleClick = { [weak view] in
            guard let view, let document = view.document,
                  let page = view.page(for: $0, nearest: true) else { return }
            guard let pageIndex = (0..<document.pageCount).first(where: {
                document.page(at: $0) === page
            }) else { return }
            let pagePoint = view.convert($0, to: page)
            let pageBounds = page.bounds(for: view.displayBox)
            onDoubleClick?(
                pageIndex,
                CGPoint(x: pagePoint.x, y: pageBounds.maxY - pagePoint.y + pageBounds.minY)
            )
        }
        context.coordinator.observe(view)
        return view
    }

    static func dismantleNSView(_ view: FittingPDFView, coordinator: Coordinator) {
        guard view.document != nil else { return }
        coordinator.onReadingPositionChanged(
            view.persistedReadingPosition(fallbackPageIndex: 0)
        )
    }

    func updateNSView(_ view: FittingPDFView, context: Context) {
        context.coordinator.onReadingPositionChanged = onReadingPositionChanged
        context.coordinator.onNavigate = onNavigate
        view.onFindFocus = onFindFocus
        view.onFindMatchCount = onFindMatchCount
        let documentChanged = view.loadedPDFData != data
        let zoomChanged = view.zoom != zoom
        let previousPosition = (documentChanged || zoomChanged) && view.loadedPDFData != nil
            ? view.readingPosition(fallbackPageIndex: pageIndex)
            : nil
        if documentChanged {
            view.isRestoringPosition = true
            view.document = PDFDocument(data: data)
            view.loadedPDFData = data
            view.claimKeyboardFocus()
        }
        view.zoom = zoom
        if documentChanged || zoomChanged {
            view.fitPageWidth(force: true)
        }
        let didHandleFindNavigation = view.updateFind(
            query: findQuery,
            requestID: findRequestID,
            backwards: findBackwards,
            isFindTarget: isFindTarget,
            force: documentChanged
        )
        guard PDFPreviewUpdatePolicy.shouldSynchronizeReadingPosition(
            afterFindNavigationHandled: didHandleFindNavigation
        ) else { return }

        if let previousPosition {
            view.scheduleRestore(of: previousPosition) { restoredPageIndex in
                onReadingPositionChanged(
                    view.persistedReadingPosition(fallbackPageIndex: restoredPageIndex)
                )
            }
        } else if documentChanged, let readingPosition {
            view.scheduleRestore(of: .init(readingPosition)) { restoredPageIndex in
                onReadingPositionChanged(
                    view.persistedReadingPosition(fallbackPageIndex: restoredPageIndex)
                )
            }
        } else if let pageIndexToApply = PDFPreviewUpdatePolicy.pageIndexToApply(
            documentChanged: documentChanged,
            requestedPageIndex: requestedPageIndex,
            pageIndex: pageIndex
        ) {
            view.goToPage(at: pageIndexToApply)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onReadingPositionChanged: (PDFReadingPosition) -> Void
        var onNavigate: ((URL) -> Void)?
        private var pageChangedObservers: [ObserverToken] = []

        init(
            onReadingPositionChanged: @escaping (PDFReadingPosition) -> Void,
            onNavigate: ((URL) -> Void)?
        ) {
            self.onReadingPositionChanged = onReadingPositionChanged
            self.onNavigate = onNavigate
        }

        func observe(_ view: FittingPDFView) {
            let notificationNames: [Notification.Name] = [
                Notification.Name.PDFViewPageChanged,
                Notification.Name.PDFViewVisiblePagesChanged
            ]
            let observers = notificationNames.map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: view,
                    queue: .main
                ) { [weak self, weak view] _ in
                    Task { @MainActor [weak self, weak view] in
                        guard let self, let view, !view.isRestoringPosition,
                              view.document != nil else { return }
                        self.onReadingPositionChanged(
                            view.persistedReadingPosition(fallbackPageIndex: 0)
                        )
                    }
                }
            }
            pageChangedObservers = observers.map(ObserverToken.init)
        }

        deinit {
            for observer in pageChangedObservers {
                NotificationCenter.default.removeObserver(observer.value)
            }
        }
    }

    private final class ObserverToken: @unchecked Sendable {
        let value: NSObjectProtocol

        init(_ value: NSObjectProtocol) {
            self.value = value
        }
    }
}

extension PDFKitPreviewView.Coordinator: PDFViewDelegate {
    nonisolated func pdfView(_ sender: PDFView, willClickOnLink url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto", "file"].contains(scheme) else {
            return
        }
        Task { @MainActor [weak self] in
            if let onNavigate = self?.onNavigate {
                onNavigate(url)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }

    nonisolated func pdfViewPerformPrint(_ sender: PDFView) {
        // Do not let an embedded PDF action open the system print flow.
    }

    nonisolated func pdfViewPerformFind(_ sender: PDFView) {
        // Search is controlled by the app's own find bar.
    }

    nonisolated func pdfViewPerformGo(toPage sender: PDFView) {
        // Page navigation is controlled by the app and the outline sidebar.
    }

    nonisolated func pdfView(
        _ sender: PDFView,
        openPDF url: URL,
        forRemoteGoToAction action: PDFActionRemoteGoTo
    ) {
        // Remote go-to actions must never open another document silently.
    }
}
