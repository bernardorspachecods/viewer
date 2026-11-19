import Foundation

struct ViewerContractRunner {
    static func main() throws {
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewer-local-image-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        try runMarkdownContracts()
        try runMarkdownLocalImageContracts(root: fixtureRoot)
        let latex = try makeLatexContractFixture(root: fixtureRoot)
        try runLatexRootDiscoveryContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runLatexExecutableLocatorContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runLatexRenderContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runLatexRuntimeArtifactContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runProcessRunnerContracts(fixtureRoot: fixtureRoot)
        try runLiveLatexCompileContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runManualLatexFixtureContracts()
        try runOptionalLatexCorpusContracts()
        try runLatexRootSelectionContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runLatexDependencyContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runLatexFontContracts(fixtureRoot: fixtureRoot, latex: latex)
        try runLatexCacheContracts(fixtureRoot: fixtureRoot, latex: latex)
    }

    static func expect(_ condition: Bool, _ name: String) {
        guard condition else {
            fatalError("Contract failed: \(name)")
        }
        print("PASS \(name)")
    }
}

try ViewerContractRunner.main()
