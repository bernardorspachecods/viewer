import Foundation

private struct GitDocumentLocation: Sendable {
    let repositoryURL: URL
    let relativePath: String
}

private enum GitDocumentLocationResolution {
    case available(GitDocumentLocation)
    case unavailable(String)
}

private struct GitDocumentLocator: Sendable {
    let runner: any ProcessRunning
    let gitExecutable: URL

    func locate(_ url: URL) -> GitDocumentLocationResolution {
        let directory = url.deletingLastPathComponent()
        let repositoryResult: ProcessResult
        do {
            repositoryResult = try runner.run(
                ProcessRequest(
                    executable: gitExecutable,
                    arguments: ["-C", directory.path, "rev-parse", "--show-toplevel"],
                    workingDirectory: directory,
                    timeout: 10,
                    maxOutputBytes: 32_000
                )
            )
        } catch {
            return .unavailable("Git is not available for this document.")
        }

        guard repositoryResult.status == .success,
              let repositoryPath = nonEmptyPath(from: repositoryResult.standardOutput) else {
            return .unavailable("This file is not inside a Git repository.")
        }

        let repositoryURL = URL(fileURLWithPath: repositoryPath).standardizedFileURL
        let documentURL = url.standardizedFileURL
        let repositoryPrefix = repositoryURL.path.hasSuffix("/")
            ? repositoryURL.path
            : repositoryURL.path + "/"
        guard documentURL.path.hasPrefix(repositoryPrefix) else {
            return .unavailable("This file is outside the Git repository.")
        }

        let relativePath = String(documentURL.path.dropFirst(repositoryPrefix.count))
            .replacingOccurrences(of: "\\", with: "/")
        return .available(GitDocumentLocation(
            repositoryURL: repositoryURL,
            relativePath: relativePath
        ))
    }

    private func nonEmptyPath(from output: String) -> String? {
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}

public struct GitHeadDocumentDiffBaselineProvider: DocumentDiffBaselineProviding {
    private let runner: any ProcessRunning
    private let gitExecutable: URL

    public init(
        runner: any ProcessRunning = LiveProcessRunner(),
        gitExecutable: URL = URL(fileURLWithPath: "/usr/bin/git")
    ) {
        self.runner = runner
        self.gitExecutable = gitExecutable
    }

    public func baseline(for url: URL) -> DocumentDiffBaselineResolution {
        let locator = GitDocumentLocator(runner: runner, gitExecutable: gitExecutable)
        let location: GitDocumentLocation
        switch locator.locate(url) {
        case let .available(value):
            location = value
        case let .unavailable(message):
            return .unavailable(message)
        }

        let headResult: ProcessResult
        do {
            headResult = try runner.run(
                ProcessRequest(
                    executable: gitExecutable,
                    arguments: ["show", "HEAD:\(location.relativePath)"],
                    workingDirectory: location.repositoryURL,
                    timeout: 10,
                    maxOutputBytes: 8_000_000
                )
            )
        } catch {
            return .unavailable("Git could not read this file from HEAD.")
        }

        guard headResult.status == .success else {
            return .unavailable("This file has no version in the latest Git commit.")
        }
        return .available(
            DocumentDiffBaseline(
                label: "HEAD",
                source: headResult.standardOutput
            )
        )
    }
}

public struct GitHeadDocumentRestorer: Sendable {
    private let runner: any ProcessRunning
    private let gitExecutable: URL

    public init(
        runner: any ProcessRunning = LiveProcessRunner(),
        gitExecutable: URL = URL(fileURLWithPath: "/usr/bin/git")
    ) {
        self.runner = runner
        self.gitExecutable = gitExecutable
    }

    public func restoreToHead(for url: URL) -> GitDocumentRestoreResolution {
        let locator = GitDocumentLocator(runner: runner, gitExecutable: gitExecutable)
        let location: GitDocumentLocation
        switch locator.locate(url) {
        case let .available(value):
            location = value
        case let .unavailable(message):
            return .unavailable(message)
        }

        let headResult: ProcessResult
        do {
            headResult = try runner.run(
                ProcessRequest(
                    executable: gitExecutable,
                    arguments: ["show", "HEAD:\(location.relativePath)"],
                    workingDirectory: location.repositoryURL,
                    timeout: 10,
                    maxOutputBytes: 8_000_000
                )
            )
        } catch {
            return .unavailable("Git could not read this file from HEAD.")
        }

        guard headResult.status == .success else {
            return .unavailable("This file has no version in the latest Git commit.")
        }

        let restoreResult: ProcessResult
        do {
            restoreResult = try runner.run(
                ProcessRequest(
                    executable: gitExecutable,
                    arguments: [
                        "restore",
                        "--source=HEAD",
                        "--staged",
                        "--worktree",
                        "--",
                        location.relativePath
                    ],
                    workingDirectory: location.repositoryURL,
                    timeout: 10,
                    maxOutputBytes: 32_000
                )
            )
        } catch {
            return .failed("Git could not restore this file to HEAD.")
        }

        guard restoreResult.status == .success else {
            let detail = restoreResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failed(
                detail.isEmpty
                    ? "Git could not restore this file to HEAD."
                    : "Git could not restore this file to HEAD.\n\(detail)"
            )
        }
        return .restored(source: headResult.standardOutput)
    }
}
