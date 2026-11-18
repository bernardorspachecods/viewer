import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    func startWatchingActiveFiles(_ urls: [URL]) {
        guard let activeTabID else { return }
        activeDocumentWatcher.start(
            tabID: activeTabID,
            urls: urls.filter(\.isFileURL)
        )
    }

    func stopWatchingActiveFiles() {
        activeDocumentWatcher.stop()
    }

    func restartWatchingActiveFiles(_ urls: [URL]) {
        startWatchingActiveFiles(urls)
    }

    func handleActiveDocumentChange(_ change: ActiveDocumentChange) {
        guard activeTabID == change.tabID,
              tabs.contains(where: { $0.id == change.tabID }) else { return }

        Task { @MainActor [weak self] in
            guard let self,
                  self.activeTabID == change.tabID,
                  let currentTab = self.tabs.first(where: { $0.id == change.tabID }) else { return }

            switch currentTab.kind {
            case .latex:
                if currentTab.editableSourceURL.standardizedFileURL == change.url.standardizedFileURL,
                   currentTab.latexEditSession?.isEditing == true {
                    await self.handleExternalLatexChange(tabID: change.tabID)
                } else {
                    self.renderLatex(tabID: change.tabID)
                }
            case .json:
                if currentTab.editableSourceURL.standardizedFileURL == change.url.standardizedFileURL,
                   currentTab.jsonEditSession?.isEditing == true {
                    await self.handleExternalJSONChange(tabID: change.tabID)
                } else {
                    self.renderJSON(tabID: change.tabID)
                }
            case .csv:
                if let session = currentTab.csvEditSession,
                   session.currentSource != session.baseSource {
                    await self.handleExternalCSVChange(tabID: change.tabID)
                } else {
                    self.renderCSV(tabID: change.tabID)
                }
            case .pdf:
                self.renderPDF(tabID: change.tabID)
            case .docx:
                self.refreshDocx(tabID: change.tabID)
            case .image:
                self.renderImage(tabID: change.tabID)
            case .markdown:
                if currentTab.editableSourceURL.standardizedFileURL == change.url.standardizedFileURL,
                   currentTab.markdownEditSession?.isEditing == true {
                    await self.handleExternalMarkdownChange(tabID: change.tabID)
                } else {
                    self.renderMarkdown(tabID: change.tabID)
                }
            case .other:
                break
            }
        }
    }

    func handleExternalMarkdownChange(tabID: String) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].markdownEditSession,
              session.isEditing else {
            renderMarkdown(tabID: tabID)
            return
        }

        do {
            let externalSource = try await documentEditCoordinator.readSource(at: tabs[index].url)
            guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
                  tabs[currentIndex].markdownEditSession?.currentSource == session.currentSource else { return }

            guard externalSource != session.baseSource else { return }

            if session.currentSource == session.baseSource {
                tabs[currentIndex].markdownSource = externalSource
                tabs[currentIndex].markdownBlocks = MarkdownBlockDocument(source: externalSource).blocks
                var refreshedSession = session
                refreshedSession.baseSource = externalSource
                refreshedSession.currentSource = externalSource
                refreshedSession.saveState = .saved
                refreshedSession.conflict = nil
                tabs[currentIndex].markdownEditSession = refreshedSession
                if tabs[currentIndex].diffSession?.mode == .savedOnDisk {
                    tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
                        label: "Saved on Disk",
                        source: externalSource
                    )
                }
                renderMarkdown(tabID: tabID)
                return
            }

            if tabs[currentIndex].diffSession?.mode == .savedOnDisk {
                tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
                    label: "Saved on Disk",
                    source: externalSource
                )
            }

            tabs[currentIndex].markdownEditSession?.saveState = .conflict
            tabs[currentIndex].markdownEditSession?.isEditing = true
            tabs[currentIndex].markdownEditSession?.conflict = MarkdownConflict(
                localSource: session.currentSource,
                externalSource: externalSource,
                blockIDs: []
            )
        } catch {
            tabs[index].markdownEditSession?.saveState = .failed
            tabs[index].markdownEditSession?.isEditing = true
            tabs[index].errorMessage = error.localizedDescription
        }
    }

    func handleExternalJSONChange(tabID: String) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].jsonEditSession,
              session.isEditing else {
            renderJSON(tabID: tabID)
            return
        }

        do {
            let externalSource = try await documentEditCoordinator.readSource(at: tabs[index].url)
            guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
                  tabs[currentIndex].jsonEditSession?.currentSource == session.currentSource else { return }

            guard externalSource != session.baseSource else { return }

            if session.currentSource == session.baseSource {
                tabs[currentIndex].jsonSource = externalSource
                var refreshedSession = session
                refreshedSession.baseSource = externalSource
                refreshedSession.currentSource = externalSource
                refreshedSession.saveState = .saved
                refreshedSession.conflict = nil
                tabs[currentIndex].jsonEditSession = refreshedSession
                if tabs[currentIndex].diffSession?.mode == .savedOnDisk {
                    tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
                        label: "Saved on Disk",
                        source: externalSource
                    )
                }
                renderJSON(tabID: tabID)
                return
            }

            if tabs[currentIndex].diffSession?.mode == .savedOnDisk {
                tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
                    label: "Saved on Disk",
                    source: externalSource
                )
            }

            tabs[currentIndex].jsonEditSession?.saveState = .conflict
            tabs[currentIndex].jsonEditSession?.isEditing = true
            tabs[currentIndex].jsonEditSession?.conflict = MarkdownConflict(
                localSource: session.currentSource,
                externalSource: externalSource,
                blockIDs: []
            )
        } catch {
            tabs[index].jsonEditSession?.saveState = .failed
            tabs[index].jsonEditSession?.isEditing = true
            tabs[index].errorMessage = error.localizedDescription
        }
    }

    func handleExternalLatexChange(tabID: String) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].latexEditSession,
              session.isEditing else {
            renderLatex(tabID: tabID)
            return
        }

        do {
            let externalSource = try await documentEditCoordinator.readSource(at: tabs[index].editableSourceURL)
            guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
                  tabs[currentIndex].latexEditSession?.currentSource == session.currentSource else { return }

            guard externalSource != session.baseSource else { return }

            if session.currentSource == session.baseSource {
                var refreshedSession = session
                refreshedSession.baseSource = externalSource
                refreshedSession.currentSource = externalSource
                refreshedSession.saveState = .saved
                refreshedSession.conflict = nil
                tabs[currentIndex].latexEditSession = refreshedSession
                if tabs[currentIndex].diffSession?.mode == .savedOnDisk {
                    tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
                        label: "Saved on Disk",
                        source: externalSource
                    )
                }
                renderLatex(tabID: tabID)
                return
            }

            if tabs[currentIndex].diffSession?.mode == .savedOnDisk {
                tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
                    label: "Saved on Disk",
                    source: externalSource
                )
            }
            tabs[currentIndex].latexEditSession?.saveState = .conflict
            tabs[currentIndex].latexEditSession?.isEditing = true
            tabs[currentIndex].latexEditSession?.conflict = MarkdownConflict(
                localSource: session.currentSource,
                externalSource: externalSource,
                blockIDs: []
            )
        } catch {
            tabs[index].latexEditSession?.saveState = .failed
            tabs[index].latexEditSession?.isEditing = true
            tabs[index].errorMessage = error.localizedDescription
        }
    }

    private func handleExternalCSVChange(tabID: String) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let session = tabs[index].csvEditSession,
              session.currentSource != session.baseSource else {
            renderCSV(tabID: tabID)
            return
        }

        do {
            let externalSource = try await documentEditCoordinator.readSource(at: tabs[index].url)
            guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }),
                  tabs[currentIndex].csvEditSession?.currentSource == session.currentSource else { return }
            if externalSource == session.baseSource {
                tabs[currentIndex].csvEditSession?.saveState = .unsaved
            } else {
                tabs[currentIndex].csvEditSession?.saveState = .conflict
                tabs[currentIndex].csvEditSession?.conflict = MarkdownConflict(
                    localSource: session.currentSource,
                    externalSource: externalSource,
                    blockIDs: []
                )
            }
        } catch {
            tabs[index].csvEditSession?.saveState = .failed
            tabs[index].errorMessage = error.localizedDescription
        }
    }

    private func refreshDiskDiffBaseline(tabID: String) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].diffSession?.mode == .savedOnDisk else { return }
        guard let source = try? await documentEditCoordinator.readSource(at: tabs[index].editableSourceURL),
              let currentIndex = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[currentIndex].diffSession?.baseline = DocumentDiffBaseline(
            label: "Saved on Disk",
            source: source
        )
    }

}
