import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func toggleDocumentDiff(mode: DocumentDiffMode, tabID: String) {
        guard let initialIndex = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if tabs[initialIndex].presentationMode == .diff(mode) {
            tabs[initialIndex].restorePreviousPresentationMode()
            return
        }

        let returnMode = tabs[initialIndex].diffSession?.returnMode
            ?? tabs[initialIndex].presentationMode

        switch tabs[initialIndex].kind {
        case .markdown:
            if tabs[initialIndex].markdownEditSession?.isEditing != true {
                beginMarkdownEditing(tabID: tabID)
            }
        case .json:
            if tabs[initialIndex].jsonEditSession?.isEditing != true {
                beginJSONEditing(tabID: tabID)
            }
        case .latex:
            if tabs[initialIndex].latexEditSession?.isEditing != true {
                beginLatexEditing(tabID: tabID)
            }
        default:
            return
        }

        openDocumentDiff(tabID: tabID, mode: mode, returningTo: returnMode)
    }

    private func openDocumentDiff(
        tabID: String,
        mode: DocumentDiffMode,
        returningTo returnMode: DocumentPresentationMode
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .markdown
                || tabs[index].kind == .json
                || tabs[index].kind == .latex else { return }

        switch documentDiffCoordinator.baseline(for: mode, url: tabs[index].editableSourceURL) {
        case let .available(baseline):
            tabs[index].activateDiff(DocumentDiffSession(
                mode: mode,
                baseline: baseline,
                returnMode: returnMode
            ))
        case let .unavailable(message):
            tabs[index].activateDiff(DocumentDiffSession(
                mode: mode,
                unavailableMessage: message,
                returnMode: returnMode
            ))
        }
    }

}
