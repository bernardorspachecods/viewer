import Foundation
import ViewerCore

struct StubGitProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) throws -> ProcessResult {
        if request.arguments.contains("rev-parse") {
            return ProcessResult(
                status: .success,
                exitCode: 0,
                standardOutput: "/tmp/project\n",
                standardError: ""
            )
        }
        return ProcessResult(
            status: .success,
            exitCode: 0,
            standardOutput: "from head",
            standardError: ""
        )
    }
}

struct RecordingLatexProcessRunner: ProcessRunning {
    private let storage = LatexRequestStorage()

    var requests: [ProcessRequest] {
        storage.requests
    }

    var observedChapterSource: String? {
        storage.observedChapterSource
    }

    var observedRootPath: String? {
        storage.observedRootPath
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        storage.requests.append(request)
        guard let rootPath = request.arguments.last,
              let outputArgument = request.arguments.first(where: { $0.hasPrefix("-outdir=") }) else {
            return ProcessResult(
                status: .failed,
                exitCode: 1,
                standardOutput: "",
                standardError: "missing test compiler arguments"
            )
        }

        let rootURL = URL(fileURLWithPath: rootPath)
        storage.observedRootPath = rootURL.path
        let chapterURL = rootURL.deletingLastPathComponent().appendingPathComponent("chapter.tex")
        storage.observedChapterSource = try? String(contentsOf: chapterURL, encoding: .utf8)

        let outputDirectory = URL(fileURLWithPath: String(outputArgument.dropFirst("-outdir=".count)))
        try Data("%PDF-1.4\n".utf8).write(
            to: outputDirectory.appendingPathComponent("main.pdf")
        )
        try "Input:\(rootURL.path)\nLine:1\nColumn:0\n"
            .write(
                to: outputDirectory.appendingPathComponent("main.synctex"),
                atomically: true,
                encoding: .utf8
            )
        return ProcessResult(
            status: .success,
            exitCode: 0,
            standardOutput: "",
            standardError: ""
        )
    }
}

final class LatexRequestStorage: @unchecked Sendable {
    var requests: [ProcessRequest] = []
    var observedChapterSource: String?
    var observedRootPath: String?
}

struct RecordingGitProcessRunner: ProcessRunning {
    let headResult: ProcessResult
    let repositoryPath: String
    private let storage: RequestStorage

    init(
        headResult: ProcessResult = ProcessResult(
            status: .success,
            exitCode: 0,
            standardOutput: "from head",
            standardError: ""
        ),
        repositoryPath: String = "/tmp/project"
    ) {
        self.headResult = headResult
        self.repositoryPath = repositoryPath
        self.storage = RequestStorage()
    }

    var requests: [ProcessRequest] {
        storage.requests
    }

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        storage.requests.append(request)
        if request.arguments.contains("rev-parse") {
            return ProcessResult(
                status: .success,
                exitCode: 0,
                standardOutput: "\(repositoryPath)\n",
                standardError: ""
            )
        }
        if request.arguments.first == "show" {
            return headResult
        }
        return ProcessResult(
            status: .success,
            exitCode: 0,
            standardOutput: "",
            standardError: ""
        )
    }
}

final class RequestStorage: @unchecked Sendable {
    var requests: [ProcessRequest] = []
}
