import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownEditorCursorContracts() {
        let source = "# Título\n\nCorpo com 😀 emoji.\n\n## Fim"
        let heading = source.utf8.distance(
            from: source.utf8.startIndex,
            to: source.range(of: "## Fim")!.lowerBound.samePosition(in: source.utf8)!
        )
        let expected = (source as NSString).range(of: "## Fim").location
        expect(
            MarkdownEditorCursor.utf16Offset(inDisplay: source, forSourceUTF8Offset: heading, source: source) == expected,
            "editor cursor maps a UTF-8 source offset to UTF-16 when the editor shows the source verbatim"
        )
        expect(
            MarkdownEditorCursor.utf16Offset(inDisplay: source, forSourceUTF8Offset: 0, source: source) == 0,
            "editor cursor keeps offset zero"
        )

        let displayed = "Título\n\n\u{FFFC}\n\n## Fim"
        expect(
            MarkdownEditorCursor.utf16Offset(inDisplay: displayed, forSourceUTF8Offset: heading, source: source)
                == (displayed as NSString).range(of: "## Fim").location,
            "editor cursor falls back to the source line when the editor draws something in place of source"
        )
        expect(
            MarkdownEditorCursor.utf16Offset(inDisplay: "outro texto", forSourceUTF8Offset: heading, source: source) == nil,
            "editor cursor returns nil when the source line is not in the editor"
        )
        expect(
            MarkdownEditorCursor.utf16Offset(inDisplay: source, forSourceUTF8Offset: 10_000, source: source) == nil,
            "editor cursor rejects an offset past the end"
        )

        let table = "| a | b |\n| - | - |\n| alpha | 1 |\n"
        let edited = "| a | b |\n| - | - |\n| alphaXY | 1 |\n"
        let afterUndo = MarkdownEditorCursor.caretUTF8Offset(afterReplacing: edited, with: table)
        expect(
            afterUndo == (table as NSString).range(of: "alpha").upperBound,
            "undo puts the caret at the end of the restored text, inside the table cell"
        )
        expect(
            MarkdownEditorCursor.caretUTF8Offset(afterReplacing: table, with: edited)
                == (edited as NSString).range(of: "alphaXY").upperBound,
            "redo puts the caret at the end of the re-applied text"
        )
        expect(
            MarkdownEditorCursor.caretUTF8Offset(afterReplacing: "a😀b", with: "a😀😀b") == "a😀😀".utf8.count,
            "the caret after undo or redo is counted in UTF-8 bytes and never splits a character"
        )
        expect(
            MarkdownEditorCursor.caretUTF8Offset(afterReplacing: "same", with: "same") == 4,
            "an unchanged text puts the caret at its end"
        )
    }
}
