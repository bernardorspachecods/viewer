import Foundation

struct LatexContractFixture {
    let project: URL
    let root: URL
    let chapter: URL
}

extension BPViewerContractRunner {
    static func makeLatexContractFixture(root fixtureRoot: URL) throws -> LatexContractFixture {
        let latexProject = fixtureRoot.appendingPathComponent("developer-cv", isDirectory: true)
        let latexRoot = latexProject.appendingPathComponent("main.tex")
        let latexChapter = latexProject.appendingPathComponent("chapters/methods.tex")
        try FileManager.default.createDirectory(
            at: latexChapter.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "\\documentclass{developercv}\n\\begin{document}\nMain\\end{document}\n"
            .write(to: latexRoot, atomically: true, encoding: .utf8)
        try "\\ProvidesClass{developercv}\n\\LoadClass{article}\n"
            .write(
                to: latexProject.appendingPathComponent("developercv.cls"),
                atomically: true,
                encoding: .utf8
            )
        try "\\section{Methods}\nChapter text\n"
            .write(to: latexChapter, atomically: true, encoding: .utf8)

        return LatexContractFixture(project: latexProject, root: latexRoot, chapter: latexChapter)
    }
}
