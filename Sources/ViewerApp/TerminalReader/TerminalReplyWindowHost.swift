import AppKit

/// The app side of the terminal reader boundary: which window receives a
/// captured reply. Reader and capture windows are created through
/// `WorkspaceWindowManager.makeStandaloneWindow`, shared with the Finder route.
extension WorkspaceWindowManager: TerminalReplyHost {
    func showReplyWindow(for destination: TerminalReplyDestination) -> TerminalReplyTarget? {
        // The shortcut arrives while Terminal is frontmost. `activeModel` is
        // the Viewer window that was focused before the app switch; AppKit's
        // keyWindow may still point at another transient or stale window.
        // A tab belongs to a workspace window: a reader or capture window left
        // focused by an earlier capture has no tab bar, so it is never the target.
        let model: AppModel?
        if destination == .workspaceTab {
            model = [activeModel, lastWorkspaceModel, lastKnownModel]
                .compactMap { $0 }
                .first { $0.presentation == .workspace }
                ?? models.values.first { $0.presentation == .workspace }
        } else {
            model = activeModel ?? lastKnownModel
        }
        guard let model else {
            // No workspace window exists: the tab falls back to a capture window.
            guard destination == .workspaceTab else { return nil }
            let (captureModel, captureWindow) = makeStandaloneWindow(.standalone)
            bringForward(captureWindow, model: captureModel)
            return captureModel
        }

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
