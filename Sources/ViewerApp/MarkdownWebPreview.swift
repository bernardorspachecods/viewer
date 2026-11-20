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
    let onNavigate: (URL) -> Void
    let limitsTextWidth: Bool
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        configuration.userContentController.addUserScript(Self.textWidthScript(limitsTextWidth: limitsTextWidth))
        context.coordinator.limitsTextWidth = limitsTextWidth
        let messageHandler = MarkdownReadingPositionMessageHandler()
        messageHandler.coordinator = context.coordinator
        configuration.userContentController.add(messageHandler, name: Coordinator.readingPositionMessageName)
        configuration.userContentController.addUserScript(Self.scrollReportingScript)
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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.readingPositionMessageName)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        applyTextWidth(to: webView, coordinator: context.coordinator)
        context.coordinator.onReadingPositionChanged = onReadingPositionChanged
        context.coordinator.onAnchorRequestApplied = onAnchorRequestApplied
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
            let isFirstLoad = context.coordinator.html == nil
            let currentScrollY = webView.enclosingScrollView.map {
                max(Double($0.contentView.bounds.origin.y), 0)
            }
            let knownPosition = context.coordinator.lastReadingPosition ?? readingPosition
            let currentPosition = currentScrollY.map { scrollY in
                MarkdownReadingPosition(
                    scrollY: scrollY,
                    anchorID: knownPosition?.anchorID,
                    anchorOffset: knownPosition?.anchorOffset ?? 0,
                    sourceOffset: knownPosition?.sourceOffset,
                    blockTop: knownPosition?.blockTop ?? 0
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
            // A new web view stays hidden until `didFinish` has scrolled to the position, so it
            // never shows its top first. Reloads of a page already on screen keep showing it.
            if isFirstLoad, context.coordinator.pendingReadingPosition != nil { webView.alphaValue = 0 }
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
    }

    private static let scrollReportingScript = WKUserScript(
        source: Coordinator.scrollReportingScript,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    private static func textWidthScript(limitsTextWidth: Bool) -> WKUserScript {
        WKUserScript(
            source: TextWidthPreference.previewScript(limitsTextWidth: limitsTextWidth),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    /// A changed preference replaces the script for the next load and updates the page on screen.
    private func applyTextWidth(to webView: WKWebView, coordinator: Coordinator) {
        guard coordinator.limitsTextWidth != limitsTextWidth else { return }
        coordinator.limitsTextWidth = limitsTextWidth
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(Self.textWidthScript(limitsTextWidth: limitsTextWidth))
        controller.addUserScript(Self.scrollReportingScript)
        webView.evaluateJavaScript(TextWidthPreference.previewScript(limitsTextWidth: limitsTextWidth), completionHandler: nil)
    }

    private func configureScrollView(of webView: WKWebView) {
        guard let scrollView = webView.enclosingScrollView else { return }
        scrollView.horizontalScrollElasticity = .none
        scrollView.hasHorizontalScroller = false
    }

}
