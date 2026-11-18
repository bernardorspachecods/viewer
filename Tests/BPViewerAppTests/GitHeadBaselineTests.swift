import Foundation
import Testing
import BPViewerCore

/// Answers each Git request from a closure, so the locate and HEAD-read logic runs
/// without a real repository.
private struct ScriptedGitRunner: ProcessRunning {
    let respond: @Sendable (ProcessRequest) throws -> ProcessResult

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        try respond(request)
    }
}

private struct GitUnavailable: Error {}

private func gitResult(_ output: String, status: ProcessRunStatus = .success) -> ProcessResult {
    ProcessResult(
        status: status,
        exitCode: status == .success ? 0 : 128,
        standardOutput: output,
        standardError: ""
    )
}

@Test("reads the HEAD version of a file relative to its repository root")
func readsHeadVersionRelativeToRepositoryRoot() {
    let provider = GitHeadDocumentDiffBaselineProvider(
        runner: ScriptedGitRunner { request in
            if request.arguments.contains("rev-parse") {
                return gitResult("/work/repo\n")
            }
            guard request.arguments == ["show", "HEAD:docs/a.md"] else {
                return gitResult("", status: .failed)
            }
            return gitResult("old text")
        }
    )

    #expect(
        provider.baseline(for: URL(fileURLWithPath: "/work/repo/docs/a.md"))
            == .available(DocumentDiffBaseline(label: "HEAD", source: "old text"))
    )
}

@Test("reports a file outside any Git repository")
func reportsFileOutsideRepository() {
    let provider = GitHeadDocumentDiffBaselineProvider(
        runner: ScriptedGitRunner { _ in gitResult("", status: .failed) }
    )

    #expect(
        provider.baseline(for: URL(fileURLWithPath: "/work/loose/a.md"))
            == .unavailable("This file is not inside a Git repository.")
    )
}

@Test("reports Git as unavailable when the process cannot run")
func reportsGitUnavailable() {
    let provider = GitHeadDocumentDiffBaselineProvider(
        runner: ScriptedGitRunner { _ in throw GitUnavailable() }
    )

    #expect(
        provider.baseline(for: URL(fileURLWithPath: "/work/repo/a.md"))
            == .unavailable("Git is not available for this document.")
    )
}

@Test("does not treat a sibling folder that shares the repository name as inside it")
func rejectsSiblingFolderWithSharedPrefix() {
    let provider = GitHeadDocumentDiffBaselineProvider(
        runner: ScriptedGitRunner { request in
            request.arguments.contains("rev-parse") ? gitResult("/work/repo\n") : gitResult("unused")
        }
    )

    #expect(
        provider.baseline(for: URL(fileURLWithPath: "/work/repo-copy/a.md"))
            == .unavailable("This file is outside the Git repository.")
    )
}

@Test("reports a file that has no version in HEAD")
func reportsFileMissingFromHead() {
    let provider = GitHeadDocumentDiffBaselineProvider(
        runner: ScriptedGitRunner { request in
            request.arguments.contains("rev-parse")
                ? gitResult("/work/repo\n")
                : gitResult("", status: .failed)
        }
    )

    #expect(
        provider.baseline(for: URL(fileURLWithPath: "/work/repo/new.md"))
            == .unavailable("This file has no version in the latest Git commit.")
    )
}
