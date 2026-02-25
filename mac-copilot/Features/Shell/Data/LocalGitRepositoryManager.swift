import Foundation

private struct GitCommandResult {
    let terminationStatus: Int32
    let output: String
}

struct GitRepositoryError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

final class LocalGitRepositoryManager: GitRepositoryManaging {
    func isGitRepository(at path: String) async -> Bool {
        await runInBackground {
            let gitURL = URL(fileURLWithPath: path).appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitURL.path) {
                return true
            }

            let result = self.runGit(arguments: ["-C", path, "rev-parse", "--is-inside-work-tree"])
            guard result.terminationStatus == 0 else {
                return false
            }

            return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
    }

    func initializeRepository(at path: String) async throws {
        let result = await runInBackground {
            self.runGit(arguments: ["-C", path, "init"])
        }

        if result.terminationStatus == 0 {
            return
        }

        let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        throw GitRepositoryError(message: message.isEmpty ? "Could not initialize Git repository." : message)
    }

    private func runGit(arguments: [String]) -> GitCommandResult {
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

    private func runInBackground<T>(_ operation: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: operation())
            }
        }
    }
}
