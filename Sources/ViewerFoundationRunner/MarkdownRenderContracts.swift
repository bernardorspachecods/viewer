import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownRenderContracts() {
        let rendered = try? SwiftMarkdownAdapter().render(
            source: "# Title\n\nParagraph\n\n- One\n- Two",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(rendered?.html.contains("data-bp-block-id=\"markdown-block-2\"") == true, "paragraph HTML exposes its block ID")
        expect(rendered?.html.contains("data-bp-block-id=\"markdown-block-3\"") == true, "list HTML exposes its block ID")
        expect(rendered?.html.contains("data-bp-editable=\"true\"") == true, "supported Markdown regions are visually editable")

        let linked = try? SwiftMarkdownAdapter().render(
            source: "A [link](notes.md) and **strong** text.",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(linked?.html.contains("data-bp-editable=\"true\"") == true, "inline links and formatting stay visually editable")
        expect(linked?.html.contains("data-bp-markdown-href=\"notes.md\"") == true, "rendered links preserve their Markdown destination")

        let tasks = MarkdownBlockDocument(source: "- [ ] Draft\n- [x] Done")
        let taskEdited = tasks.replacingVisualEntries([
            MarkdownVisualEntry(
                id: tasks.blocks[0].id,
                text: "[x] Draft\n[ ] Done",
                kind: .unorderedList
            )
        ])
        expect(taskEdited.source == "- [x] Draft\n- [ ] Done", "visual task list edits preserve checkbox markers")

        let renderedTasks = try? SwiftMarkdownAdapter().render(
            source: "- [ ] Draft\n- [x] Done",
            baseURL: URL(fileURLWithPath: "/tmp/project")
        )
        expect(renderedTasks?.html.contains("data-bp-task-checkbox=\"true\"") == true, "task list checkboxes expose an editing hook")
    }
}
