import Foundation

struct ControlCenterCommandExecutionResult {
    let exitCode: Int32
    let output: String
}

protocol ControlCenterCommandStatusRunning {
    func runCommand(
        executable: String,
        arguments: [String],
        cwd: URL,
        environment: [String: String]
    ) async throws -> ControlCenterCommandExecutionResult
}

struct ProcessControlCenterCommandStatusRunner: ControlCenterCommandStatusRunning {
    func runCommand(
        executable: String,
        arguments: [String],
        cwd: URL,
        environment: [String: String]
    ) async throws -> ControlCenterCommandExecutionResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.currentDirectoryURL = cwd
                process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ControlCenterCommandExecutionResult(exitCode: process.terminationStatus, output: output))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
