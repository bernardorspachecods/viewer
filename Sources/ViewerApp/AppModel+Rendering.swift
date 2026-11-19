import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func syncPreviewZoomToActiveTab() {
        previewZoom = tabs.first(where: { $0.id == activeTabID })?.previewZoom ?? 1.0
    }

    func renderActiveTabIfNeeded() {
        guard let activeTabID,
              let tab = tabs.first(where: { $0.id == activeTabID }),
              tab.kind == .markdown || tab.kind == .latex || tab.kind == .json || tab.kind == .csv || tab.kind == .pdf || tab.kind == .docx || tab.kind == .image else {
            stopWatchingActiveFiles()
            return
        }

        startWatchingActiveFiles(
            [tab.url, tab.editableSourceURL]
                + tab.previewDependencies + tab.previewExternalDependencies
        )
        let hasPreview: Bool
        switch tab.kind {
        case .markdown:
            hasPreview = tab.previewHTML != nil
        case .latex:
            hasPreview = tab.previewPDFData != nil
        case .pdf:
            hasPreview = tab.previewPDFData != nil
        case .json:
            hasPreview = tab.previewJSON != nil
        case .csv:
            hasPreview = tab.previewCSV != nil
        case .docx:
            return
        case .image:
            hasPreview = tab.previewImageData != nil
        case .other:
            hasPreview = false
        }
        if !hasPreview || tab.status != .ready {
            if tab.kind == .markdown {
                renderMarkdown(tabID: activeTabID)
            } else if tab.kind == .latex {
                renderLatex(tabID: activeTabID)
            } else if tab.kind == .json {
                renderJSON(tabID: activeTabID)
            } else if tab.kind == .csv {
                renderCSV(tabID: activeTabID)
            } else if tab.kind == .pdf {
                renderPDF(tabID: activeTabID)
            } else if tab.kind == .image {
                renderImage(tabID: activeTabID)
            }
        }
    }

    func renderLatex(
        tabID: String,
        rootURL explicitRootURL: URL? = nil,
        force: Bool = false
    ) {
        guard let tab = tabs.first(where: { $0.id == tabID }),
              let projectRoot = rootURL else { return }
        let sourceOverride: String?
        if let session = tab.latexEditSession,
           session.isEditing,
           session.currentSource != session.baseSource {
            sourceOverride = session.currentSource
        } else {
            sourceOverride = nil
        }
        documentRenderCoordinator.render(DocumentRenderRequest(
            tabID: tabID,
            url: tab.url,
            kind: .latex,
            projectRoot: projectRoot,
            markdownSourceOverride: nil,
            latexSourceURL: sourceOverride == nil ? nil : tab.editableSourceURL,
            latexSourceOverride: sourceOverride,
            latexRootURL: explicitRootURL ?? storedLatexRoot(for: projectRoot),
            latexShellEscapeMode: latexShellEscapeMode,
            approvedLatexExternalPaths: approvedLatexExternalPaths,
            force: force
        ))
    }

    func scheduleLatexRender(tabID: String) {
        latexRenderDebounceTasks[tabID]?.cancel()
        latexRenderDebounceTasks[tabID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.renderLatex(tabID: tabID)
            self.latexRenderDebounceTasks[tabID] = nil
        }
    }

    func renderMarkdown(tabID: String, sourceOverride: String? = nil) {
        guard let tab = tabs.first(where: { $0.id == tabID }), tab.kind == .markdown else { return }
        let effectiveSourceOverride = sourceOverride
            ?? (tab.isUntitled ? tab.markdownEditSession?.currentSource ?? tab.markdownSource ?? "" : nil)
        documentRenderCoordinator.render(DocumentRenderRequest(
            tabID: tabID,
            url: tab.url,
            kind: .markdown,
            projectRoot: rootURL,
            markdownSourceOverride: effectiveSourceOverride,
            latexRootURL: nil,
            latexShellEscapeMode: latexShellEscapeMode,
            approvedLatexExternalPaths: [:],
            force: false
        ))
    }

    func scheduleMarkdownRender(tabID: String) {
        markdownRenderDebounceTasks[tabID]?.cancel()
        markdownRenderDebounceTasks[tabID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, let self,
                  let tab = self.tabs.first(where: { $0.id == tabID }),
                  let session = tab.markdownEditSession,
                  session.isEditing,
                  session.mode == .split else { return }
            self.renderMarkdown(tabID: tabID, sourceOverride: session.currentSource)
            self.markdownRenderDebounceTasks[tabID] = nil
        }
    }

    func refreshDocx(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .docx else { return }

        tabs[index].status = .ready
        tabs[index].isStale = false
        tabs[index].errorMessage = nil
        tabs[index].previewUpdatedAt = Date()
    }

    func renderJSON(tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }), tab.kind == .json else { return }
        documentRenderCoordinator.render(DocumentRenderRequest(
            tabID: tabID,
            url: tab.url,
            kind: .json,
            projectRoot: rootURL,
            markdownSourceOverride: nil,
            latexRootURL: nil,
            latexShellEscapeMode: latexShellEscapeMode,
            approvedLatexExternalPaths: [:],
            force: false
        ))
    }

    func renderCSV(tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }), tab.kind == .csv else { return }
        documentRenderCoordinator.render(DocumentRenderRequest(
            tabID: tabID,
            url: tab.url,
            kind: .csv,
            projectRoot: rootURL,
            markdownSourceOverride: nil,
            latexRootURL: nil,
            latexShellEscapeMode: latexShellEscapeMode,
            approvedLatexExternalPaths: [:],
            force: false
        ))
    }

    func renderPDF(tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }), tab.kind == .pdf else { return }
        documentRenderCoordinator.render(DocumentRenderRequest(
            tabID: tabID,
            url: tab.url,
            kind: .pdf,
            projectRoot: rootURL,
            markdownSourceOverride: nil,
            latexRootURL: nil,
            latexShellEscapeMode: latexShellEscapeMode,
            approvedLatexExternalPaths: [:],
            force: false
        ))
    }

    func renderImage(tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }), tab.kind == .image else { return }
        documentRenderCoordinator.render(DocumentRenderRequest(
            tabID: tabID,
            url: tab.url,
            kind: .image,
            projectRoot: rootURL,
            markdownSourceOverride: nil,
            latexRootURL: nil,
            latexShellEscapeMode: latexShellEscapeMode,
            approvedLatexExternalPaths: [:],
            force: false
        ))
    }

    func handleDocumentRenderEvent(_ event: DocumentRenderEvent) {
        switch event {
        case let .started(tabID):
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
            tabs[index].status = .updating
            tabs[index].errorMessage = nil

        case let .ready(tabID, output):
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
            switch output.kind {
            case .markdown:
                tabs[index].previewHTML = output.html
                tabs[index].previewBaseURL = output.baseURL
                tabs[index].markdownOutline = output.outline
                tabs[index].markdownSource = output.source
                tabs[index].markdownBlocks = output.blocks
            case .json:
                tabs[index].previewJSON = output.json
                tabs[index].jsonSource = output.source
            case .csv:
                tabs[index].previewCSV = output.csv
            case .latex, .pdf:
                tabs[index].previewPDFData = output.pdfData
                tabs[index].latexSyncTeXData = output.syncTeXData
                tabs[index].latexGeneratedBibliographySource = output.generatedBibliographySource
                tabs[index].previewHTML = nil
                tabs[index].previewJSON = nil
                tabs[index].previewBaseURL = nil
                tabs[index].previewImageData = nil
            case .image:
                tabs[index].previewImageData = output.imageData
                tabs[index].previewHTML = nil
                tabs[index].previewJSON = nil
                tabs[index].previewCSV = nil
                tabs[index].previewPDFData = nil
                tabs[index].previewBaseURL = nil
            case .docx, .other:
                return
            }
            tabs[index].previewUpdatedAt = Date()
            tabs[index].previewDependencies = output.dependencies
            tabs[index].previewExternalDependencies = output.externalDependencies
            tabs[index].status = .ready
            tabs[index].isStale = false
            tabs[index].errorMessage = nil
            if activeTabID == tabID {
                restartWatchingActiveFiles(
                    [tabs[index].url, tabs[index].editableSourceURL]
                        + output.dependencies + output.externalDependencies
                )
            }

        case let .failed(tabID, failure):
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
            tabs[index].status = failure.status
            tabs[index].isStale = tabs[index].previewHTML != nil
                || tabs[index].previewJSON != nil
                || tabs[index].previewCSV != nil
                || tabs[index].previewPDFData != nil
                || tabs[index].previewImageData != nil
            tabs[index].errorMessage = failure.message
            if let candidates = failure.latexRootSelectionCandidates,
               let projectRoot = failure.projectRoot {
                pendingLatexRootSelection = LatexRootSelectionRequest(
                    id: tabID,
                    tabID: tabID,
                    openedFile: tabs[index].url,
                    projectRoot: projectRoot,
                    candidates: candidates
                )
            }
            if let rootURL = failure.latexRootURL,
               let dependencies = failure.latexExternalDependencies,
               let projectRoot = failure.projectRoot {
                pendingLatexExternalDependencies = LatexExternalDependencyRequest(
                    id: tabID,
                    tabID: tabID,
                    rootURL: rootURL,
                    projectRoot: projectRoot,
                    dependencies: dependencies
                )
            }
            if activeTabID == tabID {
                restartWatchingActiveFiles(
                    [tabs[index].url]
                        + tabs[index].previewDependencies
                        + tabs[index].previewExternalDependencies
                )
            }
        }
    }

}
