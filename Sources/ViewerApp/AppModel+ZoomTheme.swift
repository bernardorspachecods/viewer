import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func zoomIn() {
        setPreviewZoom(previewZoom + 0.1)
    }

    func zoomOut() {
        setPreviewZoom(previewZoom - 0.1)
    }

    func setPreviewZoomFromGesture(_ value: Double) {
        setPreviewZoom(value)
    }

    func resetPreviewZoom() {
        guard let activeTab else { return }
        setPreviewZoom(defaultZoom(for: activeTab.kind), customized: false)
    }

    func setDefaultMarkdownZoom(_ value: Double) {
        let normalizedValue = normalizedZoom(value)
        guard defaultMarkdownZoom != normalizedValue else { return }
        defaultMarkdownZoom = normalizedValue
        applyDefaultZoom(normalizedValue, to: .markdown)
        persistState()
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    func setDefaultLatexZoom(_ value: Double) {
        let normalizedValue = normalizedZoom(value)
        guard defaultLatexZoom != normalizedValue else { return }
        defaultLatexZoom = normalizedValue
        applyDefaultZoom(normalizedValue, to: .latex)
        persistState()
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

    private func setPreviewZoom(_ value: Double, customized: Bool = true) {
        let normalizedValue = normalizedZoom(value)
        previewZoom = normalizedValue
        guard let activeTabID,
              let index = tabs.firstIndex(where: { $0.id == activeTabID }) else {
            return
        }
        tabs[index].previewZoom = normalizedValue
        tabs[index].isPreviewZoomCustomized = customized
        persistState()
    }

    func defaultZoom(for kind: DocumentKind) -> Double {
        switch kind {
        case .markdown:
            return defaultMarkdownZoom
        case .latex, .pdf:
            return defaultLatexZoom
        case .json, .docx, .image, .other:
            return 1.0
        case .csv:
            return 1.0
        }
    }

    func applyDefaultZoom(_ value: Double, to kind: DocumentKind) {
        for index in tabs.indices where
            (tabs[index].kind == kind || (kind == .latex && tabs[index].kind == .pdf))
                && !tabs[index].isPreviewZoomCustomized {
            tabs[index].previewZoom = value
        }
        syncPreviewZoomToActiveTab()
    }

    private func normalizedZoom(_ value: Double) -> Double {
        min(max(value, 0.7), 2.0)
    }

    func cycleTheme() {
        setTheme(theme == .light ? .dark : .light)
    }

    func setTheme(_ preference: AppThemePreference) {
        guard theme != preference else { return }
        theme = preference
        persistState()
        WorkspaceWindowManager.shared.synchronizeGlobalPreferences(from: self)
    }

}
