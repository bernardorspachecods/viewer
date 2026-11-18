import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func beginJSONEditing(tabID: String, previewUTF8Offset: Int = 0) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .json else { return }

        let source = tabs[index].jsonSource
            ?? (try? String(contentsOf: tabs[index].url, encoding: .utf8))
            ?? ""
        tabs[index].diffSession = nil
        let transition = documentEditCoordinator.beginJSON(
            source: source,
            previewUTF8Offset: previewUTF8Offset
        )
        tabs[index].jsonSource = source
        tabs[index].errorMessage = nil
        tabs[index].jsonCursorUTF8Offset = transition.jsonCursorUTF8Offset
        tabs[index].jsonEditSession = transition.session
    }

    func updateJSONEditing(
        tabID: String,
        text: String,
        validate: Bool = true
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .json,
              let session = tabs[index].jsonEditSession,
              let transition = documentEditCoordinator.updateJSON(
                  session: session,
                  source: text,
                  validate: validate
              ) else { return }

        applyJSONTransition(transition, at: index)
    }

    func endJSONEditing(tabID: String, source: String? = nil) {
        if let source,
           tabs.first(where: { $0.id == tabID })?.jsonEditSession?.currentSource != source {
            updateJSONEditing(tabID: tabID, text: source, validate: false)
        }

        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .json,
              let session = tabs[index].jsonEditSession else { return }

        if let validationError = documentEditCoordinator.jsonValidationError(
            for: session.currentSource
        ) {
            tabs[index].jsonEditSession?.saveState = .failed
            tabs[index].errorMessage = validationError
            pendingInvalidJSONTabID = tabID
            showingInvalidJSONConfirmation = true
            return
        }

        if session.saveState == .failed {
            pendingInvalidJSONTabID = tabID
            showingInvalidJSONConfirmation = true
            return
        }

        if session.currentSource == session.baseSource {
            tabs[index].jsonEditSession?.isEditing = false
            tabs[index].diffSession = nil
            renderJSON(tabID: tabID)
        } else {
            tabs[index].jsonEditSession?.saveState = .saving
            Task { @MainActor [weak self] in
                _ = await self?.saveJSONEdit(tabID: tabID, finishEditing: true)
            }
        }
    }

    func cancelInvalidJSONEditing() {
        pendingInvalidJSONTabID = nil
        showingInvalidJSONConfirmation = false
    }

    func discardInvalidJSONEditing() {
        guard let tabID = pendingInvalidJSONTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession else {
            cancelInvalidJSONEditing()
            return
        }

        tabs[index].jsonSource = session.baseSource
        tabs[index].jsonEditSession?.currentSource = session.baseSource
        tabs[index].jsonEditSession?.undoSources.removeAll()
        tabs[index].jsonEditSession?.redoSources.removeAll()
        tabs[index].jsonEditSession?.saveState = .saved
        tabs[index].jsonEditSession?.conflict = nil
        tabs[index].jsonEditSession?.isEditing = false
        tabs[index].diffSession = nil
        tabs[index].errorMessage = nil
        cancelInvalidJSONEditing()
        renderJSON(tabID: tabID)
    }

    @discardableResult
    func undoJSONEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession,
              let transition = documentEditCoordinator.undoJSON(session: session) else { return false }
        applyJSONTransition(transition, at: index)
        return true
    }

    @discardableResult
    func redoJSONEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession,
              let transition = documentEditCoordinator.redoJSON(session: session) else { return false }
        applyJSONTransition(transition, at: index)
        return true
    }

    func keepLocalJSONEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession else { return }
        applyJSONSaveOutcome(
            documentEditCoordinator.commitJSON(url: tabs[index].url, source: session.currentSource),
            tabID: tabID,
            finishEditing: true
        )
    }

    func useExternalJSONEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession,
              let conflict = session.conflict else { return }
        applyJSONTransition(
            documentEditCoordinator.useExternal(
                session: session,
                externalSource: conflict.externalSource
            ),
            at: index
        )
        tabs[index].diffSession = nil
        renderJSON(tabID: tabID)
    }

    @discardableResult
    func saveJSONEdit(tabID: String, finishEditing: Bool = false) async -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession else {
            return false
        }

        guard session.currentSource != session.baseSource else {
            if finishEditing {
                tabs[index].jsonEditSession?.isEditing = false
                tabs[index].diffSession = nil
                renderJSON(tabID: tabID)
            }
            return true
        }

        tabs[index].jsonEditSession?.saveState = .saving
        let localSource = session.currentSource
        let outcome = await documentEditCoordinator.saveJSON(
            url: tabs[index].url,
            baseSource: session.baseSource,
            localSource: localSource
        )
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[currentIndex].jsonEditSession?.currentSource == localSource else {
            return false
        }
        return applyJSONSaveOutcome(outcome, tabID: tabID, finishEditing: finishEditing)
    }

}
