import AppKit
import ViewerCore
import Foundation
import SwiftUI
import WebKit

/// Displays Word documents as a sharp, scrollable page on the app's document canvas.
struct DocxPreviewView: View {
    let url: URL
    let zoom: Double
    let previewRevision: Date?
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let onZoomChanged: (Double) -> Void

    var body: some View {
        DocxHTMLPreview(
            url: url,
            zoom: zoom,
            previewRevision: previewRevision,
            findQuery: findQuery,
            findRequestID: findRequestID,
            findBackwards: findBackwards,
            isFindTarget: isFindTarget,
            onFindFocus: onFindFocus,
            onFindMatchCount: onFindMatchCount,
            onZoomChanged: onZoomChanged
        )
        .background(BPTokens.Color.canvas)
    }
}

private struct DocxHTMLPreview: NSViewRepresentable {
    let url: URL
    let zoom: Double
    let previewRevision: Date?
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let onZoomChanged: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, revision: previewRevision)
    }

    func makeNSView(context: Context) -> DocxHTMLPreviewContainer {
        let view = DocxHTMLPreviewContainer(
            onZoomChanged: onZoomChanged,
            onFindFocus: onFindFocus,
            onFindMatchCount: onFindMatchCount
        )
        view.setPreview(url: url, zoom: zoom)
        return view
    }

    func updateNSView(_ view: DocxHTMLPreviewContainer, context: Context) {
        view.setZoom(zoom)
        view.updateFind(
            query: findQuery,
            requestID: findRequestID,
            backwards: findBackwards,
            isFindTarget: isFindTarget
        )

        guard context.coordinator.url != url || context.coordinator.revision != previewRevision else {
            return
        }

        context.coordinator.url = url
        context.coordinator.revision = previewRevision
        view.setPreview(url: url, zoom: zoom)
    }

    static func dismantleNSView(_ view: DocxHTMLPreviewContainer, coordinator: Coordinator) {
        view.closePreview()
    }

    @MainActor
    final class Coordinator {
        var url: URL
        var revision: Date?

        init(url: URL, revision: Date?) {
            self.url = url
            self.revision = revision
        }
    }
}

@MainActor
private final class DocxHTMLPreviewContainer: NSView, WKNavigationDelegate {
    private let webView: ZoomableDocxWebView
    private let statusLabel = NSTextField(labelWithString: "Preparing Word Preview…")
    private var previewURL: URL?
    private var previewTask: Task<Void, Never>?
    private var artifactDirectory: URL?
    private var zoom = 1.0
    private let onZoomChanged: (Double) -> Void
    private var findQuery = ""
    private var findRequestID = -1
    private var findBackwards = false
    private var isFindTarget = true
    private let onFindMatchCount: @MainActor @Sendable (Int) -> Void

    init(
        onZoomChanged: @escaping (Double) -> Void,
        onFindFocus: @escaping @MainActor @Sendable () -> Void,
        onFindMatchCount: @escaping @MainActor @Sendable (Int) -> Void
    ) {
        self.onZoomChanged = onZoomChanged
        self.onFindMatchCount = onFindMatchCount
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = ZoomableDocxWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        webView.onFindFocus = onFindFocus
        configure()
    }

    required init?(coder: NSCoder) {
        onZoomChanged = { _ in }
        onFindMatchCount = { _ in }
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = ZoomableDocxWebView(frame: .zero, configuration: configuration)
        super.init(coder: coder)
        configure()
    }

    override func layout() {
        super.layout()
        updateCanvasAppearance()
        webView.frame = bounds
        statusLabel.frame = NSRect(
            x: 24,
            y: (bounds.height - 28) / 2,
            width: max(bounds.width - 48, 200),
            height: 28
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateCanvasAppearance()
    }

    func setPreview(url: URL, zoom: Double) {
        setZoom(zoom)
        guard previewURL != url else {
            loadPreview(url: url)
            return
        }

        previewURL = url
        previewTask?.cancel()
        removeArtifact()
        webView.isHidden = true
        statusLabel.isHidden = false
        statusLabel.stringValue = "Preparing Word Preview…"

        previewTask = Task { @MainActor [weak self] in
            do {
                let artifact = try await Task.detached(priority: .userInitiated) {
                    try DocxHTMLConverter.convert(url: url)
                }.value
                guard let self, self.previewURL == url, !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: artifact.directoryURL)
                    return
                }
                self.artifactDirectory = artifact.directoryURL
                self.loadPreview(url: artifact.htmlURL)
            } catch {
                guard let self, self.previewURL == url, !Task.isCancelled else { return }
                self.statusLabel.stringValue = "Unable to prepare the Word preview."
                self.statusLabel.isHidden = false
            }
        }
    }

    func setZoom(_ zoom: Double) {
        self.zoom = DocumentZoomLimits.clamped(CGFloat(zoom))
        webView.currentZoom = self.zoom
        webView.pageZoom = self.zoom
    }

    func closePreview() {
        previewTask?.cancel()
        previewTask = nil
        webView.navigationDelegate = nil
        webView.stopLoading()
        removeArtifact()
    }

    func updateFind(query: String, requestID: Int, backwards: Bool, isFindTarget: Bool) {
        let queryChanged = findQuery != query
        let targetChanged = self.isFindTarget != isFindTarget
        guard findQuery != query
                || findRequestID != requestID
                || findBackwards != backwards
                || self.isFindTarget != isFindTarget else { return }
        findQuery = query
        findRequestID = requestID
        findBackwards = backwards
        self.isFindTarget = isFindTarget
        applyFind(updateMatchCount: queryChanged || targetChanged)
    }

    private func applyFind(updateMatchCount: Bool) {
        guard isFindTarget, !webView.isHidden else { return }
        if updateMatchCount {
            WebViewFindSupport.countMatches(in: webView, query: findQuery) { [onFindMatchCount] count in
                onFindMatchCount(count)
            }
        }
        WebViewFindSupport.find(in: webView, query: findQuery, backwards: findBackwards)
    }

    private func configure() {
        wantsLayer = true
        updateCanvasAppearance()

        webView.navigationDelegate = self
        webView.disableDrawsBackground()
        webView.underPageBackgroundColor = .clear
        webView.allowsMagnification = false
        webView.onMagnificationChanged = { [weak self] zoom in
            self?.setZoom(Double(zoom))
        }
        webView.onMagnificationEnded = { [weak self] magnification in
            guard let self else { return }
            self.setZoom(Double(magnification))
            self.onZoomChanged(Double(self.zoom))
        }
        webView.autoresizingMask = [.width, .height]
        webView.isHidden = true
        addSubview(webView)

        statusLabel.alignment = .center
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.autoresizingMask = [.width]
        addSubview(statusLabel)
    }

    private func updateCanvasAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = PreviewCanvasStyle.backgroundColor.cgColor
        }
    }

    private func loadPreview(url: URL) {
        let accessURL = artifactDirectory ?? url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: accessURL)
    }

    private func removeArtifact() {
        guard let artifactDirectory else { return }
        try? FileManager.default.removeItem(at: artifactDirectory)
        self.artifactDirectory = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.pageZoom = zoom
        webView.isHidden = false
        statusLabel.isHidden = true
        applyFind(updateMatchCount: true)
    }
}

private final class ZoomableDocxWebView: FindTrackingWKWebView {
    var currentZoom: CGFloat = 1.0
    var onMagnificationChanged: ((CGFloat) -> Void)?
    var onMagnificationEnded: ((CGFloat) -> Void)?

    override func magnify(with event: NSEvent) {
        let scale = max(CGFloat(0.1), 1 + event.magnification)
        let targetZoom = DocumentZoomLimits.clamped(currentZoom * scale)
        currentZoom = targetZoom
        onMagnificationChanged?(targetZoom)

        if event.phase == .ended {
            onMagnificationEnded?(targetZoom)
        }
    }
}
