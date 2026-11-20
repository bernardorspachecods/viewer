import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Payload of a dragged document tab. A custom type keeps web views and text editors from
/// swallowing the drag the way they would a plain string, so it reaches the SwiftUI drop targets.
struct TabDragItem: Codable, Transferable {
    let tabID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .viewerTab)
    }
}

extension UTType {
    static let viewerTab = UTType(exportedAs: "com.bernardopacheco.viewer.tab", conformingTo: .data)
}
