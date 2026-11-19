import Testing
import Foundation
import Darwin
import AppKit
@testable import ViewerApp
@testable import ViewerCore

@Test("recognizes CSV documents as supported preview files")
func recognizesCSVDocuments() {
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/data.csv")) == .csv)
    #expect(DocumentKind(url: URL(fileURLWithPath: "/tmp/project/DATA.CSV")) == .csv)
}

@Test("parses quoted CSV fields, escaped quotes, and line breaks")
func parsesCSVFields() throws {
    let source = "Name,Note\nAlice,\"hello\nworld\"\nBob,\"He said \"\"hi\"\"\""
    let document = try CSVPreviewAdapter().parse(source: source)

    #expect(document.rows == [
        ["Name", "Note"],
        ["Alice", "hello\nworld"],
        ["Bob", "He said \"hi\""]
    ])
}

@Test("detects semicolon-delimited CSV files")
func detectsSemicolonDelimitedCSV() throws {
    let document = try CSVPreviewAdapter().parse(source: "Name;Age\nAlice;42")

    #expect(document.delimiter == ";")
    #expect(document.rows == [["Name", "Age"], ["Alice", "42"]])
}

@Test("parses CRLF CSV records as separate rows")
func parsesCRLFCSVRecords() throws {
    let document = try CSVPreviewAdapter().parse(source: "Name,Age\r\nAlice,42\r\nBob,37")

    #expect(document.rows == [["Name", "Age"], ["Alice", "42"], ["Bob", "37"]])
}

@Test("updates and serializes a CSV cell using the detected delimiter")
func updatesAndSerializesCSVCell() throws {
    let adapter = CSVPreviewAdapter()
    let document = try adapter.parse(source: "Name;Note\nAlice;plain")
    let updated = try #require(document.replacingCell(atRow: 1, column: 1, with: "needs;quotes"))

    #expect(adapter.serialize(document: updated) == "Name;Note\nAlice;\"needs;quotes\"")
}

@Test("serializes CSV quotes and line breaks safely")
func serializesCSVQuotesAndLineBreaks() throws {
    let document = try CSVPreviewAdapter().parse(source: "Name,Note\nAlice,plain")
    let updated = try #require(document.replacingCell(atRow: 1, column: 1, with: "He said \"hi\"\nnext"))

    #expect(CSVPreviewAdapter().serialize(document: updated) == "Name,Note\nAlice,\"He said \"\"hi\"\"\nnext\"")
}

@Test("renders CSV spreadsheet coordinates and focusable cells")
func rendersCSVSpreadsheetCoordinates() throws {
    let document = try CSVPreviewAdapter().parse(source: "Name,Age\nAlice,42")
    let html = CSVPreviewAdapter().html(document: document, isDark: false)

    #expect(html.contains("data-column-header=\"A\""))
    #expect(html.contains("data-column-header=\"B\""))
    #expect(html.contains("data-row-header=\"1\""))
    #expect(html.contains("data-row-index=\"0\" data-column-index=\"0\""))
    #expect(html.contains("tabindex=\"0\""))
    #expect(html.contains("data-row-index=\"0\" data-column-index=\"0\" tabindex=\"0\" aria-selected=\"false\""))
    #expect(!html.contains("aria-selected=\"true\""))
    #expect(html.contains(">Name</div>"))
    #expect(html.contains("data-row-index=\"1\" data-column-index=\"0\""))
    #expect(html.contains("<div class=\"sheet\" data-bp-csv"))
    #expect(html.contains("grid-template-columns: 42px repeat(2"))
    #expect(!html.contains("<table data-bp-csv"))
    #expect(html.contains("background-color: #e9e9eb !important"))
    #expect(html.contains(".coordinate-header"))
    #expect(!html.contains("opacity: 0.56"))
    #expect(!html.contains("selected-header"))
}

@Test("CSV preview exposes keyboard navigation for the active cell")
func exposesCSVKeyboardNavigation() throws {
    let document = try CSVPreviewAdapter().parse(source: "Name,Age\nAlice,42")
    let html = CSVPreviewAdapter().html(document: document, isDark: false)

    #expect(html.contains("ArrowRight"))
    #expect(html.contains("ArrowLeft"))
    #expect(html.contains("ArrowDown"))
    #expect(html.contains("ArrowUp"))
    #expect(html.contains("event.key === 'Tab'"))
    #expect(html.contains("event.key === 'Enter'"))
    #expect(html.contains("function revealCell"))
    #expect(html.contains("const visibleLeft"))
    #expect(html.contains("viewport.scrollLeft"))
    #expect(html.contains("let hasActiveSelection = false"))
    #expect(html.contains("if (hasActiveSelection)"))
    #expect(html.contains("dblclick"))
    #expect(html.contains("if (editingCell !== cell)"))
    #expect(html.contains("contentEditable = 'true'"))
    #expect(html.contains("function commitCellEditing"))
    #expect(html.contains("commitCellEditing();"))
    #expect(!html.contains("cellChangedAndSave"))
    #expect(html.contains("document.addEventListener('keydown'"))
    #expect(html.contains("if (event.key !== 'Escape' || editingCell)"))
    #expect(html.contains("type: 'save'"))
    #expect(html.contains("window.webkit.messageHandlers.csvEdit.postMessage"))
}

@Test("rejects CSV files with an unterminated quoted field")
func rejectsUnterminatedCSVField() {
    #expect(throws: CSVPreviewError.self) {
        try CSVPreviewAdapter().parse(source: "Name,Note\nAlice,\"missing end")
    }
}
