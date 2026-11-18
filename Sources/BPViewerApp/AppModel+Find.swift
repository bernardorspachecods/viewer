import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func showFindBar() {
        guard let kind = activeTab?.kind,
              [.markdown, .latex, .pdf, .json, .csv, .docx].contains(kind) else { return }
        isFindBarVisible = true
    }

    func setFindTarget(_ target: FindTarget) {
        guard findTarget != target else { return }
        findTarget = target
        findMatchCount = nil
    }

    func setFindMatchCount(_ count: Int) {
        findMatchCount = count
    }

    func hideFindBar() {
        isFindBarVisible = false
        findQuery = ""
        findRequestID += 1
        findTarget = .preview
        findMatchCount = nil
    }

    func findNext() {
        findBackwards = false
        findRequestID += 1
    }

    func findPrevious() {
        findBackwards = true
        findRequestID += 1
    }

}
