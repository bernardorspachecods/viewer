import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func updateCSVEditing(tabID: String, row: Int, column: Int, value: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .csv,
              let document = tabs[index].previewCSV,
              let updatedDocument = document.replacingCell(atRow: row, column: column, with: value) else {
            return
        }

        let adapter = CSVPreviewAdapter()
        let currentSource = adapter.serialize(document: updatedDocument)
        if tabs[index].csvEditSession == nil {
            let baseSource = (try? String(contentsOf: tabs[index].url, encoding: .utf8))
                ?? adapter.serialize(document: document)
            tabs[index].csvEditSession = CSVEditSession(
                baseSource: baseSource,
                currentSource: currentSource,
                saveState: .unsaved,
                undoSources: [baseSource]
            )
        } else {
            guard let session = tabs[index].csvEditSession,
                  session.currentSource != currentSource else { return }
            tabs[index].csvEditSession?.undoSources.append(session.currentSource)
            tabs[index].csvEditSession?.redoSources.removeAll()
            tabs[index].csvEditSession?.isEditing = true
            tabs[index].csvEditSession?.currentSource = currentSource
            tabs[index].csvEditSession?.saveState = .unsaved
            tabs[index].csvEditSession?.conflict = nil
        }
        tabs[index].previewCSV = updatedDocument
        tabs[index].previewUpdatedAt = Date()
        tabs[index].errorMessage = nil
    }

    func keepLocalCSVEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].csvEditSession else { return }
        applyCSVSaveOutcome(
            documentEditCoordinator.commitCSV(url: tabs[index].url, source: session.currentSource),
            tabID: tabID
        )
    }

    @discardableResult
    func saveCSVEditing(tabID: String) async -> Bool {
        await saveCSVEdit(tabID: tabID)
    }

    @discardableResult
    func undoCSVEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].csvEditSession,
              let previous = session.undoSources.last,
              let document = try? CSVPreviewAdapter().parse(source: previous) else { return false }

        var updated = session
        updated.undoSources.removeLast()
        updated.redoSources.append(updated.currentSource)
        updated.currentSource = previous
        updated.saveState = previous == updated.baseSource ? .saved : .unsaved
        updated.conflict = nil
        updated.isEditing = true
        tabs[index].csvEditSession = updated
        tabs[index].previewCSV = document
        tabs[index].previewUpdatedAt = Date()
        tabs[index].errorMessage = nil
        return true
    }

    @discardableResult
    func redoCSVEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].csvEditSession,
              let next = session.redoSources.last,
              let document = try? CSVPreviewAdapter().parse(source: next) else { return false }

        var updated = session
        updated.redoSources.removeLast()
        updated.undoSources.append(updated.currentSource)
        updated.currentSource = next
        updated.saveState = next == updated.baseSource ? .saved : .unsaved
        updated.conflict = nil
        updated.isEditing = true
        tabs[index].csvEditSession = updated
        tabs[index].previewCSV = document
        tabs[index].previewUpdatedAt = Date()
        tabs[index].errorMessage = nil
        return true
    }

    func useExternalCSVEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].csvEditSession,
              let conflict = session.conflict,
              let document = try? CSVPreviewAdapter().parse(source: conflict.externalSource) else {
            return
        }
        tabs[index].previewCSV = document
        tabs[index].csvEditSession = CSVEditSession(
            isEditing: false,
            baseSource: conflict.externalSource,
            currentSource: conflict.externalSource,
            saveState: .saved
        )
        tabs[index].previewUpdatedAt = Date()
        tabs[index].errorMessage = nil
    }

    @discardableResult
    func saveCSVEdit(tabID: String) async -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].csvEditSession else {
            return false
        }
        guard session.currentSource != session.baseSource else { return true }

        tabs[index].csvEditSession?.saveState = .saving
        let localSource = session.currentSource
        let outcome = await documentEditCoordinator.saveCSV(
            url: tabs[index].url,
            baseSource: session.baseSource,
            localSource: localSource
        )
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[currentIndex].csvEditSession?.currentSource == localSource else {
            return false
        }
        return applyCSVSaveOutcome(outcome, tabID: tabID)
    }

    @discardableResult
    private func applyCSVSaveOutcome(
        _ outcome: DocumentEditSaveOutcome,
        tabID: String
    ) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              var session = tabs[index].csvEditSession else {
            return false
        }
        switch outcome {
        case let .saved(source):
            guard let document = try? CSVPreviewAdapter().parse(source: source) else {
                session.saveState = .failed
                tabs[index].csvEditSession = session
                return false
            }
            session.baseSource = source
            session.currentSource = source
            session.saveState = .saved
            session.conflict = nil
            tabs[index].csvEditSession = session
            tabs[index].previewCSV = document
            tabs[index].previewUpdatedAt = Date()
            tabs[index].errorMessage = nil
            return true
        case let .conflict(conflict):
            session.saveState = .conflict
            session.conflict = conflict
            tabs[index].csvEditSession = session
            return false
        case let .failed(message):
            session.saveState = .failed
            session.conflict = nil
            tabs[index].csvEditSession = session
            tabs[index].errorMessage = message
            return false
        }
    }

}
