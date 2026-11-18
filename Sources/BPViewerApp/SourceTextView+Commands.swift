import AppKit
import BPViewerCore

extension SourceTextView {
    func applyMarkdownShortcut(
        _ formatting: MarkdownInlineFormatting,
        to textView: NSTextView,
        onSourceChanged: @escaping @MainActor @Sendable (String) -> Void
    ) {
        let source = textView.string
        let selection = textView.selectedRange()
        let result = MarkdownShortcutFormatter.apply(
            formatting,
            to: source,
            selectionUTF16Offset: selection.location,
            selectionUTF16Length: selection.length
        )
        let fullRange = NSRange(location: 0, length: (source as NSString).length)
        guard textView.shouldChangeText(in: fullRange, replacementString: result.source) else { return }
        textView.replaceCharacters(in: fullRange, with: result.source)
        textView.setSelectedRange(NSRange(
            location: result.selectionUTF16Offset,
            length: result.selectionUTF16Length
        ))
        textView.didChangeText()
        onSourceChanged(result.source)
    }

    func focus(
        _ textView: NSTextView,
        selection: NSRange?,
        attempt: Int = 0,
        onFocused: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async { [weak textView] in
            guard let textView else { return }
            guard let window = textView.window else {
                guard attempt < 10 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focus(textView, selection: selection, attempt: attempt + 1, onFocused: onFocused)
                }
                return
            }
            if let selection {
                textView.setSelectedRange(selection)
                textView.scrollRangeToVisible(selection)
            }
            window.makeFirstResponder(textView)
            onFocused?()
        }
    }
}
