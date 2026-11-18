import AppKit
import BPViewerCore
@preconcurrency import PDFKit
import SwiftUI

enum PDFPreviewUpdatePolicy {
    static func shouldSynchronizeReadingPosition(afterFindNavigationHandled handled: Bool) -> Bool {
        !handled
    }

    static func pageIndexToApply(
        documentChanged: Bool,
        requestedPageIndex: Int?,
        pageIndex: Int
    ) -> Int? {
        if let requestedPageIndex { return requestedPageIndex }
        return documentChanged ? pageIndex : nil
    }
}

struct PDFPreviewView: View {
    let data: Data
    let zoom: Double
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let pageIndex: Int
    let readingPosition: PDFReadingPosition?
    let onReadingPositionChanged: (PDFReadingPosition) -> Void
    @Binding var isOutlineVisible: Bool
    let isSnapshotCaptureActive: Bool
    let onSnapshotCancel: () -> Void
    let onSnapshotCapture: (NSImage) -> Void
    let onNavigate: ((URL) -> Void)?
    let onDoubleClick: ((Int, CGPoint) -> Void)?
    @State private var requestedPageIndex: Int?
    @State private var selectedOutlineID: String?

    init(
        data: Data,
        zoom: Double,
        findQuery: String,
        findRequestID: Int,
        findBackwards: Bool,
        isFindTarget: Bool,
        onFindFocus: @escaping @MainActor @Sendable () -> Void,
        onFindMatchCount: @escaping @MainActor @Sendable (Int) -> Void,
        pageIndex: Int,
        readingPosition: PDFReadingPosition?,
        onReadingPositionChanged: @escaping (PDFReadingPosition) -> Void,
        isOutlineVisible: Binding<Bool>,
        isSnapshotCaptureActive: Bool,
        onSnapshotCancel: @escaping () -> Void,
        onSnapshotCapture: @escaping (NSImage) -> Void,
        onNavigate: ((URL) -> Void)? = nil,
        onDoubleClick: ((Int, CGPoint) -> Void)? = nil
    ) {
        self.data = data
        self.zoom = zoom
        self.findQuery = findQuery
        self.findRequestID = findRequestID
        self.findBackwards = findBackwards
        self.isFindTarget = isFindTarget
        self.onFindFocus = onFindFocus
        self.onFindMatchCount = onFindMatchCount
        self.pageIndex = pageIndex
        self.readingPosition = readingPosition
        self.onReadingPositionChanged = onReadingPositionChanged
        self._isOutlineVisible = isOutlineVisible
        self.isSnapshotCaptureActive = isSnapshotCaptureActive
        self.onSnapshotCancel = onSnapshotCancel
        self.onSnapshotCapture = onSnapshotCapture
        self.onNavigate = onNavigate
        self.onDoubleClick = onDoubleClick
    }

    private var outlineEntries: [PDFOutlineEntry] {
        PDFOutlineEntry.entries(from: data)
    }

    private var outlineItems: [DocumentOutlineItem] {
        outlineEntries.map {
            DocumentOutlineItem(
                id: $0.id,
                title: $0.title,
                level: $0.level,
                isSelectable: $0.pageIndex != nil
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !outlineItems.isEmpty {
                DocumentOutlineToolbar(
                    isVisible: isOutlineVisible,
                    onToggle: { isOutlineVisible.toggle() }
                )
            }

            HStack(spacing: 0) {
                if isOutlineVisible {
                    DocumentOutlineSidebar(
                        entries: outlineItems,
                        selectedID: selectedOutlineID
                    ) { item in
                        guard let pageIndex = outlineEntries.first(where: { $0.id == item.id })?.pageIndex else {
                            return
                        }
                        selectedOutlineID = item.id
                        requestedPageIndex = pageIndex
                    }
                    Divider()
                }

                ZStack {
                    PDFKitPreviewView(
                        data: data,
                        zoom: zoom,
                        findQuery: findQuery,
                        findRequestID: findRequestID,
                        findBackwards: findBackwards,
                        isFindTarget: isFindTarget,
                        onFindFocus: onFindFocus,
                        onFindMatchCount: onFindMatchCount,
                        pageIndex: pageIndex,
                        requestedPageIndex: requestedPageIndex,
                        readingPosition: readingPosition,
                        onReadingPositionChanged: { position in
                            if requestedPageIndex == position.pageIndex {
                                requestedPageIndex = nil
                            }
                            onReadingPositionChanged(position)
                        },
                        onNavigate: onNavigate,
                        onDoubleClick: onDoubleClick
                    )
                    if isSnapshotCaptureActive {
                        SnapshotSelectionOverlay(
                            onCancel: onSnapshotCancel,
                            onCapture: onSnapshotCapture
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
}

private struct PDFOutlineEntry: Identifiable {
    let id: String
    let title: String
    let level: Int
    let pageIndex: Int?

    static func entries(from data: Data) -> [PDFOutlineEntry] {
        guard let document = PDFDocument(data: data),
              let root = document.outlineRoot else {
            return []
        }
        return entries(from: root, document: document, prefix: "outline", level: 0)
    }

    private static func entries(
        from outline: PDFOutline,
        document: PDFDocument,
        prefix: String,
        level: Int
    ) -> [PDFOutlineEntry] {
        (0..<outline.numberOfChildren).flatMap { offset -> [PDFOutlineEntry] in
            guard let child = outline.child(at: offset) else { return [] }
            let id = "\(prefix)-\(offset)"
            let children = entries(from: child, document: document, prefix: id, level: level + 1)
            let title = child.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pageIndex: Int? = child.destination.flatMap { destination in
                guard let page = destination.page else { return nil }
                return document.index(for: page)
            }
            guard !title.isEmpty || pageIndex != nil || !children.isEmpty else {
                return []
            }

            let entry = PDFOutlineEntry(
                id: id,
                title: title.isEmpty ? "Untitled" : title,
                level: level,
                pageIndex: pageIndex,
            )
            return [entry] + children
        }
    }
}
