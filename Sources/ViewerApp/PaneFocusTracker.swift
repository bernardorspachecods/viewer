import AppKit
import SwiftUI

/// Reports a mouse-down inside its view without consuming the event, so clicks still reach the content.
struct PaneFocusTracker: NSViewRepresentable {
    let onMouseDown: () -> Void

    func makeNSView(context: Context) -> PaneFocusTrackingView {
        let view = PaneFocusTrackingView()
        view.onMouseDown = onMouseDown
        return view
    }

    func updateNSView(_ nsView: PaneFocusTrackingView, context: Context) {
        nsView.onMouseDown = onMouseDown
    }
}

final class PaneFocusTrackingView: NSView {
    var onMouseDown: (() -> Void)?
    nonisolated(unsafe) private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeEventMonitor()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onMouseDown?()
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
