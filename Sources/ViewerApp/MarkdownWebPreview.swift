import SwiftUI
import WebKit
import ViewerCore
import AppKit

enum MarkdownScrollObservationPolicy {
    static func shouldCapture(previousBounds: CGRect?, currentBounds: CGRect) -> Bool {
        guard let previousBounds else { return false }
        return previousBounds.size == currentBounds.size
            && previousBounds.origin != currentBounds.origin
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL
    let documentID: String
    let previewRevision: Date?
    let canBeginEditing: Bool
    let onNavigate: (URL) -> Void
    let onMarkdownEditEvent: (MarkdownWebEditEvent) -> Void
    let zoom: Double
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let requestedHeadingID: String?
    let outlineRequestID: Int
    /// A fragment from a link into this document, scrolled to once it is rendered.
    let anchorRequest: MarkdownAnchorRequest?
    let onAnchorRequestApplied: (UUID) -> Void
    let readingPosition: MarkdownReadingPosition?
    let onReadingPositionChanged: (MarkdownReadingPosition) -> Void
    let isQuickEditEnabled: Bool
    let quickEditFocus: (blockID: String, offset: Int, requestID: Int)?
    let onQuickEditFocusApplied: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: MarkdownEditingJavaScript.source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.add(context.coordinator, name: "viewerMarkdownEdit")
        CopyOnSelect.install(in: configuration)

        let webView = FindTrackingWKWebView(frame: .zero, configuration: configuration)
        webView.onFindFocus = onFindFocus
        webView.disableDrawsBackground()
        webView.navigationDelegate = context.coordinator
        configureScrollView(of: webView)
        context.coordinator.observeScroll(in: webView)
        return webView
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.captureReadingPosition(in: webView)
        coordinator.removeScrollObservation()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        context.coordinator.onMarkdownEditEvent = onMarkdownEditEvent
        context.coordinator.onReadingPositionChanged = onReadingPositionChanged
        context.coordinator.onQuickEditFocusApplied = onQuickEditFocusApplied
        context.coordinator.onAnchorRequestApplied = onAnchorRequestApplied
        context.coordinator.canBeginEditing = canBeginEditing
        context.coordinator.onFindMatchCount = onFindMatchCount
        (webView as? FindTrackingWKWebView)?.onFindFocus = onFindFocus
        configureScrollView(of: webView)
        context.coordinator.observeScroll(in: webView)
        if abs(webView.pageZoom - zoom) > 0.001 {
            webView.pageZoom = zoom
        }

        if context.coordinator.findRequestID != findRequestID
            || context.coordinator.findQuery != findQuery
            || context.coordinator.isFindTarget != isFindTarget {
            let queryChanged = context.coordinator.findQuery != findQuery
            let targetChanged = context.coordinator.isFindTarget != isFindTarget
            context.coordinator.findRequestID = findRequestID
            context.coordinator.findQuery = findQuery
            context.coordinator.findBackwards = findBackwards
            context.coordinator.isFindTarget = isFindTarget
            context.coordinator.find(
                in: webView,
                updateMatchCount: queryChanged || targetChanged
            )
        }

        let documentChanged = context.coordinator.html != html || context.coordinator.baseURL != baseURL
            || context.coordinator.previewRevision != previewRevision
        if documentChanged {
            let isSameDocument = context.coordinator.documentID == documentID
            let currentScrollY = webView.enclosingScrollView.map {
                max(Double($0.contentView.bounds.origin.y), 0)
            }
            let knownPosition = context.coordinator.lastReadingPosition ?? readingPosition
            let currentPosition = currentScrollY.map { scrollY in
                MarkdownReadingPosition(
                    scrollY: scrollY,
                    anchorID: knownPosition?.anchorID,
                    anchorOffset: knownPosition?.anchorOffset ?? 0
                )
            }
            context.coordinator.pendingReadingPosition = isSameDocument
                ? currentPosition ?? knownPosition
                : readingPosition
            context.coordinator.documentID = documentID
            context.coordinator.previewRevision = previewRevision
            context.coordinator.html = html
            context.coordinator.baseURL = baseURL
            context.coordinator.isDocumentLoaded = false
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        if context.coordinator.outlineRequestID != outlineRequestID {
            context.coordinator.outlineRequestID = outlineRequestID
            context.coordinator.pendingAnchors = requestedHeadingID.map { [$0] } ?? []
            if !documentChanged {
                context.coordinator.scrollToPendingAnchors(in: webView)
            }
        }

        if let anchorRequest, context.coordinator.lastAnchorRequestID != anchorRequest.id {
            context.coordinator.lastAnchorRequestID = anchorRequest.id
            context.coordinator.pendingAnchors = anchorRequest.anchors
            context.coordinator.pendingAnchorRequestID = anchorRequest.id
            if !documentChanged {
                context.coordinator.scrollToPendingAnchors(in: webView)
            }
        }

        if context.coordinator.isQuickEditEnabled != isQuickEditEnabled {
            context.coordinator.isQuickEditEnabled = isQuickEditEnabled
            context.coordinator.applyQuickEditState(in: webView)
        }
        // Focus is applied in didFinish, once the web view created for Quick Edit has loaded.
        context.coordinator.quickEditFocus = quickEditFocus
    }

    private func configureScrollView(of webView: WKWebView) {
        guard let scrollView = webView.enclosingScrollView else { return }
        scrollView.horizontalScrollElasticity = .none
        scrollView.hasHorizontalScroller = false
    }

}
