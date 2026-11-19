import Foundation
import Testing
@testable import ViewerCore

@Test("Markdown merge takes the side that changed")
func markdownMergeTakesChangedSide() {
    #expect(MarkdownThreeWayMerge.resolve(base: "a\n", local: "a\n", external: "b\n") == .merged("b\n"))
    #expect(MarkdownThreeWayMerge.resolve(base: "a\n", local: "b\n", external: "a\n") == .merged("b\n"))
}

@Test("Markdown merge accepts the same edit made on both sides")
func markdownMergeAcceptsIdenticalEdits() {
    let base = "# Title\n\nFirst"
    let edited = "# Title\n\nSame edit"
    #expect(MarkdownThreeWayMerge.resolve(base: base, local: edited, external: edited) == .merged(edited))
}

@Test("Markdown merge keeps multi-byte text intact around merged blocks")
func markdownMergeKeepsMultiByteText() {
    let base = "Café one\n\nNaïve two\n\nEnd 🎉"
    let document = MarkdownBlockDocument(source: base)
    let local = document.replacingBlock(id: document.blocks[0].id, withVisualText: "Café ☕ one")
    let external = document.replacingBlock(id: document.blocks[2].id, withVisualText: "End 🎈")

    #expect(
        MarkdownThreeWayMerge.resolve(base: base, local: local.source, external: external.source)
            == .merged("Café ☕ one\n\nNaïve two\n\nEnd 🎈")
    )
}

@Test("Markdown merge treats a block added on one side as a conflict with no block ids")
func markdownMergeTreatsStructureChangeAsConflict() {
    let base = "First\n\nSecond"
    let local = "First\n\nSecond\n\nAdded"
    let external = "First\n\nSecond edited"

    #expect(
        MarkdownThreeWayMerge.resolve(base: base, local: local, external: external)
            == .conflict(base: base, local: local, external: external, blockIDs: [])
    )
}

@Test("Markdown merge names only the block both sides changed differently")
func markdownMergeNamesConflictingBlock() {
    let base = MarkdownBlockDocument(source: "First\n\nSecond")
    let local = base.replacingBlock(id: base.blocks[0].id, withVisualText: "Local first")
        .replacingBlock(id: base.blocks[1].id, withVisualText: "Local second")
    let external = base.replacingBlock(id: base.blocks[0].id, withVisualText: "External first")

    #expect(
        MarkdownThreeWayMerge.resolve(base: base.source, local: local.source, external: external.source)
            == .conflict(
                base: base.source,
                local: local.source,
                external: external.source,
                blockIDs: [base.blocks[0].id]
            )
    )
}

@Test("source merge takes the side that changed, or the shared edit")
func sourceMergeTakesChangedSide() {
    #expect(SourceThreeWayMerge.resolve(base: "a", local: "a", external: "b") == .merged("b"))
    #expect(SourceThreeWayMerge.resolve(base: "a", local: "b", external: "a") == .merged("b"))
    #expect(SourceThreeWayMerge.resolve(base: "a", local: "b", external: "b") == .merged("b"))
}

@Test("source merge reports independent changes as a conflict")
func sourceMergeReportsIndependentChangesAsConflict() {
    #expect(
        SourceThreeWayMerge.resolve(base: "a", local: "b", external: "c")
            == .conflict(base: "a", local: "b", external: "c")
    )
}
