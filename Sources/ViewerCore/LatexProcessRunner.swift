import Foundation
import Darwin

public enum ProcessRunStatus: String, Sendable {
    case success
    case failed
    case cancelled
    case timedOut
    case launchFailed
}

public struct ProcessRequest: Sendable {
    public let executable: URL
    public let arguments: [String]
    public let workingDirectory: URL
    public let environment: [String: String]
    public let timeout: TimeInterval
    public let maxOutputBytes: Int

    public init(
        executable: URL,
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String] = [:],
        timeout: TimeInterval = 120,
        maxOutputBytes: Int = 2_000_000
    ) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeout = timeout
        self.maxOutputBytes = max(0, maxOutputBytes)
    }
}

public struct ProcessResult: Sendable {
    public let status: ProcessRunStatus
    public let exitCode: Int32?
    public let standardOutput: String
    public let standardError: String
    public let duration: TimeInterval

    public init(
        status: ProcessRunStatus,
        exitCode: Int32?,
        standardOutput: String,
        standardError: String,
        duration: TimeInterval = 0
    ) {
        self.status = status
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.duration = duration
    }

    public var combinedOutput: String {
        [standardOutput, standardError]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

public protocol ProcessRunning: Sendable {
    func run(_ request: ProcessRequest) throws -> ProcessResult
}
public struct LiveProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ request: ProcessRequest) throws -> ProcessResult {
        let process = Process()
        process.executableURL = request.executable
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectory
        if !request.environment.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            request.environment.forEach { environment[$0.key] = $0.value }
            process.environment = environment
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let startedAt = Date()

        do {
            try process.run()
        } catch {
            return ProcessResult(
                status: .launchFailed,
                exitCode: nil,
                standardOutput: "",
                standardError: error.localizedDescription,
                duration: Date().timeIntervalSince(startedAt)
            )
        }

        let processIdentifier = process.processIdentifier
        let processGroupConfigured = processIdentifier > 0
            && setpgid(processIdentifier, processIdentifier) == 0

        let outputBuffer = ProcessOutputBuffer(handle: outputPipe.fileHandleForReading)
        let errorBuffer = ProcessOutputBuffer(handle: errorPipe.fileHandleForReading)
        let outputGroup = DispatchGroup()
        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outputBuffer.capture(maxBytes: request.maxOutputBytes)
            outputGroup.leave()
        }
        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errorBuffer.capture(maxBytes: request.maxOutputBytes)
            outputGroup.leave()
        }

        var status: ProcessRunStatus = .success
        while process.isRunning {
            if Task.isCancelled {
                terminate(
                    process,
                    processIdentifier: processIdentifier,
                    processGroupConfigured: processGroupConfigured
                )
                status = .cancelled
                break
            }
            if request.timeout > 0, Date().timeIntervalSince(startedAt) >= request.timeout {
                terminate(
                    process,
                    processIdentifier: processIdentifier,
                    processGroupConfigured: processGroupConfigured
                )
                status = .timedOut
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }

        process.waitUntilExit()
        outputGroup.wait()
        if status == .success, process.terminationStatus != 0 {
            status = .failed
        }

        return ProcessResult(
            status: status,
            exitCode: process.terminationStatus,
            standardOutput: outputBuffer.string,
            standardError: errorBuffer.string,
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    private func terminate(
        _ process: Process,
        processIdentifier: pid_t,
        processGroupConfigured: Bool
    ) {
        if processGroupConfigured {
            _ = kill(-processIdentifier, SIGTERM)
        }
        process.terminate()
        Thread.sleep(forTimeInterval: 0.1)
        guard process.isRunning else { return }
        if processGroupConfigured {
            _ = kill(-processIdentifier, SIGKILL)
        }
        process.terminate()
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var data = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    func capture(maxBytes: Int) {
        let chunkSize = 64 * 1024
        var capturedData = Data()
        var wasTruncated = false
        while true {
            let chunk = handle.readData(ofLength: chunkSize)
            guard !chunk.isEmpty else { break }
            guard capturedData.count < maxBytes else {
                wasTruncated = true
                continue
            }
            let remaining = maxBytes - capturedData.count
            if chunk.count <= remaining {
                capturedData.append(chunk)
            } else {
                capturedData.append(chunk.prefix(remaining))
                wasTruncated = true
            }
        }
        if wasTruncated {
            capturedData.append(Data("\n[output truncated by viewer]\n".utf8))
        }
        lock.lock()
        data = capturedData
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
