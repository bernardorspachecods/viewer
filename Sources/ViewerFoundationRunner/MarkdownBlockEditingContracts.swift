import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownBlockEditingContracts() {
        expect(MarkdownEditingMode.allCases == [.markdown, .split], "Markdown editing exposes source and split modes")
        expect(MarkdownEditingMode(rawValue: "visual") == nil, "visual Markdown editing mode is no longer supported")

        let positioned = MarkdownBlockDocument(source: "# Title\n\nBody **strong**.")
        expect(positioned.blocks[0].sourceOffset(forRenderedTextOffset: 0) == 2, "heading cursor skips Markdown marker")
        expect(positioned.blocks[1].sourceOffset(forRenderedTextOffset: 5) == 7, "inline formatting cursor skips Markdown markers")

        let source = """
        # Title

        First paragraph.
        It keeps its second line.

        - One
        - Two

        ## Final heading
        """
        let document = MarkdownBlockDocument(source: source)

        expect(document.blocks.map(\.kind) == [.heading, .paragraph, .unorderedList, .heading], "Markdown blocks preserve top-level structure")
        expect(document.blocks[1].source == "First paragraph.\nIt keeps its second line.", "paragraph block keeps its exact source")
        let formatted = MarkdownBlockDocument(source: "A **formatted** paragraph")
        expect(formatted.blocks[0].supportsVisualEditing, "supported inline Markdown remains visually editable")

        let updated = document.replacingBlock(id: document.blocks[1].id, withSource: "Edited paragraph.")
        expect(updated.source.contains("# Title\n\nEdited paragraph.\n\n- One"), "editing a block preserves surrounding Markdown")

        let visualDocument = document.replacingVisualEntries([
            MarkdownVisualEntry(id: document.blocks[1].id, text: "Visual paragraph."),
            MarkdownVisualEntry(id: document.blocks[2].id, text: "First visual\nSecond visual")
        ])
        expect(
            visualDocument.source.contains("Visual paragraph.\n\n- First visual\n- Second visual"),
            "document visual editing serializes supported regions without exposing blocks"
        )

        let structural = MarkdownBlockDocument(source: "Before\n\n> Existing quote\n> continues\n\n---")
        expect(
            structural.blocks.map(\.kind) == [.paragraph, .blockquote, .thematicBreak],
            "blockquote and separator regions remain part of the document model"
        )
        let quoted = MarkdownBlockDocument(source: "Plain text").replacingVisualEntries([
            MarkdownVisualEntry(id: "markdown-block-1", text: "Quoted text", kind: .blockquote)
        ])
        expect(quoted.source == "> Quoted text", "visual quote transformation preserves Markdown syntax")
        let withSeparator = MarkdownBlockDocument(source: "Plain text").insertingVisualBlock(
            MarkdownVisualInsertion(afterID: "markdown-block-1", kind: .thematicBreak)
        )
        expect(withSeparator.source == "Plain text\n\n---", "visual separator insertion preserves document order")

        let editedHeading = updated.replacingBlock(id: updated.blocks[3].id, withVisualText: "Closing heading")
        expect(editedHeading.source.contains("## Closing heading"), "visual heading edits preserve heading syntax")
    }
}
