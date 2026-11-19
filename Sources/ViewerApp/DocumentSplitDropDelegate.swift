import SwiftUI
import UniformTypeIdentifiers
import ViewerCore

/// Accepts a dragged tab anywhere on the document surface and splits the view on the side it lands.
struct DocumentSplitDropDelegate: DropDelegate {
    let model: AppModel
    let surfaceWidth: Double
    @Binding var hoveredSide: DocumentSplitSide?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.viewerTab])
    }

    func dropEntered(info: DropInfo) {
        updateHoveredSide(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHoveredSide(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        hoveredSide = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.viewerTab]).first else { return false }
        let side = DocumentSplitDropZone.side(forX: Double(info.location.x), width: surfaceWidth)
        hoveredSide = nil
        _ = provider.loadTransferable(type: TabDragItem.self) { result in
            guard case .success(let item) = result else { return }
            Task { @MainActor in
                model.enterSplit(dropping: item.tabID, on: side)
            }
        }
        return true
    }

    private func updateHoveredSide(_ info: DropInfo) {
        guard info.hasItemsConforming(to: [.viewerTab]) else {
            hoveredSide = nil
            return
        }
        hoveredSide = DocumentSplitDropZone.side(forX: Double(info.location.x), width: surfaceWidth)
    }
}
