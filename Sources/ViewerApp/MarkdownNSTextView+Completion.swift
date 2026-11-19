import AppKit
import ViewerCore

extension MarkdownNSTextView {
    func drawInlineCompletion() {
        guard usesMarkdownInlineCompletion,
              let inlineCompletion,
              inlineCompletion.wordRange.location + inlineCompletion.wordRange.length
                == selectedRange().location,
              !inlineCompletion.suffix.isEmpty,
              let window else { return }

        let screenRect = firstRect(
            forCharacterRange: NSRange(location: selectedRange().location, length: 0),
            actualRange: nil
        )
        guard !screenRect.isEmpty else { return }
        let caretRect = convert(window.convertFromScreen(screenRect), from: nil)
        let ghost = NSAttributedString(
            string: inlineCompletion.suffix,
            attributes: [
                .font: font ?? NSFont.systemFont(ofSize: SourceEditorLayout.editorFontSize),
                .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.55)
            ]
        )
        ghost.draw(at: NSPoint(x: caretRect.minX, y: caretRect.minY))
    }

    @discardableResult
    func acceptInlineCompletion(appendSpace: Bool) -> Bool {
        guard let inlineCompletion,
              selectedRange().length == 0,
              selectedRange().location == inlineCompletion.wordRange.location
                + inlineCompletion.wordRange.length,
              ((string as NSString).substring(with: inlineCompletion.wordRange)
                == inlineCompletion.prefix) else { return false }

        let insertion = inlineCompletion.suffix + (appendSpace ? " " : "")
        let range = NSRange(location: selectedRange().location, length: 0)
        guard shouldChangeText(in: range, replacementString: insertion) else { return false }
        self.inlineCompletion = nil
        suppressInlineCompletionAfterAcceptance = !appendSpace
        replaceCharacters(in: range, with: insertion)
        setSelectedRange(NSRange(location: range.location + (insertion as NSString).length, length: 0))
        didChangeText()
        return true
    }
}
