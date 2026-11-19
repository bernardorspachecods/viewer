import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func beginLatexEditing(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .latex else { return }

        let sourceURL = tabs[index].editableSourceURL
        let source = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? ""
        tabs[index].diffSession = nil
        tabs[index].latexCursorUTF8Offset = nil
        tabs[index].latexEditSession = documentEditCoordinator.beginLatex(source: source).session
        tabs[index].errorMessage = nil
    }

    func openLatexCitation(tabID: String, sourceOffset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .latex,
              let session = tabs[index].latexEditSession,
              let projectRoot = rootURL,
              let key = LatexCitationLookup.citationKey(
                  atUTF8Offset: sourceOffset,
                  in: session.currentSource
              ),
              let bibliography = latexBibliographyEntry(
                  for: key,
                  tab: tabs[index],
                  projectRoot: projectRoot
              ) else { return }

        tabs[index].contextURL = bibliography.url == tabs[index].url ? nil : bibliography.url
        tabs[index].latexEditSession = documentEditCoordinator.beginLatex(
            source: bibliography.source
        ).session
        tabs[index].latexCursorUTF8Offset = bibliography.offset
        tabs[index].diffSession = nil
        tabs[index].errorMessage = nil
        if activeTabID == tabID {
            startWatchingActiveFiles(
                [tabs[index].url, tabs[index].editableSourceURL]
                    + tabs[index].previewDependencies
                    + tabs[index].previewExternalDependencies
            )
        }
    }

    func beginLatexEditing(tabID: String, pageIndex: Int, pointFromTopLeft: CGPoint) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard let syncTeXData = tabs[index].latexSyncTeXData,
              let pdfData = tabs[index].previewPDFData,
              let projectRoot = rootURL else {
            beginLatexEditing(tabID: tabID)
            return
        }

        Task { @MainActor [weak self] in
            let location = await Task.detached {
                LatexSyncTeXLookup.location(
                    syncTeXData: syncTeXData,
                    pdfData: pdfData,
                    pageIndex: pageIndex,
                    pointFromTopLeft: pointFromTopLeft,
                    projectRoot: projectRoot
                )
            }.value
            guard let self,
                  let currentIndex = self.tabs.firstIndex(where: { $0.id == tabID }) else { return }

            // Wait for SyncTeX before exposing the editor. This keeps the
            // source view from briefly appearing at line one and then
            // jumping to the clicked location.
            if self.tabs[currentIndex].latexEditSession?.isEditing != true {
                self.beginLatexEditing(tabID: tabID)
            }
            if let location {
                self.applyLatexSourceLocation(
                    location,
                    tabID: tabID,
                    projectRoot: projectRoot
                )
            }
        }
    }

    func applyLatexSourceLocation(
        _ location: LatexSourceLocation,
        tabID: String,
        projectRoot: URL
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].latexEditSession?.isEditing == true else { return }

        let target: (url: URL, source: String, offset: Int)
        if location.url.pathExtension.lowercased() == "bbl",
           location.url.deletingPathExtension().lastPathComponent
               == tabs[index].url.deletingPathExtension().lastPathComponent {
            let key = tabs[index].latexGeneratedBibliographySource.flatMap {
                LatexCitationLookup.keyInGeneratedBibliography(
                    atLine: location.line,
                    in: $0
                )
            }
            guard let bibliography = key.flatMap({
                latexBibliographyEntry(
                    for: $0,
                    tab: tabs[index],
                    projectRoot: projectRoot
                )
            }) ?? latexFirstBibliography(tab: tabs[index], projectRoot: projectRoot) else { return }
            target = bibliography
        } else {
            guard let sourceURL = latexSourceURL(
                for: location.url,
                tab: tabs[index],
                projectRoot: projectRoot
            ), let source = try? String(contentsOf: sourceURL, encoding: .utf8) else { return }

            let offset = latexUTF8Offset(
                in: source,
                line: location.line,
                column: location.column
            )
            if sourceURL.pathExtension.lowercased() == "tex",
               let key = LatexCitationLookup.citationKey(
                   atUTF8Offset: offset,
                   in: source
               ),
               let bibliography = latexBibliographyEntry(
                   for: key,
                   tab: tabs[index],
                   projectRoot: projectRoot
               ) {
                target = bibliography
            } else {
                target = (sourceURL, source, offset)
            }
        }

        let currentURL = tabs[index].editableSourceURL.standardizedFileURL
        if target.url != currentURL {
            tabs[index].contextURL = target.url == tabs[index].url ? nil : target.url
            tabs[index].latexEditSession = documentEditCoordinator.beginLatex(
                source: target.source
            ).session
            tabs[index].diffSession = nil
            tabs[index].errorMessage = nil
            if activeTabID == tabID {
                startWatchingActiveFiles(
                    [tabs[index].url, tabs[index].editableSourceURL]
                        + tabs[index].previewDependencies
                        + tabs[index].previewExternalDependencies
                )
            }
        }
        tabs[index].latexCursorUTF8Offset = target.offset
    }

    private func latexSourceURL(
        for locationURL: URL,
        tab: DocumentTab,
        projectRoot: URL
    ) -> URL? {
        let candidate = locationURL.resolvingSymlinksInPath().standardizedFileURL
        if isInside(candidate, project: projectRoot),
           FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        let dependencies = Set(
            tab.previewDependencies.map { $0.resolvingSymlinksInPath().standardizedFileURL }
        )
        if let dependency = dependencies.first(where: { dependency in
            dependency.lastPathComponent == candidate.lastPathComponent
                && dependency.pathExtension.lowercased() == candidate.pathExtension.lowercased()
        }) {
            return dependency
        }

        guard !locationURL.path.hasPrefix("/") else { return nil }
        let relativeCandidate = projectRoot
            .appendingPathComponent(locationURL.path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return isInside(relativeCandidate, project: projectRoot)
            && FileManager.default.fileExists(atPath: relativeCandidate.path)
            ? relativeCandidate
            : nil
    }

    private func latexBibliographyEntry(
        for key: String,
        tab: DocumentTab,
        projectRoot: URL
    ) -> (url: URL, source: String, offset: Int)? {
        for url in latexBibliographyURLs(tab: tab, projectRoot: projectRoot) {
            guard let source = try? String(contentsOf: url, encoding: .utf8),
                  let offset = LatexCitationLookup.bibliographyEntryOffset(
                      for: key,
                      in: source
                  ) else { continue }
            return (url, source, offset)
        }
        return nil
    }

    private func latexFirstBibliography(
        tab: DocumentTab,
        projectRoot: URL
    ) -> (url: URL, source: String, offset: Int)? {
        for url in latexBibliographyURLs(tab: tab, projectRoot: projectRoot) {
            if let source = try? String(contentsOf: url, encoding: .utf8) {
                return (url, source, 0)
            }
        }
        return nil
    }

    private func latexBibliographyURLs(tab: DocumentTab, projectRoot: URL) -> [URL] {
        let rootURL = storedLatexRoot(for: projectRoot) ?? tab.url
        let dependencies = Set(
            tab.previewDependencies
                + LocalLatexAdapter().sourceDependencies(
                    rootURL: rootURL,
                    projectRoot: projectRoot
                )
        )
        return dependencies
            .filter {
                $0.pathExtension.lowercased() == "bib"
                    && isInside($0, project: projectRoot)
            }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func latexUTF8Offset(in source: String, line: Int, column: Int) -> Int {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return 0 }
        let lineIndex = min(max(line - 1, 0), max(lines.count - 1, 0))
        let prefix = lines.prefix(lineIndex).joined(separator: "\n")
        return prefix.utf8.count + (lineIndex > 0 ? 1 : 0)
            + min(max(column, 0), lines[lineIndex].utf8.count)
    }

    func updateLatexEditing(tabID: String, text: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .latex,
              let session = tabs[index].latexEditSession,
              let transition = documentEditCoordinator.updateLatex(
                  session: session,
                  source: text
              ) else { return }

        tabs[index].latexEditSession = transition.session
        tabs[index].errorMessage = nil
        scheduleLatexRender(tabID: tabID)
    }

    func endLatexEditing(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession else { return }
        if session.currentSource == session.baseSource {
            tabs[index].latexEditSession?.isEditing = false
            tabs[index].diffSession = nil
            renderLatex(tabID: tabID)
        } else {
            tabs[index].latexEditSession?.saveState = .saving
            Task { @MainActor [weak self] in
                _ = await self?.saveLatexEdit(tabID: tabID, finishEditing: true)
            }
        }
    }

    @discardableResult
    func undoLatexEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession,
              let transition = documentEditCoordinator.undoLatex(session: session) else { return false }
        tabs[index].latexEditSession = transition.session
        scheduleLatexRender(tabID: tabID)
        return true
    }

    @discardableResult
    func redoLatexEdit() -> Bool {
        guard let tabID = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession,
              let transition = documentEditCoordinator.redoLatex(session: session) else { return false }
        tabs[index].latexEditSession = transition.session
        scheduleLatexRender(tabID: tabID)
        return true
    }

    func keepLocalLatexEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession else { return }
        applyLatexSaveOutcome(
            documentEditCoordinator.commitLatex(
                url: tabs[index].editableSourceURL,
                source: session.currentSource
            ),
            tabID: tabID,
            finishEditing: true
        )
    }

    func useExternalLatexEdit(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession,
              let conflict = session.conflict else { return }
        let external = documentEditCoordinator.useExternal(
            session: session,
            externalSource: conflict.externalSource
        )
        tabs[index].latexEditSession = external.session
        tabs[index].diffSession = nil
        tabs[index].errorMessage = nil
        renderLatex(tabID: tabID)
    }

    @discardableResult
    func saveLatexEdit(tabID: String, finishEditing: Bool = false) async -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession else { return false }

        guard session.currentSource != session.baseSource else {
            if finishEditing {
                tabs[index].latexEditSession?.isEditing = false
                tabs[index].diffSession = nil
                renderLatex(tabID: tabID)
            }
            return true
        }

        let localSource = session.currentSource
        tabs[index].latexEditSession?.saveState = .saving
        let outcome = await documentEditCoordinator.saveLatex(
            url: tabs[index].editableSourceURL,
            baseSource: session.baseSource,
            localSource: localSource
        )
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[currentIndex].latexEditSession?.currentSource == localSource else {
            return false
        }
        return applyLatexSaveOutcome(outcome, tabID: tabID, finishEditing: finishEditing)
    }

    @discardableResult
    private func applyLatexSaveOutcome(
        _ outcome: DocumentEditSaveOutcome,
        tabID: String,
        finishEditing: Bool
    ) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return false }
        switch outcome {
        case let .saved(source):
            tabs[index].latexEditSession?.baseSource = source
            tabs[index].latexEditSession?.currentSource = source
            tabs[index].latexEditSession?.saveState = .saved
            tabs[index].latexEditSession?.conflict = nil
            tabs[index].errorMessage = nil
            if tabs[index].diffSession?.mode == .savedOnDisk {
                tabs[index].diffSession?.baseline = DocumentDiffBaseline(
                    label: "Saved on Disk",
                    source: source
                )
            }
            if finishEditing {
                tabs[index].latexEditSession?.isEditing = false
                tabs[index].diffSession = nil
            }
            renderLatex(tabID: tabID)
            return true
        case let .conflict(conflict):
            tabs[index].latexEditSession?.saveState = .conflict
            tabs[index].latexEditSession?.isEditing = true
            tabs[index].latexEditSession?.conflict = conflict
            return false
        case let .failed(message):
            tabs[index].latexEditSession?.saveState = .failed
            tabs[index].latexEditSession?.isEditing = true
            tabs[index].errorMessage = message
            return false
        }
    }

    func toggleLatexSplitView(tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].kind == .latex else { return }
        guard tabs[index].latexEditSession?.isEditing == true else {
            let returnMode = tabs[index].presentationMode
            beginLatexEditing(tabID: tabID)
            tabs[index].latexEditSession?.mode = .split
            tabs[index].latexEditSession?.splitReturnMode = returnMode
            renderLatex(tabID: tabID)
            return
        }

        if tabs[index].presentationMode == .split {
            let returnMode = tabs[index].latexEditSession?.splitReturnMode ?? .source
            let modeAfterClosing = returnMode == .preview && hasUnsavedChanges(in: tabs[index])
                ? .source
                : returnMode
            tabs[index].selectPresentationMode(modeAfterClosing)
            tabs[index].latexEditSession?.splitReturnMode = nil
            renderLatex(tabID: tabID)
            return
        }

        let returnMode = tabs[index].latexEditSession?.splitReturnMode ?? .source
        tabs[index].latexEditSession?.splitReturnMode = returnMode
        tabs[index].selectPresentationMode(.split)
        renderLatex(tabID: tabID)
    }

}
