import AppKit
import SwiftUI

/// Calls `onReset` on the first mouse, key or scroll event after a drag. While a drag is in
/// progress the app receives none of these, so any of them means the drag is over; SwiftUI's drop
/// callbacks do not always say so (a stale drop highlight stayed on screen after a drop).
struct DropHighlightReset: NSViewRepresentable {
    let isActive: Bool
    let onReset: () -> Void

    func makeNSView(context: Context) -> DropHighlightResetView {
        DropHighlightResetView()
    }

    func updateNSView(_ nsView: DropHighlightResetView, context: Context) {
        nsView.isActive = isActive
        nsView.onReset = onReset
    }
}

final class DropHighlightResetView: NSView {
    var isActive = false
    var onReset: (() -> Void)?
    nonisolated(unsafe) private var eventMonitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeEventMonitor()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .keyDown, .scrollWheel]
        ) { [weak self] event in
            if let self, self.isActive {
                DispatchQueue.main.async { self.onReset?() }
            }
            return event
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
