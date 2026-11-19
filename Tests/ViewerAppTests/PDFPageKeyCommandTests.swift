import AppKit
import Testing
@testable import ViewerApp

@Test("left and right arrows map to previous and next page")
func arrowKeysMapToPageSteps() {
    #expect(PDFPageKeyCommand.command(keyCode: 124, modifiers: []) == .nextPage)
    #expect(PDFPageKeyCommand.command(keyCode: 123, modifiers: []) == .previousPage)
    // macOS sets numeric-pad and function flags on arrow keys; they must not block them.
    #expect(PDFPageKeyCommand.command(keyCode: 124, modifiers: [.numericPad, .function]) == .nextPage)
    #expect(PDFPageKeyCommand.command(keyCode: 123, modifiers: [.function]) == .previousPage)
}

@Test("arrows with ⌘, ⌥, ⌃ or ⇧ and other keys do not step pages")
func modifiedArrowsAndOtherKeysAreIgnored() {
    for modifier in [NSEvent.ModifierFlags.command, .option, .control, .shift] {
        #expect(PDFPageKeyCommand.command(keyCode: 124, modifiers: modifier) == nil)
        #expect(PDFPageKeyCommand.command(keyCode: 123, modifiers: [modifier, .numericPad]) == nil)
    }
    #expect(PDFPageKeyCommand.command(keyCode: 125, modifiers: []) == nil)
    #expect(PDFPageKeyCommand.command(keyCode: 126, modifiers: []) == nil)
    #expect(PDFPageKeyCommand.command(keyCode: 0, modifiers: []) == nil)
}

@Test("a page step stops at the first and last page")
func pageStepStaysInsideDocument() {
    #expect(PDFPageKeyCommand.nextPage.targetPageIndex(from: 0, pageCount: 3) == 1)
    #expect(PDFPageKeyCommand.nextPage.targetPageIndex(from: 1, pageCount: 3) == 2)
    #expect(PDFPageKeyCommand.nextPage.targetPageIndex(from: 2, pageCount: 3) == nil)
    #expect(PDFPageKeyCommand.previousPage.targetPageIndex(from: 2, pageCount: 3) == 1)
    #expect(PDFPageKeyCommand.previousPage.targetPageIndex(from: 0, pageCount: 3) == nil)
    #expect(PDFPageKeyCommand.nextPage.targetPageIndex(from: 0, pageCount: 0) == nil)
}
