import AppKit
import ViewerCore
import SwiftUI

struct SourceTextView: NSViewRepresentable {
    let source: String
    let zoom: Double
    let cursorUTF8Offset: Int?
    var cursorRequestID: Int = 0
    let isEditable: Bool
    let lineNumbers: Bool
    let lineNumberOverrides: [Int: Int]
    let lineHighlights: [Int: DocumentDiffCellKind]
    let lineSpacingBefore: [Int: CGFloat]
    let monospaced: Bool
    let syntaxHighlighting: SourceSyntaxHighlighting?
    let markdownShortcutsEnabled: Bool
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    var defersSourceChangeUpdates = false
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let onSourceChanged: @MainActor @Sendable (String) -> Void
    let onEndEditing: @MainActor @Sendable (String) -> Void
    let onDoubleClick: ((Int) -> Void)?
    var onScrollViewReady: (@MainActor (NSScrollView) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSourceChanged: onSourceChanged,
            onEndEditing: onEndEditing,
            onFindMatchCount: onFindMatchCount,
            defersSourceChangeUpdates: defersSourceChangeUpdates
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownNSTextView()
        textView.fixedEditorParagraphStyle = SourceEditorLayout.editorParagraphStyle(zoom: zoom)
        textView.onFindFocus = onFindFocus
        textView.onEscape = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView else { return }
            coordinator?.flushPendingSourceChange()
            coordinator?.onEndEditing(textView.string)
        }
        textView.onMarkdownShortcut = { [weak textView] formatting in
            guard markdownShortcutsEnabled, let textView else { return }
            applyMarkdownShortcut(formatting, to: textView, onSourceChanged: onSourceChanged)
        }
        textView.onDoubleClick = { [weak textView] event in
            guard let textView else { return }
            let point = textView.convert(event.locationInWindow, from: nil)
            let utf16Offset = textView.characterIndexForInsertion(at: point)
            onDoubleClick?(Self.utf8Offset(in: textView.string, utf16Offset: utf16Offset))
        }
        textView.isRichText = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.markdownAutoListContinuationEnabled = markdownShortcutsEnabled && isEditable
        textView.isAutomaticSpellingCorrectionEnabled = isEditable
        textView.isAutomaticTextCompletionEnabled = isEditable
        textView.usesMarkdownInlineCompletion = markdownShortcutsEnabled
            && isEditable
            && MarkdownInlineCompletionProvider.usesCustomCompletion()
        textView.inlinePredictionType = isEditable && !textView.usesMarkdownInlineCompletion ? .yes : .no
        if monospaced {
            // JSON syntax requires ASCII quotes; macOS smart quotes would turn
            // a typed delimiter into a Unicode character such as U+201D.
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
        }
        textView.usesFindPanel = false
        textView.drawsBackground = syntaxHighlighting == nil
        applyBaseColors(to: textView)
        context.coordinator.appliedBaseColors = syntaxHighlighting
        context.coordinator.hasAppliedBaseColors = true
        textView.insertionPointColor = .controlAccentColor
        textView.string = source
        let initialSelection = cursorUTF8Offset.map { offset in
            NSRange(
                location: Self.utf16Offset(in: source, utf8Offset: offset),
                length: 0
            )
        }
        if let initialSelection {
            textView.setSelectedRange(initialSelection)
        }
        applyTypography(to: textView)
        context.coordinator.appliedZoom = zoom
        context.coordinator.appliedMonospaced = monospaced
        context.coordinator.appliedLineSpacingBefore = lineSpacingBefore
        context.coordinator.requiresTypographyRefresh = false
        context.coordinator.requiresSyntaxRefresh = true
        context.coordinator.requiresInitialSyntaxRefresh = true
        context.coordinator.lastModelSource = source
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(
            width: textContainerHorizontalInset(zoom: zoom),
            height: SourceEditorLayout.verticalPadding * CGFloat(zoom)
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.showsLineNumbers = lineNumbers
        textView.lineNumberGutterWidth = SourceEditorLayout.lineNumberGutterWidth * CGFloat(zoom)
        textView.lineNumberFontSize = SourceEditorLayout.lineNumberFontSize * CGFloat(zoom)
        textView.lineNumberOverrides = lineNumberOverrides
        textView.lineHighlights = lineHighlights
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = syntaxHighlighting == nil
        scrollView.backgroundColor = textView.backgroundColor
        scrollView.documentView = textView
        context.coordinator.appliedCursorUTF8Offset = cursorUTF8Offset
        context.coordinator.appliedCursorRequestID = cursorRequestID
        context.coordinator.scheduleInitialSyntaxRefresh(
            in: textView,
            source: source,
            syntaxHighlighting: syntaxHighlighting
        )
        if isEditable {
            focus(textView, selection: initialSelection)
        }
        onScrollViewReady?(scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownNSTextView else { return }
        textView.fixedEditorParagraphStyle = SourceEditorLayout.editorParagraphStyle(zoom: zoom)
        context.coordinator.onSourceChanged = onSourceChanged
        context.coordinator.onEndEditing = onEndEditing
        context.coordinator.onFindMatchCount = onFindMatchCount

        textView.lineHighlights = lineHighlights
        textView.onDoubleClick = { [weak textView] event in
            guard let textView else { return }
            let point = textView.convert(event.locationInWindow, from: nil)
            let utf16Offset = textView.characterIndexForInsertion(at: point)
            onDoubleClick?(Self.utf8Offset(in: textView.string, utf16Offset: utf16Offset))
        }

        textView.showsLineNumbers = lineNumbers
        textView.lineNumberGutterWidth = SourceEditorLayout.lineNumberGutterWidth * CGFloat(zoom)
        textView.lineNumberFontSize = SourceEditorLayout.lineNumberFontSize * CGFloat(zoom)
        textView.lineNumberOverrides = lineNumberOverrides
        textView.isEditable = isEditable
        textView.markdownAutoListContinuationEnabled = markdownShortcutsEnabled && isEditable
        textView.isAutomaticSpellingCorrectionEnabled = isEditable
        textView.isAutomaticTextCompletionEnabled = isEditable
        textView.usesMarkdownInlineCompletion = markdownShortcutsEnabled
            && isEditable
            && MarkdownInlineCompletionProvider.usesCustomCompletion()
        textView.inlinePredictionType = isEditable && !textView.usesMarkdownInlineCompletion ? .yes : .no
        if !textView.usesMarkdownInlineCompletion {
            context.coordinator.cancelInlineCompletion(for: textView)
        }

        if !context.coordinator.didRequestInitialFocus, isEditable {
            focus(textView, selection: nil) {
                context.coordinator.didRequestInitialFocus = true
            }
        } else if !isEditable {
            context.coordinator.didRequestInitialFocus = true
        }

        if !context.coordinator.hasAppliedBaseColors
            || context.coordinator.appliedBaseColors != syntaxHighlighting {
            applyBaseColors(to: textView)
            context.coordinator.appliedBaseColors = syntaxHighlighting
            context.coordinator.hasAppliedBaseColors = true
        }
        scrollView.drawsBackground = syntaxHighlighting == nil
        scrollView.backgroundColor = textView.backgroundColor
        let sourceChanged = textView.string != source
        let modelSourceChanged = context.coordinator.lastModelSource != source
        let hasLocalEditorChange = isEditable && sourceChanged && !modelSourceChanged
        if sourceChanged && !hasLocalEditorChange {
            let selectedRange = textView.selectedRange()
            let restoredSelection = Self.replaceSourcePreservingUnchangedAttributes(
                source,
                in: textView,
                selection: selectedRange
            )
            textView.setSelectedRange(restoredSelection)
            textView.invalidateLineNumberCache()
            context.coordinator.requiresTypographyRefresh = true
        }
        context.coordinator.lastModelSource = source

        let effectiveSource = textView.string

        let typographyChanged = context.coordinator.appliedZoom != zoom
            || context.coordinator.appliedMonospaced != monospaced
            || context.coordinator.appliedLineSpacingBefore != lineSpacingBefore
        if typographyChanged || context.coordinator.requiresTypographyRefresh {
            applyTypography(to: textView)
            context.coordinator.appliedZoom = zoom
            context.coordinator.appliedMonospaced = monospaced
            context.coordinator.appliedLineSpacingBefore = lineSpacingBefore
            context.coordinator.requiresTypographyRefresh = false
        }

        let syntaxChanged = context.coordinator.syntaxHighlightingGate.applied.map {
            $0.syntaxHighlighting != syntaxHighlighting
        } ?? false
        if sourceChanged
            || context.coordinator.requiresSyntaxRefresh
            || context.coordinator.requiresInitialSyntaxRefresh
            || syntaxChanged {
            if !syntaxChanged {
                context.coordinator.scheduleSyntaxHighlighting(
                    in: textView,
                    source: effectiveSource,
                    syntaxHighlighting: syntaxHighlighting,
                    delay: context.coordinator.requiresInitialSyntaxRefresh || !isEditable
                        || modelSourceChanged
                        ? .zero
                        : .milliseconds(300)
                )
            } else {
                Self.applySyntaxHighlighting(
                    to: textView,
                    source: effectiveSource,
                    syntaxHighlighting: syntaxHighlighting
                )
                context.coordinator.syntaxHighlightingGate.markApplied(
                    SourceSyntaxHighlightingRequest(
                        source: effectiveSource,
                        syntaxHighlighting: syntaxHighlighting
                    )
                )
                context.coordinator.requiresSyntaxRefresh = false
                context.coordinator.requiresInitialSyntaxRefresh = false
            }
        }
        context.coordinator.applyFind(
            in: textView,
            source: effectiveSource,
            query: findQuery,
            requestID: findRequestID,
            backwards: findBackwards,
            isFindTarget: isFindTarget
        )
        textView.textContainerInset = NSSize(
            width: textContainerHorizontalInset(zoom: zoom),
            height: SourceEditorLayout.verticalPadding * CGFloat(zoom)
        )
        textView.textContainer?.lineFragmentPadding = 0

        guard let cursorUTF8Offset,
              context.coordinator.appliedCursorUTF8Offset != cursorUTF8Offset
                || context.coordinator.appliedCursorRequestID != cursorRequestID else { return }
        let cursorOffset = Self.utf16Offset(in: effectiveSource, utf8Offset: cursorUTF8Offset)
        let selection = NSRange(location: cursorOffset, length: 0)
        textView.setSelectedRange(selection)
        focus(textView, selection: selection)
        context.coordinator.appliedCursorUTF8Offset = cursorUTF8Offset
        context.coordinator.appliedCursorRequestID = cursorRequestID
    }
}
