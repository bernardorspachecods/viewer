import ViewerCore
import Foundation

extension ViewerContractRunner {
    static func runProcessRunnerContracts(fixtureRoot: URL) throws {
        let processResult = try LiveProcessRunner().run(
            ProcessRequest(
                executable: URL(fileURLWithPath: "/bin/echo"),
                arguments: ["viewer-process-runner"],
                workingDirectory: fixtureRoot
            )
        )
        expect(processResult.status == .success, "process runner success status")
        expect(processResult.standardOutput.contains("viewer-process-runner"), "process runner captures stdout")
        let boundedProcessResult = try LiveProcessRunner().run(
            ProcessRequest(
                executable: URL(fileURLWithPath: "/bin/echo"),
                arguments: [String(repeating: "x", count: 100)],
                workingDirectory: fixtureRoot,
                maxOutputBytes: 20
            )
        )
        expect(
            boundedProcessResult.standardOutput.contains("output truncated"),
            "process runner bounds compiler output"
        )
        let timedOutProcessResult = try LiveProcessRunner().run(
            ProcessRequest(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["2"],
                workingDirectory: fixtureRoot,
                timeout: 0.05
            )
        )
        expect(timedOutProcessResult.status == .timedOut, "process runner reports timeout")
    }
}
