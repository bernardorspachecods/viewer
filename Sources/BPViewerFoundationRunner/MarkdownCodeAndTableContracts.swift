import BPViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownCodeAndTableContracts() {
        let codeSource = "Before\n\n```swift\nlet value = 1\n```\n\nAfter"
        let codeDocument = MarkdownBlockDocument(source: codeSource)
        expect(codeDocument.blocks.map(\.kind) == [.paragraph, .codeBlock, .paragraph], "fenced code blocks remain distinct document regions")
        expect(codeDocument.blocks[1].visualText == "let value = 1", "code block visual text omits its fence")
        let editedCode = codeDocument.replacingVisualEntries([
            MarkdownVisualEntry(id: codeDocument.blocks[1].id, text: "let value = 2", kind: .codeBlock)
        ])
        expect(editedCode.source.contains("```swift\nlet value = 2\n```"), "visual code edits preserve fence and language")
        let renderedCode = try? SwiftMarkdownAdapter().render(
            source: codeSource,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedCode?.html.contains("data-bp-editable=\"true\"") == true, "fenced code blocks expose an editing hook")

        let tableSource = "| Name | Value |\n| --- | --- |\n| One | 1 |\n| Two | 2 |"
        let tableDocument = MarkdownBlockDocument(source: tableSource)
        expect(tableDocument.blocks.map(\.kind) == [.table], "Markdown tables remain distinct document regions")
        let editedTable = tableDocument.replacingVisualEntries([
            MarkdownVisualEntry(
                id: tableDocument.blocks[0].id,
                text: "| Name | Value |\n| --- | --- |\n| One | 10 |\n| Two | 2 |",
                kind: .table
            )
        ])
        expect(editedTable.source.contains("| One | 10 |"), "visual table edits preserve Markdown rows")
        let renderedTable = try? SwiftMarkdownAdapter().render(
            source: tableSource,
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedTable?.html.contains("<table data-bp-block-id=\"markdown-block-1\"") == true, "tables expose an editing hook")
    }
}
