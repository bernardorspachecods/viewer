import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    var canCaptureActivePreview: Bool {
        guard let activeTab else { return false }
        return activeTab.previewHTML != nil
            || activeTab.previewJSON != nil
            || activeTab.previewCSV != nil
            || activeTab.previewPDFData != nil
            || activeTab.previewImageData != nil
    }

    func startSnapshotCapture() {
        guard canCaptureActivePreview else { return }
        isSnapshotCaptureActive = true
    }

    func cancelSnapshotCapture() {
        isSnapshotCaptureActive = false
    }

    func finishSnapshotCapture(_ image: NSImage, forTabID tabID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }),
              let rootURL,
              image.size.width > 1,
              image.size.height > 1 else {
            cancelSnapshotCapture()
            return
        }

        let recordID = UUID().uuidString
        do {
            let artifactURL = try snapshotArtifactStore.save(image, id: recordID)
            let record = SnapshotRecord(
                id: recordID,
                documentPath: workspaceSession.documentKey(for: tab.url),
                title: tab.title,
                artifactPath: artifactURL.path,
                createdAt: Date()
            )
            workspaceSession.addSnapshot(record, for: rootURL)
            persistState()
            snapshotWindowManager.open(
                record: record,
                image: image,
                above: NSApp.keyWindow ?? NSApp.windows.first
            )
        } catch {
            // A failed snapshot must not leave capture mode active.
        }
        cancelSnapshotCapture()
    }

    func removeSnapshot(id: String) {
        let artifactPath = workspaceSession.removeSnapshot(id: id)
        if let artifactPath {
            snapshotArtifactStore.remove(at: URL(fileURLWithPath: artifactPath))
        }
        persistState()
    }

    func restoreSnapshots(for rootURL: URL) {
        let records = workspaceSession.snapshots(for: rootURL)
        guard !records.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.rootURL?.standardizedFileURL == rootURL.standardizedFileURL else { return }
            for record in records {
                guard let image = self.snapshotArtifactStore.load(
                    from: URL(fileURLWithPath: record.artifactPath)
                ) else { continue }
                self.snapshotWindowManager.open(
                    record: record,
                    image: image,
                    above: NSApp.keyWindow ?? NSApp.windows.first
                )
            }
        }
    }

}
