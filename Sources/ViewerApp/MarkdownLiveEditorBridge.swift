import AppKit
import SwiftUI
import ViewerCore

/// Reaches the engine's `NSTextView` for what the engine's SwiftUI wrapper does not expose:
/// `Esc` to leave editing, the ⌘B/⌘I/⌘K shortcuts, find, and moving the caret to a heading.
struct MarkdownLiveEditorBridge: NSViewRepresentable {
    let bus: MarkdownLiveEditorBus
    let source: String
    let cursorUTF8Offset: Int?
    let cursorRequestID: Int
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let onEndEditing: @MainActor @Sendable () -> Void
    /// The reading position to show when the editor appears, and the zoom it is measured at.
    let entryPosition: MarkdownReadingPosition?
    let zoom: Double
    let onViewportChanged: @MainActor @Sendable (MarkdownReadingPosition) -> Void
    /// Called once the entry position is applied (or given up on), so the editor can be shown.
    let onEntryApplied: @MainActor @Sendable () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(bus: bus) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.bridgeView = view
        // An outline jump made before this editor existed must not be replayed.
        context.coordinator.appliedCursorRequestID = cursorRequestID
        context.coordinator.installEventMonitor()
        DispatchQueue.main.async { onFindFocus() }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onFindFocus = onFindFocus
        coordinator.onFindMatchCount = onFindMatchCount
        coordinator.onEndEditing = onEndEditing
        coordinator.onViewportChanged = onViewportChanged
        coordinator.onEntryApplied = onEntryApplied
        coordinator.updateViewport(source: source, zoom: zoom, entryPosition: entryPosition)
        coordinator.applyCursor(source: source, offset: cursorUTF8Offset, requestID: cursorRequestID)
        coordinator.applyFind(
            source: source,
            query: findQuery,
            requestID: findRequestID,
            backwards: findBackwards,
            isFindTarget: isFindTarget
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator {
        weak var bridgeView: NSView?
        var onFindFocus: @MainActor @Sendable () -> Void = {}
        var onFindMatchCount: @MainActor @Sendable (Int) -> Void = { _ in }
        var onEndEditing: @MainActor @Sendable () -> Void = {}
        var onViewportChanged: @MainActor @Sendable (MarkdownReadingPosition) -> Void = { _ in }
        var onEntryApplied: @MainActor @Sendable () -> Void = {}
        let viewport = MarkdownLiveEditorViewportState()

        private var monitor: Any?
        private var resultsObserver: NSObjectProtocol?
        private var matchCount = 0
        private var currentIndex: Int?
        private var lastQuery = ""
        private var lastRequestID = -1
        private var lastSource = ""
        private var wasFindTarget = false
        var appliedCursorRequestID = 0
        private let bus: MarkdownLiveEditorBus

        init(bus: MarkdownLiveEditorBus) {
            self.bus = bus
            resultsObserver = NotificationCenter.default.addObserver(
                forName: bus.findResults,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let count = note.userInfo?["count"] as? Int ?? 0
                MainActor.assumeIsolated { self?.matchCount = count }
            }
        }

        func teardown() {
            stopObservingScrolling()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            if let resultsObserver { NotificationCenter.default.removeObserver(resultsObserver) }
            resultsObserver = nil
        }

        // MARK: Locating the engine's text view

        func locateTextView() -> NSTextView? {
            guard let bridgeView, let root = bridgeView.window?.contentView else { return nil }
            let center = bridgeView.convert(
                NSPoint(x: bridgeView.bounds.midX, y: bridgeView.bounds.midY),
                to: nil
            )
            return Self.textViews(in: root).first { textView in
                guard String(describing: type(of: textView)).contains("NativeTextView") else { return false }
                return textView.convert(textView.bounds, to: nil).contains(center)
            }
        }

        private static func textViews(in view: NSView) -> [NSTextView] {
            var found: [NSTextView] = []
            if let textView = view as? NSTextView { found.append(textView) }
            for subview in view.subviews { found += textViews(in: subview) }
            return found
        }

        // MARK: Keys and focus

        func installEventMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
                guard let self else { return event }
                return self.handle(event)
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard event.window != nil, event.window === bridgeView?.window,
                  let textView = locateTextView(), event.window === textView.window else { return event }
            if event.type == .leftMouseDown {
                let point = textView.convert(event.locationInWindow, from: nil)
                if textView.bounds.contains(point) { onFindFocus() }
                return event
            }
            guard textView.window?.firstResponder === textView else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if event.keyCode == 53, flags.isEmpty, !textView.hasMarkedText() {
                // The engine pushes text to the draft on the next main-queue turn, so ending
                // one turn later keeps a character typed just before `Esc`.
                let end = onEndEditing
                DispatchQueue.main.async { end() }
                return nil
            }
            if flags == .command, let key = event.charactersIgnoringModifiers?.lowercased() {
                let name: Notification.Name? = switch key {
                case "b": bus.bold
                case "i": bus.italic
                case "k": bus.inlineCode
                default: nil
                }
                if let name {
                    NotificationCenter.default.post(name: name, object: nil)
                    return nil
                }
            }
            return event
        }

        // MARK: Caret

        func applyCursor(source: String, offset: Int?, requestID: Int) {
            guard requestID != appliedCursorRequestID else { return }
            appliedCursorRequestID = requestID
            guard let offset else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let textView = self.locateTextView(),
                      let utf16 = MarkdownEditorCursor.utf16Offset(
                          inDisplay: textView.string,
                          forSourceUTF8Offset: offset,
                          source: source
                      ) else { return }
                let range = NSRange(location: utf16, length: 0)
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(range)
                textView.scrollRangeToVisible(range)
            }
        }

        // MARK: Find

        func applyFind(
            source: String,
            query: String,
            requestID: Int,
            backwards: Bool,
            isFindTarget: Bool
        ) {
            let active = isFindTarget && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard active else {
                if wasFindTarget {
                    NotificationCenter.default.post(name: bus.findClear, object: nil)
                    reportCount(0)
                }
                wasFindTarget = false
                lastQuery = ""
                lastRequestID = requestID
                currentIndex = nil
                return
            }

            let queryChanged = query != lastQuery || !wasFindTarget
            // Typing changes the source on every key; re-running the search then would scroll
            // the view to the current match, away from the caret.
            let isTyping = locateTextView().map { $0.window?.firstResponder === $0 } ?? false
            let sourceChanged = source != lastSource && !isTyping
            let requestChanged = requestID != lastRequestID
            guard queryChanged || sourceChanged || requestChanged else { return }
            wasFindTarget = true
            lastQuery = query
            lastSource = source
            lastRequestID = requestID

            if queryChanged {
                search(query: query, index: 0)
                currentIndex = TextSearch.nextMatchIndex(
                    currentIndex: nil,
                    matchCount: matchCount,
                    backwards: backwards
                )
            } else if requestChanged {
                currentIndex = TextSearch.nextMatchIndex(
                    currentIndex: currentIndex,
                    matchCount: matchCount,
                    backwards: backwards
                )
            }
            search(query: query, index: min(currentIndex ?? 0, max(matchCount - 1, 0)))
            reportCount(matchCount)
        }

        /// The engine answers synchronously: it highlights and scrolls to match `index`, then
        /// posts the match count.
        private func search(query: String, index: Int) {
            NotificationCenter.default.post(
                name: bus.findQuery,
                object: nil,
                userInfo: ["query": query, "currentIndex": index]
            )
        }

        private func reportCount(_ count: Int) {
            let report = onFindMatchCount
            DispatchQueue.main.async { report(count) }
        }
    }
}
