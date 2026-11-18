import BPViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownShortcutContracts() {
        let boldShortcut = MarkdownShortcutFormatter.apply(
            .bold,
            to: "texto",
            selectionUTF16Offset: 0,
            selectionUTF16Length: 5
        )
        expect(
            boldShortcut.source == "**texto**"
                && boldShortcut.selectionUTF16Offset == 2
                && boldShortcut.selectionUTF16Length == 5,
            "Markdown Cmd+B wraps selected text"
        )
        let italicShortcut = MarkdownShortcutFormatter.apply(
            .italic,
            to: "texto",
            selectionUTF16Offset: 5,
            selectionUTF16Length: 0
        )
        expect(
            italicShortcut.source == "texto**"
                && italicShortcut.selectionUTF16Offset == 6,
            "Markdown Cmd+I inserts empty formatting"
        )
        let unwrapShortcut = MarkdownShortcutFormatter.apply(
            .bold,
            to: "**texto**",
            selectionUTF16Offset: 2,
            selectionUTF16Length: 5
        )
        expect(
            unwrapShortcut.source == "texto"
                && unwrapShortcut.selectionUTF16Offset == 0
                && unwrapShortcut.selectionUTF16Length == 5,
            "Markdown formatting shortcuts toggle existing markup"
        )
        let codeShortcut = MarkdownShortcutFormatter.apply(
            .code,
            to: "texto",
            selectionUTF16Offset: 0,
            selectionUTF16Length: 5
        )
        expect(
            codeShortcut.source == "`texto`"
                && codeShortcut.selectionUTF16Offset == 1
                && codeShortcut.selectionUTF16Length == 5,
            "Markdown Cmd+K wraps selected text as inline code"
        )
    }
}
