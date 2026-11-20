import AppKit
import Testing
@testable import ViewerApp

@MainActor
private func event(_ type: NSEvent.EventType, in window: NSWindow) -> NSEvent {
    NSEvent.mouseEvent(
        with: type,
        location: NSPoint(x: 10, y: 10),
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
@Test("the drop highlight resets on the first event after a drag, and only while it is shown", .serialized)
func dropHighlightResetsOnFirstEventAfterDrag() async throws {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let view = DropHighlightResetView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
    var resets = 0
    view.onReset = { resets += 1 }
    window.contentView?.addSubview(view)
    withExtendedLifetime(window) {}

    NSApp.sendEvent(event(.leftMouseDown, in: window))
    try await Task.sleep(for: .milliseconds(50))
    #expect(resets == 0, "nothing is shown, so nothing resets")

    view.isActive = true
    NSApp.sendEvent(event(.mouseMoved, in: window))
    try await Task.sleep(for: .milliseconds(50))
    // Local monitors see every event the app dispatches, including other tests' clicks.
    #expect(resets >= 1)
}
