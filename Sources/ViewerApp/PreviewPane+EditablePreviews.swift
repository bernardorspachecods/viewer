import ViewerCore
import SwiftUI

extension PreviewPane {
    func markdownPreview(html: String) -> some View {
        VStack(spacing: 0) {
            MarkdownPreviewView(
                html: html,
                baseURL: tab.previewBaseURL ?? tab.url.deletingLastPathComponent(),
                documentID: tab.id,
                previewRevision: tab.previewUpdatedAt,
                outline: tab.markdownOutline,
                editingSession: tab.markdownEditSession?.isEditing == true
                    || tab.markdownEditSession?.conflict != nil
                    ? tab.markdownEditSession
                    : nil,
                diffSession: tab.diffSession,
                presentationMode: tab.presentationMode,
                onNavigate: model.openPreviewURL,
                onMarkdownTextChanged: { text in
                    model.updateMarkdownEditing(
                        tabID: tab.id,
                        text: text,
                        rebuildBlocks: false
                    )
                },
                onToggleMarkdownEditor: {
                    model.toggleMarkdownEditor(tabID: tab.id)
                },
                onUndo: {
                    _ = model.undoMarkdownEdit()
                },
                onRedo: {
                    _ = model.redoMarkdownEdit()
                },
                onToggleSplitView: {
                    model.toggleMarkdownSplitView(tabID: tab.id)
                },
                onToggleDiff: { mode in
                    model.toggleDocumentDiff(mode: mode, tabID: tab.id)
                },
                onEndMarkdownEditing: {
                    model.endMarkdownEditing(tabID: tab.id)
                },
                onSaveMarkdownEditing: {
                    Task { @MainActor in
                        _ = await model.saveMarkdownEditing(tabID: tab.id)
                    }
                },
                onDiscardMarkdownEditing: {
                    model.discardEditing(tabID: tab.id)
                },
                onDiscardGitChanges: {
                    model.requestDiscardGitChanges(tabID: tab.id)
                },
                onKeepLocalMarkdownEdit: {
                    model.keepLocalMarkdownEdit(tabID: tab.id)
                },
                onUseExternalMarkdownEdit: {
                    model.useExternalMarkdownEdit(tabID: tab.id)
                },
                zoom: tab.previewZoom,
                findQuery: model.findQuery,
                findRequestID: model.findRequestID,
                findBackwards: model.findBackwards,
                findTarget: model.findTarget,
                onFindTargetChanged: model.setFindTarget,
                onFindMatchCount: model.setFindMatchCount,
                anchorRequest: tab.previewAnchorRequest,
                onAnchorRequestApplied: { requestID in
                    model.clearPreviewAnchorRequest(requestID, forTabID: tab.id)
                },
                isOutlineVisible: Binding(
                    get: { model.tabs.first(where: { $0.id == tab.id })?.isOutlineVisible ?? false },
                    set: { model.setOutlineVisible($0, forTabID: tab.id) }
                ),
                outlineWidth: tab.outlineWidth,
                onOutlineWidthChanged: { width in
                    model.resizeOutline(to: width, forTabID: tab.id)
                },
                onOutlineWidthChangeEnded: {
                    model.finishOutlineResize(forTabID: tab.id)
                },
                readingPosition: tab.markdownReadingPosition,
                onReadingPositionChanged: { position in
                    model.updateMarkdownReadingPosition(position, forTabID: tab.id)
                },
                isSnapshotCaptureActive: model.isSnapshotCaptureActive && model.activeTabID == tab.id,
                onSnapshotCancel: model.cancelSnapshotCapture,
                onSnapshotCapture: { image in
                    model.finishSnapshotCapture(image, forTabID: tab.id)
                },
            )
        }
    }

    func jsonPreview(source: String) -> some View {
        VStack(spacing: 0) {
            JSONPreviewView(
                source: source,
                zoom: tab.previewZoom,
                cursorUTF8Offset: tab.jsonCursorUTF8Offset,
                editingSession: tab.jsonEditSession?.isEditing == true
                    || tab.jsonEditSession?.conflict != nil
                    ? tab.jsonEditSession
                    : nil,
                diffSession: tab.diffSession,
                presentationMode: tab.presentationMode,
                onBeginEditing: { offset in
                    model.beginJSONEditing(
                        tabID: tab.id,
                        previewUTF8Offset: offset
                    )
                },
                onSourceChanged: { text in
                    model.updateJSONEditing(
                        tabID: tab.id,
                        text: text,
                        validate: false
                    )
                },
                onUndo: {
                    _ = model.undoJSONEdit()
                },
                onRedo: {
                    _ = model.redoJSONEdit()
                },
                onToggleDiff: { mode in
                    model.toggleDocumentDiff(mode: mode, tabID: tab.id)
                },
                onEndEditing: { source in
                    model.endJSONEditing(tabID: tab.id, source: source)
                },
                onDiscardEditing: {
                    model.discardEditing(tabID: tab.id)
                },
                onDiscardGitChanges: {
                    model.requestDiscardGitChanges(tabID: tab.id)
                },
                onKeepLocalEdit: {
                    model.keepLocalJSONEdit(tabID: tab.id)
                },
                onUseExternalEdit: {
                    model.useExternalJSONEdit(tabID: tab.id)
                },
                isSnapshotCaptureActive: model.isSnapshotCaptureActive && model.activeTabID == tab.id,
                onSnapshotCancel: model.cancelSnapshotCapture,
                onSnapshotCapture: { image in
                    model.finishSnapshotCapture(image, forTabID: tab.id)
                },
                findQuery: model.findQuery,
                findRequestID: model.findRequestID,
                findBackwards: model.findBackwards,
                findTarget: model.findTarget,
                onFindTargetChanged: model.setFindTarget,
                onFindMatchCount: model.setFindMatchCount
            )
        }
    }

    func csvPreview(document: CSVDocument) -> some View {
        CSVPreviewView(
            document: document,
            editingSession: tab.csvEditSession,
            zoom: tab.previewZoom,
            previewRevision: tab.previewUpdatedAt,
            findQuery: model.findQuery,
            findRequestID: model.findRequestID,
            findBackwards: model.findBackwards,
            isFindTarget: model.findTarget == .preview,
            onFindFocus: { model.setFindTarget(.preview) },
            onFindMatchCount: model.setFindMatchCount,
            onCellChanged: { row, column, value in
                model.updateCSVEditing(
                    tabID: tab.id,
                    row: row,
                    column: column,
                    value: value
                )
            },
            onUndo: {
                _ = model.undoCSVEdit()
            },
            onRedo: {
                _ = model.redoCSVEdit()
            },
            onSaveEditing: {
                Task { @MainActor in
                    _ = await model.saveCSVEditing(tabID: tab.id)
                }
            },
            onDiscardEditing: {
                model.discardEditing(tabID: tab.id)
            },
            onKeepLocalEdit: {
                model.keepLocalCSVEdit(tabID: tab.id)
            },
            onUseExternalEdit: {
                model.useExternalCSVEdit(tabID: tab.id)
            },
            isSnapshotCaptureActive: model.isSnapshotCaptureActive && model.activeTabID == tab.id,
            onSnapshotCancel: model.cancelSnapshotCapture,
            onSnapshotCapture: { image in
                model.finishSnapshotCapture(image, forTabID: tab.id)
            }
        )
    }

    func latexPreview(pdfData: Data) -> some View {
        LatexPreviewView(
            data: pdfData,
            documentID: tab.id,
            sourceURL: tab.editableSourceURL,
            editingSession: tab.latexEditSession?.isEditing == true
                || tab.latexEditSession?.conflict != nil
                ? tab.latexEditSession
                : nil,
            cursorUTF8Offset: tab.latexCursorUTF8Offset,
            diffSession: tab.diffSession,
            presentationMode: tab.presentationMode,
            zoom: tab.previewZoom,
            onNavigate: model.openPreviewURL,
            onBeginEditing: { pageIndex, point in
                model.beginLatexEditing(
                    tabID: tab.id,
                    pageIndex: pageIndex,
                    pointFromTopLeft: point
                )
            },
            onOpenCitation: { sourceOffset in
                model.openLatexCitation(
                    tabID: tab.id,
                    sourceOffset: sourceOffset
                )
            },
            onSourceChanged: { text in
                model.updateLatexEditing(tabID: tab.id, text: text)
            },
            onUndo: {
                _ = model.undoLatexEdit()
            },
            onRedo: {
                _ = model.redoLatexEdit()
            },
            onToggleSplitView: {
                model.toggleLatexSplitView(tabID: tab.id)
            },
            onToggleDiff: { mode in
                model.toggleDocumentDiff(mode: mode, tabID: tab.id)
            },
            onEndEditing: {
                model.endLatexEditing(tabID: tab.id)
            },
            onDiscardEditing: {
                model.discardEditing(tabID: tab.id)
            },
            onDiscardGitChanges: {
                model.requestDiscardGitChanges(tabID: tab.id)
            },
            onKeepLocalEdit: {
                model.keepLocalLatexEdit(tabID: tab.id)
            },
            onUseExternalEdit: {
                model.useExternalLatexEdit(tabID: tab.id)
            },
            findQuery: model.findQuery,
            findRequestID: model.findRequestID,
            findBackwards: model.findBackwards,
            findTarget: model.findTarget,
            onFindTargetChanged: model.setFindTarget,
            onFindMatchCount: model.setFindMatchCount,
            isOutlineVisible: Binding(
                get: { model.tabs.first(where: { $0.id == tab.id })?.isOutlineVisible ?? false },
                set: { model.setOutlineVisible($0, forTabID: tab.id) }
            ),
            pageIndex: tab.previewPageIndex,
            readingPosition: tab.pdfReadingPosition,
            onReadingPositionChanged: { position in
                model.updatePDFReadingPosition(position, forTabID: tab.id)
            },
            isSnapshotCaptureActive: model.isSnapshotCaptureActive && model.activeTabID == tab.id,
            onSnapshotCancel: model.cancelSnapshotCapture,
            onSnapshotCapture: { image in
                model.finishSnapshotCapture(image, forTabID: tab.id)
            }
        )
    }
}
