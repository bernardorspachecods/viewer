import SwiftUI
import WebKit
import ViewerCore
import AppKit

extension MarkdownWebView {
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var html: String?
        var baseURL: URL?
        var documentID: String?
        var previewRevision: Date?
        var onNavigate: ((URL) -> Void)?
        var onReadingPositionChanged: ((MarkdownReadingPosition) -> Void)?
        var onFindMatchCount: @MainActor @Sendable (Int) -> Void = { _ in }
        var lastReadingPosition: MarkdownReadingPosition?
        var pendingReadingPosition: MarkdownReadingPosition?
        var findQuery = ""
        var findRequestID = 0
        var findBackwards = false
        var isFindTarget = true
        var outlineRequestID = 0
        /// Anchors to scroll to once the document has loaded, tried in order.
        var pendingAnchors: [String] = []
        /// Request that produced `pendingAnchors`, reported back once applied.
        var pendingAnchorRequestID: UUID?
        var lastAnchorRequestID: UUID?
        var onAnchorRequestApplied: (UUID) -> Void = { _ in }
        var isDocumentLoaded = false
        var limitsTextWidth = false
        private var scrollObserver: ObserverToken?
        private var captureTask: Task<Void, Never>?
        private var boundsObservationTask: Task<Void, Never>?
        private var lastObservedScrollBounds: CGRect?

        deinit {
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver.value)
            }
        }

        func observeScroll(in webView: WKWebView) {
            guard scrollObserver == nil, let scrollView = webView.enclosingScrollView else { return }
            let contentView = scrollView.contentView
            contentView.postsBoundsChangedNotifications = true
            lastObservedScrollBounds = contentView.bounds
            scrollObserver = ObserverToken(NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: contentView,
                queue: .main
            ) { [weak self, weak webView, weak contentView] _ in
                MainActor.assumeIsolated {
                    self?.scheduleBoundsObservation(in: contentView, webView: webView)
                }
            })
        }

        func removeScrollObservation() {
            boundsObservationTask?.cancel()
            boundsObservationTask = nil
            captureTask?.cancel()
            captureTask = nil
            guard let scrollObserver else { return }
            NotificationCenter.default.removeObserver(scrollObserver.value)
            self.scrollObserver = nil
            lastObservedScrollBounds = nil
        }

        func scheduleBoundsObservation(in contentView: NSView?, webView: WKWebView?) {
            guard let contentView, let webView else { return }
            boundsObservationTask?.cancel()
            boundsObservationTask = Task { @MainActor [weak self, weak webView, weak contentView] in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled,
                      let self,
                      let webView,
                      let contentView else { return }
                let currentBounds = contentView.bounds
                let previousBounds = self.lastObservedScrollBounds
                self.lastObservedScrollBounds = currentBounds
                guard MarkdownScrollObservationPolicy.shouldCapture(
                    previousBounds: previousBounds,
                    currentBounds: currentBounds
                ) else { return }
                self.scheduleCapture(of: webView)
            }
        }

        func scheduleCapture(of webView: WKWebView) {
            captureTask?.cancel()
            captureTask = Task { @MainActor [weak self, weak webView] in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled,
                      let self,
                      let webView else { return }
                self.captureReadingPosition(in: webView)
            }
        }

        func captureReadingPosition(in webView: WKWebView) {
            guard isDocumentLoaded else { return }
            webView.evaluateJavaScript(
                """
                (() => {
                    const scrollY = window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0;
                    const headings = Array.from(document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]'));
                    const anchor = headings.find((element) => element.getBoundingClientRect().bottom >= 0) || headings.at(-1);
                    return {
                        scrollY,
                        anchorID: anchor ? anchor.id : null,
                        anchorOffset: anchor ? anchor.getBoundingClientRect().top : 0
                    };
                })()
                """,
                completionHandler: { [weak self] result, _ in
                    guard let self,
                          let payload = result as? [String: Any] else { return }
                    let scrollY = (payload["scrollY"] as? NSNumber)?.doubleValue ?? 0
                    let anchorOffset = (payload["anchorOffset"] as? NSNumber)?.doubleValue ?? 0
                    self.publishReadingPosition(
                        scrollY: scrollY,
                        anchorID: payload["anchorID"] as? String,
                        anchorOffset: anchorOffset
                    )
                }
            )
        }

        func publishReadingPosition(
            scrollY: Double,
            anchorID: String?,
            anchorOffset: Double
        ) {
            let position = MarkdownReadingPosition(
                scrollY: max(scrollY, 0),
                anchorID: anchorID,
                anchorOffset: anchorOffset
            )
            guard lastReadingPosition != position else { return }
            lastReadingPosition = position
            onReadingPositionChanged?(position)
        }

        private final class ObserverToken: @unchecked Sendable {
            let value: NSObjectProtocol

            init(_ value: NSObjectProtocol) {
                self.value = value
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isDocumentLoaded = true
            if let pendingReadingPosition {
                restoreReadingPosition(pendingReadingPosition, in: webView)
                self.pendingReadingPosition = nil
            }
            scrollToPendingAnchors(in: webView)
            find(in: webView, updateMatchCount: true)
            scheduleCapture(of: webView)
        }

        func restoreReadingPosition(_ position: MarkdownReadingPosition, in webView: WKWebView) {
            guard let encodedID = try? String(
                data: JSONEncoder().encode(position.anchorID),
                encoding: .utf8
            ),
            let scrollY = String(position.scrollY).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let anchorOffset = String(position.anchorOffset).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }

            let script = """
            (() => {
                const fallback = \(scrollY);
                const anchor = \(encodedID) ? document.getElementById(\(encodedID)) : null;
                if (!anchor) {
                    window.scrollTo(0, fallback);
                    return;
                }
                const desiredTop = window.scrollY + anchor.getBoundingClientRect().top - \(anchorOffset);
                window.scrollTo(0, Math.max(0, desiredTop));
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        func scrollToPendingAnchors(in webView: WKWebView) {
            guard isDocumentLoaded, !pendingAnchors.isEmpty else { return }
            scrollToAnchors(pendingAnchors, in: webView)
            pendingAnchors = []
            if let requestID = pendingAnchorRequestID {
                pendingAnchorRequestID = nil
                // Reported asynchronously: this can run during a SwiftUI update.
                Task { @MainActor [weak self] in self?.onAnchorRequestApplied(requestID) }
            }
        }

        /// Scrolls to the first anchor that exists in the document.
        func scrollToAnchors(_ anchors: [String], in webView: WKWebView) {
            guard !anchors.isEmpty,
                  let encoded = try? String(data: JSONEncoder().encode(anchors), encoding: .utf8) else {
                return
            }
            let script = """
            (() => {
                for (const id of \(encoded)) {
                    const element = document.getElementById(id);
                    if (element) {
                        element.scrollIntoView({ block: 'start', behavior: 'smooth' });
                        return true;
                    }
                }
                return false;
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        /// Anchors when the navigation stays in this document (a fragment on the same file).
        private func sameDocumentAnchors(for url: URL, in webView: WKWebView) -> [String]? {
            for directory in [baseURL, webView.url].compactMap({ $0 }) {
                if let anchors = MarkdownLinkResolver.sameDocumentAnchors(for: url, documentDirectory: directory) {
                    return anchors
                }
            }
            return nil
        }

        func find(in webView: WKWebView, updateMatchCount: Bool) {
            guard isFindTarget else { return }
            if updateMatchCount {
                WebViewFindSupport.countMatches(in: webView, query: findQuery) { [weak self] count in
                    self?.onFindMatchCount(count)
                }
            }
            WebViewFindSupport.find(in: webView, query: findQuery, backwards: findBackwards)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let requestedURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let currentBaseURL = baseURL

            let resolvedURL: URL
            if requestedURL.scheme == nil,
               let currentBaseURL,
               let relativeURL = URL(string: requestedURL.absoluteString, relativeTo: currentBaseURL)?.absoluteURL {
                resolvedURL = relativeURL
            } else {
                resolvedURL = requestedURL
            }

            // Same-document fragments scroll in place; they must not reopen the file.
            if let anchors = sameDocumentAnchors(for: resolvedURL, in: webView) {
                scrollToAnchors(anchors, in: webView)
                decisionHandler(.cancel)
                return
            }

            let isLocalFileNavigation = resolvedURL.isFileURL
                && !resolvedURL.hasDirectoryPath
                && resolvedURL != webView.url
            let isAppPreviewNavigation = resolvedURL.scheme?.lowercased() == MarkdownPreviewLink.scheme
            guard navigationAction.navigationType == .linkActivated
                    || isLocalFileNavigation
                    || isAppPreviewNavigation else {
                decisionHandler(.allow)
                return
            }

            onNavigate?(resolvedURL)
            decisionHandler(.cancel)
        }
    }
}
