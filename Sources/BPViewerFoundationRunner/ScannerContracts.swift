import BPViewerCore
import Foundation

extension Runner {
    mutating func runScannerContracts(root: URL) {
        let scanner = FileSystemScanner()
        let topLevel = scanner.scanTopLevel(root: root)

        expect(topLevel.map(\.title) == ["docs", "empty", "config.json", "README.md", "report.docx", "sample.pdf", "zeta.txt"], "top-level order and hidden-file omission")
        expect(topLevel.first?.isDirectory == true, "directories precede files")
        expect(topLevel.first(where: { $0.title == "docs" })?.childrenLoaded == false, "top-level scan is lazy")
        expect(topLevel.first(where: { $0.title == "empty" })?.children.isEmpty == true, "empty directory has no eager children")

        let compatible = scanner.filter(topLevel, kindFilter: FileKindFilter(), query: "")
        expect(compatible.map(\.title) == ["docs", "empty", "config.json", "README.md", "report.docx", "sample.pdf"], "compatible filter keeps unknown lazy directories")

        let docsURL = root.appendingPathComponent("docs", isDirectory: true)
        let docsChildren = scanner.scanChildren(of: docsURL, root: root)
        expect(docsChildren.map(\.title) == ["nested", "inside.md"], "lazy child scan order")
        expect(docsChildren.first?.childrenLoaded == false, "nested directory remains lazy after child scan")

        let complete = scanner.scan(root: root)
        let docs = complete.first(where: { $0.title == "docs" })
        expect(docs?.childrenLoaded == true, "full scan loads descendants")
        expect(docs?.children.first(where: { $0.title == "nested" })?.childrenLoaded == true, "full scan loads nested descendants")

        let search = scanner.filter(complete, kindFilter: FileKindFilter(), query: "  DEEP  ")
        expect(search.first?.title == "docs", "search is case-insensitive and trims whitespace")
        expect(search.first?.children.first?.title == "nested", "search preserves matching ancestor chain")
        expect(search.first?.children.first?.children.first?.title == "deep.tex", "search reaches nested compatible file")

        let topLevelSearch = scanner.filterTopLevel(complete, kindFilter: FileKindFilter(), query: "  DOCS  ")
        expect(topLevelSearch.map(\.title) == ["docs"], "top-level search matches only root entries")
        expect(topLevelSearch.first?.children.isEmpty == true, "top-level search does not return descendants")
        expect(scanner.filterTopLevel(complete, kindFilter: FileKindFilter(), query: "DEEP").isEmpty, "top-level search ignores nested entries")

        let allFiles = scanner.filter(topLevel, kindFilter: FileKindFilter(showsOnlySelectedKinds: false), query: "")
        expect(allFiles.map(\.title) == ["docs", "empty", "config.json", "README.md", "report.docx", "sample.pdf", "zeta.txt"], "unfiltered tree keeps all visible entries")
        expect(scanner.scan(root: root.appendingPathComponent("missing")) .isEmpty, "missing root is non-fatal")
        expect(DocumentKind(url: root.appendingPathComponent("sample.PDF")) == .pdf, "PDF files are recognized case-insensitively")

        let markdownOnly = FileKindFilter(showsOnlySelectedKinds: true, selectedKinds: [.markdown])
        let markdownTopLevel = scanner.filterTopLevel(topLevel, kindFilter: markdownOnly, query: "")
        expect(markdownTopLevel.map(\.title) == ["docs", "empty", "README.md"], "markdown-only top level keeps folders and markdown files")
        let markdownTree = scanner.filter(complete, kindFilter: markdownOnly, query: "")
        expect(markdownTree.map(\.title) == ["docs", "README.md"], "markdown-only tree drops other kinds and empty folders")
        expect(markdownTree.first?.children.map(\.title) == ["inside.md"], "markdown-only tree keeps only markdown inside folders")
        expect(
            scanner.filter(complete, kindFilter: FileKindFilter(showsOnlySelectedKinds: true, selectedKinds: []), query: "").isEmpty,
            "selecting no kinds hides every file"
        )
        expect(
            scanner.filter(complete, kindFilter: FileKindFilter(showsOnlySelectedKinds: false, selectedKinds: []), query: "").count == 7,
            "turning the option off ignores the selected kinds"
        )
    }
}
