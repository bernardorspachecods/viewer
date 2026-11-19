import ViewerCore
import SwiftUI

extension PreviewPane {
    func pdfPreview(pdfData: Data) -> some View {
        VStack(spacing: 0) {
            PDFPreviewView(
                data: pdfData,
                zoom: tab.previewZoom,
                findQuery: paneFindQuery,
                findRequestID: model.findRequestID,
                findBackwards: model.findBackwards,
                isFindTarget: isFocusedPane && model.findTarget == .preview,
                onFindFocus: { model.setFindTarget(.preview) },
                onFindMatchCount: paneFindMatchCount,
                pageIndex: tab.previewPageIndex,
                readingPosition: tab.pdfReadingPosition,
                onReadingPositionChanged: { position in
                    model.updatePDFReadingPosition(position, forTabID: tab.id)
                },
                isOutlineVisible: Binding(
                    get: { model.tabs.first(where: { $0.id == tab.id })?.isOutlineVisible ?? false },
                    set: { model.setOutlineVisible($0, forTabID: tab.id) }
                ),
                isSnapshotCaptureActive: model.isSnapshotCaptureActive && model.activeTabID == tab.id,
                onSnapshotCancel: model.cancelSnapshotCapture,
                onSnapshotCapture: { image in
                    model.finishSnapshotCapture(image, forTabID: tab.id)
                }
            )
        }
    }

    func imagePreview(imageData: Data) -> some View {
        ImagePreviewView(
            data: imageData,
            zoom: tab.previewZoom,
            previewRevision: tab.previewUpdatedAt,
            isSnapshotCaptureActive: model.isSnapshotCaptureActive && model.activeTabID == tab.id,
            onSnapshotCancel: model.cancelSnapshotCapture,
            onSnapshotCapture: { image in
                model.finishSnapshotCapture(image, forTabID: tab.id)
            },
            onZoomChanged: model.setPreviewZoomFromGesture
        )
    }

    var docxPreview: some View {
        DocxPreviewView(
            url: tab.url,
            zoom: tab.previewZoom,
            previewRevision: tab.previewUpdatedAt,
            findQuery: paneFindQuery,
            findRequestID: model.findRequestID,
            findBackwards: model.findBackwards,
            isFindTarget: isFocusedPane && model.findTarget == .preview,
            onFindFocus: { model.setFindTarget(.preview) },
            onFindMatchCount: paneFindMatchCount,
            onZoomChanged: { value in
                model.setPreviewZoomFromGesture(value)
            }
        )
    }
}
