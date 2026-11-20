import AppKit
import ViewerCore

extension NSWindow {
    /// Sizes the content in points, keeping the top-left corner where possible.
    func applyOpeningSize(_ openingSize: WindowOpeningSize) {
        let screen = self.screen ?? NSScreen.main
        let available = screen.map { contentRect(forFrameRect: $0.visibleFrame).size }
            ?? CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let fitted = openingSize.fitted(toWidth: Double(available.width), height: Double(available.height))
        let contentSize = CGSize(width: fitted.width, height: fitted.height)
        let frameSize = frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
        let targetFrame = CGRect(
            x: frame.minX, y: frame.maxY - frameSize.height,
            width: frameSize.width, height: frameSize.height
        )
        setFrame(constrainFrameRect(targetFrame, to: screen), display: false)
    }
}
