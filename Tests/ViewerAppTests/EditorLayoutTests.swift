import Testing
import Foundation
import Darwin
import AppKit
@testable import ViewerApp
@testable import ViewerCore

@Test("finds text case-insensitively without distinguishing accents")
func findsTextWithNormalizedMatching() {
    let matches = TextSearch.matches(in: "Café cafe", query: "CAFE")

    #expect(matches.map(\.utf16Range) == [0..<4, 5..<9])
}

@Test("find navigation wraps in both directions")
func findNavigationWraps() {
    #expect(TextSearch.nextMatchIndex(currentIndex: 1, matchCount: 3, backwards: false) == 2)
    #expect(TextSearch.nextMatchIndex(currentIndex: 2, matchCount: 3, backwards: false) == 0)
    #expect(TextSearch.nextMatchIndex(currentIndex: 0, matchCount: 3, backwards: true) == 2)
    #expect(TextSearch.nextMatchIndex(currentIndex: nil, matchCount: 3, backwards: true) == 2)
}

@Test("does not reapply the persisted page while PDF search navigates")
func preservesPDFSearchDestinationDuringViewUpdate() {
    #expect(
        PDFPreviewUpdatePolicy.shouldSynchronizeReadingPosition(
            afterFindNavigationHandled: true
        ) == false
    )
}

@Test("does not capture Markdown reading position for viewport resizing")
func ignoresMarkdownViewportResizeWhenTrackingScroll() {
    let beforeResize = CGRect(x: 0, y: 420, width: 800, height: 600)
    let afterResize = CGRect(x: 0, y: 420, width: 1_050, height: 600)
    let afterScroll = CGRect(x: 0, y: 520, width: 800, height: 600)

    #expect(
        MarkdownScrollObservationPolicy.shouldCapture(
            previousBounds: beforeResize,
            currentBounds: afterResize
        ) == false
    )
    #expect(
        MarkdownScrollObservationPolicy.shouldCapture(
            previousBounds: beforeResize,
            currentBounds: afterScroll
        ) == true
    )
}

@Test("keeps explicit PDF page navigation available")
func appliesExplicitPDFPageNavigationDuringViewUpdate() {
    #expect(
        PDFPreviewUpdatePolicy.pageIndexToApply(
            documentChanged: false,
            requestedPageIndex: 3,
            pageIndex: 0
        ) == 3
    )
}

@Test("keeps the editor cursor when no find query is active")
func keepsEditorCursorWithoutFindQuery() {
    #expect(SourceEditorFindSelectionPolicy.shouldSelectMatch(query: "", matchCount: 0) == false)
    #expect(SourceEditorFindSelectionPolicy.shouldSelectMatch(query: "   ", matchCount: 0) == false)
    #expect(SourceEditorFindSelectionPolicy.shouldSelectMatch(query: "heading", matchCount: 1))
}

@Test("numbers every source line, including empty and trailing lines")
func numbersEverySourceLineIncludingEmptyLines() {
    #expect(SourceEditorLineNumbering.lineCount(in: "one\n\nthree\n") == 4)
    #expect(SourceEditorLineNumbering.lineNumber(atUTF16Offset: 4, in: "one\n\nthree\n") == 2)
    #expect(SourceEditorLineNumbering.lineNumber(atUTF16Offset: 5, in: "one\n\nthree\n") == 3)
}

@Test("maps glyph locations to the line baseline")
func mapsGlyphLocationsToTheLineBaseline() {
    #expect(
        SourceEditorLayout.lineBaselineY(
            lineFragmentRect: CGRect(x: 0, y: 24, width: 200, height: 24),
            glyphLocationY: 21
        ) == 45
    )
}

@Test("keeps the extra line fragment on the configured baseline")
func keepsExtraLineFragmentOnTheConfiguredBaseline() {
    #expect(
        SourceEditorLayout.extraLineBaselineOffset(
            lineHeight: 24,
            defaultBaselineOffset: 13,
            defaultLineHeight: 16
        ) == 21
    )
}

@Test("keeps the trailing line fragment at the editor line height")
func keepsTrailingLineFragmentAtEditorLineHeight() {
    #expect(
        SourceEditorLayout.normalizedLineHeight(
            extraLineHeight: 10,
            configuredLineHeight: 24
        ) == 24
    )
}

@Test("uses the fallback line height for an empty text storage")
func usesFallbackLineHeightForEmptyTextStorage() {
    #expect(
        SourceEditorLayout.lineHeightForExtraFragment(
            textStorageLength: 0,
            paragraphStyleMinimumLineHeight: 24,
            fallback: SourceEditorLayout.codeLineHeight
        ) == SourceEditorLayout.codeLineHeight
    )
}

@Test("starts the trailing line after the previous line fragment")
func startsTrailingLineAfterPreviousLineFragment() {
    #expect(
        SourceEditorLayout.normalizedExtraLineRect(
            extraLineRect: CGRect(x: 0, y: 96, width: 0, height: 10),
            previousLineMaxY: 100,
            configuredLineHeight: 24
        ) == CGRect(x: 0, y: 100, width: 0, height: 24)
    )
}
