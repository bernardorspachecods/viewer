import SwiftUI
import WebKit
import BPViewerCore
import AppKit

extension MarkdownWebView {
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var html: String?
        var baseURL: URL?
        var documentID: String?
        var previewRevision: Date?
        var onNavigate: ((URL) -> Void)?
        var onMarkdownEditEvent: ((MarkdownWebEditEvent) -> Void)?
        var onReadingPositionChanged: ((MarkdownReadingPosition) -> Void)?
        var onFindMatchCount: @MainActor @Sendable (Int) -> Void = { _ in }
        var lastReadingPosition: MarkdownReadingPosition?
        var pendingReadingPosition: MarkdownReadingPosition?
        var findQuery = ""
        var findRequestID = 0
        var findBackwards = false
        var isFindTarget = true
        var outlineRequestID = 0
        var pendingHeadingID: String?
        var isDocumentLoaded = false
        var canBeginEditing = true
        var isQuickEditEnabled = false
        var quickEditFocus: (blockID: String, offset: Int, requestID: Int)?
        var onQuickEditFocusApplied: () -> Void = {}
        private var handledQuickEditRequestID: Int?
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
            scrollToPendingHeading(in: webView)
            find(in: webView, updateMatchCount: true)
            scheduleCapture(of: webView)
            applyQuickEditState(in: webView)
            applyQuickEditFocus(in: webView)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "bpViewerMarkdownEdit",
                  let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String,
                  let text = payload["text"] as? String else { return }
            guard type != "begin" || canBeginEditing else { return }

            let kind: MarkdownWebEditEvent.Kind
            switch type {
            case "begin": kind = .begin
            case "change": kind = .change
            case "end": kind = .end
            case "undo": kind = .undo
            case "redo": kind = .redo
            case "inlineChange": kind = .inlineChange
            default: return
            }
            onMarkdownEditEvent?(MarkdownWebEditEvent(
                kind: kind,
                text: text,
                blockID: payload["blockID"] as? String,
                renderedTextOffset: (payload["renderedTextOffset"] as? NSNumber)?.intValue,
                unitIndex: (payload["unitIndex"] as? NSNumber)?.intValue,
                originalText: payload["original"] as? String
            ))
        }

        func applyQuickEditState(in webView: WKWebView) {
            guard isDocumentLoaded else { return }
            webView.evaluateJavaScript(
                "window.bpInline?.setEnabled(\(isQuickEditEnabled))",
                completionHandler: nil
            )
        }

        func applyQuickEditFocus(in webView: WKWebView) {
            guard isDocumentLoaded,
                  let quickEditFocus,
                  quickEditFocus.requestID != handledQuickEditRequestID,
                  let encodedID = try? String(
                    data: JSONEncoder().encode(quickEditFocus.blockID),
                    encoding: .utf8
                  ) else {
                return
            }
            handledQuickEditRequestID = quickEditFocus.requestID
            webView.evaluateJavaScript(
                "window.bpInline?.focusAt(\(encodedID), \(quickEditFocus.offset))",
                completionHandler: nil
            )
            onQuickEditFocusApplied()
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

        func scrollToPendingHeading(in webView: WKWebView) {
            guard isDocumentLoaded, let pendingHeadingID,
                  let encodedID = try? String(data: JSONEncoder().encode(pendingHeadingID), encoding: .utf8) else {
                return
            }

            let script = "document.getElementById(\(encodedID))?.scrollIntoView({ block: 'start', behavior: 'smooth' });"
            webView.evaluateJavaScript(script, completionHandler: nil)
            self.pendingHeadingID = nil
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
