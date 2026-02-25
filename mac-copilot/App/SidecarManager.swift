import Foundation

final class SidecarManager {
    static let shared = SidecarManager()

    private var process: Process?
    private var outputPipe: Pipe?

    private init() {}

    func startIfNeeded() {
        guard process == nil else { return }

        guard let scriptURL = resolveSidecarScriptURL() else {
            NSLog("[CopilotForge] sidecar/index.js not found in app bundle resources or local source tree")
            return
        }

        if isHealthySidecarAlreadyRunning() {
            NSLog("[CopilotForge] Existing sidecar detected on :7878, reusing it")
            return
        }

        terminateStaleSidecarProcesses(matching: scriptURL.path)

        guard let nodeExecutable = resolveNodeExecutable() else {
            NSLog("[CopilotForge] Node executable not found (expected bundled node or /opt/homebrew/bin/node or /usr/local/bin/node)")
            return
        }

        let process = Process()
        process.executableURL = nodeExecutable
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()
        process.environment = ProcessInfo.processInfo.environment

        let outputPipe = Pipe()
        self.outputPipe = outputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                NSLog("[CopilotForge][Sidecar] %@", trimmed)
            }
        }

        process.terminationHandler = { [weak self] process in
            NSLog(
                "[CopilotForge] Sidecar terminated (reason=%ld, status=%d)",
                process.terminationReason.rawValue,
                process.terminationStatus
            )

            self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
            self?.outputPipe = nil
            self?.process = nil
        }

        do {
            try process.run()
            self.process = process
            NSLog("[CopilotForge] Sidecar started at %@", scriptURL.path)
        } catch {
            NSLog("[CopilotForge] Failed to start sidecar: %@", error.localizedDescription)
        }
    }

    private func resolveSidecarScriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "index", withExtension: "js", subdirectory: "sidecar") {
            return bundled
        }

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectAppFolder = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRootFolder = projectAppFolder.deletingLastPathComponent()

        let candidatePaths = [
            projectRootFolder
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false),
            projectAppFolder
                .appendingPathComponent("sidecar", isDirectory: true)
                .appendingPathComponent("index.js", isDirectory: false),
        ]

        for candidate in candidatePaths where FileManager.default.fileExists(atPath: candidate.path) {
            NSLog("[CopilotForge] Using local sidecar source at %@", candidate.path)
            return candidate
        }

        return nil
    }

    func stop() {
        process?.terminate()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        process = nil
    }

    private func resolveNodeExecutable() -> URL? {
        if let override = ProcessInfo.processInfo.environment["COPILOTFORGE_NODE_PATH"],
           FileManager.default.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }

        if let bundled = Bundle.main.url(forResource: "node", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        let fallbacks = [
            "/opt/homebrew/bin/node",
            "/opt/homebrew/opt/node@20/bin/node",
            "/opt/homebrew/opt/node/bin/node",
            "/usr/local/bin/node",
            "/opt/local/bin/node",
        ]

        for path in fallbacks where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        if let resolvedFromPath = resolveNodeFromEnvironmentPATH() {
            return resolvedFromPath
        }

        return nil
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
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private func isHealthySidecarAlreadyRunning() -> Bool {
        guard let url = URL(string: "http://localhost:7878/health") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.0

        let semaphore = DispatchSemaphore(value: 0)
        var isHealthy = false

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }

            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  let data,
                  let body = String(data: data, encoding: .utf8),
                  body.contains("copilotforge-sidecar")
            else {
                return
            }

            isHealthy = true
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 1.2)
        return isHealthy
    }

    private func terminateStaleSidecarProcesses(matching scriptPath: String) {
        let pidsOutput = runCommand(executable: "/usr/sbin/lsof", arguments: ["-nP", "-iTCP:7878", "-sTCP:LISTEN", "-t"])
        let pids = pidsOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pids.isEmpty else { return }

        for pid in pids {
            let commandLine = runCommand(executable: "/bin/ps", arguments: ["-p", pid, "-o", "command="])
            let normalized = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)

            guard normalized.contains("node"),
                  (normalized.contains(scriptPath) || normalized.contains("sidecar/index.js"))
            else {
                continue
            }

            _ = runCommand(executable: "/bin/kill", arguments: ["-TERM", pid])
            NSLog("[CopilotForge] Terminated stale sidecar process pid=%@", pid)
        }

        Thread.sleep(forTimeInterval: 0.2)
    }

    private func runCommand(executable: String, arguments: [String]) -> String {
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
}
