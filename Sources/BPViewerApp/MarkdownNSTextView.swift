import AppKit
import BPViewerCore

final class MarkdownNSTextView: NSTextView {
    struct LineFragment {
        let physicalLine: Int
        let rect: NSRect
        let baselineY: CGFloat
    }

    var onEscape: (() -> Void)?
    var onMarkdownShortcut: ((MarkdownInlineFormatting) -> Void)?
    var markdownAutoListContinuationEnabled = false
    var onFindFocus: (() -> Void)?
    var onDoubleClick: ((NSEvent) -> Void)?
    var usesMarkdownInlineCompletion = false
    var suppressInlineCompletionAfterAcceptance = false
    var inlineCompletion: MarkdownInlineCompletion? {
        didSet {
            guard oldValue != inlineCompletion else { return }
            needsDisplay = true
        }
    }
    var fixedEditorParagraphStyle: NSParagraphStyle? {
        didSet {
            guard let fixedEditorParagraphStyle else { return }
            if let oldValue,
               oldValue.minimumLineHeight == fixedEditorParagraphStyle.minimumLineHeight,
               oldValue.maximumLineHeight == fixedEditorParagraphStyle.maximumLineHeight,
               oldValue.lineHeightMultiple == fixedEditorParagraphStyle.lineHeightMultiple,
               oldValue.lineSpacing == fixedEditorParagraphStyle.lineSpacing,
               oldValue.paragraphSpacing == fixedEditorParagraphStyle.paragraphSpacing,
               oldValue.paragraphSpacingBefore == fixedEditorParagraphStyle.paragraphSpacingBefore {
                return
            }
            defaultParagraphStyle = fixedEditorParagraphStyle
            var attributes = typingAttributes
            attributes[.paragraphStyle] = fixedEditorParagraphStyle
            typingAttributes = attributes
        }
    }
    var showsLineNumbers = false {
        didSet {
            guard oldValue != showsLineNumbers else { return }
            needsDisplay = true
        }
    }
    var lineNumberGutterWidth: CGFloat = 0 {
        didSet {
            guard oldValue != lineNumberGutterWidth else { return }
            needsDisplay = true
        }
    }
    var lineNumberFontSize: CGFloat = 11 {
        didSet {
            guard oldValue != lineNumberFontSize else { return }
            needsDisplay = true
        }
    }
    var lineNumberOverrides: [Int: Int] = [:] {
        didSet {
            guard oldValue != lineNumberOverrides else { return }
            needsDisplay = true
        }
    }
    var lineHighlights: [Int: DocumentDiffCellKind] = [:] {
        didSet {
            guard oldValue != lineHighlights else { return }
            needsDisplay = true
        }
    }

    var cachedLineStarts: [Int]?
    var pendingLineStartEdit: (range: NSRange, replacement: String)?
    private var pendingParagraphStyleEdit: (range: NSRange, replacement: String)?

    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()
        if becameFirstResponder {
            onFindFocus?()
        }
        return becameFirstResponder
    }

    override func mouseDown(with event: NSEvent) {
        inlineCompletion = nil
        onFindFocus?()
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawInlineCompletion()
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        let fragments = lineFragments(in: visibleRect)
        drawLineHighlights(in: rect, fragments: fragments)
        drawLineNumberSeparator()
        if showsLineNumbers {
            drawLineNumbers(in: rect, fragments: fragments)
        }
    }

    override func shouldChangeText(
        in affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        let shouldChange = super.shouldChangeText(
            in: affectedCharRange,
            replacementString: replacementString
        )
        if shouldChange, cachedLineStarts != nil {
            pendingLineStartEdit = (
                affectedCharRange,
                replacementString ?? ""
            )
        }
        if shouldChange {
            pendingParagraphStyleEdit = (
                affectedCharRange,
                replacementString ?? ""
            )
        }
        return shouldChange
    }

    override func didChangeText() {
        super.didChangeText()
        if let edit = pendingParagraphStyleEdit {
            normalizeEditedParagraphs(edit)
        }
        pendingParagraphStyleEdit = nil
        guard let edit = pendingLineStartEdit,
              let starts = cachedLineStarts else {
            invalidateLineNumberCache()
            needsDisplay = true
            return
        }
        pendingLineStartEdit = nil
        cachedLineStarts = updatedLineStarts(
            starts,
            replacing: edit.range,
            with: edit.replacement
        )
        // NSTextView may invalidate only the edited glyph area. The gutter is
        // drawn in drawBackground, so explicitly refresh it with each edit.
        needsDisplay = true
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if usesMarkdownInlineCompletion,
           isEditable,
           modifiers.isEmpty,
           event.keyCode == 48,
           acceptInlineCompletion(appendSpace: false) {
            return
        }
        if usesMarkdownInlineCompletion,
           isEditable,
           modifiers.isEmpty,
           event.characters == " ",
           acceptInlineCompletion(appendSpace: true) {
            return
        }
        if markdownAutoListContinuationEnabled,
           isEditable,
           (event.keyCode == 36 || event.keyCode == 76),
           modifiers.intersection([.command, .option, .control, .shift]).isEmpty,
           !hasMarkedText(),
           selectedRange().length == 0,
           continueMarkdownListIfNeeded() {
            return
        }
        if modifiers.contains(.command),
           !modifiers.contains(.option),
           !modifiers.contains(.control),
           let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "b":
                if let onMarkdownShortcut {
                    onMarkdownShortcut(.bold)
                    return
                }
            case "i":
                if let onMarkdownShortcut {
                    onMarkdownShortcut(.italic)
                    return
                }
            case "k":
                if let onMarkdownShortcut {
                    onMarkdownShortcut(.code)
                    return
                }
            default:
                break
            }
        }
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?(event)
        }
        super.mouseUp(with: event)
    }
}
