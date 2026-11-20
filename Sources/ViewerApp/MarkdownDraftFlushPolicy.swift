import AppKit

/// Decides whether `⌘S` and `⌘Z` copy the focused text view's text into the Markdown draft
/// first. That copy exists for the raw source editors, which push edits to the draft late.
enum MarkdownDraftFlushPolicy {
    static func shouldFlush(from textView: NSTextView) -> Bool {
        guard textView.isEditable else { return false }
        // The search field's editor is an editable text view, but its text is not the document.
        if textView.isFieldEditor { return false }
        // The Markdown editor shows display text (an alias link `[[Page|Alias]]` is drawn as
        // `[[Page]]`), so its `string` would rewrite the document. It already pushes the
        // storage text to the draft through its binding.
        return !String(describing: type(of: textView)).contains("NativeTextView")
    }
}
