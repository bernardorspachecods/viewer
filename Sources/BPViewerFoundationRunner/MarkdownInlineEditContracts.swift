import BPViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownInlineEditContracts() {
        func edit(_ source: String, block: Int = 0, unit: Int? = nil, from original: String, to edited: String) -> String? {
            let document = MarkdownBlockDocument(source: source)
            return document.applyingInlineTextEdit(
                blockID: document.blocks[block].id,
                unitIndex: unit,
                originalText: original,
                editedText: edited
            )
        }

        expect(
            edit("Hello world.\n", from: "Hello world.", to: "Hello there.") == "Hello there.\n",
            "inline paragraph edit keeps the trailing newline"
        )
        expect(
            edit("Hello **big** world.", from: "Hello big world.", to: "Hello world.") == "Hello world.",
            "inline deletion removes a bold word with its markers"
        )
        expect(
            edit("Hello **big** world.", from: "Hello big world.", to: "Hello  world.") == "Hello  world.",
            "inline deletion of bold content removes the empty pair"
        )
        expect(
            edit("a **b** c", from: "a b c", to: "a b X c") == "a **b** X c",
            "inline insertion stays outside an adjacent bold pair"
        )
        expect(
            edit("Read [the docs](http://x.io/a) now", from: "Read the docs now", to: "Read  now") == "Read  now",
            "inline deletion removes a link entirely"
        )
        expect(
            edit("Read [the docs](http://x.io/a) now", from: "Read the docs now", to: "Read the manual now")
                == "Read [the manual](http://x.io/a) now",
            "inline replacement keeps the link destination"
        )
        expect(edit("# Title", from: "Title", to: "Titles") == "# Titles", "inline heading edit keeps the ATX marker")
        expect(edit("## T ##", from: "T", to: "Tx") == "## Tx ##", "inline heading edit keeps the closing sequence")

        let list = "- one\n- two\n  - nested\n- three"
        expect(
            edit(list, unit: 1, from: "two", to: "2") == "- one\n- 2\n  - nested\n- three",
            "inline list edit changes only the addressed item"
        )
        expect(
            edit(list, unit: 2, from: "nested", to: "deep") == "- one\n- two\n  - deep\n- three",
            "inline list edit reaches a nested item by document order"
        )
        expect(
            edit("Hello world.", from: "Hello world.", to: "Hello world.*") == "Hello world.\\*",
            "inline typed asterisk is escaped"
        )
        expect(
            edit("Hello", from: "Hello", to: "# Hello") == "\\# Hello",
            "inline insertion at paragraph start escapes a leading hash"
        )
        expect(
            edit("Café 🎉 **olá** mundo", from: "Café 🎉 olá mundo", to: "Café 🎈 olá mundo") == "Café 🎈 **olá** mundo",
            "inline multi-byte replacement keeps every other byte"
        )
        expect(
            edit("Café 🎉 **olá** mundo", from: "Café 🎉 olá mundo", to: "Café 🎉 mundo") == "Café 🎉 mundo",
            "inline multi-byte deletion removes a bold word with its markers"
        )

        expect(
            edit("Hello world.", from: "Hello world.", to: "") == nil,
            "inline edit rejects empty text"
        )
        expect(
            edit("| A | B |\n| --- | --- |\n| 1 | 2 |", from: "| A | B |\n| --- | --- |\n| 1 | 2 |", to: "| A | B |\n| --- | --- |\n| 1 | 3 |") == nil,
            "inline edit rejects table blocks"
        )
        expect(
            edit("```\nlet x = 1\n```", from: "let x = 1", to: "let x = 2") == nil,
            "inline edit rejects code blocks"
        )
        expect(
            edit("---\ntitle: Draft\n---\n\n# Body", from: "---\ntitle: Draft\n---", to: "---\ntitle: Final\n---") == nil,
            "inline edit rejects front matter"
        )
        expect(
            edit("- one\n  continued\n- two", unit: 0, from: "one", to: "uno") == nil,
            "inline list edit rejects a continuation line"
        )
        expect(
            edit("Hello **big** world.", from: "Hello big world", to: "Hello world") == nil,
            "inline edit rejects original text that does not match the rendered text"
        )
        expect(
            edit("foo **bar** baz", from: "foo bar baz", to: "fo baz") == "fo baz",
            "inline deletion takes a whole bold pair when its content is in the range"
        )
        expect(
            edit("a **b** c", from: "a b c", to: " c") == " c",
            "inline deletion takes a bold pair whose opener is in the range"
        )
        expect(
            edit("foo **bar** baz", from: "foo bar baz", to: "foo baz") == nil,
            "inline deletion rejects removing one marker of a bold pair that keeps content"
        )
        expect(
            edit("Use `code` now", from: "Use code now", to: "Use coXde now") == nil,
            "inline insertion rejects the inside of a code span"
        )

        let defaultSession = SourceEditSession(baseSource: "# A", currentSource: "# A")
        expect(defaultSession.isPreviewInline == false, "source edit session defaults to the raw editor")
        let splitSession = SourceEditSession(mode: .split, baseSource: "# A", currentSource: "# A")
        expect(splitSession.isPreviewInline == false, "split source edit session is not Quick Edit")
    }
}
