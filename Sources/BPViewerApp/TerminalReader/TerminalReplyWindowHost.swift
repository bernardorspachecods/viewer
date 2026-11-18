import AppKit

/// The app side of the terminal reader boundary: which window receives a
/// captured reply. Reader and capture windows are created through
/// `WorkspaceWindowManager.makeStandaloneWindow`, shared with the Finder route.
extension WorkspaceWindowManager: TerminalReplyHost {
    func showReplyWindow(for destination: TerminalReplyDestination) -> TerminalReplyTarget? {
        // The shortcut arrives while Terminal is frontmost. `activeModel` is
        // the Viewer window that was focused before the app switch; AppKit's
        // keyWindow may still point at another transient or stale window.
        let model = activeModel ?? lastKnownModel
        guard let model else { return nil }

        let existingWindow = window(for: model)
            ?? (lastKnownModel === model ? lastKnownWindow : nil)

        // A reader window always opens separately. A tab opens in a standalone
        // window instead when the workspace window is minimized.
        if destination == .readerWindow || existingWindow?.isMiniaturized == true {
            let presentation: WindowPresentation = destination == .readerWindow ? .reader : .standalone
            let (captureModel, captureWindow) = makeStandaloneWindow(presentation)
            bringForward(captureWindow, model: captureModel)
            return captureModel
        }

        if let existingWindow {
            if windows[ObjectIdentifier(existingWindow)] == nil {
                register(model: model, window: existingWindow)
            }
            bringForward(existingWindow, model: model)
            return model
        }

        let restoredWindow = makeWindow(for: model)
        register(model: model, window: restoredWindow)
        bringForward(restoredWindow, model: model)
        return model
    }
}

extension AppModel: TerminalReplyTarget {
    func saveReply(markdown: String, to fileURL: URL) async -> Bool {
        await createSavedMarkdownDocument(source: markdown, at: fileURL)
    }
}
