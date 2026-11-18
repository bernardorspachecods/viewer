import BPViewerCore
import Foundation

extension Runner {
    /// The shared document zoom range: values are clamped to 0.7...2.0 and keep their type.
    mutating func runDocumentZoomContracts() {
        expect(DocumentZoomLimits.clamped(0.1) == 0.7, "zoom below the minimum clamps to the minimum")
        expect(DocumentZoomLimits.clamped(3.0) == 2.0, "zoom above the maximum clamps to the maximum")
        expect(DocumentZoomLimits.clamped(1.25) == 1.25, "zoom inside the range is unchanged")
        expect(DocumentZoomLimits.clamped(CGFloat(0.7)) == CGFloat(0.7), "CGFloat zoom keeps its type")
        expect(DocumentZoomLimits.clamped(Float(2.5)) == Float(2.0), "Float zoom clamps to the maximum")
    }
}
