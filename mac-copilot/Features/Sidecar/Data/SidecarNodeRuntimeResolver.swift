import Foundation

final class SidecarNodeRuntimeResolver {
    private let commandRunner: SidecarCommandRunner

    init(commandRunner: SidecarCommandRunner = SidecarCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func resolveNodeExecutable() -> URL? {
#if DEBUG
        if let override = ProcessInfo.processInfo.environment["COPILOTFORGE_NODE_PATH"],
           FileManager.default.isExecutableFile(atPath: override) {
            let executable = URL(fileURLWithPath: override)
            if supportsRequiredBuiltins(executable: executable) {
                return executable
            }
        }
#endif

        if let bundled = Bundle.main.url(forResource: "node", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path),
           supportsRequiredBuiltins(executable: bundled) {
            return bundled
        }

#if DEBUG
        if let pathResolved = resolveNodeFromEnvironmentPATH() {
            return pathResolved
        }

        let fallbacks = [
            "/opt/homebrew/bin/node",
            "/opt/homebrew/opt/node@22/bin/node",
            "/opt/homebrew/opt/node/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
            "/opt/local/bin/node",
        ]

        for path in fallbacks where FileManager.default.isExecutableFile(atPath: path) {
            let executable = URL(fileURLWithPath: path)
            if supportsRequiredBuiltins(executable: executable) {
                return executable
            }
        }
#endif

        return nil
    }

    func nodeVersionString(executable: URL) -> String {
        let output = commandRunner.runCommand(executable: executable.path, arguments: ["-v"])
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? "unknown" : version
    }

    func supportsRequiredBuiltins(executable: URL) -> Bool {
        let script = "await import('node:sqlite');"
        let status = commandRunner.runStatus(
            executable: executable.path,
            arguments: ["--input-type=module", "-e", script]
        )
        return status == 0
    }

    private func resolveNodeFromEnvironmentPATH() -> URL? {
        guard let pathValue = ProcessInfo.processInfo.environment["PATH"], !pathValue.isEmpty else {
            return nil
        }

        let directories = pathValue
            .split(separator: ":")
            .map { String($0) }

        for directory in directories {
            let candidate = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("node", isDirectory: false)
            if FileManager.default.isExecutableFile(atPath: candidate.path),
               supportsRequiredBuiltins(executable: candidate) {
                return candidate
            }
        }

        return nil
    }
}

final class SidecarCommandRunner {
    func runCommand(executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func runStatus(executable: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
