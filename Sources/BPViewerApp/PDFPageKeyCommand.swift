import AppKit

/// A page step requested by an arrow key in a PDF preview.
enum PDFPageKeyCommand: Equatable {
    case nextPage
    case previousPage

    /// Left and right arrows only. ⌘, ⌥, ⌃ and ⇧ combinations keep their own meaning
    /// (selection, word or line movement, shortcuts), so they map to nothing. The
    /// numeric-pad and function flags that macOS sets on arrow keys are ignored.
    static func command(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> PDFPageKeyCommand? {
        guard modifiers.intersection([.command, .option, .control, .shift]).isEmpty else { return nil }
        switch keyCode {
        case 124: return .nextPage
        case 123: return .previousPage
        default: return nil
        }
    }

    /// The page to show for this step, or nil at the first or last page.
    func targetPageIndex(from currentIndex: Int, pageCount: Int) -> Int? {
        guard pageCount > 0 else { return nil }
        let target = self == .nextPage ? currentIndex + 1 : currentIndex - 1
        guard (0..<pageCount).contains(target) else { return nil }
        return target
    }
}
