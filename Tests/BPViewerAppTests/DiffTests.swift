import Testing
import Foundation
import Darwin
import AppKit
@testable import BPViewerApp
@testable import BPViewerCore

@Test("keeps diff highlights aligned with the line fragment")
func keepsFinalDiffLineInsideFullWidthHighlightRow() {
    #expect(
        SourceEditorLayout.lineHighlightRect(
            lineFragmentRect: CGRect(x: 0, y: 48, width: 240, height: 24),
            textContainerOrigin: CGPoint(x: 52, y: 40),
            viewWidth: 360
        ) == CGRect(x: 0, y: 88, width: 360, height: 24)
    )
}

@Test("builds a side by side diff with stable line numbers")
func buildsSideBySideDiffWithStableLineNumbers() {
    let diff = DocumentDiffEngine().compare(
        reference: "one\ntwo\nthree",
        edited: "one\nchanged\nthree\nfour"
    )

    #expect(diff.hasChanges)
    #expect(diff.rows.count == 4)
    #expect(diff.rows[0].left?.lineNumber == 1)
    #expect(diff.rows[0].left?.text == "one")
    #expect(diff.rows[0].right?.lineNumber == 1)
    #expect(diff.rows[0].right?.text == "one")
    #expect(diff.rows[1].left?.lineNumber == 2)
    #expect(diff.rows[1].left?.text == "two")
    #expect(diff.rows[1].right?.lineNumber == 2)
    #expect(diff.rows[1].right?.text == "changed")
    #expect(diff.rows[1].left?.kind == .removed)
    #expect(diff.rows[1].right?.kind == .added)
    #expect(diff.rows[2].left?.lineNumber == 3)
    #expect(diff.rows[2].right?.lineNumber == 3)
    #expect(diff.rows[3].left == nil)
    #expect(diff.rows[3].right?.lineNumber == 4)
    #expect(diff.rows[3].right?.text == "four")
    #expect(diff.rightLineKinds == [
        1: .unchanged,
        2: .added,
        3: .unchanged,
        4: .added
    ])
}

@Test("keeps replaced lines on the same diff row")
func keepsReplacedLinesOnTheSameDiffRow() {
    let diff = DocumentDiffEngine().compare(
        reference: "before",
        edited: "after"
    )

    #expect(diff.rows.count == 1)
    #expect(diff.rows[0].left?.lineNumber == 1)
    #expect(diff.rows[0].left?.text == "before")
    #expect(diff.rows[0].left?.kind == .removed)
    #expect(diff.rows[0].right?.lineNumber == 1)
    #expect(diff.rows[0].right?.text == "after")
    #expect(diff.rows[0].right?.kind == .added)
}

@Test("uses one AppKit layout model for wrapped diff rows")
func usesOneAppKitLayoutModelForWrappedDiffRows() {
    let diff = DocumentDiffEngine().compare(
        reference: "one\nthree\nfour",
        edited: "one\nthis inserted line is deliberately long enough to wrap across the diff column\nthree\nfour"
    )
    let layout = DocumentDiffLayout(
        diff: diff,
        panelWidth: 360,
        zoom: 1,
        monospaced: true
    )

    #expect((layout.referenceLineSpacingBefore[3] ?? 0) > 0)
    #expect(layout.referenceLineSpacingBefore[4] == 0)
    #expect(layout.editedLineSpacingBefore[2] == 0)
    #expect(layout.editedLineSpacingBefore[3] == 0)
}

@Test("reports an unchanged document without diff rows marked as changes")
func reportsUnchangedDocument() {
    let diff = DocumentDiffEngine().compare(reference: "same", edited: "same")

    #expect(!diff.hasChanges)
    #expect(diff.addedLineCount == 0)
    #expect(diff.removedLineCount == 0)
    #expect(diff.rows.count == 1)
    #expect(diff.rows[0].left?.kind == .unchanged)
    #expect(diff.rows[0].right?.kind == .unchanged)
}
