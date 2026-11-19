import ViewerCore
import Foundation

struct SuccessfulLatexProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) throws -> ProcessResult {
        guard let rootArgument = request.arguments.last else {
            fatalError("LaTeX contract failed: root argument missing")
        }
        let rootURL = URL(fileURLWithPath: rootArgument)
        expect(
            FileManager.default.fileExists(atPath: rootURL.path),
            "LaTeX source remains available"
        )
        expect(
            request.workingDirectory.standardizedFileURL != rootURL.deletingLastPathComponent().standardizedFileURL
                && request.environment["TEXINPUTS"]?.contains(rootURL.deletingLastPathComponent().path) == true,
            "LaTeX compiler uses isolated cwd and recursive project inputs"
        )
        guard let outputArgument = request.arguments.first(where: { $0.hasPrefix("-outdir=") }) else {
            fatalError("LaTeX contract failed: output directory argument missing")
        }
        let outputDirectory = URL(fileURLWithPath: String(outputArgument.dropFirst("-outdir=".count)))
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let rootName = request.arguments.last.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? "main"
        try Data("%PDF-1.4\\n% fake PDF\\n".utf8)
            .write(to: outputDirectory.appendingPathComponent(rootName + ".pdf"))
        let recorder = """
        PWD \(request.workingDirectory.path)
        INPUT \(rootURL.path)
        INPUT \(rootURL.deletingLastPathComponent().appendingPathComponent("chapters/methods.tex").path)
        INPUT \(rootURL.deletingLastPathComponent().appendingPathComponent("developercv.cls").path)
        INPUT \(outputDirectory.path)/\(rootName).aux
        """
        try recorder.write(
            to: outputDirectory.appendingPathComponent(rootName + ".fls"),
            atomically: true,
            encoding: .utf8
        )
        return ProcessResult(status: .success, exitCode: 0, standardOutput: "", standardError: "")
    }

    private func expect(_ condition: Bool, _ name: String) {
        guard condition else {
            fatalError("LaTeX contract failed: \(name)")
        }
    }
}

struct InvalidPDFProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) throws -> ProcessResult {
        guard let outputArgument = request.arguments.first(where: { $0.hasPrefix("-outdir=") }) else {
            fatalError("LaTeX invalid PDF contract failed: output directory argument missing")
        }
        let outputDirectory = URL(fileURLWithPath: String(outputArgument.dropFirst("-outdir=".count)))
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let rootName = request.arguments.last.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? "main"
        try Data("not a pdf".utf8).write(to: outputDirectory.appendingPathComponent(rootName + ".pdf"))
        return ProcessResult(status: .success, exitCode: 0, standardOutput: "", standardError: "")
    }
}

final class RecordingLatexProcessRunner: @unchecked Sendable, ProcessRunning {
    private(set) var calls: [String] = []
    private(set) var requests: [ProcessRequest] = []

    func run(_ request: ProcessRequest) throws -> ProcessResult {
        let executableName = request.executable.lastPathComponent
        calls.append(executableName)
        requests.append(request)
        guard ["pdflatex", "xelatex", "lualatex"].contains(executableName) else {
            return ProcessResult(status: .success, exitCode: 0, standardOutput: "", standardError: "")
        }

        guard let outputArgument = request.arguments.first(where: { $0.hasPrefix("-output-directory=") }) else {
            fatalError("LaTeX bibliography contract failed: output directory argument missing")
        }
        let outputDirectory = URL(fileURLWithPath: String(outputArgument.dropFirst("-output-directory=".count)))
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let rootName = request.arguments.last.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? "main"
        try Data("%PDF-1.4\\n% fake PDF\\n".utf8)
            .write(to: outputDirectory.appendingPathComponent(rootName + ".pdf"))
        return ProcessResult(status: .success, exitCode: 0, standardOutput: "", standardError: "")
    }
}
