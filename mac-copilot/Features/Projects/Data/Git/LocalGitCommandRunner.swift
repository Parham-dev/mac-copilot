import Foundation

struct GitCommandResult {
    let terminationStatus: Int32
    let output: String
}

protocol GitCommandRunning {
    func runGit(arguments: [String]) -> GitCommandResult
}

final class LocalGitCommandRunner: GitCommandRunning {
    func runGit(arguments: [String]) -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            return GitCommandResult(terminationStatus: process.terminationStatus, output: output)
        } catch {
            return GitCommandResult(terminationStatus: -1, output: error.localizedDescription)
        }
    }
}
