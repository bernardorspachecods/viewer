import AppKit
import Testing
@testable import ViewerApp

// A click anywhere in a split pane focuses that pane without consuming the click: the tracker is a
// local event monitor, so it has to see events dispatched through the application.

@MainActor
private func clickEvent(at point: NSPoint, in window: NSWindow) -> NSEvent {
    NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: point,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    )!
}

@MainActor
@Test("a mouse-down inside the tracked pane reports once, one outside does not", .serialized)
func paneFocusTrackerReportsClicksInsideOnly() async throws {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let tracked = PaneFocusTrackingView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
    var reports = 0
    tracked.onMouseDown = { reports += 1 }
    window.contentView?.addSubview(tracked)
    withExtendedLifetime(window) {}

    NSApp.sendEvent(clickEvent(at: NSPoint(x: 50, y: 100), in: window))
    try await Task.sleep(for: .milliseconds(100))
    #expect(reports == 1)

    NSApp.sendEvent(clickEvent(at: NSPoint(x: 300, y: 100), in: window))
    try await Task.sleep(for: .milliseconds(100))
    #expect(reports == 1)

    tracked.removeFromSuperview()
    NSApp.sendEvent(clickEvent(at: NSPoint(x: 50, y: 100), in: window))
    try await Task.sleep(for: .milliseconds(100))
    #expect(reports == 1)
}
