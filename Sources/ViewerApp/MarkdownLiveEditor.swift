import AppKit
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex
import SwiftUI
import ViewerCore

/// The Markdown editor: swift-markdown-engine's live-styled TextKit 2 editor, bound to the
/// draft (`MarkdownEditSession.currentSource`). The raw `SourceTextView` stays only in the diffs.
struct MarkdownLiveEditor: View {
    let source: String
    let documentID: String
    let zoom: Double
    let limitsTextWidth: Bool
    let cursorUTF8Offset: Int?
    let cursorRequestID: Int
    let findQuery: String
    let findRequestID: Int
    let findBackwards: Bool
    let isFindTarget: Bool
    let onFindFocus: @MainActor @Sendable () -> Void
    let onFindMatchCount: @MainActor @Sendable (Int) -> Void
    let onSourceChanged: @MainActor @Sendable (String) -> Void
    let onEndEditing: @MainActor @Sendable () -> Void
    /// Where the document was scrolled in the preview, so the editor opens at the same text and
    /// height; the editor reports its own scroll through `onViewportChanged`.
    let entryPosition: MarkdownReadingPosition?
    let onViewportChanged: @MainActor @Sendable (MarkdownReadingPosition) -> Void

    @State private var isFocused = true
    /// Hidden until the entry position is applied, so the editor never shows its first lines for a
    /// frame before it scrolls to where the preview was.
    @State private var isRevealed = false
    /// One bus and configuration per editor: the engine listens to its bus names on the whole
    /// app, so a shared name would send ⌘B or a find to every open editor in every window.
    @State private var session = MarkdownLiveEditorSession()

    var body: some View {
        NativeTextViewWrapper(
            text: Binding(
                get: { source },
                set: { newValue in
                    if newValue != source { onSourceChanged(newValue) }
                }
            ),
            configuration: session.configuration(limitsTextWidth: limitsTextWidth, zoom: zoom),
            fontSize: CGFloat(MarkdownStyleTokens.shared.scaled(by: zoom).bodyFontSize),
            documentId: documentID,
            isFocused: $isFocused
        )
        .opacity(isRevealed || entryPosition?.sourceOffset == nil ? 1 : 0)
        // The reading column and the spacing are fixed when the editor is built, so a changed
        // preference or zoom rebuilds it.
        .id("\(limitsTextWidth)-\(zoom)")
        .background(
            MarkdownLiveEditorBridge(
                bus: session.bus,
                source: source,
                cursorUTF8Offset: cursorUTF8Offset,
                cursorRequestID: cursorRequestID,
                findQuery: findQuery,
                findRequestID: findRequestID,
                findBackwards: findBackwards,
                isFindTarget: isFindTarget,
                onFindFocus: onFindFocus,
                onFindMatchCount: onFindMatchCount,
                onEndEditing: onEndEditing,
                entryPosition: entryPosition,
                zoom: zoom,
                onViewportChanged: onViewportChanged,
                onEntryApplied: { isRevealed = true }
            )
        )
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        .background(BPTokens.Color.canvas)
    }
}

/// The state one editor instance owns: its notification names (formatting, find) and the
/// engine configuration that carries them.
@MainActor
final class MarkdownLiveEditorSession {
    let bus: MarkdownLiveEditorBus
    private let baseConfiguration: MarkdownEditorConfiguration

    init() {
        let bus = MarkdownLiveEditorBus()
        var configuration = MarkdownEditorConfiguration.default
        configuration.services = MarkdownEditorServices(
            syntaxHighlighter: HighlightJSBridge(),
            latex: SwiftMathBridge(),
            bus: bus.engineBus
        )
        self.bus = bus
        self.baseConfiguration = configuration
    }

    /// The text runs to the pane edges unless a reading column is asked for.
    func configuration(limitsTextWidth: Bool, zoom: Double) -> MarkdownEditorConfiguration {
        MarkdownLiveEditorStyle.configuration(
            base: baseConfiguration,
            tokens: MarkdownStyleTokens.shared.scaled(by: zoom),
            limitsTextWidth: limitsTextWidth
        )
    }
}

/// Notification names the engine and the app use to talk to each other. The names carry a
/// per-instance id.
struct MarkdownLiveEditorBus: Sendable {
    let bold: Notification.Name
    let italic: Notification.Name
    let inlineCode: Notification.Name
    let findQuery: Notification.Name
    let findResults: Notification.Name
    let findClear: Notification.Name

    init(id: UUID = UUID()) {
        func name(_ kind: String) -> Notification.Name {
            Notification.Name("viewer.markdownEditor.\(kind).\(id.uuidString)")
        }
        bold = name("bold")
        italic = name("italic")
        inlineCode = name("inlineCode")
        findQuery = name("findQuery")
        findResults = name("findResults")
        findClear = name("findClear")
    }

    var engineBus: MarkdownEditorBus {
        MarkdownEditorBus(
            applyBoldRequest: bold,
            applyItalicRequest: italic,
            applyInlineCodeRequest: inlineCode,
            findClearHighlights: findClear,
            findQuery: findQuery,
            findResults: findResults
        )
    }
}
