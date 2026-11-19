import ViewerCore
import Foundation

extension Runner {
    mutating func runMarkdownMergeContracts() {
        let base = MarkdownBlockDocument(source: "# Title\n\nFirst\n\nSecond")
        let local = base.replacingBlock(id: base.blocks[1].id, withVisualText: "Local first")
        let external = base.replacingBlock(id: base.blocks[2].id, withVisualText: "External second")
        let merged = MarkdownThreeWayMerge.resolve(
            base: base.source,
            local: local.source,
            external: external.source
        )
        expect(
            merged == .merged("# Title\n\nLocal first\n\nExternal second"),
            "non-overlapping Markdown edits merge automatically"
        )

        let conflictingExternal = base.replacingBlock(id: base.blocks[1].id, withVisualText: "External first")
        let conflict = MarkdownThreeWayMerge.resolve(
            base: base.source,
            local: local.source,
            external: conflictingExternal.source
        )
        expect(conflict.isConflict, "overlapping Markdown edits become an explicit conflict")
    }
}
